#pragma once

// CELL G-Eval Scorer — Self-Critique Gate
//
// Scores a WisdomEntry candidate against four metrics before it is committed
// to WisdomStore.  All scoring is heuristic / algorithmic (no external model
// call) so it runs zero-latency on the ResearchLoop or DocIngester thread.
//
// Metrics (each 0.0 – 10.0):
//   Clarity        — rule_text contains explicit direction and outcome keywords
//   Specificity    — confidence × log(evidence_count) reaches a meaningful mass
//   Conciseness    — rule_text stays within a readable length
//   Actionability  — rule references a measurable delta or structured domain path
//
// Aggregate score is the unweighted mean of the four metrics.
// A WisdomEntry "passes" when aggregate >= config.min_score.
//
// The scorer also provides a refine() helper that applies lightweight text
// transformations to a failing entry (trim verbose suffixes, normalise direction
// language) and returns the revised candidate for a single re-score attempt.

#include "nexus/cell/wisdom_store.h"

#include <string>

namespace nexus::cell {

// ── Per-metric breakdown ──────────────────────────────────────────────────────

struct GEvalMetrics {
  double clarity{0.0};       ///< [0, 10]
  double specificity{0.0};   ///< [0, 10]
  double conciseness{0.0};   ///< [0, 10]
  double actionability{0.0}; ///< [0, 10]
};

// ── Scored result ─────────────────────────────────────────────────────────────

struct GEvalResult {
  GEvalMetrics metrics;
  double       aggregate{0.0}; ///< unweighted mean of the four metrics
  bool         passes{false};  ///< aggregate >= GEvalConfig::min_score
};

// ── Config ────────────────────────────────────────────────────────────────────

struct GEvalConfig {
  /// Minimum aggregate score (0–10) required for a WisdomEntry to be committed.
  /// Default 6.0 — entries scoring below this are refined once and re-scored.
  double min_score{6.0};

  /// Maximum rule_text length before conciseness penalty kicks in.
  std::size_t concise_length_target{120};

  /// Hard cap on rule_text length for full conciseness score.
  std::size_t concise_length_max{300};
};

// ── Scorer ────────────────────────────────────────────────────────────────────

class GEvalScorer {
public:
  explicit GEvalScorer(GEvalConfig config = {});

  /// Score a WisdomEntry candidate.  Const and thread-safe.
  [[nodiscard]] auto score(const WisdomEntry& entry) const -> GEvalResult;

  /// Attempt a lightweight refinement of a failing entry to improve its score.
  /// Returns the revised entry (caller should re-score once).
  [[nodiscard]] auto refine(WisdomEntry entry) const -> WisdomEntry;

  [[nodiscard]] auto config() const -> const GEvalConfig& { return m_config; }

private:
  [[nodiscard]] auto scoreClarity(const WisdomEntry& e)       const -> double;
  [[nodiscard]] auto scoreSpecificity(const WisdomEntry& e)   const -> double;
  [[nodiscard]] auto scoreConciseness(const WisdomEntry& e)   const -> double;
  [[nodiscard]] auto scoreActionability(const WisdomEntry& e) const -> double;

  GEvalConfig m_config;
};

} // namespace nexus::cell
