#include "nexus/cell/self_improvement_scheduler.h"

#include "nexus/core/job_system.h"
#include "nexus/core/log.h"

#include <chrono>
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
      m_trainer(m_config.model) {}

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

  m_research.start(m_bus, m_ledger, m_wisdom, jobs);
  m_trainer.start(m_ledger);

  m_initialized = true;
  NEXUS_LOG_INFO(LogChannel::kCell, "CELL initialised — phase: Embryo");
  return Result<void>::ok();
}

void SelfImprovementScheduler::tick() {
  // Non-blocking: flush is O(1) pointer swap inside ObservationBus.
  // The ResearchLoop drains the bus on its own schedule.
  // Nothing to do here — the bus is drained by the ResearchLoop thread.
  // We keep tick() as an extension point for future lightweight per-frame work.
}

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
                {"phase",                s.phase_name},
                {"ledger_size",          s.ledger_size},
                {"model_version",        s.model_version},
                {"wisdom_count",         s.wisdom_count},
                {"model_accuracy",       s.model_accuracy},
                {"observation_queue",    s.observation_queue_size},
                {"research_cycles",      m_research.cycleCount()},
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

  return {{"id", id}, {"status", "error"}, {"error", "Unsupported cell query: " + query}};
}

void SelfImprovementScheduler::shutdown() {
  if (!m_initialized) {
    return;
  }
  m_research.stop();
  m_trainer.stop();
  m_ledger.flush();
  m_ledger.shutdown();
  m_wisdom.shutdown();
  m_initialized = false;
  NEXUS_LOG_INFO(LogChannel::kCell, "CELL shutdown complete");
}

} // namespace nexus::cell
