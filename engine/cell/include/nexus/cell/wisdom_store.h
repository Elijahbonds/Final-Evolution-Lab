#pragma once

// CELL Wisdom Store — Long-Term Memory
//
// A persistent, ranked collection of WisdomEntry structs written to
// artifacts/cell/wisdom.json.  Entries are keyed by (domain, rule_text) and
// never deleted — confidence decays when evidence stops accumulating.
// Queryable by domain and exposed over the cell.wisdom command.
//
// Entries are organised in a two-tier hierarchy:
//   kTactical   — top-level heuristics about a domain (e.g., "higher fps improves outcomes")
//   kMechanical — micro-mechanical sub-rules linked to a tactical parent
//                 (e.g., "higher physics.velocity.x improves outcomes")
// The hierarchy is exposed via queryHierarchy() which returns WisdomNode trees.

#include "nexus/core/result.h"

#include <cstdint>
#include <mutex>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

namespace nexus::cell {

// ── Tier classification ───────────────────────────────────────────────────────

enum class WisdomTier : std::uint8_t {
  kTactical,   ///< High-level domain heuristic (root node)
  kMechanical, ///< Micro-mechanical sub-rule linked to a tactical parent
};

// ── Entry ─────────────────────────────────────────────────────────────────────

struct WisdomEntry {
  std::string   domain;
  std::string   rule_text;
  double        confidence{0.0}; ///< [0, 1] — decays without supporting evidence
  std::uint64_t evidence_count{0};
  std::uint64_t last_updated_ms{0};
  // Hierarchy fields (new — default to kTactical for backward compatibility)
  WisdomTier    tier{WisdomTier::kTactical};
  std::string   parent_rule_text; ///< empty for kTactical entries
};

// ── Hierarchy node (returned by queryHierarchy) ───────────────────────────────

struct WisdomNode {
  WisdomEntry              entry;
  std::vector<WisdomEntry> children; ///< kMechanical entries whose parent_rule_text == entry.rule_text
};

// ── Serialisation helpers ─────────────────────────────────────────────────────

inline auto wisdomEntryToJson(const WisdomEntry& e) -> nlohmann::json {
  return {{"domain",           e.domain},
          {"rule",             e.rule_text},
          {"confidence",       e.confidence},
          {"evidence_count",   e.evidence_count},
          {"last_updated_ms",  e.last_updated_ms},
          {"tier",             static_cast<int>(e.tier)},
          {"parent_rule_text", e.parent_rule_text}};
}

inline auto wisdomEntryFromJson(const nlohmann::json& j) -> WisdomEntry {
  WisdomEntry e;
  if (j.contains("domain"))           e.domain           = j["domain"].get<std::string>();
  if (j.contains("rule"))             e.rule_text         = j["rule"].get<std::string>();
  if (j.contains("confidence"))       e.confidence        = j["confidence"].get<double>();
  if (j.contains("evidence_count"))   e.evidence_count    = j["evidence_count"].get<std::uint64_t>();
  if (j.contains("last_updated_ms"))  e.last_updated_ms   = j["last_updated_ms"].get<std::uint64_t>();
  if (j.contains("tier"))             e.tier              = static_cast<WisdomTier>(j["tier"].get<int>());
  if (j.contains("parent_rule_text")) e.parent_rule_text  = j["parent_rule_text"].get<std::string>();
  return e;
}

// ── Config ─────────────────────────────────────────────────────────────────────

struct WisdomStoreConfig {
  std::string wisdom_path{"artifacts/cell/wisdom.json"};
  /// Multiply confidence by this factor each decay cycle (0 < k < 1).
  double decay_factor{0.995};
};

// ── Store ─────────────────────────────────────────────────────────────────────

class WisdomStore {
public:
  explicit WisdomStore(WisdomStoreConfig config = {});

  /// Load from disk if the file exists. Safe to call on an empty store.
  auto load() -> Result<void>;

  /// Persist the full store to disk.
  auto save() const -> Result<void>;

  /// Insert or update an entry. Merges evidence_count; takes max confidence.
  void upsert(WisdomEntry entry);

  /// Apply confidence decay to all entries (call periodically from research loop).
  void decay();

  /// Returns all entries for the given domain, sorted by confidence descending.
  [[nodiscard]] auto query(const std::string& domain) const -> std::vector<WisdomEntry>;

  /// Returns the top-n entries across all domains, sorted by confidence descending.
  [[nodiscard]] auto topN(std::size_t n) const -> std::vector<WisdomEntry>;

  /// Returns a hierarchical view of the given domain: each kTactical entry is a
  /// root node carrying its kMechanical children sorted by confidence descending.
  /// Nodes are themselves sorted by tactical entry confidence descending.
  [[nodiscard]] auto queryHierarchy(const std::string& domain) const
      -> std::vector<WisdomNode>;

  [[nodiscard]] auto count() const -> std::size_t;

  void shutdown();

private:
  WisdomStoreConfig           m_config;
  mutable std::mutex          m_mutex;
  std::vector<WisdomEntry>    m_entries;
};

} // namespace nexus::cell
