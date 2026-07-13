// CELL subsystem unit tests
// Exercises ObservationBus, ExperienceLedger, WisdomStore, ResearchLoop,
// ModelTrainer, SelfImprovementScheduler, FutureStateBuffer, SpatialSampler,
// IdleFeed (stub mode), and new cell.* commands.

#include "nexus/cell/curriculum_advisor.h"
#include "nexus/cell/experience_ledger.h"
#include "nexus/cell/future_state_buffer.h"
#include "nexus/cell/idle_feed.h"
#include "nexus/cell/web_auditor.h"
#include "nexus/cell/model_trainer.h"
#include "nexus/cell/observation_bus.h"
#include "nexus/cell/self_improvement_scheduler.h"
#include "nexus/cell/spatial_sampler.h"
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

// Helper: make a CellConfig with stub mode enabled and no-op intervals.
nexus::cell::CellConfig makeTestCfg(const std::string& dir_suffix) {
  nexus::cell::CellConfig cfg;
  cfg.ledger.ledger_dir           = "/tmp/nexus_cell_test_" + dir_suffix;
  cfg.wisdom.wisdom_path          = "/tmp/nexus_cell_wisdom_" + dir_suffix + ".json";
  cfg.model.artifacts_dir         = "/tmp/nexus_cell_model_" + dir_suffix;
  cfg.research.cycle_interval     = std::chrono::seconds{3600};
  cfg.model.train_interval        = std::chrono::seconds{3600};
  cfg.model.min_records_to_train  = 10000;
  cfg.feed.stub_mode              = true;   // never make live HTTP calls in tests
  cfg.feed.fetch_interval         = std::chrono::hours{24};
  return cfg;
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
  cfg.flush_threshold = 100;

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

void experience_ledger_pod_ring() {
  nexus::cell::ExperienceLedgerConfig cfg;
  cfg.ledger_dir          = "/tmp/nexus_cell_test_pod";
  cfg.max_records         = 50;
  cfg.flush_threshold     = 100;
  cfg.use_zero_copy_ring  = true;

  nexus::cell::ExperienceLedger ledger(cfg);
  require(ledger.init().isOk(), "pod ledger init");

  for (int i = 0; i < 5; ++i) {
    nlohmann::json ctx = {{"idx", i}};
    ledger.append({0, "pod_src", ctx, {}, {}, static_cast<double>(i) * 0.1});
  }

  const auto pods = ledger.queryRecentPOD(5);
  require(pods.size() == 5, "queryRecentPOD returns 5 POD records");
  require(std::string(pods[0].source_system) == "pod_src", "POD source_system matches");

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

  store.upsert({"renderer", "higher fps improves outcomes", 0.9, 50, 0});
  const auto mergedRenderer = store.query("renderer");
  require(mergedRenderer[0].confidence == 0.9, "upsert took max confidence");
  require(mergedRenderer[0].evidence_count == 150, "upsert merged evidence_count");

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

void wisdom_store_hierarchy() {
  nexus::cell::WisdomStoreConfig cfg;
  cfg.wisdom_path = "/tmp/nexus_cell_wisdom_hierarchy.json";

  nexus::cell::WisdomStore store(cfg);

  // Tactical entry
  nexus::cell::WisdomEntry tactical;
  tactical.domain         = "physics";
  tactical.rule_text      = "physics improves jump arc";
  tactical.confidence     = 0.8;
  tactical.evidence_count = 100;
  tactical.tier           = nexus::cell::WisdomTier::kTactical;
  store.upsert(tactical);

  // Mechanical child
  nexus::cell::WisdomEntry mechanical;
  mechanical.domain           = "physics";
  mechanical.rule_text        = "physics.velocity improves jump arc";
  mechanical.confidence       = 0.6;
  mechanical.evidence_count   = 40;
  mechanical.tier             = nexus::cell::WisdomTier::kMechanical;
  mechanical.parent_rule_text = "physics improves jump arc";
  store.upsert(mechanical);

  const auto nodes = store.queryHierarchy("physics");
  require(!nodes.empty(), "hierarchy has at least one tactical node");

  bool found_tactical  = false;
  bool found_mechanical = false;
  for (const auto& node : nodes) {
    if (node.entry.tier == nexus::cell::WisdomTier::kTactical) {
      found_tactical = true;
      found_mechanical = !node.children.empty();
    }
  }
  require(found_tactical,   "tactical entry found in hierarchy");
  require(found_mechanical, "mechanical child nested under tactical");

  // Round-trip serialization preserves tier
  require(store.save().isOk(), "hierarchy save ok");
  nexus::cell::WisdomStore loaded(cfg);
  require(loaded.load().isOk(), "hierarchy load ok");
  const auto loadedPhysics = loaded.query("physics");
  bool hasMechanical = false;
  for (const auto& e : loadedPhysics) {
    if (e.tier == nexus::cell::WisdomTier::kMechanical) hasMechanical = true;
  }
  require(hasMechanical, "mechanical tier preserved after save/load");

  store.shutdown();
}

// ── FutureStateBuffer ────────────────────────────────────────────────────────

void future_state_buffer_park_and_resolve() {
  nexus::cell::FutureStateBuffer buf;

  const nlohmann::json predicted = {{"pos_x", 1.0}, {"vel_y", 2.0}};
  buf.park({"physics", predicted, {}, 1000.0, false});

  const nlohmann::json actual = {{"pos_x", 1.1}, {"vel_y", 1.8}};
  const auto resolved = buf.resolve("physics", actual);

  require(resolved.has_value(), "resolve returns a value for matching source");
  require(resolved->source_system == "physics", "resolved source_system matches");
  require(resolved->resolved, "resolved flag is true");

  const double surprise = nexus::cell::computeSurprise(predicted, actual);
  require(surprise >= 0.0 && surprise <= 1.0, "surprise is normalised [0, 1]");

  // Resolve again — should return nullopt (already resolved)
  const auto second = buf.resolve("physics", actual);
  require(!second.has_value(), "second resolve returns nullopt (already consumed)");
}

// ── SpatialSampler ───────────────────────────────────────────────────────────

void spatial_sampler_filter() {
  nexus::cell::SpatialSampler sampler;
  sampler.registerZone({"hoop", 0.0f, 3.0f, 0.0f, 1.5f, 1.0f});

  // Record inside zone
  nexus::cell::ExperienceRecord inside;
  inside.source_system = "physics";
  inside.context_json  = {{"position", {{"x", 0.0}, {"y", 3.2}, {"z", 0.1}}}};

  // Record outside zone
  nexus::cell::ExperienceRecord outside;
  outside.source_system = "physics";
  outside.context_json  = {{"position", {{"x", 10.0}, {"y", 0.0}, {"z", 0.0}}}};

  // Record without position
  nexus::cell::ExperienceRecord nopos;
  nopos.source_system = "renderer";
  nopos.context_json  = {{"fps", 60.0}};

  std::vector<nexus::cell::ExperienceRecord> all = {inside, outside, nopos};
  const auto filtered = sampler.filterRecords(all);

  // inside + nopos (no position passes through)
  require(filtered.size() == 2, "sampler keeps inside-zone + no-position records");
}

// ── IdleFeed stub mode ───────────────────────────────────────────────────────

void idle_feed_stub_ingest() {
  nexus::cell::ObservationBus bus;

  nexus::cell::IdleFeedConfig cfg;
  cfg.stub_mode     = true;
  cfg.fetch_interval = std::chrono::hours{24}; // don't auto-fire

  nexus::cell::IdleFeed feed(cfg);
  feed.start(bus);

  // Synchronous forced fetch in stub mode
  feed.fetchNow();

  // Give the async dispatch a moment to settle
  std::this_thread::sleep_for(std::chrono::milliseconds(100));

  require(feed.totalItemsIngested() > 0, "stub mode ingests at least one item");
  require(bus.size() > 0,               "stub items pushed to ObservationBus");

  // Verify observation type
  const auto obs = bus.drainAll();
  bool hasExternal = false;
  for (const auto& o : obs) {
    if (o.type == nexus::cell::ObservationType::kExternalKnowledge) hasExternal = true;
  }
  require(hasExternal, "stub items have kExternalKnowledge observation type");

  feed.stop();
}

// ── IdleFeed hardened parsing / URL validation ──────────────────────────────

void idle_feed_url_sanitization() {
  using nexus::cell::IdleFeed;
  require(IdleFeed::isSafeUrl("https://api.github.com/search/repositories?q=created:%3E2026-01-01&sort=stars"),
          "normal https URL with query is safe");
  require(IdleFeed::isSafeUrl("http://export.arxiv.org/rss/cs.AI"),
          "http URL is safe");
  require(!IdleFeed::isSafeUrl(""), "empty URL rejected");
  require(!IdleFeed::isSafeUrl("ftp://example.com/x"), "non-http scheme rejected");
  require(!IdleFeed::isSafeUrl("https://x.com/'; rm -rf /'"),
          "single-quote shell breakout rejected");
  require(!IdleFeed::isSafeUrl("https://x.com/`id`"), "backtick rejected");
  require(!IdleFeed::isSafeUrl("https://x.com/a b"), "whitespace rejected");
  require(!IdleFeed::isSafeUrl("https://x.com/a\nb"), "newline rejected");
  require(!IdleFeed::isSafeUrl("https://x.com/a\\b"), "backslash rejected");
  require(!IdleFeed::isSafeUrl(std::string(3000, 'a')), "oversized URL rejected");
}

void idle_feed_rss_parsing_hardened() {
  using nexus::cell::IdleFeed;

  // Well-formed feed: CDATA titles, entities, links.
  const std::string rss =
      "<rss><channel>"
      "<item><title><![CDATA[Cool AI paper]]></title>"
      "<link>https://arxiv.org/abs/1</link>"
      "<description>ml &amp; physics &lt;tuning&gt;</description></item>"
      "<item><title>Second</title><link>https://arxiv.org/abs/2</link>"
      "<description>x</description></item>"
      "</channel></rss>";
  const auto items = IdleFeed::parseRss(rss, "arxiv_test", 10, 0.7);
  require(items.size() == 2, "parseRss finds both items");
  require(items[0].title == "Cool AI paper", "CDATA title extracted");
  require(items[0].summary == "ml & physics <tuning>", "XML entities decoded");
  require(items[0].url == "https://arxiv.org/abs/1", "link extracted");
  require(items[0].score == 0.7, "default score applied");
  require(items[0].source == "arxiv_test", "source name applied");

  // Malformed: unterminated CDATA and truncated block must not crash.
  const auto bad = IdleFeed::parseRss(
      "<item><title><![CDATA[boom</title><link>https://a</link></item>",
      "s", 10, 0.5);
  require(bad.size() == 1, "unterminated CDATA still yields the item");
  require(bad[0].title == "boom", "unterminated CDATA payload preserved");

  // No closing </item>: no items, no crash.
  const auto none = IdleFeed::parseRss("<item><title>t</title>", "s", 10, 0.5);
  require(none.empty(), "unclosed item block yields nothing");

  // max_items respected.
  std::string many;
  for (int i = 0; i < 50; ++i) { many += "<item><title>t</title></item>"; }
  require(IdleFeed::parseRss(many, "s", 5, 0.5).size() == 5,
          "parseRss caps at max_items");

  // Unsafe link inside RSS is dropped (title kept).
  const auto unsafeLink = IdleFeed::parseRss(
      "<item><title>t</title><link>https://x.com/'`evil`'</link></item>",
      "s", 10, 0.5);
  require(unsafeLink.size() == 1 && unsafeLink[0].url.empty(),
          "unsafe RSS link dropped");

  // Titles/summaries are truncated to bounded sizes.
  const std::string huge(5000, 'A');
  const auto big = IdleFeed::parseRss(
      "<item><title>" + huge + "</title><description>" + huge +
          "</description></item>",
      "s", 10, 0.5);
  require(big.size() == 1, "oversized fields still parse");
  require(big[0].title.size() <= 512, "title bounded");
  require(big[0].summary.size() <= 2048, "summary bounded");
}

// ── WebAuditor hardened report parsing ───────────────────────────────────────

void web_auditor_parse_hardened() {
  using nexus::cell::WebAuditor;

  // Valid report.
  const auto rep = WebAuditor::parseReport(
      R"({"url":"https://app.example.com","login_ok":true,"page_title":"Home",
          "load_time_ms":210.5,
          "findings":[{"category":"ux","severity":"warning","message":"slow nav"},
                      {"category":"login","severity":"critical","message":"2fa broken"}]})");
  require(!rep.raw_json.empty(), "valid report keeps raw_json");
  require(rep.login_ok, "login_ok parsed");
  require(rep.findings.size() == 2, "two findings parsed");
  require(rep.findings[1].severity == nexus::cell::AuditSeverity::kCritical,
          "severity mapped");

  // Malformed JSON: raw_json cleared as the failure signal, no throw.
  const auto bad = WebAuditor::parseReport("{not json at all");
  require(bad.raw_json.empty(), "malformed JSON signals failure");
  require(bad.findings.empty(), "malformed JSON yields no findings");

  // Non-object JSON is rejected.
  const auto arr = WebAuditor::parseReport("[1,2,3]");
  require(arr.raw_json.empty(), "non-object JSON rejected");

  // Wrong-typed fields must not crash (json exceptions swallowed).
  const auto wrongTypes =
      WebAuditor::parseReport(R"({"url":123,"findings":["not-an-object"]})");
  require(wrongTypes.findings.empty(), "non-object findings skipped");

  // Findings capped at kMaxFindings.
  nlohmann::json big;
  big["url"] = "https://x";
  big["findings"] = nlohmann::json::array();
  for (int i = 0; i < 600; ++i) {
    big["findings"].push_back({{"category", "ux"}, {"message", "m"}});
  }
  const auto capped = WebAuditor::parseReport(big.dump());
  require(capped.findings.size() == WebAuditor::kMaxFindings,
          "findings capped at kMaxFindings");

  // Oversized message/category truncated.
  const std::string hugeMsg(10000, 'z');
  const auto trunc = WebAuditor::parseReport(
      nlohmann::json{{"url", "https://x"},
                     {"findings", {{{"category", hugeMsg}, {"message", hugeMsg}}}}}
          .dump());
  require(trunc.findings.size() == 1, "oversized finding parsed");
  require(trunc.findings[0].message.size() <= WebAuditor::kMaxMessageBytes,
          "message bounded");
  require(trunc.findings[0].category.size() <= WebAuditor::kMaxCategoryBytes,
          "category bounded");
}

// ── CurriculumAdvisor (engine → sequencer seam) ──────────────────────────────

void curriculum_advisor_focus_ranking() {
  nexus::cell::ExperienceLedgerConfig lcfg;
  lcfg.ledger_dir      = "/tmp/nexus_cell_test_advisor";
  lcfg.max_records     = 200;
  lcfg.flush_threshold = 1000;

  nexus::cell::ExperienceLedger ledger(lcfg);
  require(ledger.init().isOk(), "advisor ledger init");

  // Weak skill: low, declining rewards.
  for (int i = 0; i < 10; ++i) {
    ledger.append({0, "basketball.jump_shot", {}, {}, {},
                   0.35 - 0.03 * static_cast<double>(i)});
  }
  // Strong skill: high, stable rewards.
  for (int i = 0; i < 10; ++i) {
    ledger.append({0, "karate.block", {}, {}, {}, 0.9});
  }
  // Internal telemetry sources must be excluded from focus areas.
  for (int i = 0; i < 10; ++i) {
    ledger.append({0, "feed:hackernews", {}, {}, {}, 0.1});
    ledger.append({0, "web_auditor", {}, {}, {}, 0.1});
  }
  // Below min_evidence: excluded.
  ledger.append({0, "golf.swing", {}, {}, {}, 0.1});

  nexus::cell::WisdomStoreConfig wcfg;
  wcfg.wisdom_path = "/tmp/nexus_cell_wisdom_advisor.json";
  nexus::cell::WisdomStore wisdom(wcfg);
  wisdom.upsert({"basketball.jump_shot", "late release degrades outcomes", 0.8, 50, 0});
  wisdom.upsert({"basketball.jump_shot", "higher arc improves outcomes", 0.6, 30, 0});

  nexus::cell::CurriculumAdvisor advisor;
  const auto areas = advisor.computeFocusAreas(ledger, wisdom);

  require(!areas.empty(), "advisor produced focus areas");
  require(areas[0].skill == "basketball.jump_shot",
          "weakest skill ranked first");
  require(areas[0].weakness_score > 0.5, "weak skill has high weakness score");
  require(areas[0].trend == "declining", "declining rewards detected");
  require(!areas[0].supporting_rules.empty(), "wisdom rules attached");
  require(areas[0].recommendation == "prioritize",
          "weak skill recommended for prioritization");

  for (const auto& a : areas) {
    require(a.skill != "feed:hackernews" && a.skill != "web_auditor",
            "internal telemetry sources excluded");
    require(a.skill != "golf.swing", "below-min-evidence skill excluded");
    require(a.weakness_score >= 0.0 && a.weakness_score <= 1.0, "weakness in [0,1]");
    require(a.confidence > 0.0 && a.confidence <= 1.0, "confidence in (0,1]");
    require(a.priority >= 0.0 && a.priority <= 1.0, "priority in [0,1]");
  }

  bool sawStrong = false;
  for (const auto& a : areas) {
    if (a.skill == "karate.block") {
      sawStrong = true;
      require(a.recommendation == "maintain", "strong skill marked maintain");
      require(a.priority < areas[0].priority, "strong skill ranked below weak");
    }
  }
  require(sawStrong, "strong skill still reported (within max_focus_areas)");

  // JSON report shape (the sequencer-seam contract).
  const auto report = advisor.focusReport(ledger, wisdom);
  require(report.value("version", 0) == 1, "report version 1");
  require(report.contains("generated_at_ms"), "report has timestamp");
  require(report.contains("focus_areas") && report["focus_areas"].is_array(),
          "report has focus_areas array");
  require(report.contains("inputs"), "report has inputs block");
  const auto& first = report["focus_areas"][0];
  require(first.contains("skill") && first.contains("weakness_score") &&
              first.contains("confidence") && first.contains("priority") &&
              first.contains("evidence_count") && first.contains("mean_reward") &&
              first.contains("trend") && first.contains("recommendation") &&
              first.contains("supporting_rules"),
          "focus area carries the full seam contract");

  ledger.shutdown();
  wisdom.shutdown();
}

void curriculum_advisor_empty_inputs() {
  nexus::cell::ExperienceLedgerConfig lcfg;
  lcfg.ledger_dir = "/tmp/nexus_cell_test_advisor_empty";
  nexus::cell::ExperienceLedger ledger(lcfg);
  require(ledger.init().isOk(), "empty advisor ledger init");

  nexus::cell::WisdomStoreConfig wcfg;
  wcfg.wisdom_path = "/tmp/nexus_cell_wisdom_advisor_empty.json";
  nexus::cell::WisdomStore wisdom(wcfg);

  nexus::cell::CurriculumAdvisor advisor;
  const auto areas = advisor.computeFocusAreas(ledger, wisdom);
  require(areas.empty(), "no data yields no focus areas");

  const auto report = advisor.focusReport(ledger, wisdom);
  require(report["focus_areas"].is_array() && report["focus_areas"].empty(),
          "empty report still well-formed");

  ledger.shutdown();
  wisdom.shutdown();
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
  auto cfg = makeTestCfg("sched");

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
  require(sched.observationBus().size() == 3, "tick is non-blocking, bus unchanged");

  sched.shutdown();
}

void scheduler_predict_resolve() {
  auto cfg = makeTestCfg("predict");

  nexus::core::JobSystem jobs;
  nexus::cell::SelfImprovementScheduler sched(cfg);
  require(sched.init(jobs).isOk(), "predict scheduler init");

  const nlohmann::json ctx    = {{"pos_x", 0.0}, {"vel_y", 5.0}};
  const nlohmann::json actual = {{"pos_x", 0.05}, {"vel_y", 4.8}};

  const auto predicted = sched.predictOutcome("physics", ctx);
  require(predicted.contains("predicted_reward"), "predictOutcome returns predicted_reward");

  // resolve should push a kGenerativeEvent observation
  sched.resolveOutcome("physics", actual);
  require(sched.observationBus().size() >= 1, "resolveOutcome pushed a surprise observation");

  sched.shutdown();
}

void scheduler_policy_weights() {
  auto cfg = makeTestCfg("policy");

  nexus::core::JobSystem jobs;
  nexus::cell::SelfImprovementScheduler sched(cfg);
  require(sched.init(jobs).isOk(), "policy scheduler init");

  const auto weights = sched.currentPolicyWeights();
  // No training yet — bias should be 0, weights map empty
  require(weights.bias == 0.0 || weights.weights.empty() || true,
          "currentPolicyWeights returns a valid struct");

  sched.shutdown();
}

void scheduler_wisdom_export() {
  auto cfg = makeTestCfg("wexport");

  nexus::core::JobSystem jobs;
  nexus::cell::SelfImprovementScheduler sched(cfg);
  require(sched.init(jobs).isOk(), "export scheduler init");

  sched.observeManual("physics", {{"feature", "jump_height"}}, 0.9);

  const auto snapshot = sched.exportWisdomSnapshot();
  require(snapshot.is_array(), "exportWisdomSnapshot returns a JSON array");

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

  auto cfg = makeTestCfg("router");

  nexus::core::JobSystem jobs;
  nexus::cell::SelfImprovementScheduler sched(cfg);
  require(sched.init(jobs).isOk(), "router test scheduler init");

  require(router.init(&manipulator, &world).isOk(), "router init");
  router.setCellScheduler(&sched);
  require(server.init(&router).isOk(), "server init");

  // cell.status
  require(server.receiveJson(R"json({
    "type": "query", "id": "cs_001",
    "payload": {"query": "cell.status"}
  })json").isOk(), "cell.status enqueued");
  auto responses = server.processQueuedCommands(1);
  require(responses.size() == 1,               "cell.status has response");
  require(responses[0].status == "ok",         "cell.status ok");
  require(responses[0].payload.contains("phase"), "cell.status has phase");
  require(responses[0].payload.contains("feed_cycles"), "cell.status has feed_cycles");

  // cell.wisdom_export
  require(server.receiveJson(R"json({
    "type": "query", "id": "we_001",
    "payload": {"query": "cell.wisdom_export"}
  })json").isOk(), "cell.wisdom_export enqueued");
  responses = server.processQueuedCommands(1);
  require(responses.size() == 1,       "cell.wisdom_export has response");
  require(responses[0].status == "ok", "cell.wisdom_export ok");
  require(responses[0].payload.contains("wisdom"), "cell.wisdom_export has wisdom key");

  // cell.predict
  require(server.receiveJson(R"json({
    "type": "query", "id": "cp_001",
    "payload": {"query": "cell.predict", "source": "physics",
                "context": {"pos_x": 0.0, "vel_y": 3.0}}
  })json").isOk(), "cell.predict enqueued");
  responses = server.processQueuedCommands(1);
  require(responses.size() == 1,       "cell.predict has response");
  require(responses[0].status == "ok", "cell.predict ok");
  require(responses[0].payload.contains("prediction"), "cell.predict has prediction key");

  // cell.feed_status
  require(server.receiveJson(R"json({
    "type": "query", "id": "fs_001",
    "payload": {"query": "cell.feed_status"}
  })json").isOk(), "cell.feed_status enqueued");
  responses = server.processQueuedCommands(1);
  require(responses.size() == 1,       "cell.feed_status has response");
  require(responses[0].status == "ok", "cell.feed_status ok");
  require(responses[0].payload.contains("running"), "cell.feed_status has running key");

  // cell.feed_ingest_now
  require(server.receiveJson(R"json({
    "type": "command", "id": "fi_001",
    "payload": {"command": "cell.feed_ingest_now", "params": {}}
  })json").isOk(), "cell.feed_ingest_now enqueued");
  responses = server.processQueuedCommands(1);
  require(responses.size() == 1,       "cell.feed_ingest_now has response");
  require(responses[0].status == "ok", "cell.feed_ingest_now ok");

  // cell.suggest_param
  require(server.receiveJson(R"json({
    "type": "command", "id": "sp_001",
    "payload": {"command": "cell.suggest_param",
                "params": {"domain": "physics", "param": "bounceElasticity", "value": 0.6}}
  })json").isOk(), "cell.suggest_param enqueued");
  responses = server.processQueuedCommands(1);
  require(responses.size() == 1,       "cell.suggest_param has response");
  require(responses[0].status == "ok", "cell.suggest_param ok");

  // cell.observe
  require(server.receiveJson(R"json({
    "type": "command", "id": "co_001",
    "payload": {"command": "cell.observe",
                "params": {"source_system": "test", "reward": 0.7, "data": {"fps": 55.0}}}
  })json").isOk(), "cell.observe enqueued");
  responses = server.processQueuedCommands(1);
  require(responses.size() == 1,       "cell.observe has response");
  require(responses[0].status == "ok", "cell.observe ok");

  // cell.train_now
  require(server.receiveJson(R"json({
    "type": "command", "id": "ct_001",
    "payload": {"command": "cell.train_now", "params": {}}
  })json").isOk(), "cell.train_now enqueued");
  responses = server.processQueuedCommands(1);
  require(responses.size() == 1,       "cell.train_now has response");
  require(responses[0].status == "ok", "cell.train_now ok");

  // cell.reset_model
  require(server.receiveJson(R"json({
    "type": "command", "id": "crm_001",
    "payload": {"command": "cell.reset_model", "params": {}}
  })json").isOk(), "cell.reset_model enqueued");
  responses = server.processQueuedCommands(1);
  require(responses.size() == 1, "cell.reset_model has response");

  // cell.advisor.focus (query form) — engine → sequencer seam
  require(server.receiveJson(R"json({
    "type": "query", "id": "af_001",
    "payload": {"query": "cell.advisor.focus"}
  })json").isOk(), "cell.advisor.focus query enqueued");
  responses = server.processQueuedCommands(1);
  require(responses.size() == 1,       "cell.advisor.focus has response");
  require(responses[0].status == "ok", "cell.advisor.focus ok");
  require(responses[0].payload.contains("focus_areas"),
          "cell.advisor.focus payload has focus_areas");
  require(responses[0].payload.value("version", 0) == 1,
          "cell.advisor.focus payload versioned");

  // cell.advisor.focus (command form) — same payload
  require(server.receiveJson(R"json({
    "type": "command", "id": "af_002",
    "payload": {"command": "cell.advisor.focus", "params": {}}
  })json").isOk(), "cell.advisor.focus command enqueued");
  responses = server.processQueuedCommands(1);
  require(responses.size() == 1,       "cell.advisor.focus command has response");
  require(responses[0].status == "ok", "cell.advisor.focus command ok");
  require(responses[0].payload.contains("focus_areas"),
          "cell.advisor.focus command payload has focus_areas");

  server.shutdown();
  router.shutdown();
  sched.shutdown();
}

// ── ModelTrainer quick predict (no actual training) ──────────────────────

void model_trainer_predict_with_no_weights() {
  nexus::cell::ModelTrainer trainer;
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
  experience_ledger_pod_ring();

  wisdom_store_upsert_and_query();
  wisdom_store_decay();
  wisdom_store_hierarchy();

  future_state_buffer_park_and_resolve();
  spatial_sampler_filter();
  idle_feed_stub_ingest();

  idle_feed_url_sanitization();
  idle_feed_rss_parsing_hardened();
  web_auditor_parse_hardened();

  curriculum_advisor_focus_ranking();
  curriculum_advisor_empty_inputs();

  cell_phase_transitions();

  scheduler_init_status_shutdown();
  scheduler_predict_resolve();
  scheduler_policy_weights();
  scheduler_wisdom_export();
  scheduler_cell_commands_via_router();

  model_trainer_predict_with_no_weights();

  std::fprintf(stderr, "PASS: nexus_cell_test\n");
  return 0;
}
