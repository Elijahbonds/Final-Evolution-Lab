// CELL MasteryTracker — Bayesian Knowledge Tracing (BKT) per (userId, skillId).
// Fully deterministic at runtime; no LLM calls ever.
// BKT model: p(mastery | response) updated via Bayes rule each session result.
#pragma once

#include "nexus/cell/cell_config.h"
#include "nexus/cell/wisdom_store.h"
#include "nexus/core/result.h"

#include <string>
#include <string_view>

namespace nexus::cell {

struct MasteryRecord {
  std::string userId;
  std::string skillId;
  float pMastery{0.0F};   ///< Current p(mastery) ∈ [0,1].
  int32_t observations{0}; ///< Total session results observed.
};

/// Updates per-(userId, skillId) mastery probability using BKT.
/// All state persisted via WisdomStore; no LLM calls.
class MasteryTracker {
public:
  explicit MasteryTracker(WisdomStore& store, MasteryConfig config = {});

  /// Update mastery for (userId, skillId) given a binary `correct` outcome.
  auto update(std::string_view userId, std::string_view skillId, bool correct) -> Result<void>;

  /// Read the current mastery probability.  Returns 0 if not yet observed.
  [[nodiscard]] auto getMastery(std::string_view userId, std::string_view skillId) const -> float;

  /// Returns true if the skill is considered learned (p ≥ masteryThreshold).
  [[nodiscard]] auto isMastered(std::string_view userId, std::string_view skillId) const -> bool;

  [[nodiscard]] auto getRecord(std::string_view userId, std::string_view skillId) const
      -> MasteryRecord;

  /// Persist all mastery data to WisdomStore.
  auto save() -> Result<void>;

private:
  [[nodiscard]] static auto storeKey(std::string_view userId, std::string_view skillId,
                                     std::string_view prefix) -> std::string;

  [[nodiscard]] auto loadRecord(std::string_view userId,
                                std::string_view skillId) const -> MasteryRecord;

  WisdomStore& m_store;
  MasteryConfig m_config;
};

} // namespace nexus::cell
