#include "nexus/cell/budget_meter.h"
#include "nexus/cell/experience_ledger.h"
#include "nexus/cell/mastery_tracker.h"
#include "nexus/cell/wisdom_store.h"
#include "nexus/cell/batch_learner.h"
#include "nexus/runtime/lesson_queue.h"
#include "nexus/runtime/provider_router.h"

#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <string>

namespace {

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

// ---------------------------------------------------------------------------
// BudgetMeter tests
// ---------------------------------------------------------------------------

void budget_meter_allows_under_cap() {
  auto& meter = nexus::cell::BudgetMeter::instance();
  nexus::cell::BudgetConfig cfg;
  cfg.maxTokensPerDay["test_sub"] = 1000;
  cfg.logDirectory = "/tmp/cell_test_budget";
  meter.configure(cfg);
  meter.resetDaily();
  require(meter.consume("test_sub", 100), "consume under cap should succeed");
  require(meter.consume("test_sub", 800), "consume still under cap should succeed");
  require(!meter.consume("test_sub", 200), "consume over cap should fail");
}

void budget_meter_status_reflects_usage() {
  auto& meter = nexus::cell::BudgetMeter::instance();
  nexus::cell::BudgetConfig cfg;
  cfg.maxTokensPerDay["status_sub"] = 500;
  cfg.logDirectory = "/tmp/cell_test_budget";
  meter.configure(cfg);
  meter.resetDaily();
  const bool consumed = meter.consume("status_sub", 200);
  require(consumed, "consume within cap should succeed");
  const auto st = meter.status("status_sub");
  require(st.usedToday == 200, "used reflects consumed tokens");
  require(st.dailyCap == 500, "cap matches config");
  require(!st.overBudget(), "not over budget yet");
}

// ---------------------------------------------------------------------------
// WisdomStore tests
// ---------------------------------------------------------------------------

void wisdom_store_set_get_roundtrip() {
  nexus::cell::WisdomStore store({"/tmp/cell_test_wisdom/wisdom.json"});
  store.set("hello", "world");
  const auto val = store.get("hello");
  require(val.has_value(), "key should be found");
  require(val->get<std::string>() == "world", "value should match");
}

void wisdom_store_missing_key_returns_nullopt() {
  nexus::cell::WisdomStore store;
  require(!store.get("nonexistent").has_value(), "missing key returns nullopt");
}

void wisdom_store_remove_key() {
  nexus::cell::WisdomStore store;
  store.set("tmp_key", 42);
  require(store.has("tmp_key"), "key exists before remove");
  store.remove("tmp_key");
  require(!store.has("tmp_key"), "key gone after remove");
}

// ---------------------------------------------------------------------------
// MasteryTracker / BKT tests
// ---------------------------------------------------------------------------

void mastery_tracker_starts_at_p_l0() {
  nexus::cell::WisdomStore store;
  nexus::cell::MasteryTracker tracker(store);
  const float p = tracker.getMastery("user1", "skill_a");
  require(p >= 0.0F && p <= 1.0F, "initial mastery in [0,1]");
  require(p < 0.5F, "initial mastery should be low");
}

void mastery_tracker_increases_on_correct() {
  nexus::cell::WisdomStore store;
  nexus::cell::MasteryTracker tracker(store);
  const float p0 = tracker.getMastery("user1", "skill_b");
  tracker.update("user1", "skill_b", true);
  const float p1 = tracker.getMastery("user1", "skill_b");
  require(p1 > p0, "correct response increases mastery");
}

void mastery_tracker_not_mastered_initially() {
  nexus::cell::WisdomStore store;
  nexus::cell::MasteryTracker tracker(store);
  require(!tracker.isMastered("user1", "skill_c"), "not mastered on first observation");
}

void mastery_tracker_reaches_threshold_with_many_correct() {
  nexus::cell::WisdomStore store;
  nexus::cell::MasteryConfig cfg;
  cfg.masteryThreshold = 0.95F;
  nexus::cell::MasteryTracker tracker(store, cfg);
  for (int i = 0; i < 50; ++i) {
    tracker.update("user1", "skill_d", true);
  }
  require(tracker.isMastered("user1", "skill_d"), "mastered after many correct responses");
}

// ---------------------------------------------------------------------------
// ExperienceLedger tests
// ---------------------------------------------------------------------------

void experience_ledger_append_and_read() {
  const std::string dir = "/tmp/cell_test_ledger";
  std::filesystem::remove_all(dir);
  nexus::cell::ExperienceLedger ledger(dir);
  const auto r1 = ledger.append({{"session_id", "s1"}, {"score", 80}});
  require(r1.isOk(), "append should succeed");
  const auto r2 = ledger.append({{"session_id", "s2"}, {"score", 90}});
  require(r2.isOk(), "second append should succeed");
  const auto records = ledger.readRecent(10);
  require(records.size() == 2, "should read back 2 records");
}

// ---------------------------------------------------------------------------
// LessonQueue tests
// ---------------------------------------------------------------------------

void lesson_queue_returns_unmastered_skills() {
  nexus::cell::WisdomStore store;
  nexus::cell::MasteryTracker mastery(store);
  nexus::runtime::LessonQueue queue(mastery);
  queue.registerSkill("skill_x");
  queue.registerSkill("skill_y");
  const auto lessons = queue.computeQueue("user_q");
  require(lessons.size() == 2, "two unmastered skills should be queued");
  require(lessons[0].pMastery <= lessons[1].pMastery,
          "lessons sorted ascending by mastery");
}

void lesson_queue_excludes_mastered_skills() {
  nexus::cell::WisdomStore store;
  nexus::cell::MasteryConfig cfg;
  cfg.masteryThreshold = 0.5F;
  nexus::cell::MasteryTracker mastery(store, cfg);
  // Artificially set high mastery via many correct responses.
  for (int i = 0; i < 30; ++i) {
    mastery.update("user_q2", "mastered_skill", true);
  }
  nexus::runtime::LessonQueue queue(mastery);
  queue.registerSkill("mastered_skill");
  const auto lessons = queue.computeQueue("user_q2");
  require(lessons.empty(), "mastered skill should not appear in queue");
}

// ---------------------------------------------------------------------------
// ProviderRouter tests
// ---------------------------------------------------------------------------

void provider_router_routes_coaching() {
  nexus::runtime::ProviderRouter router;
  const auto result = router.route("coaching", "lesson_dunk_v1");
  require(!result.fromCache, "first request is not cached");
  require(!result.providerName.empty(), "should have a provider");
  require(result.cacheKey.size() > 0, "cache key should be non-empty");
}

void provider_router_caches_response() {
  nexus::runtime::ProviderRouter router;
  router.cacheResponse("my_lesson_key", {{"title", "Dunk Lesson"}});
  const auto cached = router.getCached("my_lesson_key");
  require(cached.has_value(), "cached entry should be found");
  require((*cached)["title"] == "Dunk Lesson", "cached value matches");
  require(router.cacheSize() == 1, "cache size is 1");
  const auto routeResult = router.route("lesson_serve", "my_lesson_key");
  require(routeResult.fromCache, "route should return fromCache=true for cached key");
}

void provider_router_deterministic_lesson_serve_has_no_provider() {
  nexus::runtime::ProviderRouter router;
  const auto result = router.route("lesson_serve", "uncached_key_xyz");
  require(result.providerName == "none", "lesson_serve with no cache should return 'none'");
}

} // namespace

auto main() -> int {
  // BudgetMeter
  budget_meter_allows_under_cap();
  budget_meter_status_reflects_usage();

  // WisdomStore
  wisdom_store_set_get_roundtrip();
  wisdom_store_missing_key_returns_nullopt();
  wisdom_store_remove_key();

  // MasteryTracker
  mastery_tracker_starts_at_p_l0();
  mastery_tracker_increases_on_correct();
  mastery_tracker_not_mastered_initially();
  mastery_tracker_reaches_threshold_with_many_correct();

  // ExperienceLedger
  experience_ledger_append_and_read();

  // LessonQueue
  lesson_queue_returns_unmastered_skills();
  lesson_queue_excludes_mastered_skills();

  // ProviderRouter
  provider_router_routes_coaching();
  provider_router_caches_response();
  provider_router_deterministic_lesson_serve_has_no_provider();

  std::fprintf(stderr, "PASS: nexus_cell_test\n");
  return 0;
}
