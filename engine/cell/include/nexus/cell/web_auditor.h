#pragma once

// CELL Web Auditor — Browser-Based App Critique Agent
//
// Drives the MCP `web_audit` tool (Playwright/Chromium) to open URLs, follow
// login flows, interact with web apps, and collect structured findings.
// Each finding is pushed into ObservationBus as a kWebAudit observation so
// the ResearchLoop can build WisdomStore entries about app quality over time.
//
// Typical usage:
//   1. Caller calls auditNow() (or CELL handles "cell.web_audit_now" command).
//   2. WebAuditor shells out to the nexus-cursor-mcp `web_audit` tool via CLI
//      (or reads the last written artifact when the MCP server already ran it).
//   3. The resulting JSON report at WebAuditConfig::artifact_path is parsed and
//      each finding is pushed as an Observation onto the bus.
//   4. ResearchLoop harvests those observations in the normal cycle.
//
// Threading:
//   start() launches a background thread that polls artifact_path every
//   poll_interval seconds for new reports, pushing any unseen ones into the bus.
//   auditNow() additionally triggers the MCP tool synchronously and then polls
//   immediately.  All public methods are thread-safe.
//
// Stub mode:
//   Set WebAuditConfig::stub_mode = true — or any of the env vars
//   NEXUS_WEB_AUDIT_STUB / NEXUS_HEADLESS / CI to a truthy value — to skip
//   Playwright and return a canned report. Graceful default for unit tests
//   and headless CI: no browser or subprocess is ever launched there.
//
// Hardening:
//   Artifact files larger than 8 MiB are rejected before reading; parsed
//   reports are capped at 500 findings with bounded message/category sizes;
//   the MCP CLI path and URL are validated against a shell-safe character
//   allowlist before any subprocess is spawned.

#include "nexus/cell/observation_bus.h"

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstdint>
#include <mutex>
#include <string>
#include <thread>
#include <unordered_map>
#include <vector>

namespace nexus::cell {

// ── Finding severity ──────────────────────────────────────────────────────────

enum class AuditSeverity : std::uint8_t {
  kInfo,     ///< Informational — no action required
  kWarning,  ///< Should be fixed, not blocking
  kError,    ///< Functional failure or broken flow
  kCritical, ///< Login failure or data loss risk
};

inline auto auditSeverityName(AuditSeverity s) -> const char* {
  switch (s) {
  case AuditSeverity::kInfo:     return "info";
  case AuditSeverity::kWarning:  return "warning";
  case AuditSeverity::kError:    return "error";
  case AuditSeverity::kCritical: return "critical";
  }
  return "info";
}

// ── Single finding from an audit run ─────────────────────────────────────────

struct WebAuditFinding {
  /// Category tag: "login", "ux", "performance", "accessibility", "error"
  std::string   category;
  AuditSeverity severity{AuditSeverity::kInfo};
  std::string   message;
  std::string   url;           ///< URL where the finding occurred (may be empty)
  std::string   screenshot_b64; ///< Base64-encoded PNG (may be empty)
  double        value{0.0};    ///< Optional numeric metric (e.g., LCP ms, CLS score)
};

// ── One complete audit report ─────────────────────────────────────────────────

struct WebAuditReport {
  std::string                url;           ///< Top-level URL audited
  bool                       login_ok{false};
  std::string                page_title;
  double                     load_time_ms{0.0};
  std::uint64_t              timestamp_ms{0};
  std::vector<WebAuditFinding> findings;
  std::string                raw_json;      ///< Original JSON text (for dedup hash)
};

// ── Audit step (scripted interactions) ───────────────────────────────────────

struct AuditStep {
  /// Action: "navigate" | "click" | "fill" | "assert_text" | "screenshot"
  std::string action;
  std::string selector;  ///< CSS selector or text match (for click/fill/assert_text)
  std::string value;     ///< Text to fill or expected text for assert_text
  std::string url;       ///< Target URL for navigate action
};

// ── Configuration ─────────────────────────────────────────────────────────────

struct WebAuditConfig {
  /// Top-level URL to audit.
  std::string url;

  /// Login credentials (email / password keys).  Leave empty to skip login.
  std::unordered_map<std::string, std::string> credentials;

  /// Optional scripted steps to execute after the initial page load / login.
  std::vector<AuditStep> steps;

  /// Path where the MCP web_audit tool writes its JSON report.
  std::string artifact_path{"artifacts/web-audit/latest.json"};

  /// Path to the nexus-cursor-mcp binary or launch script used to trigger an
  /// audit from C++.  If empty, only the artifact polling path is used.
  std::string mcp_cli_path{"tools/nexus-cursor-mcp/dist/index.js"};

  /// Polling interval for new artifact files.
  std::chrono::seconds poll_interval{60};

  /// When true (or env NEXUS_WEB_AUDIT_STUB=1), no browser is launched;
  /// a canned report is injected instead.  For tests and headless CI.
  bool stub_mode{false};
};

// ── WebAuditor ────────────────────────────────────────────────────────────────

class WebAuditor {
public:
  explicit WebAuditor(WebAuditConfig config = {});
  ~WebAuditor();

  WebAuditor(const WebAuditor&)            = delete;
  WebAuditor& operator=(const WebAuditor&) = delete;

  /// Start background polling thread.
  void start(ObservationBus& bus);

  /// Stop background thread gracefully.
  void stop();

  /// Trigger an immediate audit (non-blocking: wakes the background thread).
  void auditNow();

  [[nodiscard]] auto isRunning()          const -> bool;
  [[nodiscard]] auto totalReportsRead()   const -> std::uint64_t;
  [[nodiscard]] auto totalFindingsPushed() const -> std::uint64_t;
  [[nodiscard]] auto lastReport()         const -> WebAuditReport;

  /// Parse the raw JSON string into a WebAuditReport. Never throws; on
  /// malformed JSON the returned report's raw_json is empty (failure signal).
  /// Findings are capped at kMaxFindings; messages/categories are truncated.
  /// Public static so unit tests can exercise malformed inputs directly.
  [[nodiscard]] static auto parseReport(const std::string& json) -> WebAuditReport;

  static constexpr std::size_t kMaxFindings       = 500;
  static constexpr std::size_t kMaxArtifactBytes  = 8 * 1024 * 1024;
  static constexpr std::size_t kMaxMessageBytes   = 2048;
  static constexpr std::size_t kMaxCategoryBytes  = 64;

private:
  void loop();
  void runOneCycle();

  /// Shell out to the MCP tool to produce a new audit report.
  void triggerMcpAudit();

  /// Read and parse the artifact JSON.  Returns an empty report on failure.
  [[nodiscard]] auto readArtifact() const -> WebAuditReport;

  /// Push findings from a report as kWebAudit observations.
  void pushReport(const WebAuditReport& report);

  /// FNV-1a hash used to skip already-pushed reports.
  [[nodiscard]] static auto fnv1aHash(const std::string& s) -> std::uint64_t;

  WebAuditConfig    m_config;
  ObservationBus*   m_bus{nullptr};

  mutable std::mutex  m_reportMutex;
  WebAuditReport      m_lastReport;
  std::uint64_t       m_lastArtifactHash{0};

  std::thread             m_thread;
  std::mutex              m_cvMutex;
  std::condition_variable m_cv;
  std::atomic<bool>       m_running{false};
  std::atomic<bool>       m_auditNow{false};
  std::atomic<std::uint64_t> m_totalReports{0};
  std::atomic<std::uint64_t> m_totalFindings{0};
};

} // namespace nexus::cell
