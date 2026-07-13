// CELL subsystem unit tests
// Exercises ObservationBus, ExperienceLedger, WisdomStore, ResearchLoop,
// ModelTrainer, and SelfImprovementScheduler.

#include "nexus/cell/experience_ledger.h"
#include "nexus/cell/model_trainer.h"
#include "nexus/cell/observation_bus.h"
#include "nexus/cell/self_improvement_scheduler.h"
#include "nexus/cell/wisdom_store.h"
#include "nexus/core/job_system.h"

#include "nexus/ai/agent_server.h"
#include "nexus/ai/command_router.h"
#include "nexus/creative/voxel_world.h"
#include "nexus/creative/world_manipulator.h"

#include <cstdio>
#include <cstdlib>
#include <thread>
#include <chrono>

namespace {

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

// ── ObservationBus ──────────────────────────────────────────────────────────

void observation_bus_push_and_drain() {
  nexus::cell::ObservationBus bus;
  require(bus.size() == 0, "bus starts empty");

  bus.push({nexus::cell::ObservationType::kFrameTelemetry, "renderer",
            {{"fps", 60.0}}, 0.0});
  bus.push({nexus::cell::ObservationType::kAgentOutput, "agent",
            {{"status", "ok"}}, 0.0});

  require(bus.size() == 2, "bus has two items");

  auto obs = bus.drainAll();
  require(obs.size() == 2, "drained two items");
  require(bus.size() == 0, "bus empty after drain");
  require(obs[0].source_system == "renderer", "first obs source_system");
  require(obs[1].type == nexus::cell::ObservationType::kAgentOutput, "second obs type");
}

void observation_bus_capacity_drop() {
  nexus::cell::ObservationBus bus;
  // Push more than kCapacity items — oldest should be evicted silently.
  for (std::size_t i = 0; i < nexus::cell::ObservationBus::kCapacity + 5; ++i) {
    bus.push({nexus::cell::ObservationType::kManual, "test", {{"i", i}}, 0.0});
  }
  require(bus.size() == nexus::cell::ObservationBus::kCapacity, "bus capped at kCapacity");
  static_cast<void>(bus.drainAll());
  require(bus.size() == 0, "bus empty after drain");
}

// ── ExperienceLedger ────────────────────────────────────────────────────────

void experience_ledger_append_and_query() {
  nexus::cell::ExperienceLedgerConfig cfg;
  cfg.ledger_dir     = "/tmp/nexus_cell_test_ledger";
  cfg.max_records    = 50;
  cfg.flush_threshold = 100; // keep in-memory for the test

  nexus::cell::ExperienceLedger ledger(cfg);
  require(ledger.init().isOk(), "ledger init ok");
  require(ledger.totalCount() == 0, "ledger starts empty");

  for (int i = 0; i < 10; ++i) {
    ledger.append({0, "test", {{"i", i}}, {}, {}, static_cast<double>(i) / 10.0});
  }
  require(ledger.totalCount() == 10, "ledger has 10 records");

  const auto recent = ledger.queryRecent(5);
  require(recent.size() == 5, "queryRecent(5) returns 5");
  require(recent.back().reward_signal == 0.9, "last record has highest reward");

  const auto highReward = ledger.queryByReward(0.5, 100);
  require(highReward.size() == 5, "5 records have reward >= 0.5");

  ledger.shutdown();
}

void experience_ledger_capacity_eviction() {
  nexus::cell::ExperienceLedgerConfig cfg;
  cfg.ledger_dir     = "/tmp/nexus_cell_test_ledger_evict";
  cfg.max_records    = 20;
  cfg.flush_threshold = 100;

  nexus::cell::ExperienceLedger ledger(cfg);
  require(ledger.init().isOk(), "evict ledger init");

  for (int i = 0; i < 30; ++i) {
    ledger.append({0, "src", {}, {}, {}, 0.0});
  }
  require(ledger.totalCount() == 20, "eviction keeps max_records entries");
  ledger.shutdown();
}

// ── WisdomStore ─────────────────────────────────────────────────────────────

void wisdom_store_upsert_and_query() {
  nexus::cell::WisdomStoreConfig cfg;
  cfg.wisdom_path = "/tmp/nexus_cell_wisdom_test.json";

  nexus::cell::WisdomStore store(cfg);

  store.upsert({"renderer", "higher fps improves outcomes", 0.8, 100, 0});
  store.upsert({"renderer", "lower frame_time improves outcomes", 0.6, 50, 0});
  store.upsert({"physics", "fewer substeps degrades outcomes", 0.7, 30, 0});

  require(store.count() == 3, "3 entries in store");

  const auto renderer = store.query("renderer");
  require(renderer.size() == 2, "2 renderer entries");
  require(renderer[0].confidence >= renderer[1].confidence, "sorted by confidence desc");

  const auto top2 = store.topN(2);
  require(top2.size() == 2, "topN(2) returns 2");
  require(top2[0].confidence >= top2[1].confidence, "topN sorted by confidence");

  // Upsert same key — should merge evidence and take max confidence.
  store.upsert({"renderer", "higher fps improves outcomes", 0.9, 50, 0});
  const auto mergedRenderer = store.query("renderer");
  require(mergedRenderer[0].confidence == 0.9, "upsert took max confidence");
  require(mergedRenderer[0].evidence_count == 150, "upsert merged evidence_count");

  // Save and load round-trip.
  require(store.save().isOk(), "wisdom store save ok");
  nexus::cell::WisdomStore loaded(cfg);
  require(loaded.load().isOk(), "wisdom store load ok");
  require(loaded.count() == 3, "loaded correct entry count");

  store.shutdown();
}

void wisdom_store_decay() {
  nexus::cell::WisdomStoreConfig cfg;
  cfg.wisdom_path  = "/tmp/nexus_cell_wisdom_decay.json";
  cfg.decay_factor = 0.5;

  nexus::cell::WisdomStore store(cfg);
  store.upsert({"test", "some rule", 1.0, 1, 0});
  store.decay();

  const auto entries = store.query("test");
  require(!entries.empty(), "entry survived decay");
  require(entries[0].confidence < 1.0, "confidence decreased after decay");
  store.shutdown();
}

// ── CellPhase helpers ───────────────────────────────────────────────────────

void cell_phase_transitions() {
  using nexus::cell::CellPhase;
  require(nexus::cell::cellPhaseFrom(0,    0) == CellPhase::kEmbryo,        "embryo phase");
  require(nexus::cell::cellPhaseFrom(999,  0) == CellPhase::kEmbryo,        "embryo upper bound");
  require(nexus::cell::cellPhaseFrom(1000, 0) == CellPhase::kLarva,         "larva phase");
  require(nexus::cell::cellPhaseFrom(10000,0) == CellPhase::kCocoon,        "cocoon phase");
  require(nexus::cell::cellPhaseFrom(100000,0) == CellPhase::kImperfectForm,"imperfect form");
  require(nexus::cell::cellPhaseFrom(1000000, 10) == CellPhase::kPerfectForm, "perfect form");
  require(nexus::cell::cellPhaseFrom(1000000, 9) == CellPhase::kImperfectForm,
          "perfect form requires model v10+");
}

// ── SelfImprovementScheduler integration ────────────────────────────────────

void scheduler_init_status_shutdown() {
  nexus::cell::CellConfig cfg;
  cfg.ledger.ledger_dir  = "/tmp/nexus_cell_sched_ledger";
  cfg.wisdom.wisdom_path = "/tmp/nexus_cell_sched_wisdom.json";
  cfg.model.artifacts_dir = "/tmp/nexus_cell_sched_model";
  cfg.research.cycle_interval = std::chrono::seconds{3600}; // don't auto-run
  cfg.model.train_interval    = std::chrono::seconds{3600};
  cfg.model.min_records_to_train = 10000; // skip training in test

  nexus::core::JobSystem jobs;
  nexus::cell::SelfImprovementScheduler sched(cfg);
  require(sched.init(jobs).isOk(), "scheduler init ok");

  const auto status = sched.status();
  require(status.phase_name == std::string("Embryo"), "initial phase is Embryo");
  require(status.ledger_size == 0, "initial ledger empty");

  sched.observeFrame(60.0, 16.7, 0);
  sched.observeAgentInput("req_1", {{"command", "terrain.fill"}});
  sched.observeAgentOutput("req_1", "ok");
  require(sched.observationBus().size() == 3, "3 observations queued");

  sched.tick();
  // tick() is a no-op stub; bus should still have 3 items
  require(sched.observationBus().size() == 3, "tick is non-blocking, bus unchanged");

  sched.shutdown();
}

void scheduler_cell_commands_via_router() {
  using nexus::ai::AgentServer;
  using nexus::ai::CommandRouter;
  using nexus::creative::VoxelWorld;
  using nexus::creative::WorldManipulator;

  VoxelWorld world;
  WorldManipulator manipulator(world);
  CommandRouter router;
  AgentServer server;

  nexus::cell::CellConfig cfg;
  cfg.ledger.ledger_dir  = "/tmp/nexus_cell_router_ledger";
  cfg.wisdom.wisdom_path = "/tmp/nexus_cell_router_wisdom.json";
  cfg.model.artifacts_dir = "/tmp/nexus_cell_router_model";
  cfg.research.cycle_interval = std::chrono::seconds{3600};
  cfg.model.train_interval    = std::chrono::seconds{3600};
  cfg.model.min_records_to_train = 10000;

  nexus::core::JobSystem jobs;
  nexus::cell::SelfImprovementScheduler sched(cfg);
  require(sched.init(jobs).isOk(), "router test scheduler init");

  require(router.init(&manipulator, &world).isOk(), "router init");
  router.setCellScheduler(&sched);
  require(server.init(&router).isOk(), "server init");

  // cell.status query
  require(server.receiveJson(R"json({
    "type": "query",
    "id": "cs_001",
    "payload": {"query": "cell.status"}
  })json").isOk(), "cell.status enqueued");
  auto responses = server.processQueuedCommands(1);
  require(responses.size() == 1,           "cell.status has response");
  require(responses[0].status == "ok",     "cell.status ok");
  require(responses[0].payload.contains("phase"), "cell.status has phase");

  // cell.wisdom query
  require(server.receiveJson(R"json({
    "type": "query",
    "id": "cw_001",
    "payload": {"query": "cell.wisdom", "domain": "renderer"}
  })json").isOk(), "cell.wisdom enqueued");
  responses = server.processQueuedCommands(1);
  require(responses.size() == 1,        "cell.wisdom has response");
  require(responses[0].status == "ok",  "cell.wisdom ok");

  // cell.observe command
  require(server.receiveJson(R"json({
    "type": "command",
    "id": "co_001",
    "payload": {
      "command": "cell.observe",
      "params": {"source_system": "test", "reward": 0.7, "data": {"fps": 55.0}}
    }
  })json").isOk(), "cell.observe enqueued");
  responses = server.processQueuedCommands(1);
  require(responses.size() == 1,        "cell.observe has response");
  require(responses[0].status == "ok",  "cell.observe ok");

  // cell.train_now command
  require(server.receiveJson(R"json({
    "type": "command",
    "id": "ct_001",
    "payload": {"command": "cell.train_now", "params": {}}
  })json").isOk(), "cell.train_now enqueued");
  responses = server.processQueuedCommands(1);
  require(responses.size() == 1,        "cell.train_now has response");
  require(responses[0].status == "ok",  "cell.train_now ok");

  // cell.reset_model command (no prior model — should report gracefully)
  require(server.receiveJson(R"json({
    "type": "command",
    "id": "crm_001",
    "payload": {"command": "cell.reset_model", "params": {}}
  })json").isOk(), "cell.reset_model enqueued");
  responses = server.processQueuedCommands(1);
  require(responses.size() == 1, "cell.reset_model has response");
  // status is "ok" or "error" depending on whether a prior model exists — both are valid.

  server.shutdown();
  router.shutdown();
  sched.shutdown();
}

// ── ModelTrainer quick predict (no actual training) ──────────────────────

void model_trainer_predict_with_no_weights() {
  nexus::cell::ModelTrainer trainer;
  // With zero weights the prediction should be 0 (bias initialised to 0).
  const double pred = trainer.predict({{"fps", 60.0}, {"frame_time", 16.7}});
  require(pred >= -1.0 && pred <= 1.0, "prediction within [-1, 1]");
  require(trainer.modelVersion() == 0, "version starts at 0");
}

} // namespace

auto main() -> int {
  observation_bus_push_and_drain();
  observation_bus_capacity_drop();

  experience_ledger_append_and_query();
  experience_ledger_capacity_eviction();

  wisdom_store_upsert_and_query();
  wisdom_store_decay();

  cell_phase_transitions();

  scheduler_init_status_shutdown();
  scheduler_cell_commands_via_router();

  model_trainer_predict_with_no_weights();

  std::fprintf(stderr, "PASS: nexus_cell_test\n");
  return 0;
}
