// NEXUS ProviderRouter — capability → provider mapping with fallback chain.
// Content-hash cache: lesson content responses are keyed by hash; cache hit = zero LLM call.
// BYO-keys: callers can pass `X-FEL-Provider-Key` to override the default API key.
#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstddef>
#include <functional>
#include <mutex>
#include <string>
#include <unordered_map>
#include <vector>

namespace nexus::runtime {

struct ProviderEntry {
  std::string name;        ///< e.g. "anthropic", "openai", "groq"
  std::string baseUrl;
  std::string defaultModel;
};

struct ProviderRouterConfig {
  /// capability → ordered provider names (first = preferred, rest = fallbacks).
  std::unordered_map<std::string, std::vector<std::string>> routes{
      {"coaching",          {"anthropic", "openai"}},
      {"curriculum_author", {"anthropic"}},
      {"lesson_serve",      {}},  // empty = deterministic/cached, no LLM
      {"escalation",        {"anthropic", "groq"}},
  };
  std::unordered_map<std::string, ProviderEntry> providers;
  /// Maximum number of entries in the content cache.
  std::size_t cacheMaxEntries{1024};
};

struct RouteResult {
  std::string providerName;
  std::string baseUrl;
  std::string model;
  bool fromCache{false};
  std::string cacheKey;
};

/// Routes capability requests to the appropriate provider, with:
/// - Ordered fallback chain (first available provider wins).
/// - Content-hash cache (stable key → cached response → no LLM call).
/// - BYO-key override via `byoKey` parameter.
class ProviderRouter {
public:
  explicit ProviderRouter(ProviderRouterConfig config = defaultConfig());

  static auto defaultConfig() -> ProviderRouterConfig;

  /// Resolve which provider to use for `capability`.
  /// `contentKey` is a stable identifier for the content (e.g., skill ID + version).
  /// `byoKey` (optional) overrides the default API key for this call.
  [[nodiscard]] auto route(std::string_view capability,
                           std::string_view contentKey,
                           std::string_view byoKey = {}) const -> RouteResult;

  /// Store a response in the content cache.
  void cacheResponse(std::string_view contentKey, nlohmann::json response);

  /// Look up a cached response.  Returns nullopt on miss.
  [[nodiscard]] auto getCached(std::string_view contentKey) const
      -> std::optional<nlohmann::json>;

  /// Evict the full cache.
  void clearCache();

  [[nodiscard]] auto cacheSize() const -> std::size_t;

private:
  [[nodiscard]] static auto hashKey(std::string_view key) -> std::string;

  ProviderRouterConfig m_config;
  mutable std::mutex m_cacheMutex;
  mutable std::unordered_map<std::string, nlohmann::json> m_cache;
};

} // namespace nexus::runtime
