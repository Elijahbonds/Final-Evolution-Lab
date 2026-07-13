#pragma once

// CELL Self-Improvement Scheduler — The Orchestrator
//
// Top-level controller that owns ObservationBus, ExperienceLedger, WisdomStore,
// ResearchLoop, and ModelTrainer.  It:
//   • is initialised once and plugged into Engine alongside AgentServer
//   • receives a non-blocking tick() every frame to flush the observation bus
//   • handles the cell.* command namespace via CommandRouter

#include "nexus/cell/cell_types.h"
#include "nexus/cell/experience_ledger.h"
#include "nexus/cell/model_trainer.h"
#include "nexus/cell/observation_bus.h"
#include "nexus/cell/research_loop.h"
#include "nexus/cell/wisdom_store.h"
#include "nexus/core/result.h"

#include <nlohmann/json.hpp>

#include <memory>
#include <string>

namespace nexus::core {
class JobSystem;
}

namespace nexus::cell {

struct CellConfig {
  ExperienceLedgerConfig ledger;
  WisdomStoreConfig      wisdom;
  ResearchLoopConfig     research;
  ModelConfig            model;
};

class SelfImprovementScheduler {
public:
  explicit SelfImprovementScheduler(CellConfig config = {});
  ~SelfImprovementScheduler();

  SelfImprovementScheduler(const SelfImprovementScheduler&) = delete;
  auto operator=(const SelfImprovementScheduler&) -> SelfImprovementScheduler& = delete;

  /// Initialise CELL and start background threads.
  auto init(nexus::core::JobSystem& jobs) -> Result<void>;

  /// Called every engine frame — flushes the observation bus (non-blocking).
  void tick();

  /// Push a frame-telemetry observation (called from Engine::tick).
  void observeFrame(double fps, double frameTimeMs, int tier);

  /// Push an agent I/O observation.
  void observeAgentInput(const std::string& id, const nlohmann::json& payload);
  void observeAgentOutput(const std::string& id, const std::string& status);

  /// Push a free-form manual observation.
  void observeManual(const std::string& source_system, const nlohmann::json& data,
                     double reward = 0.5);

  [[nodiscard]] auto status() const -> CellStatus;
  [[nodiscard]] auto observationBus() -> ObservationBus& { return m_bus; }
  [[nodiscard]] auto wisdomStore() -> WisdomStore& { return m_wisdom; }

  // ── cell.* command handler ──────────────────────────────────────────────
  /// Returns true if the command string belongs to the cell.* namespace.
  [[nodiscard]] static auto ownsCellCommand(const std::string& cmd) -> bool;
  [[nodiscard]] static auto ownsCellQuery(const std::string& query) -> bool;

  [[nodiscard]] auto handleCommand(const std::string& command,
                                   const nlohmann::json& params,
                                   const std::string& id) -> nlohmann::json;

  [[nodiscard]] auto handleQuery(const std::string& query,
                                 const nlohmann::json& payload,
                                 const std::string& id) -> nlohmann::json;

  void shutdown();

private:
  CellConfig         m_config;
  ObservationBus     m_bus;
  ExperienceLedger   m_ledger;
  WisdomStore        m_wisdom;
  ResearchLoop       m_research;
  ModelTrainer       m_trainer;
  bool               m_initialized{false};
};

} // namespace nexus::cell
