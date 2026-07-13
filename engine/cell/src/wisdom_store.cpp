#include "nexus/cell/wisdom_store.h"

#include "nexus/core/log.h"

#include <algorithm>
#include <chrono>
#include <filesystem>
#include <fstream>

namespace nexus::cell {

namespace {

auto nowMs() -> std::uint64_t {
  using namespace std::chrono;
  return static_cast<std::uint64_t>(
      duration_cast<milliseconds>(steady_clock::now().time_since_epoch()).count());
}

} // namespace

WisdomStore::WisdomStore(WisdomStoreConfig config) : m_config(std::move(config)) {}

auto WisdomStore::load() -> Result<void> {
  try {
    std::ifstream file(m_config.wisdom_path);
    if (!file.is_open()) {
      // No existing file is not an error — first run.
      return Result<void>::ok();
    }
    const nlohmann::json j = nlohmann::json::parse(file, nullptr, /*exceptions=*/false);
    if (j.is_discarded() || !j.is_array()) {
      return Result<void>::err("WisdomStore: invalid JSON in " + m_config.wisdom_path);
    }
    std::scoped_lock lock(m_mutex);
    m_entries.clear();
    m_entries.reserve(j.size());
    for (const auto& item : j) {
      m_entries.push_back(wisdomEntryFromJson(item));
    }
    NEXUS_LOG_INFO(LogChannel::kCell,
                   "WisdomStore loaded " + std::to_string(m_entries.size()) + " entries");
    return Result<void>::ok();
  } catch (const std::exception& ex) {
    return Result<void>::err(std::string("WisdomStore load: ") + ex.what());
  }
}

auto WisdomStore::save() const -> Result<void> {
  try {
    std::filesystem::create_directories(
        std::filesystem::path(m_config.wisdom_path).parent_path());
    nlohmann::json arr = nlohmann::json::array();
    {
      std::scoped_lock lock(m_mutex);
      for (const auto& e : m_entries) {
        arr.push_back(wisdomEntryToJson(e));
      }
    }
    std::ofstream file(m_config.wisdom_path);
    if (!file.is_open()) {
      return Result<void>::err("WisdomStore: cannot write " + m_config.wisdom_path);
    }
    file << arr.dump(2);
    return Result<void>::ok();
  } catch (const std::exception& ex) {
    return Result<void>::err(std::string("WisdomStore save: ") + ex.what());
  }
}

void WisdomStore::upsert(WisdomEntry entry) {
  entry.last_updated_ms = nowMs();
  std::scoped_lock lock(m_mutex);
  for (auto& existing : m_entries) {
    if (existing.domain == entry.domain && existing.rule_text == entry.rule_text) {
      existing.confidence    = std::max(existing.confidence, entry.confidence);
      existing.evidence_count += entry.evidence_count;
      existing.last_updated_ms = entry.last_updated_ms;
      return;
    }
  }
  m_entries.push_back(std::move(entry));
}

void WisdomStore::decay() {
  std::scoped_lock lock(m_mutex);
  for (auto& e : m_entries) {
    e.confidence *= m_config.decay_factor;
  }
}

auto WisdomStore::query(const std::string& domain) const -> std::vector<WisdomEntry> {
  std::scoped_lock lock(m_mutex);
  std::vector<WisdomEntry> out;
  for (const auto& e : m_entries) {
    if (e.domain == domain) {
      out.push_back(e);
    }
  }
  std::sort(out.begin(), out.end(),
            [](const WisdomEntry& a, const WisdomEntry& b) {
              return a.confidence > b.confidence;
            });
  return out;
}

auto WisdomStore::topN(std::size_t n) const -> std::vector<WisdomEntry> {
  std::scoped_lock lock(m_mutex);
  std::vector<WisdomEntry> sorted = m_entries;
  std::sort(sorted.begin(), sorted.end(),
            [](const WisdomEntry& a, const WisdomEntry& b) {
              return a.confidence > b.confidence;
            });
  if (sorted.size() > n) {
    sorted.resize(n);
  }
  return sorted;
}

auto WisdomStore::count() const -> std::size_t {
  std::scoped_lock lock(m_mutex);
  return m_entries.size();
}

void WisdomStore::shutdown() {
  const auto result = save();
  if (result.isErr()) {
    NEXUS_LOG_WARN(LogChannel::kCell, "WisdomStore shutdown save failed: " + result.error());
  } else {
    NEXUS_LOG_INFO(LogChannel::kCell,
                   "WisdomStore shutdown (entries=" + std::to_string(count()) + ")");
  }
}

} // namespace nexus::cell
