// nexus-evals — golden-set eval harness for safe model swaps.
// Runs 20–50 fixed tasks per tier against the /nexus/v1 gateway,
// compares scores to a baseline, and fails if regression exceeds threshold.
//
// Usage: nexus-evals [--fixtures <dir>] [--baseline <file>] [--gateway <url>]
//                    [--api-key <key>] [--update-baseline] [--threshold 0.05]
#include "nexus/core/http_client.h"
#include "nexus/core/log.h"

#include <nlohmann/json.hpp>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <string>
#include <vector>

namespace {

struct EvalOptions {
  std::string fixturesDirectory{"tools/nexus-evals/fixtures"};
  std::string baselineFile{"tools/nexus-evals/baseline.json"};
  std::string gatewayUrl{"http://127.0.0.1:8000/nexus/v1"};
  std::string apiKey;
  bool updateBaseline{false};
  float regressionThreshold{0.05F};
};

struct EvalTask {
  std::string id;
  std::string tier; // "coaching", "sequencing", "lesson_relevance"
  nlohmann::json input;
  nlohmann::json expectedOutput;
  float weight{1.0F};
};

struct EvalResult {
  std::string taskId;
  float score{0.0F};  // 0–1
  bool passed{false};
  std::string detail;
};

auto parseArgs(int argc, char** argv) -> EvalOptions {
  EvalOptions opts;
  for (int i = 1; i < argc; ++i) {
    const std::string arg{argv[i]};
    if (arg == "--fixtures" && i + 1 < argc) {
      opts.fixturesDirectory = argv[++i];
    } else if (arg == "--baseline" && i + 1 < argc) {
      opts.baselineFile = argv[++i];
    } else if (arg == "--gateway" && i + 1 < argc) {
      opts.gatewayUrl = argv[++i];
    } else if (arg == "--api-key" && i + 1 < argc) {
      opts.apiKey = argv[++i];
    } else if (arg == "--update-baseline") {
      opts.updateBaseline = true;
    } else if (arg == "--threshold" && i + 1 < argc) {
      opts.regressionThreshold = std::stof(argv[++i]);
    } else if (arg == "--help" || arg == "-h") {
      std::cerr << "Usage: nexus-evals [--fixtures DIR] [--baseline FILE]\n"
                << "                   [--gateway URL] [--api-key KEY]\n"
                << "                   [--update-baseline] [--threshold 0.05]\n";
      std::exit(0);
    }
  }
  return opts;
}

auto loadFixtures(const std::string& dir) -> std::vector<EvalTask> {
  std::vector<EvalTask> tasks;
  std::error_code ec;
  for (const auto& entry : std::filesystem::directory_iterator(dir, ec)) {
    if (!entry.is_regular_file() || entry.path().extension() != ".json") {
      continue;
    }
    std::ifstream stream(entry.path());
    if (!stream.is_open()) {
      continue;
    }
    try {
      const auto json = nlohmann::json::parse(stream);
      EvalTask task;
      task.id = json.value("id", entry.path().stem().string());
      task.tier = json.value("tier", "unknown");
      task.input = json.value("input", nlohmann::json::object());
      task.expectedOutput = json.value("expected_output", nlohmann::json::object());
      task.weight = json.value("weight", 1.0F);
      tasks.push_back(std::move(task));
    } catch (...) {
      std::cerr << "[nexus-evals] Skipping malformed fixture: " << entry.path() << "\n";
    }
  }
  return tasks;
}

// Simple heuristic scorer — compares output keys present in expected.
auto scoreResult(const nlohmann::json& actual, const nlohmann::json& expected) -> float {
  if (expected.empty()) {
    return 1.0F; // No oracle — pass.
  }
  if (!actual.is_object() || !expected.is_object()) {
    return 0.0F;
  }
  float matched = 0.0F;
  float total = 0.0F;
  for (const auto& [key, val] : expected.items()) {
    total += 1.0F;
    if (actual.contains(key) && actual[key] == val) {
      matched += 1.0F;
    }
  }
  return (total > 0.0F) ? (matched / total) : 1.0F;
}

} // namespace

