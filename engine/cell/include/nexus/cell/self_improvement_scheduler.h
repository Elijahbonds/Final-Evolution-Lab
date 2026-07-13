#pragma once

// CELL Self-Improvement Scheduler — The Orchestrator
//
// Top-level controller that owns ObservationBus, ExperienceLedger, WisdomStore,
// ResearchLoop, ModelTrainer, FutureStateBuffer, SpatialSampler, and IdleFeed.
// It:
//   • is initialised once and plugged into Engine alongside AgentServer
//   • receives a non-blocking tick() every frame to flush the observation bus
//   • handles the cell.* command namespace via CommandRouter
//   • runs IdleFeed to ingest world knowledge during idle time

#include "nexus/cell/cell_types.h"
#include "nexus/cell/experience_ledger.h"
#include "nexus/cell/future_state_buffer.h"
#include "nexus/cell/idle_feed.h"
#include "nexus/cell/model_trainer.h"
#include "nexus/cell/observation_bus.h"
#include "nexus/cell/research_loop.h"
#include "nexus/cell/spatial_sampler.h"
#include "nexus/cell/wisdom_store.h"
#include "nexus/core/result.h"

#include <nlohmann/json.hpp>

#include <memory>
#include <string>
#include <vector>

namespace nexus::core {
class JobSystem;
}

namespace nexus::cell {
class CellParameterDelegate;
} // namespace nexus::cell

namespace nexus::cell {

struct CellConfig {
  ExperienceLedgerConfig ledger;
  WisdomStoreConfig      wisdom;
  ResearchLoopConfig     research;
  ModelConfig            model;
  IdleFeedConfig         feed;
};

class SelfImprovementScheduler {
public:
  explicit SelfImprovementScheduler(CellConfig config = {});
  ~SelfImprovementScheduler();

  SelfImprovementScheduler(const SelfImprovementScheduler&) = delete;
  auto operator=(const SelfImprovementScheduler&) -> SelfImprovementScheduler& = delete;

  /// Initialise CELL and start background threads (ResearchLoop, ModelTrainer, IdleFeed).
  auto init(nexus::core::JobSystem& jobs) -> Result<void>;

  /// Called every engine frame — flushes the observation bus (non-blocking).
  void tick();

  // ── Standard observations ──────────────────────────────────────────────────
  void observeFrame(double fps, double frameTimeMs, int tier);
  void observeAgentInput(const std::string& id, const nlohmann::json& payload);
  void observeAgentOutput(const std::string& id, const std::string& status);
  void observeManual(const std::string& source_system, const nlohmann::json& data,
                     double reward = 0.5);

  // ── Predictive telemetry (P0) ──────────────────────────────────────────────
  /// Build a forward-model prediction for source_system given context_json.
  /// Parks the prediction in FutureStateBuffer and returns the predicted JSON.
  [[nodiscard]] auto predictOutcome(const std::string& source_system,
                                    const nlohmann::json& context_json) -> nlohmann::json;

  /// Resolve the most recent pending prediction for source_system against
  /// actual_json, compute surprise, and push a kGenerativeEvent observation.
  void resolveOutcome(const std::string& source_system,
                      const nlohmann::json& actual_json);

  // ── Experimentation (P2) ───────────────────────────────────────────────────
  /// Register a parameter delegate and the sandboxes CELL is allowed to nudge.
  void registerParameterDelegate(CellParameterDelegate* delegate,
                                 std::vector<ParameterSandbox> sandboxes);

  // ── Spatial sampling (P3) ─────────────────────────────────────────────────
  /// Register a spatial hot zone for the ResearchLoop sampler.
  void registerHotZone(const std::string& name,
                       float cx, float cy, float cz,
                       float radius,
                       float importance = 1.0f);

  // ── Policy weights (P4) ───────────────────────────────────────────────────
  /// Return a snapshot of the current model weights for physics parameter scaling.
  [[nodiscard]] auto currentPolicyWeights() const -> PolicyWeights;

  // ── Wisdom export (2c) ────────────────────────────────────────────────────
  /// Return the top-100 WisdomStore entries as a JSON array (for web dashboard).
  [[nodiscard]] auto exportWisdomSnapshot() const -> nlohmann::json;

  // ── Status & accessors ────────────────────────────────────────────────────
  [[nodiscard]] auto status() const -> CellStatus;
  [[nodiscard]] auto observationBus() -> ObservationBus& { return m_bus; }
  [[nodiscard]] auto wisdomStore() -> WisdomStore& { return m_wisdom; }

  // ── cell.* command handler ─────────────────────────────────────────────────
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
  CellConfig               m_config;
  ObservationBus           m_bus;
  ExperienceLedger         m_ledger;
  WisdomStore              m_wisdom;
  ResearchLoop             m_research;
  ModelTrainer             m_trainer;
  FutureStateBuffer        m_futureBuffer;
  SpatialSampler           m_spatialSampler;
  IdleFeed                 m_feed;
  bool                     m_initialized{false};
};

} // namespace nexus::cell
