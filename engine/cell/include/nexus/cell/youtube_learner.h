#pragma once
// YouTubeLearner — CELL's self-development channel on YouTube.
//
// Teaches CELL to use YouTube the way it already uses IdleFeed sources: pull
// fresh videos from configured channels (Atom feeds — no API key), keep the
// ones relevant to its job (athlete development, game/engine craft) and
// interests, fetch the caption transcript (timedtext endpoint), distill it
// into key insight sentences, and commit them as low-confidence external
// knowledge into the WisdomStore (domain "youtube.<topic>") where the normal
// decay/evidence machinery vets them over time. Recent items also feed a
// current-events digest for the advisor/dashboard.
//
// Network calls follow the IdleFeed pattern: curl via popen with timeouts and
// bounded buffers. Set YouTubeLearnerConfig::stub_mode = true — or env
// NEXUS_CELL_YT_STUB=1 / CI=1 — and a small deterministic fixture is used
// instead (headless/CI safe). Transcripts only; nothing is downloaded.

#include <cstdint>
#include <mutex>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

namespace nexus::cell {

class WisdomStore;

// ── Data model ───────────────────────────────────────────────────────────────

/// A subject CELL studies. Channels are Atom feeds (channel_id form); keywords
/// gate relevance so an off-topic upload from a followed channel is skipped.
struct YouTubeTopic {
  std::string              id;         ///< short slug, e.g. "vertical_training"
  std::string              label;      ///< human label for digests
  std::vector<std::string> channel_ids;///< YouTube channel ids (UC…)
  std::vector<std::string> keywords;   ///< ≥1 must appear in title/summary/transcript
  std::size_t              max_videos_per_cycle{3};
};

struct VideoInsight {
  std::string              video_id;
  std::string              title;
  std::string              channel;
  std::string              published;    ///< ISO8601 from the feed
  std::string              topic_id;
  std::vector<std::string> key_points;   ///< distilled transcript sentences
  double                   relevance{0.0}; ///< keyword-density score [0,1]
  bool                     had_transcript{false};
};

struct YouTubeLearnerConfig {
  /// Deterministic fixture instead of network (env NEXUS_CELL_YT_STUB=1 / CI=1
  /// force this on).
  bool         stub_mode{false};
  /// Hard cap on feed fetches per learn cycle (across all topics).
  std::size_t  fetch_budget_per_cycle{8};
  /// Transcript bytes kept per video (timedtext responses can be large).
  std::size_t  transcript_char_cap{20000};
  /// Key sentences distilled per video.
  std::size_t  key_points_per_video{3};
  /// Confidence band for freshly ingested external knowledge. External claims
  /// enter LOW and must earn confidence through the store's evidence flow.
  double       min_confidence{0.30};
  double       max_confidence{0.55};
  /// Seen-video ledger so a video is studied once (JSON array on disk).
  std::string  seen_path{"artifacts/cell/youtube_seen.json"};
  /// curl timeouts, IdleFeed-style.
  int          connect_timeout_s{5};
  int          max_time_s{15};
};

// ── Learner ──────────────────────────────────────────────────────────────────

class YouTubeLearner {
public:
  explicit YouTubeLearner(YouTubeLearnerConfig config = {});

  /// Topics CELL starts with: its job (athlete development, movement science)
  /// and its craft interests (engine/graphics performance, game feel). Channel
  /// lists start empty — operators add real channels via addTopic/addChannel;
  /// stub fixtures exercise the full pipeline without network.
  static auto defaultTopics() -> std::vector<YouTubeTopic>;

  void addTopic(YouTubeTopic topic);
  auto addChannel(const std::string& topic_id, const std::string& channel_id) -> bool;
  [[nodiscard]] auto topics() const -> std::vector<YouTubeTopic>;

  /// One study cycle: fetch feeds → filter relevance → transcript → distill →
  /// WisdomStore upsert. Returns a report: {studied:[VideoInsight…],
  /// skipped, fetches_used, wisdom_written}.
  auto learnNow(WisdomStore& wisdom) -> nlohmann::json;

  /// Current-events digest: the most recent studied items (newest first),
  /// suitable for the advisor/dashboard. n ≤ retained history (last 50).
  [[nodiscard]] auto digest(std::size_t n) const -> nlohmann::json;

  [[nodiscard]] auto status() const -> nlohmann::json;

  /// Self-contained command surface, mirroring the cell.* command style:
  ///   cell.youtube.learn_now | cell.youtube.digest {n} |
  ///   cell.youtube.add_topic {id,label,keywords[],channel_ids[]} |
  ///   cell.youtube.add_channel {topic_id, channel_id} | cell.youtube.status
  /// Returns {status:"ok"|"error", ...}. WisdomStore passed by the owner.
  auto handleCommand(const std::string& command, const nlohmann::json& params,
                     WisdomStore& wisdom) -> nlohmann::json;

  // Exposed for tests: pure transforms.
  static auto parseAtomFeed(const std::string& xml, std::size_t max_entries)
      -> std::vector<VideoInsight>; ///< title/video_id/channel/published only
  static auto stripTimedText(const std::string& xml, std::size_t char_cap)
      -> std::string;
  static auto distill(const std::string& transcript,
                      const std::vector<std::string>& keywords,
                      std::size_t key_points, double& relevance_out)
      -> std::vector<std::string>;

private:
  auto fetchUrl(const std::string& url) -> std::string; ///< "" on failure/stub-miss
  auto loadSeen() -> void;
  auto saveSeen() const -> void;
  [[nodiscard]] auto isStub() const -> bool;

  YouTubeLearnerConfig       m_config;
  mutable std::mutex         m_mutex;
  std::vector<YouTubeTopic>  m_topics;
  std::vector<std::string>   m_seen;     ///< studied video ids
  std::vector<VideoInsight>  m_history;  ///< last 50 studied, newest first
  std::uint64_t              m_cycles{0};
  std::uint64_t              m_wisdom_written{0};
};

} // namespace nexus::cell
