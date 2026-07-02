#include "nexus/gameplay/arena_session_manager.h"

#include "nexus/core/log.h"
#include "nexus/gameplay/arena_mode_registry.h"

#include <algorithm>

namespace nexus::gameplay {

auto ArenaSessionManager::startSession(std::string_view modeId, std::string_view userId)
    -> Result<void> {
  const auto config = ArenaModeRegistry::find(modeId);
  if (!config.has_value()) {
    return Result<void>::err("unknown arena mode_id");
  }

  m_state = {};
  m_state.phase = ArenaSessionPhase::kActive;
  m_state.modeId = config->id;
  m_state.venueToken = ArenaModeRegistry::venueTokenForMode(modeId);
  m_state.userId = std::string(userId);
  m_state.matchActive = config->scoringEnabled;
  m_state.paused = false;
  NEXUS_LOG_INFO(nexus::LogChannel::kCore,
                 "Arena session started mode=" + m_state.modeId + " venue=" + m_state.venueToken);
  return Result<void>::ok();
}

void ArenaSessionManager::update(double deltaSeconds, const FitnessSnapshot& /*fitness*/) {
  if (m_state.phase != ArenaSessionPhase::kActive || m_state.paused) {
    return;
  }
  m_state.elapsedSeconds += static_cast<float>(deltaSeconds);
}

auto ArenaSessionManager::endSession(const MatchScoreInput& scoreInput,
                                     GameplayManager& gameplayManager,
                                     const FitnessSnapshot& fitness,
                                     const nlohmann::json& modeSpecific) -> Result<SessionResult> {
  if (m_state.phase == ArenaSessionPhase::kEnded) {
    if (m_state.lastResult.has_value()) {
      return Result<SessionResult>::ok(*m_state.lastResult);
    }
    return Result<SessionResult>::err("session already ended without result");
  }
  if (m_state.phase != ArenaSessionPhase::kActive) {
    return Result<SessionResult>::err("no active arena session");
  }

  float arv = 0.0F;
  float esi = 0.0F;
  float pacing = 0.0F;
  const float mriScore = deriveMriInputs(fitness, m_state.elapsedSeconds, arv, esi, pacing);
  const MatchOutcome outcome =
      GameplayManager::evaluateOutcome(m_state.modeId, scoreInput);

  SessionResult result = gameplayManager.computeSessionResult(
      m_state.modeId, outcome, mriScore, arv, esi, pacing);
  result.userId = m_state.userId;
  result.score = scoreInput.playerScore;
  result.opponentScore = scoreInput.opponentScore;
  result.durationSeconds = m_state.elapsedSeconds;
  result.comboCount = m_state.comboCount;
  result.criticalCount = m_state.criticalCount;
  if (!modeSpecific.empty()) {
    result.modeSpecific = modeSpecific;
  } else if (!m_state.modeState.empty()) {
    result.modeSpecific = m_state.modeState;
  }

  if (const auto config = ArenaModeRegistry::find(m_state.modeId)) {
    if (config->scoringEnabled && config->modeWeight > 0.0F) {
      gameplayManager.dispatchSessionReceipt(result);
    }
  }

  m_state.phase = ArenaSessionPhase::kEnded;
  m_state.matchActive = false;
  m_state.lastResult = result;
  NEXUS_LOG_INFO(nexus::LogChannel::kCore,
                 "Arena session ended mode=" + m_state.modeId + " outcome=" + result.resultType);
  return Result<SessionResult>::ok(std::move(result));
}

auto ArenaSessionManager::setMode(std::string_view modeId) -> Result<void> {
  const auto config = ArenaModeRegistry::find(modeId);
  if (!config.has_value()) {
    return Result<void>::err("unknown arena mode_id");
  }
  m_state.modeId = config->id;
  m_state.venueToken = ArenaModeRegistry::venueTokenForMode(modeId);
  return Result<void>::ok();
}

void ArenaSessionManager::updateScores(float playerScore, float opponentScore) {
  m_state.playerScore = playerScore;
  m_state.opponentScore = opponentScore;
}

void ArenaSessionManager::syncLiveState(float playerScore,
                                        float opponentScore,
                                        int32_t comboCount,
                                        int32_t criticalCount,
                                        nlohmann::json modeState) {
  m_state.playerScore = playerScore;
  m_state.opponentScore = opponentScore;
  m_state.comboCount = comboCount;
  m_state.criticalCount = criticalCount;
  m_state.modeState = std::move(modeState);
}

void ArenaSessionManager::pauseSession() {
  if (m_state.phase == ArenaSessionPhase::kActive) {
    m_state.paused = true;
  }
}

void ArenaSessionManager::resumeSession() {
  if (m_state.phase == ArenaSessionPhase::kActive) {
    m_state.paused = false;
  }
}

auto ArenaSessionManager::state() const -> const ArenaSessionState& {
  return m_state;
}

auto ArenaSessionManager::lastResult() const -> const std::optional<SessionResult>& {
  return m_state.lastResult;
}

auto ArenaSessionManager::finalScoresJson() const -> nlohmann::json {
  if (m_state.lastResult.has_value()) {
    const SessionResult& result = *m_state.lastResult;
    return {
        {"player_score", result.score},
        {"opponent_score", result.opponentScore},
        {"outcome", result.resultType},
        {"mode_id", result.modeId},
        {"venue_id", result.venueId},
        {"session_id", result.sessionId},
        {"duration_seconds", result.durationSeconds},
        {"combo_count", result.comboCount},
        {"critical_count", result.criticalCount},
        {"completed", result.completed},
    };
  }

  return {
      {"player_score", m_state.playerScore},
      {"opponent_score", m_state.opponentScore},
      {"mode_id", m_state.modeId},
      {"venue_token", m_state.venueToken},
      {"phase", static_cast<int>(m_state.phase)},
      {"elapsed_seconds", m_state.elapsedSeconds},
      {"combo_count", m_state.comboCount},
      {"critical_count", m_state.criticalCount},
  };
}

auto ArenaSessionManager::stateJson() const -> nlohmann::json {
  nlohmann::json payload = {
      {"phase", static_cast<int>(m_state.phase)},
      {"mode_id", m_state.modeId},
      {"venue_token", m_state.venueToken},
      {"user_id", m_state.userId},
      {"elapsed_seconds", m_state.elapsedSeconds},
      {"player_score", m_state.playerScore},
      {"opponent_score", m_state.opponentScore},
      {"match_active", m_state.matchActive},
      {"paused", m_state.paused},
      {"combo_count", m_state.comboCount},
      {"critical_count", m_state.criticalCount},
      {"mode_state", m_state.modeState},
  };
  if (m_state.lastResult.has_value()) {
    payload["last_result"] = sessionResultToJson(*m_state.lastResult);
  }
  return payload;
}

auto ArenaSessionManager::deriveMriInputs(const FitnessSnapshot& fitness,
                                          float elapsedSeconds,
                                          float& outArv,
                                          float& outEsi,
                                          float& outPacing) -> float {
  outArv = (fitness.frc.mobilityScore + fitness.frc.activeRangeScore + fitness.frc.controlScore) /
           3.0F * 100.0F;
  outEsi = (1.0F - fitness.iap.engagementScore) * 100.0F;
  outPacing = std::clamp(elapsedSeconds / 300.0F, 0.0F, 1.0F) * 100.0F;
  return outArv * 0.40F + (100.0F - outEsi) * 0.35F + outPacing * 0.25F;
}

} // namespace nexus::gameplay
