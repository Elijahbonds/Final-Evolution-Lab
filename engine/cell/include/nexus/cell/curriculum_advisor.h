#pragma once

// CELL Curriculum Advisor — Engine → Sequencer Seam
//
// Consumes WisdomStore entries + ExperienceLedger outcomes and emits a ranked
// list of "focus areas": skills whose observed outcomes are weak, each with a
// confidence derived from evidence volume and supporting wisdom rules.
//
// This is the seam between the CELL learning subsystem and the backend
// adaptive-sequencing engine (Education spec [NEXUS] — "Adaptive sequencing
// engine"): the backend recommender consumes the exact JSON shape produced by
// focusReport() (exposed over the cell.advisor.focus command/query) and turns
// focus areas into a re-sequenced lesson queue.
//
// JSON contract (focusReport):
// {
//   "version": 1,
//   "generated_at_ms": <uint64>,
//   "focus_areas": [
//     {
//       "skill":            "<source_system / skill domain>",
//       "weakness_score":   0.0-1.0,   // higher = weaker, needs focus
//       "confidence":       0.0-1.0,   // evidence-based confidence
//       "priority":         0.0-1.0,   // weakness * confidence (sort key, desc)
//       "evidence_count":   <uint64>,  // ledger records analysed for this skill
//       "mean_reward":      0.0-1.0,   // clamped mean outcome reward
//       "trend":            "improving" | "declining" | "flat",
//       "recommendation":   "prioritize" | "monitor" | "maintain",
//       "supporting_rules": ["<wisdom rule text>", ...]
//     }, ...
//   ],
//   "inputs": { "ledger_records_analysed": <n>, "wisdom_entries": <n> }
// }
//
// Purely read-only over its inputs; stateless apart from config. Thread-safe
// because ExperienceLedger / WisdomStore queries are themselves thread-safe.

#include "nexus/cell/experience_ledger.h"
#include "nexus/cell/wisdom_store.h"

#include <cstdint>
#include <string>
#include <vector>

#include <nlohmann/json.hpp>

namespace nexus::cell {

// ── Focus area ────────────────────────────────────────────────────────────────

struct FocusArea {
  std::string              skill;              ///< source_system / skill domain
  double                   weakness_score{0.0}; ///< [0,1] higher = weaker
  double                   confidence{0.0};     ///< [0,1] evidence-based
  double                   priority{0.0};       ///< weakness * confidence
  std::uint64_t            evidence_count{0};
  double                   mean_reward{0.0};    ///< clamped to [0,1]
  std::string              trend;               ///< improving | declining | flat
  std::string              recommendation;      ///< prioritize | monitor | maintain
  std::vector<std::string> supporting_rules;    ///< top WisdomStore rule texts
};

// ── Config ────────────────────────────────────────────────────────────────────

struct CurriculumAdvisorConfig {
  std::size_t max_focus_areas{5};   ///< ranked areas returned
  std::size_t min_evidence{3};      ///< skip skills with fewer ledger records
  std::size_t ledger_window{2048};  ///< most-recent records analysed
  std::size_t max_rules_per_area{3};///< supporting wisdom rules attached
  /// Evidence count at which confidence reaches 0.5 (count / (count + this)).
  double confidence_saturation{20.0};
  /// Minimum |second-half mean − first-half mean| to call a trend.
  double trend_epsilon{0.05};
  /// Ledger source_systems starting with any of these prefixes are ignored
  /// (internal telemetry, not athlete skills).
  std::vector<std::string> exclude_source_prefixes{
      "feed:", "web_auditor", "renderer", "agent"};
};

// ── Advisor ───────────────────────────────────────────────────────────────────

class CurriculumAdvisor {
public:
  explicit CurriculumAdvisor(CurriculumAdvisorConfig config = {});

  /// Rank skill weaknesses from ledger outcomes + wisdom rules.
  /// Sorted by priority (weakness * confidence) descending, capped at
  /// max_focus_areas.
  [[nodiscard]] auto computeFocusAreas(const ExperienceLedger& ledger,
                                       const WisdomStore& wisdom) const
      -> std::vector<FocusArea>;

  /// Full JSON report in the sequencer-seam shape documented above.
  [[nodiscard]] auto focusReport(const ExperienceLedger& ledger,
                                 const WisdomStore& wisdom) const
      -> nlohmann::json;

  [[nodiscard]] static auto focusAreaToJson(const FocusArea& area)
      -> nlohmann::json;

  [[nodiscard]] auto config() const -> const CurriculumAdvisorConfig& {
    return m_config;
  }

private:
  [[nodiscard]] auto isExcluded(const std::string& source) const -> bool;

  CurriculumAdvisorConfig m_config;
};

} // namespace nexus::cell
