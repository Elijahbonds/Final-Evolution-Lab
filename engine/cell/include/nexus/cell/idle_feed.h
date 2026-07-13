#pragma once

// CELL Idle Feed — World-Awareness Background Agent
//
// When CELL has no active experimentation work it "scrolls" a curated set of
// external knowledge sources: Hacker News top stories, GitHub Trending repos,
// arXiv CS/AI papers, and Dev.to articles. Each item is ingested as a
// kExternalKnowledge Observation pushed into ObservationBus so the
// ResearchLoop can build WisdomStore entries about current best practices,
// popular tools, and emerging techniques.
//
// Network calls are made via curl (same pattern as HttpClient). Set
// IdleFeedConfig::stub_mode = true (or env NEXUS_CELL_FEED_STUB=1) to use
// canned responses in unit tests and headless CI.

#include <atomic>
#include <chrono>
#include <condition_variable>
#include <cstddef>
#include <cstdint>
#include <mutex>
#include <string>
#include <thread>
#include <vector>

#include <nlohmann/json.hpp>

namespace nexus::cell {
class ObservationBus;
} // namespace nexus::cell

namespace nexus::cell {

// ── Data model ───────────────────────────────────────────────────────────────

enum class FeedSourceKind : std::uint8_t {
  kHackerNews,     ///< https://hacker-news.firebaseio.com — JSON API (no auth)
  kGitHubTrending, ///< https://api.github.com/search/repositories — JSON API
  kArXiv,          ///< https://export.arxiv.org/rss/cs.AI — RSS/XML
  kDevTo,          ///< https://dev.to/api/articles — JSON API (no auth)
  kCustomRss,      ///< Any RSS 2.0 / Atom feed URL supplied by the user
};

struct FeedSource {
  FeedSourceKind            kind{FeedSourceKind::kHackerNews};
  std::string               name;           ///< display label, used as source tag
  std::string               url;            ///< override URL; empty = use built-in default
  std::size_t               max_items{10};  ///< items to ingest per fetch cycle
  std::vector<std::string>  topic_filters;  ///< keep only items matching ≥1 keyword
};

struct FeedItem {
  std::string              title;
  std::string              url;
  std::string              source;   ///< FeedSource.name
  std::string              summary;  ///< short description or abstract (may be empty)
  double                   score{0.0}; ///< normalised engagement [0, 1]
  std::vector<std::string> tags;     ///< derived from title / metadata
};

// ── Configuration ─────────────────────────────────────────────────────────────

struct IdleFeedConfig {
  /// Time between full fetch cycles. Default: 5 minutes.
  std::chrono::seconds fetch_interval{300};

  /// Maximum observations to push per fetch cycle (across all sources).
  std::size_t max_items_per_cycle{50};

  /// When true (or env NEXUS_CELL_FEED_STUB=1), curl is not called; a small
  /// set of hard-coded canned items is used instead. Intended for tests and CI.
  bool stub_mode{false};

  /// Default keyword interest filters applied to all sources unless a
  /// FeedSource overrides them with its own topic_filters.
  std::vector<std::string> global_topic_filters{
      "ai", "machine learning", "reinforcement learning", "neural",
      "game engine", "physics", "c++", "swift", "ios", "mobile",
      "performance", "optimization", "athlete", "sports", "fitness",
      "rust", "gpu", "llm", "agent", "generative", "computer vision"};

  /// Feed sources to poll. Populated with sensible defaults when left empty.
  std::vector<FeedSource> sources;
};

// ── Main class ────────────────────────────────────────────────────────────────

class IdleFeed {
public:
  explicit IdleFeed(IdleFeedConfig config = {});
  ~IdleFeed();

  IdleFeed(const IdleFeed&)            = delete;
  IdleFeed& operator=(const IdleFeed&) = delete;

  /// Start the background polling thread.
  void start(ObservationBus& bus);

  /// Stop the background thread gracefully.
  void stop();

  /// Force an immediate fetch cycle (e.g., for cell.feed_ingest_now command).
  void fetchNow();

  [[nodiscard]] auto isRunning() const -> bool;
  [[nodiscard]] auto totalItemsIngested() const -> std::uint64_t;
  [[nodiscard]] auto cycleCount() const -> std::uint64_t;

  /// Returns a snapshot of the N most recently ingested items (thread-safe).
  [[nodiscard]] auto recentItems(std::size_t n = 20) const -> std::vector<FeedItem>;

private:
  void loop();
  void runOneCycle();

  // ── Per-source fetchers ────────────────────────────────────────────────────
  [[nodiscard]] auto fetchHackerNews(const FeedSource& src) -> std::vector<FeedItem>;
  [[nodiscard]] auto fetchGitHubTrending(const FeedSource& src) -> std::vector<FeedItem>;
  [[nodiscard]] auto fetchArXiv(const FeedSource& src) -> std::vector<FeedItem>;
  [[nodiscard]] auto fetchDevTo(const FeedSource& src) -> std::vector<FeedItem>;
  [[nodiscard]] auto fetchCustomRss(const FeedSource& src) -> std::vector<FeedItem>;

  // ── Canned stub responses (stub_mode == true) ─────────────────────────────
  [[nodiscard]] auto stubItems() -> std::vector<FeedItem>;

  // ── Helpers ───────────────────────────────────────────────────────────────
  [[nodiscard]] static auto httpGet(const std::string& url) -> std::string;
  [[nodiscard]] auto passesFilter(const FeedItem& item,
                                   const std::vector<std::string>& filters) const -> bool;
  [[nodiscard]] static auto deriveTags(const std::string& text) -> std::vector<std::string>;
  [[nodiscard]] static auto normaliseScore(double raw, double max_raw) -> double;
  void pushItem(const FeedItem& item);

  // ── Built-in source defaults ───────────────────────────────────────────────
  static void applySourceDefaults(std::vector<FeedSource>& sources);

  IdleFeedConfig         m_config;
  ObservationBus*        m_bus{nullptr};

  mutable std::mutex     m_recentMutex;
  std::vector<FeedItem>  m_recentItems;
  static constexpr std::size_t kRecentCapacity = 200;

  std::thread            m_thread;
  std::mutex             m_cvMutex;
  std::condition_variable m_cv;
  std::atomic<bool>      m_running{false};
  std::atomic<bool>      m_fetchNow{false};
  std::atomic<std::uint64_t> m_totalIngested{0};
  std::atomic<std::uint64_t> m_cycleCount{0};
};

} // namespace nexus::cell
