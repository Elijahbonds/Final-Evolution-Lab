#pragma once

// CELL Agent Tool — Zero-Cost Local Tool Interface
//
// Provides a typed tool-call surface for the CELL AgentExecutor.
// All tool execution is local (no API calls, no tokens) — the agent
// is cost-free and offline-capable.
//
// Concrete tools:
//   GitTool       — safe read-only and write git operations
//   TerminalTool  — whitelisted shell commands (read-only by default)
//   IdeFileTool   — repo-file read (bounded, sandbox-safe)
//
// Each tool validates inputs against an allowlist before executing to
// prevent command-injection or path-escape attacks.

#include <nlohmann/json.hpp>

#include <cstdint>
#include <memory>
#include <string>
#include <unordered_map>
#include <vector>

namespace nexus::cell {

// ── Tool result ───────────────────────────────────────────────────────────────

struct ToolResult {
  bool        ok{false};
  std::string output;   ///< stdout / content on success
  std::string error;    ///< error message on failure
  double      duration_ms{0.0};
};

// ── Abstract tool interface ───────────────────────────────────────────────────

class AgentTool {
public:
  virtual ~AgentTool() = default;

  [[nodiscard]] virtual auto name()        const -> std::string = 0;
  [[nodiscard]] virtual auto description() const -> std::string = 0;

  /// Execute the tool with JSON params.  Must be thread-safe.
  [[nodiscard]] virtual auto execute(const nlohmann::json& params) const -> ToolResult = 0;
};

// ── Git tool ─────────────────────────────────────────────────────────────────
//
// Allowed commands: status, diff, log, show, branch, add, commit
// (commit requires explicit allow_write = true in config)

struct GitToolConfig {
  std::string repo_root{"."};
  bool        allow_write{false}; ///< Enable add/commit; push is never allowed
  std::uint32_t max_output_bytes{65536};
};

class GitTool : public AgentTool {
public:
  explicit GitTool(GitToolConfig config = {});

  [[nodiscard]] auto name()        const -> std::string override { return "git"; }
  [[nodiscard]] auto description() const -> std::string override;
  [[nodiscard]] auto execute(const nlohmann::json& params) const -> ToolResult override;

private:
  GitToolConfig m_config;
};

// ── Terminal tool ─────────────────────────────────────────────────────────────
//
// Executes whitelisted commands only.  The allowlist is fixed at construction.
// Default allowlist: cat, head, tail, ls, find, grep, wc, echo, pwd

struct TerminalToolConfig {
  std::string              working_dir{"."};
  std::vector<std::string> command_allowlist{"cat", "head", "tail", "ls",
                                              "find", "grep", "wc",  "echo",
                                              "pwd",  "date",  "env", "which"};
  std::uint32_t max_output_bytes{65536};
  std::uint32_t timeout_ms{10000};
};

class TerminalTool : public AgentTool {
public:
  explicit TerminalTool(TerminalToolConfig config = {});

  [[nodiscard]] auto name()        const -> std::string override { return "terminal"; }
  [[nodiscard]] auto description() const -> std::string override;
  [[nodiscard]] auto execute(const nlohmann::json& params) const -> ToolResult override;

private:
  TerminalToolConfig m_config;
};

// ── IDE file tool ─────────────────────────────────────────────────────────────
//
// Read-only access to files under repo_root.  Enforces path sandbox.
// params: { "path": "repo/relative/path", "max_lines": 500 }

struct IdeFileToolConfig {
  std::string   repo_root{"."};
  std::uint32_t max_bytes{131072}; ///< 128 KB read cap
};

class IdeFileTool : public AgentTool {
public:
  explicit IdeFileTool(IdeFileToolConfig config = {});

  [[nodiscard]] auto name()        const -> std::string override { return "ide_file"; }
  [[nodiscard]] auto description() const -> std::string override;
  [[nodiscard]] auto execute(const nlohmann::json& params) const -> ToolResult override;

private:
  IdeFileToolConfig m_config;
};

// ── Tool registry ─────────────────────────────────────────────────────────────

class AgentToolRegistry {
public:
  void registerTool(std::unique_ptr<AgentTool> tool);

  [[nodiscard]] auto tool(const std::string& name) const -> const AgentTool*;
  [[nodiscard]] auto names() const -> std::vector<std::string>;

private:
  std::unordered_map<std::string, std::unique_ptr<AgentTool>> m_tools;
};

} // namespace nexus::cell
