#include "nexus/runtime/provider_router.h"
#include "nexus/core/log.h"

#include <functional>
#include <sstream>

namespace nexus::runtime {

auto ProviderRouter::defaultConfig() -> ProviderRouterConfig {
  ProviderRouterConfig cfg;
  cfg.providers = {
      {"anthropic", {"anthropic", "https://api.anthropic.com/v1", "claude-haiku-4-5"}},
      {"openai",    {"openai",    "https://api.openai.com/v1",    "gpt-5-mini"}},
      {"groq",      {"groq",      "https://api.groq.com/openai/v1","llama3-8b-8192"}},
  };
  return cfg;
}

ProviderRouter::ProviderRouter(ProviderRouterConfig config)
    : m_config(std::move(config)) {}

auto ProviderRouter::hashKey(std::string_view key) -> std::string {
  // Simple FNV-1a 64-bit hash — stable across runs, no external dependency.
  // Replace with SHA-256 for cryptographic-grade content addressing if needed.
  constexpr uint64_t kFnvPrime = 0x00000100000001B3ULL;
  constexpr uint64_t kFnvOffset = 0xCBF29CE484222325ULL;
  uint64_t hash = kFnvOffset;
  for (const unsigned char ch : key) {
    hash ^= static_cast<uint64_t>(ch);
    hash *= kFnvPrime;
  }
  std::ostringstream oss;
  oss << std::hex << hash;
  return oss.str();
}

auto ProviderRouter::route(std::string_view capability,
                            std::string_view contentKey,
                            std::string_view byoKey) const -> RouteResult {
  const std::string cacheKey = hashKey(contentKey);

  // Cache check — if we have a cached response for this content, no provider needed.
  {
    std::lock_guard lock(m_cacheMutex);
    if (m_cache.contains(cacheKey)) {
      return RouteResult{"cached", {}, {}, true, cacheKey};
    }
  }

  const auto routeIt = m_config.routes.find(std::string(capability));
  if (routeIt == m_config.routes.end() || routeIt->second.empty()) {
    // No provider configured for this capability (e.g., lesson_serve = deterministic).
    return RouteResult{"none", {}, {}, false, cacheKey};
  }

  // Walk the fallback chain — return the first known provider.
  for (const auto& providerName : routeIt->second) {
    const auto provIt = m_config.providers.find(providerName);
    if (provIt == m_config.providers.end()) {
      continue;
    }
    const auto& entry = provIt->second;
    RouteResult res;
    res.providerName = entry.name;
    res.baseUrl = entry.baseUrl;
    res.model = entry.defaultModel;
    res.fromCache = false;
    res.cacheKey = cacheKey;
    // BYO-key is passed to the caller; we just surface it through the result's
    // context — the actual HTTP call uses it via X-FEL-Provider-Key logic.
    if (!byoKey.empty()) {
      NEXUS_LOG_INFO(nexus::LogChannel::kCell,
                     "[ProviderRouter] BYO key used for capability=" +
                         std::string(capability));
    }
    return res;
  }

  NEXUS_LOG_WARN(nexus::LogChannel::kCell,
                 "[ProviderRouter] No available provider for capability=" +
                     std::string(capability));
  return RouteResult{"none", {}, {}, false, cacheKey};
}

void ProviderRouter::cacheResponse(std::string_view contentKey, nlohmann::json response) {
  std::lock_guard lock(m_cacheMutex);
  if (m_cache.size() >= m_config.cacheMaxEntries) {
    // Simple eviction: clear oldest half.
    auto it = m_cache.begin();
    const std::size_t evict = m_cache.size() / 2;
    for (std::size_t i = 0; i < evict && it != m_cache.end(); ++i) {
      it = m_cache.erase(it);
    }
  }
  m_cache[hashKey(contentKey)] = std::move(response);
}

auto ProviderRouter::getCached(std::string_view contentKey) const
    -> std::optional<nlohmann::json> {
  std::lock_guard lock(m_cacheMutex);
  const auto it = m_cache.find(hashKey(contentKey));
  if (it == m_cache.end()) {
    return std::nullopt;
  }
  return it->second;
}

void ProviderRouter::clearCache() {
  std::lock_guard lock(m_cacheMutex);
  m_cache.clear();
}

auto ProviderRouter::cacheSize() const -> std::size_t {
  std::lock_guard lock(m_cacheMutex);
  return m_cache.size();
}

} // namespace nexus::runtime
