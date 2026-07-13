#include "nexus/cell/youtube_learner.h"

#include <algorithm>
#include <array>
#include <cctype>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <sstream>

#include "nexus/cell/wisdom_store.h"

namespace nexus::cell {
namespace {

auto nowMs() -> std::uint64_t {
  return static_cast<std::uint64_t>(
      std::chrono::duration_cast<std::chrono::milliseconds>(
          std::chrono::system_clock::now().time_since_epoch())
          .count());
}

auto toLower(std::string s) -> std::string {
  std::transform(s.begin(), s.end(), s.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return s;
}

/// First text between <tag ...> and </tag> after `from`; empty if absent.
auto tagText(const std::string& xml, const std::string& tag, std::size_t from,
             std::size_t* end_out = nullptr) -> std::string {
  const std::string open = "<" + tag;
  const std::string close = "</" + tag + ">";
  const auto o = xml.find(open, from);
  if (o == std::string::npos) return {};
  const auto gt = xml.find('>', o);
  if (gt == std::string::npos) return {};
  const auto c = xml.find(close, gt);
  if (c == std::string::npos) return {};
  if (end_out != nullptr) *end_out = c + close.size();
  return xml.substr(gt + 1, c - gt - 1);
}

auto xmlUnescape(std::string s) -> std::string {
  static const std::array<std::pair<const char*, const char*>, 5> kEnts{{
      {"&amp;", "&"}, {"&lt;", "<"}, {"&gt;", ">"}, {"&quot;", "\""}, {"&#39;", "'"}}};
  for (const auto& [ent, ch] : kEnts) {
    std::size_t p = 0;
    while ((p = s.find(ent, p)) != std::string::npos) {
      s.replace(p, std::strlen(ent), ch);
      p += std::strlen(ch);
    }
  }
  return s;
}

/// Deterministic fixture: one channel feed + transcript, so the whole pipeline
/// (parse → filter → distill → wisdom) runs headless.
constexpr const char* kStubFeed = R"(<feed xmlns:yt="http://www.youtube.com/xml/schemas/2015">
<title>FEL Stub Coaching Channel</title>
<entry><yt:videoId>stub_vert_01</yt:videoId><title>Vertical jump training: approach and takeoff mechanics</title><published>2026-07-12T09:00:00+00:00</published><author><name>Stub Coaching</name></author></entry>
<entry><yt:videoId>stub_cook_01</yt:videoId><title>My favorite pasta recipe</title><published>2026-07-11T09:00:00+00:00</published><author><name>Stub Coaching</name></author></entry>
<entry><yt:videoId>stub_perf_01</yt:videoId><title>Game engine frame pacing and GPU optimization deep dive</title><published>2026-07-10T09:00:00+00:00</published><author><name>Stub Coaching</name></author></entry>
</feed>)";

constexpr const char* kStubTranscript = R"(<transcript>
<text start="0" dur="4">Penultimate step length drives vertical jump height more than raw strength.</text>
<text start="4" dur="4">Plant the takeoff foot heel to toe and keep the chest tall through the jump.</text>
<text start="8" dur="4">Most athletes leak power by letting the arms trail the hips on the way up.</text>
<text start="12" dur="4">Film your approach from the side and check the last two steps every session.</text>
</transcript>)";

} // namespace

// ── ctor / topics ────────────────────────────────────────────────────────────

YouTubeLearner::YouTubeLearner(YouTubeLearnerConfig config)
    : m_config(std::move(config)), m_topics(defaultTopics()) {
  loadSeen();
}

auto YouTubeLearner::defaultTopics() -> std::vector<YouTubeTopic> {
  // Job first, then craft interests. Channels intentionally empty (operator
  // supplied); keywords are the relevance gate either way.
  return {
      {"vertical_training", "Vertical jump & dunk training", {},
       {"vertical", "jump", "dunk", "plyometric", "takeoff", "approach"}, 3},
      {"karate_technique", "Karate & striking technique", {},
       {"karate", "kick", "punch", "stance", "sparring", "kumite"}, 3},
      {"movement_science", "Biomechanics & athlete development", {},
       {"biomechanics", "mobility", "sprint", "landing", "injury", "strength"}, 3},
      {"engine_craft", "Game engine & graphics performance", {},
       {"engine", "gpu", "render", "frame", "optimization", "shader"}, 3},
      {"game_feel", "Game design & game feel", {},
       {"game feel", "juice", "animation", "camera", "input", "design"}, 3},
      {"fel_current_events", "Sports-tech & AI current events", {},
       {"ai", "sports tech", "training", "wearable", "mocap", "release"}, 3},
  };
}

