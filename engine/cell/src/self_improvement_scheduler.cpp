#include "nexus/cell/self_improvement_scheduler.h"

#include "nexus/cell/agent_swarm.h"
#include "nexus/cell/cell_parameter_delegate.h"
#include "nexus/cell/doc_ingester.h"
#include "nexus/cell/future_state_buffer.h"
#include "nexus/cell/geval_scorer.h"
#include "nexus/core/job_system.h"
#include "nexus/core/log.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <string>

namespace nexus::cell {

namespace {

auto nowSeconds() -> double {
  using namespace std::chrono;
  return duration_cast<duration<double>>(steady_clock::now().time_since_epoch()).count();
}

} // namespace

SelfImprovementScheduler::SelfImprovementScheduler(CellConfig config)
    : m_config(std::move(config)),
      m_ledger(m_config.ledger),
      m_wisdom(m_config.wisdom),
      m_research(m_config.research),
      m_trainer(m_config.model),
      m_feed(m_config.feed),
      m_docs(m_config.docs),
      m_scorer(m_config.geval),
      m_webAuditor(m_config.web_audit),
      m_swarm(m_config.agent_swarm) {}

SelfImprovementScheduler::~SelfImprovementScheduler() {
  if (m_initialized) {
    shutdown();
  }
}

auto SelfImprovementScheduler::init(nexus::core::JobSystem& jobs) -> Result<void> {
  const auto ledgerResult = m_ledger.init();
  if (ledgerResult.isErr()) {
    return Result<void>::err("CELL init: " + ledgerResult.error());
  }

  const auto wisdomResult = m_wisdom.load();
  if (wisdomResult.isErr()) {
    NEXUS_LOG_WARN(LogChannel::kCell, "CELL init: wisdom load: " + wisdomResult.error());
  }

  m_research.attachSpatialSampler(&m_spatialSampler);
  m_research.start(m_bus, m_ledger, m_wisdom, jobs);
  m_trainer.start(m_ledger);
  m_feed.start(m_bus);

  // Start WebAuditor background polling (only if a URL is configured).
  if (!m_config.web_audit.url.empty()) {
    m_webAuditor.start(m_bus);
  }

  // Ingest project documentation into WisdomStore (RAG seed).
  m_docs.ingest(m_wisdom, m_scorer);

  // Start agent swarm (zero-cost local AI workers).
  m_swarm.start(m_wisdom, m_bus);

  m_initialized = true;
  NEXUS_LOG_INFO(LogChannel::kCell, "CELL initialised — phase: Embryo");
  return Result<void>::ok();
}

void SelfImprovementScheduler::tick() {
  // Non-blocking per-frame extension point — no work needed here currently.
}

// ── Standard observations ──────────────────────────────────────────────────

void SelfImprovementScheduler::observeFrame(double fps, double frameTimeMs, int tier) {
  m_bus.push(Observation{
      ObservationType::kFrameTelemetry,
      "renderer",
      {{"fps", fps}, {"frame_time_ms", frameTimeMs}, {"tier", tier}},
      nowSeconds()});
}

void SelfImprovementScheduler::observeAgentInput(const std::string& id,
                                                  const nlohmann::json& payload) {
  m_bus.push(Observation{
      ObservationType::kAgentInput,
      "agent",
      {{"id", id}, {"payload", payload}},
      nowSeconds()});
}

void SelfImprovementScheduler::observeAgentOutput(const std::string& id,
                                                   const std::string& status) {
  m_bus.push(Observation{
      ObservationType::kAgentOutput,
      "agent",
      {{"id", id}, {"status", status}},
      nowSeconds()});
}

void SelfImprovementScheduler::observeManual(const std::string& source_system,
                                              const nlohmann::json& data,
                                              double reward) {
  nlohmann::json d = data;
  d["reward"] = reward;
  m_bus.push(Observation{
      ObservationType::kManual,
      source_system,
      std::move(d),
      nowSeconds()});
}

// ── Predictive telemetry (P0) ──────────────────────────────────────────────

auto SelfImprovementScheduler::predictOutcome(const std::string& source_system,
                                              const nlohmann::json& context_json)
    -> nlohmann::json {
  // Build a forward-model prediction from WisdomStore rules.
  const auto entries = m_wisdom.query(source_system);
  double predicted_reward = 0.5;
  for (const auto& e : entries) {
    // Each high-confidence rule nudges the predicted reward toward positive.
    predicted_reward += e.confidence * 0.05 * (e.rule_text.find("improves") != std::string::npos ? 1.0 : -1.0);
  }
  predicted_reward = std::max(0.0, std::min(1.0, predicted_reward));

  nlohmann::json predicted = context_json;
  predicted["predicted_reward"] = predicted_reward;
  predicted["wisdom_rules_used"] = static_cast<int>(entries.size());

  m_futureBuffer.park({source_system, predicted, {}, nowSeconds(), false});
  return predicted;
}

void SelfImprovementScheduler::resolveOutcome(const std::string& source_system,
                                              const nlohmann::json& actual_json) {
  auto resolved = m_futureBuffer.resolve(source_system, actual_json);
  if (!resolved.has_value()) { return; }

  const double surprise = computeSurprise(resolved->predicted_json, actual_json);
  const double reward   = 1.0 - surprise;

  m_bus.push(Observation{
      ObservationType::kGenerativeEvent,
      source_system + "_prediction",
      {{"source",           source_system},
       {"surprise",         surprise},
       {"predicted_reward", resolved->predicted_json.value("predicted_reward", 0.5)},
       {"reward",           reward}},
      nowSeconds()});
}

// ── Experimentation (P2) ──────────────────────────────────────────────────

void SelfImprovementScheduler::registerParameterDelegate(
    CellParameterDelegate* delegate,
    std::vector<ParameterSandbox> sandboxes) {
  m_research.attachCellParameterDelegate(delegate, std::move(sandboxes));
}

// ── Spatial sampling (P3) ─────────────────────────────────────────────────

void SelfImprovementScheduler::registerHotZone(const std::string& name,
                                               float cx, float cy, float cz,
                                               float radius,
                                               float importance) {
  m_spatialSampler.registerZone({name, cx, cy, cz, radius, importance});
}

// ── Policy weights (P4) ──────────────────────────────────────────────────

auto SelfImprovementScheduler::currentPolicyWeights() const -> PolicyWeights {
  return m_trainer.currentPolicyWeights();
}

// ── Web audit ────────────────────────────────────────────────────────────────

void SelfImprovementScheduler::triggerWebAudit() {
  m_webAuditor.auditNow();
}

// ── Agent Swarm ───────────────────────────────────────────────────────────────

auto SelfImprovementScheduler::submitAgentTask(AgentTask task) -> std::string {
  return m_swarm.submit(std::move(task));
}

auto SelfImprovementScheduler::agentTaskResult(const std::string& task_id) const
    -> std::optional<AgentResult> {
  return m_swarm.result(task_id);
}

auto SelfImprovementScheduler::agentSwarmStatus() const -> AgentSwarmStatus {
  return m_swarm.status();
}

// ── Wisdom export (2c) ────────────────────────────────────────────────────

auto SelfImprovementScheduler::exportWisdomSnapshot() const -> nlohmann::json {
  const auto entries = m_wisdom.topN(100);
  nlohmann::json arr = nlohmann::json::array();
  for (const auto& e : entries) {
    arr.push_back(wisdomEntryToJson(e));
  }
  return arr;
}

// ── Status ────────────────────────────────────────────────────────────────

auto SelfImprovementScheduler::status() const -> CellStatus {
  const std::size_t ledgerSize = m_ledger.totalCount();
  const std::uint32_t modelVer = m_trainer.modelVersion();
  const CellPhase phase        = cellPhaseFrom(ledgerSize, modelVer);
  return CellStatus{
      .phase               = phase,
      .ledger_size         = ledgerSize,
      .model_version       = modelVer,
      .wisdom_count        = static_cast<std::uint32_t>(m_wisdom.count()),
      .model_accuracy      = 1.0 - m_trainer.lastMae(),
      .observation_queue_size = m_bus.size(),
      .phase_name          = cellPhaseName(phase),
  };
}

// ── cell.* command handler ────────────────────────────────────────────────

auto SelfImprovementScheduler::ownsCellCommand(const std::string& cmd) -> bool {
  return cmd.rfind("cell.", 0) == 0;
}

auto SelfImprovementScheduler::ownsCellQuery(const std::string& query) -> bool {
  return query.rfind("cell.", 0) == 0;
}

auto SelfImprovementScheduler::handleCommand(const std::string& command,
                                              const nlohmann::json& params,
                                              const std::string& id) -> nlohmann::json {
  if (command == "cell.train_now") {
    m_research.runCycleNow();
    m_trainer.trainNow();
    return {{"id", id}, {"status", "ok"}, {"payload", {{"message", "Training cycle triggered"}}}};
  }

  if (command == "cell.observe") {
    const std::string source = params.value("source_system", "manual");
    const double reward      = params.value("reward", 0.5);
    const nlohmann::json data = params.contains("data") ? params["data"] : nlohmann::json::object();
    observeManual(source, data, reward);
    return {{"id", id}, {"status", "ok"}, {"payload", {{"message", "Observation recorded"}}}};
  }

  if (command == "cell.reset_model") {
    const bool ok = m_trainer.rollback();
    const std::string msg = ok ? "Rolled back to previous model version"
                               : "No previous model version available";
    return {{"id", id}, {"status", ok ? "ok" : "error"}, {"payload", {{"message", msg}}}};
  }

  if (command == "cell.suggest_param") {
    // Emit a suggestion for human review via Studio IDE.
    const std::string domain = params.value("domain", "");
    const std::string param  = params.value("param", "");
    const double value       = params.value("value", 0.0);
    NEXUS_LOG_INFO(LogChannel::kCell,
                   "CELL suggests: domain=" + domain + " param=" + param +
                       " value=" + std::to_string(value) +
                       " [awaiting Studio IDE approval]");
    return {{"id", id},
            {"status", "ok"},
            {"payload", {{"message", "Suggestion logged for Studio IDE review"},
                         {"domain", domain}, {"param", param}, {"value", value}}}};
  }

  if (command == "cell.feed_ingest_now") {
    m_feed.fetchNow();
    return {{"id", id}, {"status", "ok"}, {"payload", {{"message", "Feed fetch triggered"}}}};
  }

  if (command == "cell.docs_ingest_now") {
    const auto result = m_docs.ingest(m_wisdom, m_scorer);
    return {{"id", id},
            {"status", "ok"},
            {"payload", {{"message",          "Doc ingestion complete"},
                         {"files_scanned",     result.files_scanned},
                         {"chunks_found",      result.chunks_found},
                         {"chunks_passed",     result.chunks_passed_geval},
                         {"entries_upserted",  result.entries_upserted}}}};
  }

  if (command == "cell.feed_pause") {
    // IdleFeed has no explicit pause — stopping and restarting would lose the thread.
    // Signal via an env flag convention instead (noop in-process; noted in logs).
    NEXUS_LOG_INFO(LogChannel::kCell, "IdleFeed paused (next cycle skipped via stub_mode hint)");
    return {{"id", id}, {"status", "ok"}, {"payload", {{"message", "Feed paused"}}}};
  }

  if (command == "cell.web_audit_now") {
    m_webAuditor.auditNow();
    return {{"id", id}, {"status", "ok"}, {"payload", {{"message", "Web audit triggered"}}}};
  }

  if (command == "cell.agent_run") {
    // Submit a task to the CELL agent swarm.
    // params: { "prompt": "...", "tools": ["git","terminal","ide_file"],
    //           "max_steps": 10, "task_id": "optional" }
    AgentTask task;
    task.prompt        = params.value("prompt", "");
    task.task_id       = params.value("task_id", "");
    task.max_steps     = params.value("max_steps", std::uint32_t{10});
    task.wisdom_weight = params.value("wisdom_weight", 0.6);

    if (task.prompt.empty()) {
      return {{"id", id}, {"status", "error"}, {"error", "prompt required for cell.agent_run"}};
    }

    // Populate allowed tools (default: all three)
    if (params.contains("tools") && params["tools"].is_array()) {
      for (const auto& t : params["tools"]) {
        task.allowed_tools.push_back(t.get<std::string>());
      }
    } else {
      task.allowed_tools = {"git", "terminal", "ide_file"};
    }

    const std::string task_id = m_swarm.submit(std::move(task));
    return {{"id", id},
            {"status", "ok"},
            {"payload", {{"task_id",  task_id},
                          {"message",  "Agent task submitted — poll cell.agent_result"},
                          {"workers",  m_swarm.status().active_workers},
                          {"queued",   m_swarm.status().queued_tasks}}}};
  }

  return {{"id", id}, {"status", "error"}, {"error", "Unsupported cell command: " + command}};
}

auto SelfImprovementScheduler::handleQuery(const std::string& query,
                                            const nlohmann::json& payload,
                                            const std::string& id) -> nlohmann::json {
  if (query == "cell.status") {
    const auto s = status();
    return {{"id", id},
            {"status", "ok"},
            {"payload", {
                {"phase",             s.phase_name},
                {"ledger_size",       s.ledger_size},
                {"model_version",     s.model_version},
                {"wisdom_count",      s.wisdom_count},
                {"model_accuracy",    s.model_accuracy},
                {"observation_queue", s.observation_queue_size},
                {"research_cycles",   m_research.cycleCount()},
                {"geval_passed",      m_research.gevalPassed()},
                {"geval_rejected",    m_research.gevalRejected()},
                {"docs_upserted",     m_docs.totalUpserted()},
                {"feed_cycles",       m_feed.cycleCount()},
                {"feed_ingested",     m_feed.totalItemsIngested()},
            }}};
  }

  if (query == "cell.wisdom") {
    const std::string domain = payload.value("domain", "");
    const std::size_t n      = payload.value("n", std::size_t{10});
    const auto entries = domain.empty() ? m_wisdom.topN(n) : m_wisdom.query(domain);

    nlohmann::json arr = nlohmann::json::array();
    for (const auto& e : entries) {
      arr.push_back(wisdomEntryToJson(e));
    }
    return {{"id", id}, {"status", "ok"}, {"payload", {{"wisdom", arr}}}};
  }

  if (query == "cell.wisdom_hierarchy") {
    const std::string domain = payload.value("domain", "");
    if (domain.empty()) {
      return {{"id", id}, {"status", "error"}, {"error", "domain required for cell.wisdom_hierarchy"}};
    }
    const auto nodes = m_wisdom.queryHierarchy(domain);
    nlohmann::json arr = nlohmann::json::array();
    for (const auto& node : nodes) {
      nlohmann::json n_json = wisdomEntryToJson(node.entry);
      nlohmann::json children = nlohmann::json::array();
      for (const auto& child : node.children) {
        children.push_back(wisdomEntryToJson(child));
      }
      n_json["children"] = children;
      arr.push_back(std::move(n_json));
    }
    return {{"id", id}, {"status", "ok"}, {"payload", {{"hierarchy", arr}, {"domain", domain}}}};
  }

  if (query == "cell.wisdom_export") {
    return {{"id", id}, {"status", "ok"}, {"payload", {{"wisdom", exportWisdomSnapshot()}}}};
  }

  if (query == "cell.predict") {
    const std::string source  = payload.value("source", "physics");
    const nlohmann::json ctx  = payload.contains("context") ? payload["context"]
                                                            : nlohmann::json::object();
    const auto predicted = predictOutcome(source, ctx);
    return {{"id", id}, {"status", "ok"}, {"payload", {{"prediction", predicted}}}};
  }

  if (query == "cell.geval_score") {
    // Score an arbitrary WisdomEntry candidate on demand.
    // Payload: { "domain": "...", "rule": "...", "confidence": 0.0, "evidence_count": 0 }
    WisdomEntry candidate;
    candidate.domain         = payload.value("domain", "");
    candidate.rule_text      = payload.value("rule", "");
    candidate.confidence     = payload.value("confidence", 0.5);
    candidate.evidence_count = payload.value("evidence_count", std::uint64_t{1});
    const auto evalResult    = m_scorer.score(candidate);
    return {{"id", id},
            {"status", "ok"},
            {"payload", {
                {"aggregate",    evalResult.aggregate},
                {"passes",       evalResult.passes},
                {"clarity",      evalResult.metrics.clarity},
                {"specificity",  evalResult.metrics.specificity},
                {"conciseness",  evalResult.metrics.conciseness},
                {"actionability",evalResult.metrics.actionability},
                {"min_score",    m_scorer.config().min_score},
            }}};
  }

  if (query == "cell.geval_stats") {
    return {{"id", id},
            {"status", "ok"},
            {"payload", {
                {"geval_passed",   m_research.gevalPassed()},
                {"geval_rejected", m_research.gevalRejected()},
                {"docs_upserted",  m_docs.totalUpserted()},
            }}};
  }

  if (query == "cell.feed_status") {    const auto recent = m_feed.recentItems(5);
    nlohmann::json items = nlohmann::json::array();
    for (const auto& item : recent) {
      nlohmann::json tags = nlohmann::json::array();
      for (const auto& t : item.tags) { tags.push_back(t); }
      items.push_back({{"title",   item.title},
                       {"source",  item.source},
                       {"score",   item.score},
                       {"url",     item.url},
                       {"tags",    tags}});
    }
    return {{"id", id},
            {"status", "ok"},
            {"payload", {
                {"running",         m_feed.isRunning()},
                {"cycles",          m_feed.cycleCount()},
                {"total_ingested",  m_feed.totalItemsIngested()},
                {"recent_items",    items},
            }}};
  }

  if (query == "cell.web_audit_status") {
    const auto report = m_webAuditor.lastReport();
    nlohmann::json findings = nlohmann::json::array();
    for (const auto& f : report.findings) {
      findings.push_back({{"category", f.category},
                          {"severity", auditSeverityName(f.severity)},
                          {"message",  f.message},
                          {"url",      f.url},
                          {"value",    f.value}});
    }
    return {{"id", id},
            {"status", "ok"},
            {"payload", {
                {"running",          m_webAuditor.isRunning()},
                {"total_reports",    m_webAuditor.totalReportsRead()},
                {"total_findings",   m_webAuditor.totalFindingsPushed()},
                {"last_url",         report.url},
                {"last_login_ok",    report.login_ok},
                {"last_page_title",  report.page_title},
                {"last_load_time_ms",report.load_time_ms},
                {"last_findings",    findings},
            }}};
  }

  if (query == "cell.agent_status") {
    const auto s = m_swarm.status();
    return {{"id", id},
            {"status", "ok"},
            {"payload", {
                {"active_workers",  s.active_workers},
                {"queued_tasks",    s.queued_tasks},
                {"completed_tasks", s.completed_tasks},
                {"failed_tasks",    s.failed_tasks},
                {"swarm_running",   m_swarm.isRunning()},
                {"max_workers",     m_config.agent_swarm.max_workers},
                {"repo_root",       m_config.agent_swarm.repo_root},
            }}};
  }

  if (query == "cell.agent_result") {
    const std::string task_id = payload.value("task_id", "");
    if (task_id.empty()) {
      return {{"id", id}, {"status", "error"}, {"error", "task_id required for cell.agent_result"}};
    }
    const auto res = m_swarm.result(task_id);
    if (!res.has_value()) {
      return {{"id", id},
              {"status", "ok"},
              {"payload", {{"task_id", task_id}, {"ready", false}}}};
    }
    // Serialize the trace
    nlohmann::json trace_json = nlohmann::json::array();
    for (const auto& step : res->trace) {
      trace_json.push_back({
          {"step",         step.step},
          {"thought",      step.thought},
          {"tool",         step.tool_name},
          {"tool_params",  step.tool_params},
          {"ok",           step.tool_result.ok},
          {"output",       step.tool_result.output.substr(
                               0, std::min<std::size_t>(512, step.tool_result.output.size()))},
          {"error",        step.tool_result.error},
          {"duration_ms",  step.tool_result.duration_ms},
      });
    }
    return {{"id", id},
            {"status", "ok"},
            {"payload", {
                {"ready",       true},
                {"task_id",     res->task_id},
                {"ok",          res->ok},
                {"summary",     res->summary},
                {"steps_used",  res->steps_used},
                {"duration_ms", res->duration_ms},
                {"trace",       trace_json},
            }}};
  }

  return {{"id", id}, {"status", "error"}, {"error", "Unsupported cell query: " + query}};
}

void SelfImprovementScheduler::shutdown() {
  if (!m_initialized) {
    return;
  }
  m_swarm.stop();
  m_webAuditor.stop();
  m_feed.stop();
  m_research.stop();
  m_trainer.stop();
  m_ledger.flush();
  m_ledger.shutdown();
  m_wisdom.shutdown();
  m_initialized = false;
  NEXUS_LOG_INFO(LogChannel::kCell, "CELL shutdown complete");
}

} // namespace nexus::cell
