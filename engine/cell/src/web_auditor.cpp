#include "nexus/cell/web_auditor.h"

#include "nexus/core/log.h"

#include <chrono>
#include <cstdio>
#include <cstring>
#include <filesystem>
#include <fstream>
#include <sstream>

#include <nlohmann/json.hpp>

namespace nexus::cell {

namespace {

auto nowMs() -> std::uint64_t {
  using namespace std::chrono;
  return static_cast<std::uint64_t>(
      duration_cast<milliseconds>(steady_clock::now().time_since_epoch()).count());
}

auto nowSeconds() -> double {
  using namespace std::chrono;
  return duration_cast<duration<double>>(steady_clock::now().time_since_epoch()).count();
}

auto severityFromString(const std::string& s) -> AuditSeverity {
  if (s == "critical") { return AuditSeverity::kCritical; }
  if (s == "error")    { return AuditSeverity::kError; }
  if (s == "warning")  { return AuditSeverity::kWarning; }
  return AuditSeverity::kInfo;
}

// Reward heuristic: maps severity → numeric reward for the ResearchLoop.
auto severityReward(AuditSeverity s) -> double {
  switch (s) {
  case AuditSeverity::kCritical: return 0.0;
  case AuditSeverity::kError:    return 0.2;
  case AuditSeverity::kWarning:  return 0.5;
  case AuditSeverity::kInfo:     return 0.8;
  }
  return 0.5;
}

} // namespace

// ── Constructor / Destructor ──────────────────────────────────────────────────

WebAuditor::WebAuditor(WebAuditConfig config) : m_config(std::move(config)) {
  // Allow env-var override for stub mode (CI / unit tests).
  if (!m_config.stub_mode) {
    const char* env = std::getenv("NEXUS_WEB_AUDIT_STUB");
    if (env != nullptr && std::string{env} == "1") {
      m_config.stub_mode = true;
    }
  }
}

WebAuditor::~WebAuditor() {
  stop();
}

// ── Public API ────────────────────────────────────────────────────────────────

void WebAuditor::start(ObservationBus& bus) {
  if (m_running.load()) {
    return;
  }
  m_bus     = &bus;
  m_running = true;
  m_thread  = std::thread([this] { loop(); });
  NEXUS_LOG_INFO(LogChannel::kCell,
                 "WebAuditor started — url=" + m_config.url +
                     " poll_interval=" + std::to_string(m_config.poll_interval.count()) + "s");
}

void WebAuditor::stop() {
  if (!m_running.load()) {
    return;
  }
  {
    std::lock_guard<std::mutex> lk(m_cvMutex);
    m_running = false;
  }
  m_cv.notify_all();
  if (m_thread.joinable()) {
    m_thread.join();
  }
  NEXUS_LOG_INFO(LogChannel::kCell, "WebAuditor stopped");
}

void WebAuditor::auditNow() {
  m_auditNow = true;
  m_cv.notify_all();
}

auto WebAuditor::isRunning() const -> bool {
  return m_running.load();
}

auto WebAuditor::totalReportsRead() const -> std::uint64_t {
  return m_totalReports.load();
}

auto WebAuditor::totalFindingsPushed() const -> std::uint64_t {
  return m_totalFindings.load();
}

auto WebAuditor::lastReport() const -> WebAuditReport {
  std::lock_guard<std::mutex> lk(m_reportMutex);
  return m_lastReport;
}

// ── Background loop ───────────────────────────────────────────────────────────

void WebAuditor::loop() {
  while (m_running.load()) {
    const bool triggered = m_auditNow.exchange(false);
    if (triggered) {
      runOneCycle();
    } else {
      // Check for a new artifact written by an external MCP invocation.
      const WebAuditReport report = readArtifact();
      if (!report.raw_json.empty()) {
        const std::uint64_t h = fnv1aHash(report.raw_json);
        if (h != m_lastArtifactHash) {
          m_lastArtifactHash = h;
          pushReport(report);
        }
      }
    }

    // Wait for the next poll interval or until woken by auditNow().
    std::unique_lock<std::mutex> lk(m_cvMutex);
    m_cv.wait_for(lk, m_config.poll_interval,
                  [this] { return !m_running.load() || m_auditNow.load(); });
  }
}

void WebAuditor::runOneCycle() {
  if (!m_config.stub_mode) {
    triggerMcpAudit();
    // Small delay to allow the async MCP tool to write the artifact.
    std::this_thread::sleep_for(std::chrono::seconds(3));
  }

  const WebAuditReport report = m_config.stub_mode ? [this]() {
    // Canned stub report for CI / unit tests.
    WebAuditReport stub;
    stub.url        = m_config.url.empty() ? "https://example.com" : m_config.url;
    stub.login_ok   = true;
    stub.page_title = "Stub Page";
    stub.load_time_ms = 123.0;
    stub.timestamp_ms = nowMs();
    stub.raw_json   = R"({"stub":true})";
    WebAuditFinding f;
    f.category = "ux";
    f.severity = AuditSeverity::kInfo;
    f.message  = "Stub audit: page loaded successfully";
    f.url      = stub.url;
    stub.findings.push_back(std::move(f));
    return stub;
  }() : readArtifact();

  if (report.raw_json.empty()) {
    NEXUS_LOG_WARN(LogChannel::kCell, "WebAuditor: no audit artifact found at " +
                                          m_config.artifact_path);
    return;
  }

  pushReport(report);
}

// ── MCP trigger ───────────────────────────────────────────────────────────────

void WebAuditor::triggerMcpAudit() {
  if (m_config.mcp_cli_path.empty() || m_config.url.empty()) {
    return;
  }

  // Build a minimal JSON payload that the web_audit MCP tool understands.
  nlohmann::json params;
  params["url"]       = m_config.url;
  params["stub_mode"] = m_config.stub_mode;

  if (!m_config.credentials.empty()) {
    nlohmann::json creds;
    for (const auto& [k, v] : m_config.credentials) {
      creds[k] = v;
    }
    params["credentials"] = creds;
  }

  if (!m_config.steps.empty()) {
    nlohmann::json steps = nlohmann::json::array();
    for (const auto& s : m_config.steps) {
      steps.push_back({{"action",   s.action},
                       {"selector", s.selector},
                       {"value",    s.value},
                       {"url",      s.url}});
    }
    params["steps"] = steps;
  }

  // Ensure artifact output directory exists.
  {
    const std::filesystem::path artifactDir =
        std::filesystem::path(m_config.artifact_path).parent_path();
    std::error_code ec;
    std::filesystem::create_directories(artifactDir, ec);
  }

  // Invoke the MCP tool via Node.js — non-blocking fire-and-forget.
  // The tool writes the result to artifact_path; we poll for it after a delay.
  const std::string paramsJson  = params.dump();
  const std::string escapedJson = [&paramsJson]() {
    std::string e;
    e.reserve(paramsJson.size() + 10);
    for (char c : paramsJson) {
      if (c == '\'') { e += "'\\''"; } else { e += c; }
    }
    return e;
  }();

  std::string cmd = "node " + m_config.mcp_cli_path +
                    " web_audit '" + escapedJson + "' &";

  // NOLINT: intentional shell invocation (same pattern as IdleFeed::curlGet)
  const int ret = std::system(cmd.c_str()); // NOLINT
  if (ret != 0) {
    NEXUS_LOG_WARN(LogChannel::kCell, "WebAuditor: MCP trigger returned " +
                                          std::to_string(ret));
  }
}

// ── Artifact reading ──────────────────────────────────────────────────────────

auto WebAuditor::readArtifact() const -> WebAuditReport {
  std::error_code ec;
  if (!std::filesystem::exists(m_config.artifact_path, ec)) {
    return {};
  }
  std::ifstream f(m_config.artifact_path);
  if (!f.is_open()) {
    return {};
  }
  std::ostringstream ss;
  ss << f.rdbuf();
  const std::string json = ss.str();
  if (json.empty()) {
    return {};
  }
  return parseReport(json);
}

// ── Observation pushing ───────────────────────────────────────────────────────

void WebAuditor::pushReport(const WebAuditReport& report) {
  if (!m_bus) { return; }

  // Push one summary observation for the report itself.
  m_bus->push(Observation{
      ObservationType::kWebAudit,
      "web_auditor",
      {{"url",           report.url},
       {"login_ok",      report.login_ok},
       {"page_title",    report.page_title},
       {"load_time_ms",  report.load_time_ms},
       {"finding_count", static_cast<int>(report.findings.size())},
       {"reward",        report.login_ok ? 0.7 : 0.1}},
      nowSeconds()});

  // Push each individual finding as a separate observation so ResearchLoop
  // can track categories and severities independently.
  for (const auto& finding : report.findings) {
    m_bus->push(Observation{
        ObservationType::kWebAudit,
        "web_auditor",
        {{"url",      finding.url.empty() ? report.url : finding.url},
         {"category", finding.category},
         {"severity", auditSeverityName(finding.severity)},
         {"message",  finding.message},
         {"value",    finding.value},
         {"reward",   severityReward(finding.severity)}},
        nowSeconds()});
    ++m_totalFindings;
  }

  ++m_totalReports;
  {
    std::lock_guard<std::mutex> lk(m_reportMutex);
    m_lastReport = report;
  }

  NEXUS_LOG_INFO(LogChannel::kCell,
                 "WebAuditor: report pushed — url=" + report.url +
                     " login_ok=" + (report.login_ok ? "true" : "false") +
                     " findings=" + std::to_string(report.findings.size()));
}

// ── JSON parsing ──────────────────────────────────────────────────────────────

auto WebAuditor::parseReport(const std::string& jsonText) -> WebAuditReport {
  WebAuditReport report;
  report.raw_json = jsonText;

  try {
    const auto j = nlohmann::json::parse(jsonText);

    report.url          = j.value("url", "");
    report.login_ok     = j.value("login_ok", false);
    report.page_title   = j.value("page_title", "");
    report.load_time_ms = j.value("load_time_ms", 0.0);
    report.timestamp_ms = j.value("timestamp_ms", std::uint64_t{0});

    if (j.contains("findings") && j["findings"].is_array()) {
      for (const auto& f : j["findings"]) {
        WebAuditFinding finding;
        finding.category       = f.value("category", "ux");
        finding.severity       = severityFromString(f.value("severity", "info"));
        finding.message        = f.value("message", "");
        finding.url            = f.value("url", "");
        finding.screenshot_b64 = f.value("screenshot_b64", "");
        finding.value          = f.value("value", 0.0);
        report.findings.push_back(std::move(finding));
      }
    }
  } catch (const nlohmann::json::parse_error& e) {
    NEXUS_LOG_WARN(LogChannel::kCell,
                   std::string("WebAuditor: JSON parse error — ") + e.what());
    report.raw_json.clear(); // Signal failure to caller.
  }

  return report;
}

// ── Hash ──────────────────────────────────────────────────────────────────────

auto WebAuditor::fnv1aHash(const std::string& s) -> std::uint64_t {
  std::uint64_t hash = 0xcbf29ce484222325ULL;
  for (unsigned char c : s) {
    hash ^= c;
    hash *= 0x100000001b3ULL;
  }
  return hash;
}

} // namespace nexus::cell