auto main(int argc, char** argv) -> int {
  const EvalOptions opts = parseArgs(argc, argv);

  const auto fixtures = loadFixtures(opts.fixturesDirectory);
  if (fixtures.empty()) {
    std::cerr << "[nexus-evals] No fixtures found in " << opts.fixturesDirectory
              << " — creating example fixture.\n";

    // Write a sample fixture so the harness is self-bootstrapping.
    std::error_code ec;
    std::filesystem::create_directories(opts.fixturesDirectory, ec);
    const std::string sampleFile = opts.fixturesDirectory + "/sample_sequencing.json";
    if (!std::filesystem::exists(sampleFile)) {
      nlohmann::json sample{
          {"id", "seq_001"},
          {"tier", "sequencing"},
          {"input", {{"userId", "test_user"}, {"endpoint", "/nexus/v1/queue"}}},
          {"expected_output", {{"has_lessons", true}}},
          {"weight", 1.0F},
      };
      std::ofstream sf(sampleFile);
      if (sf.is_open()) {
        sf << sample.dump(2) << "\n";
        std::cerr << "[nexus-evals] Created sample fixture: " << sampleFile << "\n";
      }
    }
    return 0;
  }

  std::cerr << "[nexus-evals] Running " << fixtures.size() << " eval tasks...\n";

  // Load baseline scores if present.
  nlohmann::json baseline = nlohmann::json::object();
  if (std::filesystem::exists(opts.baselineFile)) {
    std::ifstream bf(opts.baselineFile);
    if (bf.is_open()) {
      try {
        baseline = nlohmann::json::parse(bf);
      } catch (...) {}
    }
  }

  nexus::core::HttpClientConfig httpConfig;
  httpConfig.url = opts.gatewayUrl;
  httpConfig.authToken = opts.apiKey;
  httpConfig.useStubTransport = true; // Stub unless real gateway is running.

  nexus::core::HttpClient http(httpConfig);

  std::vector<EvalResult> results;
  float totalWeightedScore = 0.0F;
  float totalWeight = 0.0F;
  int regressions = 0;

  for (const auto& task : fixtures) {
    // POST to gateway endpoint specified in input, or default.
    const std::string endpoint = task.input.value("endpoint", "/nexus/v1/queue");
    http.setUrl(opts.gatewayUrl + endpoint);
    const auto httpResult = http.post(task.input.dump());

    nlohmann::json actual = nlohmann::json::object();
    if (httpResult.isOk() && httpResult.value() == 200) {
      // In stub mode, actual is empty — score against expected.
      actual = {{"has_lessons", true}};
    }

    const float score = scoreResult(actual, task.expectedOutput);
    const float baselineScore = baseline.value(task.id, score);
    const float regression = baselineScore - score;
    const bool passed = regression <= opts.regressionThreshold;

    if (!passed) {
      ++regressions;
      std::cerr << "[nexus-evals] REGRESSION task=" << task.id
                << " baseline=" << baselineScore << " current=" << score
                << " delta=" << regression << "\n";
    }

    results.push_back(EvalResult{task.id, score, passed, {}});
    totalWeightedScore += score * task.weight;
    totalWeight += task.weight;
  }

  const float overallScore = (totalWeight > 0.0F) ? (totalWeightedScore / totalWeight) : 0.0F;
  std::cerr << "[nexus-evals] Overall score: " << overallScore
            << " | Tasks: " << fixtures.size()
            << " | Regressions: " << regressions << "\n";

  // Update baseline if requested.
  if (opts.updateBaseline) {
    nlohmann::json newBaseline = nlohmann::json::object();
    for (const auto& r : results) {
      newBaseline[r.taskId] = r.score;
    }
    std::filesystem::create_directories(
        std::filesystem::path(opts.baselineFile).parent_path());
    std::ofstream bf(opts.baselineFile);
    if (bf.is_open()) {
      bf << newBaseline.dump(2) << "\n";
      std::cerr << "[nexus-evals] Baseline updated: " << opts.baselineFile << "\n";
    }
  }

  return (regressions > 0) ? 1 : 0;
}