void YouTubeLearner::addTopic(YouTubeTopic topic) {
  std::lock_guard<std::mutex> lock(m_mutex);
  for (auto& t : m_topics) {
    if (t.id == topic.id) { t = std::move(topic); return; }
  }
  m_topics.push_back(std::move(topic));
}

auto YouTubeLearner::addChannel(const std::string& topic_id,
                                const std::string& channel_id) -> bool {
  std::lock_guard<std::mutex> lock(m_mutex);
  for (auto& t : m_topics) {
    if (t.id == topic_id) {
      if (std::find(t.channel_ids.begin(), t.channel_ids.end(), channel_id) ==
          t.channel_ids.end()) {
        t.channel_ids.push_back(channel_id);
      }
      return true;
    }
  }
  return false;
}

auto YouTubeLearner::topics() const -> std::vector<YouTubeTopic> {
  std::lock_guard<std::mutex> lock(m_mutex);
  return m_topics;
}

// ── pure transforms ──────────────────────────────────────────────────────────

auto YouTubeLearner::parseAtomFeed(const std::string& xml, std::size_t max_entries)
    -> std::vector<VideoInsight> {
  std::vector<VideoInsight> out;
  const std::string channel = xmlUnescape(tagText(xml, "title", 0));
  std::size_t pos = 0;
  while (out.size() < max_entries) {
    const auto e = xml.find("<entry>", pos);
    if (e == std::string::npos) break;
    std::size_t entry_end = xml.find("</entry>", e);
    if (entry_end == std::string::npos) break;
    const std::string entry = xml.substr(e, entry_end - e);
    VideoInsight v;
    v.video_id = tagText(entry, "yt:videoId", 0);
    v.title = xmlUnescape(tagText(entry, "title", 0));
    v.published = tagText(entry, "published", 0);
    v.channel = channel;
    if (!v.video_id.empty() && !v.title.empty()) out.push_back(std::move(v));
    pos = entry_end + 8;
  }
  return out;
}

auto YouTubeLearner::stripTimedText(const std::string& xml, std::size_t char_cap)
    -> std::string {
  std::string out;
  std::size_t pos = 0;
  while (out.size() < char_cap) {
    std::size_t end = 0;
    const std::string t = tagText(xml, "text", pos, &end);
    if (end == 0) break;
    if (!t.empty()) {
      out += xmlUnescape(t);
      out += ' ';
    }
    pos = end;
  }
  if (out.size() > char_cap) out.resize(char_cap);
  return out;
}

auto YouTubeLearner::distill(const std::string& transcript,
                             const std::vector<std::string>& keywords,
                             std::size_t key_points, double& relevance_out)
    -> std::vector<std::string> {
  // Extractive, deterministic, no-LLM: split into sentences, score by keyword
  // hits (earlier sentences win ties — creators front-load the thesis).
  std::vector<std::string> sentences;
  std::string cur;
  for (char c : transcript) {
    cur += c;
    if (c == '.' || c == '!' || c == '?') {
      if (cur.size() > 15) sentences.push_back(cur);
      cur.clear();
    }
  }
  if (cur.size() > 15) sentences.push_back(cur);

  const std::string lower_all = toLower(transcript);
  std::size_t total_hits = 0;
  for (const auto& k : keywords) {
    std::size_t p = 0;
    while ((p = lower_all.find(toLower(k), p)) != std::string::npos) {
      ++total_hits;
      p += k.size();
    }
  }
  relevance_out = sentences.empty()
                      ? 0.0
                      : std::min(1.0, static_cast<double>(total_hits) /
                                          static_cast<double>(sentences.size()));

  std::vector<std::pair<double, std::size_t>> scored;
  for (std::size_t i = 0; i < sentences.size(); ++i) {
    const std::string ls = toLower(sentences[i]);
    double score = 0.0;
    for (const auto& k : keywords) {
      if (ls.find(toLower(k)) != std::string::npos) score += 1.0;
    }
    score += 0.1 * (1.0 - static_cast<double>(i) /
                              static_cast<double>(sentences.size()));
    if (score > 0.0) scored.emplace_back(score, i);
  }
  std::stable_sort(scored.begin(), scored.end(),
                   [](const auto& a, const auto& b) { return a.first > b.first; });

  std::vector<std::size_t> picked;
  for (const auto& [s, i] : scored) {
    if (picked.size() >= key_points) break;
    picked.push_back(i);
  }
  std::sort(picked.begin(), picked.end()); // keep narrative order
  std::vector<std::string> out;
  for (auto i : picked) {
    std::string s = sentences[i];
    while (!s.empty() && (s.front() == ' ')) s.erase(s.begin());
    out.push_back(std::move(s));
  }
  return out;
}

