// CELL WisdomStore — persistent key/value insight store backed by a JSON file.
#pragma once

#include "nexus/cell/cell_config.h"
#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <mutex>
#include <optional>
#include <string>
#include <string_view>

namespace nexus::cell {

/// Thread-safe JSON-backed key/value store for CELL insights and mastery records.
class WisdomStore {
public:
  explicit WisdomStore(WisdomStoreConfig config = {});

  /// Load from disk (idempotent; creates empty store if file absent).
  auto load() -> Result<void>;
  /// Flush current in-memory state to disk.
  auto save() -> Result<void>;

  void set(std::string_view key, nlohmann::json value);
  [[nodiscard]] auto get(std::string_view key) const -> std::optional<nlohmann::json>;
  [[nodiscard]] auto has(std::string_view key) const -> bool;
  void remove(std::string_view key);

  [[nodiscard]] auto storeFile() const -> const std::string& { return m_config.storeFile; }
  [[nodiscard]] auto size() const -> std::size_t;

private:
  WisdomStoreConfig m_config;
  nlohmann::json m_data = nlohmann::json::object();
  mutable std::mutex m_mutex;
};

} // namespace nexus::cell
