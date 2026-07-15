// NEXUS LessonQueue — deterministic adaptive lesson sequencing.
// No LLM calls at runtime.  Uses MasteryTracker p(mastery) to rank skills.
// LLMs are only used OFFLINE by the authoring pipeline (tools/nexus-author/).
#pragma once

#include "nexus/cell/mastery_tracker.h"
#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <cstddef>
#include <string>
#include <vector>

namespace nexus::runtime {

struct LessonRef {
  std::string skillId;
  float priority{0.0F};   ///< Lower = higher priority (0 = not started, 1 = mastered).
  float pMastery{0.0F};
};

struct LessonQueueConfig {
  /// Maximum number of skills to return per queue request.
  std::size_t maxItems{10};
  /// Path to the curriculum skill graph JSON file.
  std::string curriculumFile{"artifacts/curriculum/skills.json"};
};

/// Computes the next lessons for a user based on current mastery levels.
/// Algorithm: sort registered skills by ascending p(mastery); return top-K.
/// Skills with p >= masteryThreshold are excluded (already learned).
class LessonQueue {
public:
  explicit LessonQueue(nexus::cell::MasteryTracker& mastery, LessonQueueConfig config = {});

  /// Load the skill list from the curriculum file.
  auto loadCurriculum() -> Result<void>;

  /// Compute the lesson queue for `userId`.  Returns sorted LessonRef list.
  [[nodiscard]] auto computeQueue(std::string_view userId) const -> std::vector<LessonRef>;

  /// Register a skill directly (bypasses curriculum file — useful for tests).
  void registerSkill(std::string skillId);

  [[nodiscard]] auto skillCount() const -> std::size_t { return m_skills.size(); }

private:
  nexus::cell::MasteryTracker& m_mastery;
  LessonQueueConfig m_config;
  std::vector<std::string> m_skills;
};

} // namespace nexus::runtime