// ── network / stub ───────────────────────────────────────────────────────────

auto YouTubeLearner::isStub() const -> bool {
  if (m_config.stub_mode) return true;
  const char* stub = std::getenv("NEXUS_CELL_YT_STUB");
  if (stub != nullptr && std::string(stub) == "1") return true;
  return std::getenv("CI") != nullptr;
}

auto YouTubeLearner::fetchUrl(const std::string& url) -> std::string {
  if (isStub()) {
    if (url.find("feeds/videos.xml") != std::string::npos) return kStubFeed;
    if (url.find("timedtext") != std::string::npos) return kStubTranscript;
    return {};
  }
  // IdleFeed pattern: curl with timeouts, bounded read.
  std::string cmd = "curl -fsSL --connect-timeout " +
                    std::to_string(m_config.connect_timeout_s) + " --max-time " +
                    std::to_string(m_config.max_time_s) + " \"" + url + "\" 2>/dev/null";
  FILE* pipe = popen(cmd.c_str(), "r");
  if (pipe == nullptr) return {};
  std::string out;
  std::array<char, 4096> buf{};
  const std::size_t cap = 512 * 1024; // bound the response
  while (fgets(buf.data(), static_cast<int>(buf.size()), pipe) != nullptr &&
         out.size() < cap) {
    out += buf.data();
  }
  pclose(pipe);
  return out;
}

// ── seen ledger ──────────────────────────────────────────────────────────────

void YouTubeLearner::loadSeen() {
  std::ifstream in(m_config.seen_path);
  if (!in.good()) return;
  try {
    nlohmann::json j;
    in >> j;
    if (j.is_array()) {
      for (const auto& v : j) m_seen.push_back(v.get<std::string>());
    }
  } catch (...) { /* corrupt ledger -> start fresh */ }
}

void YouTubeLearner::saveSeen() const {
  std::error_code ec;
  std::filesystem::create_directories(
      std::filesystem::path(m_config.seen_path).parent_path(), ec);
  std::ofstream out(m_config.seen_path, std::ios::trunc);
  if (out.good()) out << nlohmann::json(m_seen).dump();
}

// ── learn cycle ──────────────────────────────────────────────────────────────

auto YouTubeLearner::learnNow(WisdomStore& wisdom) -> nlohmann::json {
  std::lock_guard<std::mutex> lock(m_mutex);
  ++m_cycles;
  std::size_t fetches = 0;
  std::size_t skipped = 0;
  nlohmann::json studied = nlohmann::json::array();

  for (const auto& topic : m_topics) {
    // In stub mode exercise every topic against the fixture feed; live mode
    // requires configured channels.
    std::vector<std::string> channels = topic.channel_ids;
    if (channels.empty() && isStub()) channels.push_back("UC_stub_channel");

    for (const auto& ch : channels) {
      if (fetches >= m_config.fetch_budget_per_cycle) break;
      ++fetches;
      const std::string feed =
          fetchUrl("https://www.youtube.com/feeds/videos.xml?channel_id=" + ch);
      if (feed.empty()) continue;

      auto entries = parseAtomFeed(feed, topic.max_videos_per_cycle * 2);
      std::size_t taken = 0;
      for (auto& v : entries) {
        if (taken >= topic.max_videos_per_cycle) break;
        if (std::find(m_seen.begin(), m_seen.end(), v.video_id) != m_seen.end()) {
          ++skipped;
          continue;
        }
        // Title must clear the topic gate before we spend a transcript fetch.
        const std::string lt = toLower(v.title);
        const bool title_hit = std::any_of(
            topic.keywords.begin(), topic.keywords.end(),
            [&](const std::string& k) { return lt.find(toLower(k)) != std::string::npos; });
        if (!title_hit) {
          ++skipped;
          m_seen.push_back(v.video_id); // off-topic: don't re-examine forever
          continue;
        }

        std::string transcript;
        if (fetches < m_config.fetch_budget_per_cycle) {
          ++fetches;
          transcript = stripTimedText(
              fetchUrl("https://www.youtube.com/api/timedtext?lang=en&v=" + v.video_id),
              m_config.transcript_char_cap);
        }
        v.had_transcript = !transcript.empty();
        const std::string body = v.had_transcript ? transcript : v.title;
        v.key_points = distill(body, topic.keywords,
                               m_config.key_points_per_video, v.relevance);
        v.topic_id = topic.id;

        // External knowledge enters LOW confidence; the store's evidence/decay
        // machinery is the vetting mechanism, exactly like other CELL inputs.
        const double conf =
            m_config.min_confidence +
            (m_config.max_confidence - m_config.min_confidence) *
                std::min(1.0, v.relevance);
        for (const auto& point : v.key_points) {
          WisdomEntry entry;
          entry.domain = "youtube." + topic.id;
          entry.rule_text = point + " [" + v.title + " — " + v.channel +
                            ", yt:" + v.video_id + "]";
          entry.confidence = conf;
          entry.evidence_count = 1;
          entry.last_updated_ms = nowMs();
          entry.tier = WisdomTier::kTactical;
          wisdom.upsert(std::move(entry));
          ++m_wisdom_written;
        }

        m_seen.push_back(v.video_id);
        m_history.insert(m_history.begin(), v);
        if (m_history.size() > 50) m_history.resize(50);
        ++taken;

        nlohmann::json jv;
        jv["video_id"] = v.video_id;
        jv["title"] = v.title;
        jv["topic"] = topic.id;
        jv["relevance"] = v.relevance;
        jv["key_points"] = v.key_points;
        jv["had_transcript"] = v.had_transcript;
        studied.push_back(std::move(jv));
      }
    }
    if (fetches >= m_config.fetch_budget_per_cycle) break;
  }

  saveSeen();
  return {{"status", "ok"},
          {"studied", studied},
          {"skipped", skipped},
          {"fetches_used", fetches},
          {"wisdom_written", m_wisdom_written},
          {"stub_mode", isStub()}};
}

