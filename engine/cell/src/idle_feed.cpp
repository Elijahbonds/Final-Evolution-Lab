#include "nexus/cell/idle_feed.h"

#include "nexus/cell/observation_bus.h"
#include "nexus/core/log.h"

#include <algorithm>
#include <cctype>
#include <chrono>
#include <cstdio>
#include <cstring>
#include <sstream>

namespace nexus::cell {

namespace {

// ── Tag vocabulary CELL cares about ─────────────────────────────────────────

static const std::vector<std::string> kTagVocab = {
    "ai", "ml", "llm", "gpt", "neural", "transformer", "reinforcement",
    "generative", "diffusion", "embedding", "rag", "agent",
    "game", "engine", "physics", "graphics", "renderer", "vulkan", "metal",
    "gpu", "shader", "wgpu", "opengl",
    "c++", "rust", "swift", "go", "python", "zig",
    "ios", "mobile", "android", "xcode",
    "performance", "optimization", "memory", "profiling", "simd",
    "athlete", "sports", "fitness", "biomechanics", "training",
    "open source", "github", "trending", "paper", "research", "arxiv",
};

auto lowercase(std::string s) -> std::string {
  std::transform(s.begin(), s.end(), s.begin(),
                 [](unsigned char c) { return static_cast<char>(std::tolower(c)); });
  return s;
}

// ── Env helpers ──────────────────────────────────────────────────────────────

auto envTruthy(const char* name) -> bool {
  const char* v = std::getenv(name);
  return v != nullptr && v[0] != '\0' && std::strcmp(v, "0") != 0 &&
         std::strcmp(v, "false") != 0;
}

// ── Hardening limits ─────────────────────────────────────────────────────────

constexpr std::size_t kMaxHttpResponseBytes = 4 * 1024 * 1024; ///< 4 MiB cap
constexpr std::size_t kMaxRssBlockBytes     = 64 * 1024;       ///< per <item>
constexpr std::size_t kMaxTitleBytes        = 512;
constexpr std::size_t kMaxSummaryBytes      = 2048;

// ── Lightweight curl GET wrapper (bounded, timeouts, validated URL) ─────────

auto curlGet(const std::string& url) -> std::string {
  // Defense in depth: the caller validates too, but never build a shell
  // command from an unvalidated URL.
  if (!nexus::cell::IdleFeed::isSafeUrl(url)) { return {}; }

  std::string cmd = "curl -s --connect-timeout 5 --max-time 10 "
                    "--max-filesize " + std::to_string(kMaxHttpResponseBytes) +
                    " -L "
                    "-H 'User-Agent: NEXUS-CELL/1.0 (Final-Evolution-Lab)' "
                    "'";
  cmd += url;
  cmd += "'";
  FILE* pipe = popen(cmd.c_str(), "r"); // NOLINT
  if (pipe == nullptr) { return {}; }
  char buf[8192];
  std::string result;
  result.reserve(65536);
  while (std::fgets(buf, sizeof(buf), pipe) != nullptr) {
    result += buf;
    if (result.size() > kMaxHttpResponseBytes) {
      result.resize(kMaxHttpResponseBytes); // hard cap regardless of server
      break;
    }
  }
  pclose(pipe); // NOLINT
  return result;
}

// ── XML entity decoding ──────────────────────────────────────────────────────

auto decodeXmlEntities(std::string text) -> std::string {
  // &amp; decoded last so "&amp;lt;" stays "&lt;" (no double decoding).
  static constexpr std::pair<const char*, const char*> kEntities[] = {
      {"&lt;", "<"}, {"&gt;", ">"}, {"&quot;", "\""},
      {"&apos;", "'"}, {"&#39;", "'"}, {"&amp;", "&"},
  };
  for (const auto& [from, to] : kEntities) {
    const std::size_t fromLen = std::strlen(from);
    std::size_t pos = 0;
    while ((pos = text.find(from, pos)) != std::string::npos) {
      text.replace(pos, fromLen, to);
      pos += std::strlen(to);
    }
  }
  return text;
}

// ── Simple RSS/XML title extractor ───────────────────────────────────────────

// Extracts text between the first occurrence of <open> and </close>.
auto xmlTag(const std::string& xml, const std::string& tag,
             std::size_t from = 0) -> std::pair<std::string, std::size_t> {
  const std::string open  = "<" + tag + ">";
  const std::string openC = "<" + tag + " ";
  const std::string close = "</" + tag + ">";

  std::size_t start = xml.find(open, from);
  const std::size_t startC = xml.find(openC, from);
  if (startC != std::string::npos &&
      (start == std::string::npos || startC < start)) {
    start = xml.find(">", startC);
    if (start != std::string::npos) { ++start; }
  } else if (start != std::string::npos) {
    start += open.size();
  } else {
    return {"", std::string::npos};
  }
  if (start == std::string::npos) { return {"", std::string::npos}; }

  const std::size_t end = xml.find(close, start);
  if (end == std::string::npos) { return {"", std::string::npos}; }

  std::string text = xml.substr(start, end - start);
  // Strip CDATA if present — tolerate truncated / malformed CDATA sections.
  constexpr const char* kCdata    = "<![CDATA[";
  constexpr std::size_t kCdataLen = 9;
  if (text.rfind(kCdata, 0) == 0) {
    const std::size_t closer = text.rfind("]]>");
    if (closer != std::string::npos && closer >= kCdataLen) {
      text = text.substr(kCdataLen, closer - kCdataLen);
    } else {
      text = text.substr(kCdataLen); // unterminated CDATA: keep the payload
    }
  }
  return {text, end + close.size()};
}

} // namespace

// ── Lifecycle ────────────────────────────────────────────────────────────────

IdleFeed::IdleFeed(IdleFeedConfig config) : m_config(std::move(config)) {
  applySourceDefaults(m_config.sources);
}

IdleFeed::~IdleFeed() { stop(); }

void IdleFeed::start(ObservationBus& bus) {
  m_bus = &bus;
  m_running.store(true, std::memory_order_release);
  m_thread = std::thread([this] { loop(); });
  NEXUS_LOG_INFO(LogChannel::kCell, "IdleFeed started (" +
                                        std::to_string(m_config.sources.size()) + " sources)");
}

void IdleFeed::stop() {
  if (!m_running.load(std::memory_order_acquire)) { return; }
  m_running.store(false, std::memory_order_release);
  {
    std::scoped_lock lock(m_cvMutex);
    m_fetchNow.store(true, std::memory_order_release);
  }
  m_cv.notify_all();
  if (m_thread.joinable()) { m_thread.join(); }
  NEXUS_LOG_INFO(LogChannel::kCell, "IdleFeed stopped (cycles=" +
                                        std::to_string(m_cycleCount.load()) +
                                        " ingested=" + std::to_string(m_totalIngested.load()) + ")");
}

void IdleFeed::fetchNow() {
  {
    std::scoped_lock lock(m_cvMutex);
    m_fetchNow.store(true, std::memory_order_release);
  }
  m_cv.notify_one();
}

auto IdleFeed::isRunning() const -> bool {
  return m_running.load(std::memory_order_acquire);
}

auto IdleFeed::totalItemsIngested() const -> std::uint64_t {
  return m_totalIngested.load(std::memory_order_relaxed);
}

auto IdleFeed::cycleCount() const -> std::uint64_t {
  return m_cycleCount.load(std::memory_order_relaxed);
}

auto IdleFeed::recentItems(std::size_t n) const -> std::vector<FeedItem> {
  std::scoped_lock lock(m_recentMutex);
  if (m_recentItems.size() <= n) { return m_recentItems; }
  return std::vector<FeedItem>(m_recentItems.end() - static_cast<std::ptrdiff_t>(n),
                                m_recentItems.end());
}

// ── Background loop ──────────────────────────────────────────────────────────

void IdleFeed::loop() {
  while (m_running.load(std::memory_order_acquire)) {
    {
      std::unique_lock<std::mutex> lock(m_cvMutex);
      m_cv.wait_for(lock, m_config.fetch_interval, [this] {
        return m_fetchNow.load(std::memory_order_acquire) ||
               !m_running.load(std::memory_order_acquire);
      });
      m_fetchNow.store(false, std::memory_order_release);
    }
    if (!m_running.load(std::memory_order_acquire)) { break; }
    runOneCycle();
  }
}

void IdleFeed::runOneCycle() {
  NEXUS_LOG_INFO(LogChannel::kCell, "IdleFeed cycle " +
                                        std::to_string(m_cycleCount.load() + 1) + " starting");
  std::size_t pushed = 0;

  // Stub mode: use canned items instead of live network calls.
  // Graceful default in headless/CI environments (NEXUS_HEADLESS / CI).
  if (stubModeActive()) {
    for (const auto& item : stubItems()) {
      if (pushed >= m_config.max_items_per_cycle) { break; }
      pushItem(item);
      ++pushed;
    }
    m_cycleCount.fetch_add(1, std::memory_order_relaxed);
    NEXUS_LOG_INFO(LogChannel::kCell, "IdleFeed stub cycle done (" +
                                          std::to_string(pushed) + " items)");
    return;
  }

  for (const auto& src : m_config.sources) {
    if (pushed >= m_config.max_items_per_cycle) { break; }

    std::vector<FeedItem> items;
    switch (src.kind) {
    case FeedSourceKind::kHackerNews:    items = fetchHackerNews(src);    break;
    case FeedSourceKind::kGitHubTrending: items = fetchGitHubTrending(src); break;
    case FeedSourceKind::kArXiv:         items = fetchArXiv(src);         break;
    case FeedSourceKind::kDevTo:         items = fetchDevTo(src);          break;
    case FeedSourceKind::kCustomRss:     items = fetchCustomRss(src);      break;
    }

    const auto& filters = src.topic_filters.empty() ? m_config.global_topic_filters
                                                      : src.topic_filters;
    for (const auto& item : items) {
      if (pushed >= m_config.max_items_per_cycle) { break; }
      if (!passesFilter(item, filters)) { continue; }
      pushItem(item);
      ++pushed;
    }
  }

  m_cycleCount.fetch_add(1, std::memory_order_relaxed);
  NEXUS_LOG_INFO(LogChannel::kCell, "IdleFeed cycle done (" +
                                        std::to_string(pushed) + " items ingested)");
}

// ── Per-source fetchers ───────────────────────────────────────────────────────

auto IdleFeed::fetchHackerNews(const FeedSource& src) -> std::vector<FeedItem> {
  // Step 1: fetch top story IDs.
  const std::string indexUrl =
      src.url.empty()
          ? "https://hacker-news.firebaseio.com/v0/topstories.json"
          : src.url;
  const std::string indexBody = httpGet(indexUrl);
  if (indexBody.empty()) { return {}; }

  const nlohmann::json ids = nlohmann::json::parse(indexBody, nullptr, false);
  if (ids.is_discarded() || !ids.is_array()) { return {}; }

  std::vector<FeedItem> out;
  const std::size_t limit = std::min(src.max_items, ids.size());
  double maxScore = 1.0;

  for (std::size_t i = 0; i < limit; ++i) {
    const auto id = ids[i].get<std::int64_t>();
    const std::string itemUrl =
        "https://hacker-news.firebaseio.com/v0/item/" + std::to_string(id) + ".json";
    const std::string itemBody = httpGet(itemUrl);
    if (itemBody.empty()) { continue; }

    const nlohmann::json item = nlohmann::json::parse(itemBody, nullptr, false);
    if (item.is_discarded()) { continue; }

    const std::string type = item.value("type", "");
    if (type != "story") { continue; }

    FeedItem fi;
    fi.source  = src.name;
    fi.title   = item.value("title", "");
    fi.url     = item.value("url", "https://news.ycombinator.com/item?id=" + std::to_string(id));
    fi.summary = item.value("text", "");
    const double rawScore = static_cast<double>(item.value("score", 0));
    maxScore = std::max(maxScore, rawScore);
    fi.score   = rawScore; // normalise after collecting all
    fi.tags    = deriveTags(fi.title + " " + fi.summary);
    out.push_back(std::move(fi));
  }

  // Normalise scores to [0, 1].
  for (auto& fi : out) {
    fi.score = normaliseScore(fi.score, maxScore);
  }
  return out;
}

auto IdleFeed::fetchGitHubTrending(const FeedSource& src) -> std::vector<FeedItem> {
  // Use GitHub search API — top-starred repos created in the last 7 days.
  using namespace std::chrono;
  const auto now  = system_clock::now();
  const auto week = now - days{7};
  const std::time_t weekT = system_clock::to_time_t(week);
  std::tm* tm = std::gmtime(&weekT); // NOLINT
  char dateBuf[16];
  std::strftime(dateBuf, sizeof(dateBuf), "%Y-%m-%d", tm);

  const std::string url =
      src.url.empty()
          ? std::string("https://api.github.com/search/repositories"
                        "?q=created:%3E") +
                dateBuf + "&sort=stars&order=desc&per_page=" +
                std::to_string(src.max_items)
          : src.url;

  const std::string body = httpGet(url);
  if (body.empty()) { return {}; }

  const nlohmann::json j = nlohmann::json::parse(body, nullptr, false);
  if (j.is_discarded() || !j.contains("items")) { return {}; }

  std::vector<FeedItem> out;
  double maxStars = 1.0;
  for (const auto& repo : j["items"]) {
    FeedItem fi;
    fi.source  = src.name;
    fi.title   = repo.value("full_name", "");
    fi.url     = repo.value("html_url", "");
    fi.summary = repo.value("description", "");
    fi.score   = static_cast<double>(repo.value("stargazers_count", 0));
    maxStars   = std::max(maxStars, fi.score);
    fi.tags    = deriveTags(fi.title + " " + fi.summary +
                             " " + repo.value("language", ""));
    const auto& topics = repo["topics"];
    if (topics.is_array()) {
      for (const auto& t : topics) {
        fi.tags.push_back(t.get<std::string>());
      }
    }
    out.push_back(std::move(fi));
  }
  for (auto& fi : out) { fi.score = normaliseScore(fi.score, maxStars); }
  return out;
}

auto IdleFeed::fetchArXiv(const FeedSource& src) -> std::vector<FeedItem> {
  const std::string url =
      src.url.empty() ? "https://export.arxiv.org/rss/cs.AI" : src.url;
  const std::string body = httpGet(url);
  if (body.empty()) { return {}; }
  // arXiv papers get a fixed high score.
  return parseRss(body, src.name, src.max_items, 0.7);
}

auto IdleFeed::fetchDevTo(const FeedSource& src) -> std::vector<FeedItem> {
  const std::string url =
      src.url.empty()
          ? "https://dev.to/api/articles?top=7&per_page=" + std::to_string(src.max_items)
          : src.url;
  const std::string body = httpGet(url);
  if (body.empty()) { return {}; }

  const nlohmann::json arr = nlohmann::json::parse(body, nullptr, false);
  if (arr.is_discarded() || !arr.is_array()) { return {}; }

  std::vector<FeedItem> out;
  double maxReactions = 1.0;
  for (const auto& article : arr) {
    FeedItem fi;
    fi.source  = src.name;
    fi.title   = article.value("title", "");
    fi.url     = article.value("url", "");
    fi.summary = article.value("description", "");
    fi.score   = static_cast<double>(article.value("positive_reactions_count", 0));
    maxReactions = std::max(maxReactions, fi.score);

    if (article.contains("tag_list") && article["tag_list"].is_array()) {
      for (const auto& t : article["tag_list"]) {
        fi.tags.push_back(t.get<std::string>());
      }
    }
    fi.tags = deriveTags(fi.title + " " + fi.summary + " " +
                          article.value("tags", ""));
    out.push_back(std::move(fi));
  }
  for (auto& fi : out) { fi.score = normaliseScore(fi.score, maxReactions); }
  return out;
}

auto IdleFeed::fetchCustomRss(const FeedSource& src) -> std::vector<FeedItem> {
  if (src.url.empty()) { return {}; }
  const std::string body = httpGet(src.url);
  if (body.empty()) { return {}; }
  return parseRss(body, src.name, src.max_items, 0.5);
}

// ── Hardened shared RSS parser ───────────────────────────────────────────────

auto IdleFeed::parseRss(const std::string& body,
                        const std::string& source_name,
                        std::size_t max_items,
                        double default_score) -> std::vector<FeedItem> {
  std::vector<FeedItem> out;
  std::size_t pos = 0;
  // Iteration guard independent of max_items so a pathological body cannot
  // spin the loop even when every candidate block is rejected.
  std::size_t scanned = 0;
  constexpr std::size_t kMaxItemsScanned = 1024;

  while (out.size() < max_items && scanned < kMaxItemsScanned) {
    ++scanned;
    const std::size_t itemStart = body.find("<item>", pos);
    if (itemStart == std::string::npos) { break; }
    const std::size_t itemEnd = body.find("</item>", itemStart);
    if (itemEnd == std::string::npos) { break; }
    pos = itemEnd + 7;

    // Bounded per-item block: oversized blocks are skipped, not truncated,
    // so a single hostile item cannot dominate memory or yield garbage.
    if (itemEnd - itemStart > kMaxRssBlockBytes) { continue; }
    const std::string block = body.substr(itemStart, itemEnd - itemStart);

    auto [title, _t] = xmlTag(block, "title");
    auto [link, _l]  = xmlTag(block, "link");
    auto [desc, _d]  = xmlTag(block, "description");

    if (title.empty()) { continue; }

    FeedItem fi;
    fi.source  = source_name;
    fi.title   = decodeXmlEntities(std::move(title)).substr(0, kMaxTitleBytes);
    fi.url     = isSafeUrl(link) ? link : std::string{};
    fi.summary = decodeXmlEntities(std::move(desc)).substr(0, kMaxSummaryBytes);
    fi.score   = default_score;
    fi.tags    = deriveTags(fi.title + " " + fi.summary);
    out.push_back(std::move(fi));
  }
  return out;
}

// ── URL validation ───────────────────────────────────────────────────────────

auto IdleFeed::isSafeUrl(const std::string& url) -> bool {
  if (url.empty() || url.size() > 2048) { return false; }
  if (url.rfind("http://", 0) != 0 && url.rfind("https://", 0) != 0) {
    return false;
  }
  // Allowlist of RFC 3986 URL characters. Everything the shell could abuse
  // inside single quotes (the quote itself, backslash-newline tricks,
  // whitespace, control bytes) is absent from this set.
  static constexpr const char* kExtra = "-._~:/?#[]@!$&()*+,;=%";
  for (const unsigned char c : url) {
    if (c == '\0') { return false; } // strchr would match the terminator
    if (std::isalnum(c) == 0 && std::strchr(kExtra, static_cast<char>(c)) == nullptr) {
      return false;
    }
  }
  return true;
}

// ── Stub-mode resolution ─────────────────────────────────────────────────────

auto IdleFeed::stubModeActive() const -> bool {
  return m_config.stub_mode || envTruthy("NEXUS_CELL_FEED_STUB") ||
         envTruthy("NEXUS_HEADLESS") || envTruthy("CI");
}

// ── Stub mode ─────────────────────────────────────────────────────────────────

auto IdleFeed::stubItems() -> std::vector<FeedItem> {
  return {
      {"Reinforcement learning for physics solvers (stub)", "https://arxiv.org/stub1",
       "arxiv_ai", "Using RL to tune physics simulation parameters in real time.",
       0.9, {"reinforcement", "physics", "ai"}},
      {"Trending: nexus-physics-engine on GitHub (stub)", "https://github.com/stub1",
       "github", "Custom C++20 game physics engine with mobile-first design.",
       0.8, {"c++", "game", "engine", "physics", "mobile"}},
      {"How top athletes track performance with AI cameras (stub)",
       "https://dev.to/stub1", "devto",
       "Using computer vision and pose estimation to analyse jump mechanics.",
       0.75, {"ai", "athlete", "sports", "fitness", "computer vision"}},
      {"Show HN: WASM-based ML inference in the browser (stub)", "https://hn.stub1",
       "hackernews", "Running neural network inference at 60 fps in WebAssembly.",
       0.7, {"ml", "neural", "performance", "gpu"}},
      {"Rust-based zero-copy game engine internals (stub)", "https://github.com/stub2",
       "github",
       "Memory-mapped entity component system with lock-free job scheduling.",
       0.85, {"rust", "game", "engine", "performance", "memory"}},
  };
}

// ── Helpers ───────────────────────────────────────────────────────────────────

auto IdleFeed::httpGet(const std::string& url) -> std::string {
  return curlGet(url);
}

auto IdleFeed::passesFilter(const FeedItem& item,
                              const std::vector<std::string>& filters) const -> bool {
  if (filters.empty()) { return true; }
  const std::string haystack =
      lowercase(item.title + " " + item.summary + " " +
                [&] {
                  std::string ts;
                  for (const auto& t : item.tags) { ts += t + " "; }
                  return ts;
                }());
  for (const auto& f : filters) {
    if (haystack.find(lowercase(f)) != std::string::npos) { return true; }
  }
  return false;
}

auto IdleFeed::deriveTags(const std::string& text) -> std::vector<std::string> {
  const std::string lower = lowercase(text);
  std::vector<std::string> tags;
  for (const auto& tag : kTagVocab) {
    if (lower.find(tag) != std::string::npos) {
      tags.push_back(tag);
    }
  }
  return tags;
}

auto IdleFeed::normaliseScore(double raw, double max_raw) -> double {
  if (max_raw <= 0.0) { return 0.5; }
  return std::min(1.0, raw / max_raw);
}

void IdleFeed::pushItem(const FeedItem& item) {
  if (m_bus == nullptr) { return; }

  nlohmann::json data;
  data["source"]  = item.source;
  data["title"]   = item.title;
  data["url"]     = item.url;
  data["summary"] = item.summary;
  data["score"]   = item.score;
  data["reward"]  = item.score; // reward = engagement score
  nlohmann::json tagsArr = nlohmann::json::array();
  for (const auto& t : item.tags) { tagsArr.push_back(t); }
  data["tags"] = tagsArr;

  using namespace std::chrono;
  const double ts = duration_cast<duration<double>>(
                        steady_clock::now().time_since_epoch())
                        .count();

  m_bus->push(Observation{
      ObservationType::kExternalKnowledge,
      "feed:" + item.source,
      std::move(data),
      ts});

  m_totalIngested.fetch_add(1, std::memory_order_relaxed);

  // Maintain recent items ring.
  {
    std::scoped_lock lock(m_recentMutex);
    m_recentItems.push_back(item);
    if (m_recentItems.size() > kRecentCapacity) {
      m_recentItems.erase(m_recentItems.begin());
    }
  }
}

void IdleFeed::applySourceDefaults(std::vector<FeedSource>& sources) {
  if (!sources.empty()) { return; }
  sources = {
      {FeedSourceKind::kHackerNews,    "hackernews",  "", 10, {}},
      {FeedSourceKind::kGitHubTrending,"github",      "", 10, {}},
      {FeedSourceKind::kArXiv,         "arxiv_ai",    "", 10, {}},
      {FeedSourceKind::kDevTo,         "devto",       "", 10, {}},
  };
}

} // namespace nexus::cell
