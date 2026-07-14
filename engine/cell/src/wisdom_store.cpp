#include "nexus/cell/wisdom_store.h"
#include "nexus/core/log.h"

#include <filesystem>
#include <fstream>
#include <sstream>

namespace nexus::cell {

WisdomStore::WisdomStore(WisdomStoreConfig config) : m_config(std::move(config)) {}

auto WisdomStore::load() -> Result<void> {
  std::lock_guard lock(m_mutex);
  const std::filesystem::path path{m_config.storeFile};
  if (!std::filesystem::exists(path)) {
    m_data = nlohmann::json::object();
    return Result<void>::ok();
  }
  std::ifstream stream(path);
  if (!stream.is_open()) {
    return Result<void>::err("WisdomStore: cannot open " + m_config.storeFile);
  }
  try {
    m_data = nlohmann::json::parse(stream);
    if (!m_data.is_object()) {
      m_data = nlohmann::json::object();
    }
  } catch (const nlohmann::json::exception& ex) {
    return Result<void>::err(std::string("WisdomStore: JSON parse error: ") + ex.what());
  }
  return Result<void>::ok();
}

auto WisdomStore::save() -> Result<void> {
  std::lock_guard lock(m_mutex);
  const std::filesystem::path path{m_config.storeFile};
  std::error_code ec;
  std::filesystem::create_directories(path.parent_path(), ec);
  if (ec) {
    return Result<void>::err("WisdomStore: cannot create directory: " + ec.message());
  }
  std::ofstream stream(path);
  if (!stream.is_open()) {
    return Result<void>::err("WisdomStore: cannot write " + m_config.storeFile);
  }
  stream << m_data.dump(2);
  return Result<void>::ok();
}

void WisdomStore::set(std::string_view key, nlohmann::json value) {
  std::lock_guard lock(m_mutex);
  m_data[std::string(key)] = std::move(value);
}

auto WisdomStore::get(std::string_view key) const -> std::optional<nlohmann::json> {
  std::lock_guard lock(m_mutex);
  const auto it = m_data.find(std::string(key));
  if (it == m_data.end()) {
    return std::nullopt;
  }
  return *it;
}

auto WisdomStore::has(std::string_view key) const -> bool {
  std::lock_guard lock(m_mutex);
  return m_data.contains(std::string(key));
}

void WisdomStore::remove(std::string_view key) {
  std::lock_guard lock(m_mutex);
  m_data.erase(std::string(key));
}

auto WisdomStore::size() const -> std::size_t {
  std::lock_guard lock(m_mutex);
  return m_data.size();
}

} // namespace nexus::cell