// ── digest / status / commands ───────────────────────────────────────────────

auto YouTubeLearner::digest(std::size_t n) const -> nlohmann::json {
  std::lock_guard<std::mutex> lock(m_mutex);
  nlohmann::json items = nlohmann::json::array();
  for (std::size_t i = 0; i < m_history.size() && i < n; ++i) {
    const auto& v = m_history[i];
    items.push_back({{"video_id", v.video_id},
                     {"title", v.title},
                     {"channel", v.channel},
                     {"published", v.published},
                     {"topic", v.topic_id},
                     {"key_points", v.key_points}});
  }
  return {{"status", "ok"}, {"items", items}};
}

auto YouTubeLearner::status() const -> nlohmann::json {
  std::lock_guard<std::mutex> lock(m_mutex);
  nlohmann::json jt = nlohmann::json::array();
  for (const auto& t : m_topics) {
    jt.push_back({{"id", t.id},
                  {"label", t.label},
                  {"channels", t.channel_ids.size()},
                  {"keywords", t.keywords.size()}});
  }
  return {{"status", "ok"},
          {"cycles", m_cycles},
          {"videos_studied", m_history.size()},
          {"seen_total", m_seen.size()},
          {"wisdom_written", m_wisdom_written},
          {"topics", jt}};
}

auto YouTubeLearner::handleCommand(const std::string& command,
                                   const nlohmann::json& params,
                                   WisdomStore& wisdom) -> nlohmann::json {
  if (command == "cell.youtube.learn_now") return learnNow(wisdom);
  if (command == "cell.youtube.digest") {
    return digest(params.value("n", static_cast<std::size_t>(10)));
  }
  if (command == "cell.youtube.status") return status();
  if (command == "cell.youtube.add_channel") {
    const bool ok = addChannel(params.value("topic_id", ""),
                               params.value("channel_id", ""));
    return {{"status", ok ? "ok" : "error"},
            {"error", ok ? "" : "unknown topic_id"}};
  }
  if (command == "cell.youtube.add_topic") {
    if (!params.contains("id") || !params.contains("keywords")) {
      return {{"status", "error"}, {"error", "id and keywords required"}};
    }
    YouTubeTopic t;
    t.id = params.value("id", "");
    t.label = params.value("label", t.id);
    for (const auto& k : params["keywords"]) t.keywords.push_back(k.get<std::string>());
    if (params.contains("channel_ids")) {
      for (const auto& c : params["channel_ids"]) t.channel_ids.push_back(c.get<std::string>());
    }
    addTopic(std::move(t));
    return {{"status", "ok"}};
  }
  return {{"status", "error"}, {"error", "unknown cell.youtube command"}};
}

} // namespace nexus::cell
