// YouTubeLearner behavioral tests — run fully in stub mode (no network).
#include <cassert>
#include <cstdio>
#include <filesystem>

#include "nexus/cell/wisdom_store.h"
#include "nexus/cell/youtube_learner.h"

using nexus::cell::WisdomStore;
using nexus::cell::WisdomStoreConfig;
using nexus::cell::YouTubeLearner;
using nexus::cell::YouTubeLearnerConfig;

namespace {
int g_failures = 0;
void require(bool ok, const char* what) {
  if (!ok) {
    std::printf("FAIL: %s\n", what);
    ++g_failures;
  } else {
    std::printf("  ok: %s\n", what);
  }
}

auto tmpPath(const char* leaf) -> std::string {
  return (std::filesystem::temp_directory_path() / leaf).string();
}
} // namespace

int main() {
  // ── pure transforms ────────────────────────────────────────────────────────
  {
    const std::string feed = R"(<feed><title>Chan &amp; Co</title>
<entry><yt:videoId>abc</yt:videoId><title>Dunk approach basics</title><published>2026-07-01T00:00:00+00:00</published></entry>
<entry><yt:videoId>def</yt:videoId><title>Cooking pasta</title><published>2026-07-02T00:00:00+00:00</published></entry></feed>)";
    auto entries = YouTubeLearner::parseAtomFeed(feed, 10);
    require(entries.size() == 2, "atom parse finds both entries");
    require(entries[0].video_id == "abc" && entries[0].title == "Dunk approach basics",
            "atom parse extracts id+title");
    require(entries[0].channel == "Chan & Co", "atom parse unescapes channel");
  }
  {
    const std::string tt =
        "<transcript><text start=\"0\">First point about jumping.</text>"
        "<text start=\"4\">Second &amp; final point.</text></transcript>";
    const auto text = YouTubeLearner::stripTimedText(tt, 1000);
    require(text.find("First point about jumping.") != std::string::npos &&
                text.find("Second & final point.") != std::string::npos,
            "timedtext strip concatenates + unescapes");
    require(YouTubeLearner::stripTimedText(tt, 10).size() <= 10,
            "timedtext respects char cap");
  }
  {
    double rel = 0.0;
    auto pts = YouTubeLearner::distill(
        "The jump starts with the approach. Pasta is nice sometimes here. "
        "Penultimate step length drives jump height. Keep arms driving upward on the jump.",
        {"jump", "approach"}, 2, rel);
    require(pts.size() == 2, "distill picks requested count");
    require(pts[0].find("approach") != std::string::npos ||
                pts[0].find("jump") != std::string::npos,
            "distilled points are keyword-relevant");
    require(rel > 0.0 && rel <= 1.0, "relevance in (0,1]");
  }

  // ── full stub pipeline ─────────────────────────────────────────────────────
  {
    YouTubeLearnerConfig cfg;
    cfg.stub_mode = true;
    cfg.seen_path = tmpPath("yt_seen_test.json");
    std::filesystem::remove(cfg.seen_path);

    WisdomStoreConfig wc;
    wc.wisdom_path = tmpPath("yt_wisdom_test.json");
    std::filesystem::remove(wc.wisdom_path);
    WisdomStore wisdom(wc);

    YouTubeLearner learner(cfg);
    require(learner.topics().size() >= 5, "default topics cover job + interests");

    auto report = learner.learnNow(wisdom);
    require(report["status"] == "ok", "learn cycle ok");
    require(report["studied"].size() >= 1, "stub feed yields studied videos");
    // The off-topic stub video (pasta) must be filtered, not studied.
    bool pasta = false;
    for (const auto& v : report["studied"]) {
      if (v["video_id"] == "stub_cook_01") pasta = true;
    }
    require(!pasta, "off-topic video filtered by keyword gate");
    require(report["wisdom_written"].get<std::uint64_t>() >= 1,
            "wisdom entries written");
    require(wisdom.query("youtube.vertical_training").size() >= 1,
            "wisdom queryable under youtube.<topic> domain");
    const auto entries = wisdom.query("youtube.vertical_training");
    require(!entries.empty() && entries[0].confidence <= 0.55 + 1e-9,
            "external knowledge enters at low confidence");
    require(!entries.empty() &&
                entries[0].rule_text.find("yt:stub_vert_01") != std::string::npos,
            "wisdom carries source attribution");

    // Second cycle: seen-ledger dedupe means nothing new is studied.
    auto report2 = learner.learnNow(wisdom);
    require(report2["studied"].empty(), "seen ledger prevents re-study");

    auto digest = learner.digest(5);
    require(digest["items"].size() >= 1 &&
                digest["items"][0]["key_points"].size() >= 1,
            "digest returns recent items with key points");

    // Command surface.
    auto add = learner.handleCommand(
        "cell.youtube.add_topic",
        {{"id", "nutrition"}, {"keywords", {"protein", "recovery"}}}, wisdom);
    require(add["status"] == "ok", "cell.youtube.add_topic ok");
    auto st = learner.handleCommand("cell.youtube.status", {}, wisdom);
    require(st["status"] == "ok" && st["topics"].size() >= 6,
            "cell.youtube.status reflects added topic");
    auto bad = learner.handleCommand("cell.youtube.nope", {}, wisdom);
    require(bad["status"] == "error", "unknown command errors");

    std::filesystem::remove(cfg.seen_path);
    std::filesystem::remove(wc.wisdom_path);
  }

  if (g_failures == 0) {
    std::printf("youtube_learner_test: ALL PASS\n");
    return 0;
  }
  std::printf("youtube_learner_test: %d FAILURES\n", g_failures);
  return 1;
}
