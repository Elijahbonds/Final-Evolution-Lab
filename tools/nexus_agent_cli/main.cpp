#include "agent_cli_session.h"
#include "agent_http_listener.h"

#include "nexus/ai/command_schema.h"
#include "nexus/core/log.h"

#include <cstdlib>
#include <fstream>
#include <iostream>
#include <string>
#include <string_view>
#include <unistd.h>
#include <vector>

#include <nlohmann/json.hpp>

namespace {

struct CliOptions {
  bool serveHttp{false};
  bool batchMode{false};
  bool verbose{false};
  std::uint16_t httpPort{8765};
  std::size_t queueBudget{8};
  std::string importRoot{"assets/nexus/imported"};
  std::string manifestPath{"assets/nexus/manifests/nexus_asset_manifest.json"};
  std::string jsonArg;
  std::string fileArg;
};

auto parseArgs(int argc, char** argv) -> CliOptions {
  CliOptions options;
  for (int index = 1; index < argc; ++index) {
    const std::string_view arg{argv[index]};
    if (arg == "--serve-http") {
      options.serveHttp = true;
    } else if (arg == "--port" && index + 1 < argc) {
      options.httpPort = static_cast<std::uint16_t>(std::stoi(argv[++index]));
    } else if (arg == "--queue-budget" && index + 1 < argc) {
      options.queueBudget = static_cast<std::size_t>(std::stoul(argv[++index]));
    } else if (arg == "--import-root" && index + 1 < argc) {
      options.importRoot = argv[++index];
    } else if (arg == "--manifest" && index + 1 < argc) {
      options.manifestPath = argv[++index];
    } else if (arg == "--json" && index + 1 < argc) {
      options.batchMode = true;
      options.jsonArg = argv[++index];
    } else if (arg == "--file" && index + 1 < argc) {
      options.batchMode = true;
      options.fileArg = argv[++index];
    } else if (arg == "--verbose" || arg == "-v") {
      options.verbose = true;
    } else if (arg == "--help" || arg == "-h") {
      std::cerr
          << "Usage: nexus_agent_cli [--json '{...}'] [--file path.json]\n"
          << "                       [--serve-http] [--port 8765] [--queue-budget 8]\n"
          << "                       [--verbose]\n"
          << "                       [--import-root assets/nexus/imported]\n"
          << "                       [--manifest assets/nexus/manifests/nexus_asset_manifest.json]\n"
          << "\n"
          << "Batch mode (--json/--file): one JSON object or {\"messages\":[...]}; prints JSON array.\n"
          << "Line mode (default): newline-delimited JSON on stdin; one response line per input.\n"
          << "HTTP mode (--serve-http): POST http://127.0.0.1:8765/nexus/agent for Cursor MCP.\n";
      std::exit(0);
    }
  }
  return options;
}

auto readBatchInput(const CliOptions& options) -> std::string {
  if (!options.jsonArg.empty()) {
    return options.jsonArg;
  }
  if (!options.fileArg.empty()) {
    std::ifstream input{options.fileArg};
    return {std::istreambuf_iterator<char>(input), std::istreambuf_iterator<char>()};
  }
  return {std::istreambuf_iterator<char>(std::cin), std::istreambuf_iterator<char>()};
}

auto collectBatchMessages(const nlohmann::json& parsed) -> std::vector<std::string> {
  std::vector<std::string> messages;
  if (parsed.is_array()) {
    for (const auto& entry : parsed) {
      messages.push_back(entry.dump());
    }
    return messages;
  }
  if (parsed.is_object() && parsed.contains("messages") && parsed["messages"].is_array()) {
    for (const auto& entry : parsed["messages"]) {
      messages.push_back(entry.dump());
    }
    return messages;
  }
  if (parsed.is_object()) {
    messages.push_back(parsed.dump());
  }
  return messages;
}

auto writeLineResponses(const std::vector<nexus::ai::AgentResponse>& responses) -> void {
  for (const nexus::ai::AgentResponse& response : responses) {
    std::cout << response.serialize().dump() << '\n';
  }
  std::cout.flush();
}

auto runBatchMode(nexus::tools::AgentCliSession& session, const CliOptions& options) -> int {
  const std::string jsonInput = readBatchInput(options);
  if (jsonInput.empty()) {
    std::cout << R"([{"status":"error","error":"Empty input; pass --json or stdin"}])" << '\n';
    return 1;
  }

  const nlohmann::json parsed = nlohmann::json::parse(jsonInput, nullptr, false);
  if (parsed.is_discarded()) {
    std::cout << R"([{"status":"error","error":"Invalid JSON"}])" << '\n';
    return 1;
  }

  const std::vector<std::string> messages = collectBatchMessages(parsed);
  if (messages.empty()) {
    std::cout << R"([{"status":"error","error":"Expected agent message object or messages array"}])"
              << '\n';
    return 1;
  }

  nlohmann::json responses = nlohmann::json::array();
  for (const std::string& message : messages) {
    for (const nexus::ai::AgentResponse& response : session.dispatchLine(message)) {
      responses.push_back(response.serialize());
    }
  }

  std::cout << responses.dump(2) << '\n';
  return responses.empty() ? 1 : 0;
}

} // namespace

auto main(int argc, char** argv) -> int {
  const CliOptions options = parseArgs(argc, argv);
  if (options.verbose) {
    setenv("NEXUS_LOG_VERBOSE", "1", 1);
  }

  nexus::tools::AgentCliSession session({
      .queueBudget = options.queueBudget,
      .importRoot = options.importRoot,
      .manifestPath = options.manifestPath,
  });

  const auto initResult = session.init();
  if (initResult.isErr()) {
    NEXUS_LOG_ERROR(nexus::LogChannel::kAI, initResult.error());
    return 1;
  }

  int exitCode = 0;
  if (options.serveHttp) {
    nexus::tools::AgentHttpListener listener([&session](std::string_view body) {
      return session.dispatchLine(body);
    });
    const auto serveResult =
        listener.serve({.port = options.httpPort, .path = "/nexus/agent"});
    if (serveResult.isErr()) {
      NEXUS_LOG_ERROR(nexus::LogChannel::kAI, serveResult.error());
      exitCode = 1;
    }
  } else if (options.batchMode || !options.jsonArg.empty() || !options.fileArg.empty()) {
    exitCode = runBatchMode(session, options);
  } else if (!isatty(STDIN_FILENO)) {
    std::string line;
    while (std::getline(std::cin, line)) {
      if (options.verbose) {
        std::cerr << "[verbose] stdin: " << line << '\n';
      }
      writeLineResponses(session.dispatchLine(line));
    }
  } else {
    std::cerr << "nexus_agent_cli: no input (use --json, pipe stdin, or --serve-http)\n";
    exitCode = 1;
  }

  session.shutdown();
  return exitCode;
}
