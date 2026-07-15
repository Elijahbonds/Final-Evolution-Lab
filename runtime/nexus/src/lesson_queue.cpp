#include "nexus/runtime/lesson_queue.h"
#include "nexus/core/log.h"

#include <algorithm>
#include <filesystem>
#include <fstream>

namespace nexus::runtime {

LessonQueue::LessonQueue(nexus::cell::MasteryTracker& mastery, LessonQueueConfig config)
    : m_mastery(mastery), m_config(std::move(config)) {}

auto LessonQueue::loadCurriculum() -> Result<void> {
  const std::filesystem::path path{m_config.curriculumFile};
  if (!std::filesystem::exists(path)) {
    NEXUS_LOG_WARN(nexus::LogChannel::kCell,
                   "[LessonQueue] Curriculum file not found: " + m_config.curriculumFile +
                       " — starting with empty skill list.");
    return Result<void>::ok();
  }
  std::ifstream stream(path);
  if (!stream.is_open()) {
    return Result<void>::err("[LessonQueue] Cannot open " + m_config.curriculumFile);
  }
  try {
    const auto json = nlohmann::json::parse(stream);
    if (!json.contains("skills") || !json["skills"].is_array()) {
      return Result<void>::err("[LessonQueue] Curriculum JSON missing 'skills' array.");
    }
    m_skills.clear();
    for (const auto& skill : json["skills"]) {
      if (skill.contains("id") && skill["id"].is_string()) {
        m_skills.push_back(skill["id"].get<std::string>());
      }
    }
    NEXUS_LOG_INFO(nexus::LogChannel::kCell,
                   "[LessonQueue] Loaded " + std::to_string(m_skills.size()) + " skills.");
  } catch (const nlohmann::json::exception& ex) {
    return Result<void>::err(std::string("[LessonQueue] JSON error: ") + ex.what());
  }
  return Result<void>::ok();
}

auto LessonQueue::computeQueue(std::string_view userId) const -> std::vector<LessonRef> {
  std::vector<LessonRef> candidates;
  candidates.reserve(m_skills.size());

  for (const auto& skillId : m_skills) {
    const float pMastery = m_mastery.getMastery(userId, skillId);
    if (m_mastery.isMastered(userId, skillId)) {
      continue; // Skill already mastered — skip.
    }
    candidates.push_back(LessonRef{skillId, pMastery, pMastery});
  }

  // Sort ascending by mastery probability — lowest mastery = highest priority.
  std::sort(candidates.begin(), candidates.end(),
            [](const LessonRef& a, const LessonRef& b) {
              return a.pMastery < b.pMastery;
            });

  if (candidates.size() > m_config.maxItems) {
    candidates.resize(m_config.maxItems);
  }
  return candidates;
}

void LessonQueue::registerSkill(std::string skillId) {
  m_skills.push_back(std::move(skillId));
}

} // namespace nexus::runtime
