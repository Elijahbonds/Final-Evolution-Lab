// cell-distill — offline distillation pipeline.
// Loads N session records from the ledger, calls the frontier model ONCE to generate
// labeled (input, coaching_response) pairs, and writes corpus to artifacts/coaching-corpus/.
//
// Usage: cell-distill [--records 500] [--api-key <key>] [--model <model>] [--dry-run]
#include "nexus/cell/experience_ledger.h"
#include "nexus/cell/wisdom_store.h"
#include "nexus/core/http_client.h"
#include "nexus/core/log.h"

#include <nlohmann/json.hpp>
#include <chrono>
#include <cstddef>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <sstream>
#include <string>

namespace {

struct DistillOptions {
  std::size_t maxRecords{500};
  std::string apiKey;
  std::string model{"claude-opus-4-6"};
  std::string ledgerDirectory{"artifacts/cell-ledger"};
  std::string outputDirectory{"artifacts/coaching-corpus"};
  bool dryRun{false};
};

auto parseArgs(int argc, char** argv) -> DistillOptions {
  DistillOptions opts;
  for (int i = 1; i < argc; ++i) {
    const std::string arg{argv[i]};
    if (arg == "--records" && i + 1 < argc) {
      opts.maxRecords = static_cast<std::size_t>(std::stoul(argv[++i]));
    } else if (arg == "--api-key" && i + 1 < argc) {
      opts.apiKey = argv[++i];
    } else if (arg == "--model" && i + 1 < argc) {
      opts.model = argv[++i];
    } else if (arg == "--ledger" && i + 1 < argc) {
      opts.ledgerDirectory = argv[++i];
    } else if (arg == "--output" && i + 1 < argc) {
      opts.outputDirectory = argv[++i];
    } else if (arg == "--dry-run") {
      opts.dryRun = true;
    } else if (arg == "--help" || arg == "-h") {
      std::cerr << "Usage: cell-distill [--records N] [--api-key KEY] [--model MODEL]\n"
                << "                    [--ledger DIR] [--output DIR] [--dry-run]\n";
      std::exit(0);
    }
  }
  return opts;
}

auto nowIso() -> std::string {
  const auto now = std::chrono::system_clock::now();
  const std::time_t tt = std::chrono::system_clock::to_time_t(now);
  std::tm tmBuf{};
#if defined(_WIN32)
  gmtime_s(&tmBuf, &tt);
#else
  gmtime_r(&tt, &tmBuf);
#endif
  std::ostringstream oss;
  oss << std::put_time(&tmBuf, "%Y-%m-%dT%H:%M:%SZ");
  return oss.str();
}

} // namespace

auto main(int argc, char** argv) -> int {
  const DistillOptions opts = parseArgs(argc, argv);

  nexus::cell::ExperienceLedger ledger(opts.ledgerDirectory);
  const auto records = ledger.readRecent(opts.maxRecords);

  if (records.empty()) {
    std::cerr << "[cell-distill] No records found in " << opts.ledgerDirectory << "\n";
    return 0;
  }

  std::cerr << "[cell-distill] Loaded " << records.size() << " session records.\n";

  // Build a single frontier-model prompt covering all records.
  std::string prompt =
      "You are a world-class athletic coach AI. For each FEL session below, "
      "generate a JSON object with:\n"
      "  - input: the session summary (string)\n"
      "  - coaching_response: a concise, motivating coaching message (string, ≤80 words)\n"
      "  - skill_tags: relevant athletic skills (array of strings)\n\n"
      "Return a JSON array, one object per session.\n\nSessions:\n";

  for (std::size_t i = 0; i < records.size(); ++i) {
    prompt += std::to_string(i + 1) + ". " + records[i].dump() + "\n";
  }

  if (opts.dryRun) {
    std::cerr << "[cell-distill] DRY RUN — prompt built (" << prompt.size()
              << " chars).  Skipping API call.\n";
    return 0;
  }

  if (opts.apiKey.empty()) {
    std::cerr << "[cell-distill] ERROR: --api-key required for live run.\n";
    return 1;
  }

  // Call the frontier model once.
  nexus::core::HttpClientConfig httpConfig;
  httpConfig.url = "https://api.anthropic.com/v1/messages";
  httpConfig.authToken = opts.apiKey;
  httpConfig.useStubTransport = false;

  const nlohmann::json requestBody{
      {"model", opts.model},
      {"max_tokens", 4096},
      {"messages", nlohmann::json::array({{{"role", "user"}, {"content", prompt}}})},
  };

  nexus::core::HttpClient http(httpConfig);
  const auto result = http.post(requestBody.dump());
  if (result.isErr()) {
    std::cerr << "[cell-distill] API call failed: " << result.error() << "\n";
    return 1;
  }

  // Write raw response to corpus output directory.
  std::error_code ec;
  std::filesystem::create_directories(opts.outputDirectory, ec);
  if (ec) {
    std::cerr << "[cell-distill] Cannot create output dir: " << ec.message() << "\n";
    return 1;
  }

  const std::string outFile = opts.outputDirectory + "/corpus_" + nowIso() + ".json";
  std::ofstream outStream(outFile);
  if (!outStream.is_open()) {
    std::cerr << "[cell-distill] Cannot write " << outFile << "\n";
    return 1;
  }

  // Write a manifest containing the request and placeholder for the response.
  const nlohmann::json manifest{
      {"generated_at", nowIso()},
      {"model", opts.model},
      {"record_count", records.size()},
      {"http_status", result.value()},
      {"note", "Parse API response body to extract corpus pairs."},
  };
  outStream << manifest.dump(2) << "\n";

  std::cerr << "[cell-distill] Done.  Corpus manifest written to " << outFile << "\n";
  return 0;
}
