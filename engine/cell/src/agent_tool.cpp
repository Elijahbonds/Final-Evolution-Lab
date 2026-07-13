#include "nexus/cell/agent_tool.h"

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdio>
#include <filesystem>
#include <fstream>
#include <sstream>

namespace nexus::cell {

namespace {

auto nowMs() -> double {
  using namespace std::chrono;
  return static_cast<double>(
      duration_cast<microseconds>(steady_clock::now().time_since_epoch()).count()) / 1000.0;
}

/// Run a shell command and capture stdout.  Returns {ok, stdout, stderr}.
struct ExecResult { bool ok; std::string out; std::string err; };

auto shellExec(const std::string& cmd, std::uint32_t timeout_ms,
               std::uint32_t max_bytes) -> ExecResult {
  // Build a timeout-wrapped command (uses `timeout` on Linux/macOS).
  const double timeout_sec = static_cast<double>(timeout_ms) / 1000.0;
  const std::string full_cmd =
      "timeout " + std::to_string(timeout_sec) + " sh -c " +
      "\"" + cmd + "\" 2>/tmp/nexus_agent_tool_stderr";

  ExecResult result{};

  std::FILE* pipe = ::popen(full_cmd.c_str(), "r");
  if (!pipe) {
    result.err = "popen failed";
    return result;
  }

  std::string out;
  std::array<char, 1024> buf{};
  while (std::fgets(buf.data(), static_cast<int>(buf.size()), pipe)) {
    out += buf.data();
    if (out.size() > max_bytes) {
      out.resize(max_bytes);
      out += "\n[truncated]";
      break;
    }
  }

  const int rc = ::pclose(pipe);
  result.ok  = (rc == 0);
  result.out = std::move(out);

  // Read stderr capture
  std::ifstream ef("/tmp/nexus_agent_tool_stderr");
  if (ef) {
    std::ostringstream ss;
    ss << ef.rdbuf();
    result.err = ss.str();
    if (result.err.size() > 2048) {
      result.err.resize(2048);
      result.err += "\n[truncated]";
    }
  }

  return result;
}

/// Escape a string for single-quoted shell usage.
auto shellEscape(const std::string& s) -> std::string {
  std::string out;
  out.reserve(s.size() + 2);
  out += '\'';
  for (char c : s) {
    if (c == '\'') { out += "'\\''"; }
    else           { out += c; }
  }
  out += '\'';
  return out;
}

} // namespace

// ── GitTool ───────────────────────────────────────────────────────────────────

GitTool::GitTool(GitToolConfig config) : m_config(std::move(config)) {}

auto GitTool::description() const -> std::string {
  return "Run safe git commands in the NEXUS repo (status, diff, log, show, branch"
         + std::string(m_config.allow_write ? ", add, commit" : "") + ").";
}

auto GitTool::execute(const nlohmann::json& params) const -> ToolResult {
  const std::string subcmd = params.value("subcommand", "status");

  // Allowlist of safe subcommands
  static const std::vector<std::string> kReadOnly = {
      "status", "diff", "log", "show", "branch", "rev-parse",
      "shortlog", "stash", "describe"};
  static const std::vector<std::string> kWrite = {"add", "commit"};

  const bool isReadOnly = std::find(kReadOnly.begin(), kReadOnly.end(), subcmd) != kReadOnly.end();
  const bool isWrite    = std::find(kWrite.begin(), kWrite.end(), subcmd) != kWrite.end();

  if (!isReadOnly && !(isWrite && m_config.allow_write)) {
    return ToolResult{false, "", "git subcommand '" + subcmd + "' not allowed"};
  }

  // Build argument string safely
  std::string args;
  if (params.contains("args") && params["args"].is_string()) {
    // Accept pre-formatted args string (no shell expansion of user-controlled args)
    const std::string raw = params["args"].get<std::string>();
    // Strip any attempts at injection
    if (raw.find(';') != std::string::npos ||
        raw.find('&') != std::string::npos ||
        raw.find('`') != std::string::npos ||
        raw.find('$') != std::string::npos) {
      return ToolResult{false, "", "injection characters not allowed in args"};
    }
    args = raw;
  }

  const std::string cmd = "cd " + shellEscape(m_config.repo_root) +
                          " && git " + subcmd + " " + args;
  const double t0 = nowMs();
  auto ex = shellExec(cmd, 15000, m_config.max_output_bytes);
  const double dur = nowMs() - t0;

  return ToolResult{ex.ok, ex.out, ex.err, dur};
}

// ── TerminalTool ──────────────────────────────────────────────────────────────

TerminalTool::TerminalTool(TerminalToolConfig config) : m_config(std::move(config)) {}

auto TerminalTool::description() const -> std::string {
  return "Run whitelisted read-only shell commands (cat, ls, grep, find, head, tail, wc, echo).";
}

auto TerminalTool::execute(const nlohmann::json& params) const -> ToolResult {
  const std::string command_line = params.value("command", "");
  if (command_line.empty()) {
    return ToolResult{false, "", "command param required"};
  }

  // Extract the binary name (first word)
  std::string binary;
  {
    std::istringstream iss(command_line);
    iss >> binary;
    // Strip path prefix for allowlist check
    const auto slash = binary.rfind('/');
    if (slash != std::string::npos) {
      binary = binary.substr(slash + 1);
    }
  }

  const bool allowed = std::find(m_config.command_allowlist.begin(),
                                  m_config.command_allowlist.end(),
                                  binary) != m_config.command_allowlist.end();
  if (!allowed) {
    return ToolResult{false, "", "command '" + binary + "' not in allowlist"};
  }

  // Basic injection guard
  if (command_line.find(';') != std::string::npos ||
      command_line.find('&') != std::string::npos ||
      command_line.find('`') != std::string::npos) {
    return ToolResult{false, "", "shell metacharacters not allowed"};
  }

  const std::string full_cmd =
      "cd " + shellEscape(m_config.working_dir) + " && " + command_line;

  const double t0 = nowMs();
  auto ex = shellExec(full_cmd, m_config.timeout_ms, m_config.max_output_bytes);
  const double dur = nowMs() - t0;

  return ToolResult{ex.ok, ex.out, ex.err, dur};
}

// ── IdeFileTool ───────────────────────────────────────────────────────────────

IdeFileTool::IdeFileTool(IdeFileToolConfig config) : m_config(std::move(config)) {}

auto IdeFileTool::description() const -> std::string {
  return "Read a file within the NEXUS repo root (sandbox-safe, max 128 KB).";
}

auto IdeFileTool::execute(const nlohmann::json& params) const -> ToolResult {
  const std::string rel_path = params.value("path", "");
  if (rel_path.empty()) {
    return ToolResult{false, "", "path param required"};
  }

  // Sandbox: no absolute paths, no traversal
  if (rel_path.front() == '/' || rel_path.find("..") != std::string::npos) {
    return ToolResult{false, "", "path must be relative and within the repo"};
  }

  namespace fs = std::filesystem;
  const fs::path root  = fs::path(m_config.repo_root);
  const fs::path full  = root / rel_path;

  // Re-check canonical path to prevent symlink escapes
  std::error_code ec;
  const fs::path canonical = fs::weakly_canonical(full, ec);
  if (ec || canonical.string().find(fs::weakly_canonical(root, ec).string()) != 0) {
    return ToolResult{false, "", "path escapes repo root"};
  }

  if (!fs::exists(full, ec) || fs::is_directory(full, ec)) {
    return ToolResult{false, "", "file not found: " + rel_path};
  }

  std::ifstream file(full);
  if (!file) {
    return ToolResult{false, "", "cannot open: " + rel_path};
  }

  const double t0 = nowMs();
  std::string content;
  {
    std::ostringstream ss;
    ss << file.rdbuf();
    content = ss.str();
  }
  const double dur = nowMs() - t0;

  if (content.size() > m_config.max_bytes) {
    content.resize(m_config.max_bytes);
    content += "\n[truncated]";
  }

  // Optional line limit
  if (params.contains("max_lines") && params["max_lines"].is_number_integer()) {
    const int max_lines = params["max_lines"].get<int>();
    if (max_lines > 0) {
      int lines = 0;
      std::size_t pos = 0;
      while (pos < content.size()) {
        pos = content.find('\n', pos);
        if (pos == std::string::npos) { break; }
        ++lines;
        ++pos;
        if (lines >= max_lines) {
          content = content.substr(0, pos);
          content += "\n[truncated at " + std::to_string(max_lines) + " lines]";
          break;
        }
      }
    }
  }

  return ToolResult{true, content, "", dur};
}

// ── AgentToolRegistry ─────────────────────────────────────────────────────────

void AgentToolRegistry::registerTool(std::unique_ptr<AgentTool> tool) {
  m_tools[tool->name()] = std::move(tool);
}

auto AgentToolRegistry::tool(const std::string& name) const -> const AgentTool* {
  const auto it = m_tools.find(name);
  return (it != m_tools.end()) ? it->second.get() : nullptr;
}

auto AgentToolRegistry::names() const -> std::vector<std::string> {
  std::vector<std::string> result;
  result.reserve(m_tools.size());
  for (const auto& [k, _] : m_tools) { result.push_back(k); }
  return result;
}

} // namespace nexus::cell
