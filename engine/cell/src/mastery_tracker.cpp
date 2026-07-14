#include "nexus/cell/mastery_tracker.h"
#include "nexus/core/log.h"

#include <algorithm>
#include <cmath>

namespace nexus::cell {

// ---------------------------------------------------------------------------
// BKT update equations:
//
//  Given current p(L_n) and response r (1=correct, 0=incorrect):
//
//  P(correct | L=1) = 1 - pS           (slip)
//  P(correct | L=0) = pG               (guess)
//  P(L=1 | correct) = P(correct|L=1) * p(L_n) /
//                     [P(correct|L=1)*p(L_n) + P(correct|L=0)*(1-p(L_n))]
//  P(L=1 | incorrect) = P(incorrect|L=1) * p(L_n) /
//                       [P(incorrect|L=1)*p(L_n) + P(incorrect|L=0)*(1-p(L_n))]
//  p(L_{n+1}) = P(L=1 | response) + (1 - P(L=1 | response)) * pT
// ---------------------------------------------------------------------------

MasteryTracker::MasteryTracker(WisdomStore& store, MasteryConfig config)
    : m_store(store), m_config(std::move(config)) {}

auto MasteryTracker::storeKey(std::string_view userId, std::string_view skillId,
                               std::string_view prefix) -> std::string {
  return std::string(prefix) + ":" + std::string(userId) + ":" + std::string(skillId);
}

auto MasteryTracker::loadRecord(std::string_view userId,
                                 std::string_view skillId) const -> MasteryRecord {
  const std::string key = storeKey(userId, skillId, m_config.storePrefix);
  const auto stored = m_store.get(key);
  if (!stored.has_value()) {
    return MasteryRecord{std::string(userId), std::string(skillId),
                         m_config.bkt.pL0, 0};
  }
  MasteryRecord rec;
  rec.userId = userId;
  rec.skillId = skillId;
  rec.pMastery = stored->value("p", m_config.bkt.pL0);
  rec.observations = stored->value("n", 0);
  return rec;
}

auto MasteryTracker::update(std::string_view userId, std::string_view skillId,
                             bool correct) -> Result<void> {
  MasteryRecord rec = loadRecord(userId, skillId);
  const BktParams& p = m_config.bkt;

  const float pL = rec.pMastery;
  float pLgivenObs{0.0F};

  if (correct) {
    const float numerator = (1.0F - p.pS) * pL;
    const float denominator = numerator + p.pG * (1.0F - pL);
    pLgivenObs = (denominator > 0.0F) ? (numerator / denominator) : pL;
  } else {
    const float numerator = p.pS * pL;
    const float denominator = numerator + (1.0F - p.pG) * (1.0F - pL);
    pLgivenObs = (denominator > 0.0F) ? (numerator / denominator) : pL;
  }

  // Apply transition: chance of learning after observation.
  const float pLNext = pLgivenObs + (1.0F - pLgivenObs) * p.pT;
  rec.pMastery = std::clamp(pLNext, 0.0F, 1.0F);
  rec.observations += 1;

  const std::string key = storeKey(userId, skillId, m_config.storePrefix);
  m_store.set(key, nlohmann::json{{"p", rec.pMastery}, {"n", rec.observations}});
  return Result<void>::ok();
}

auto MasteryTracker::getMastery(std::string_view userId, std::string_view skillId) const -> float {
  return loadRecord(userId, skillId).pMastery;
}

auto MasteryTracker::isMastered(std::string_view userId, std::string_view skillId) const -> bool {
  return getMastery(userId, skillId) >= m_config.masteryThreshold;
}

auto MasteryTracker::getRecord(std::string_view userId, std::string_view skillId) const
    -> MasteryRecord {
  return loadRecord(userId, skillId);
}

auto MasteryTracker::save() -> Result<void> {
  return m_store.save();
}

} // namespace nexus::cell
