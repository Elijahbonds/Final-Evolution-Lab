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
  m_state.multiplayerMode = MultiplayerMode::kSolo;
  NEXUS_LOG_INFO(nexus::LogChannel::kCore,
                 "Arena session started mode=" + m_state.modeId + " venue=" + m_state.venueToken);
  return Result<void>::ok();
}

auto ArenaSessionManager::startMultiplayerSession(
    std::string_view modeId,
    std::string_view hostUserId,
    const std::vector<std::string>& playerIds,
    MultiplayerMode mpMode,
    std::string_view roomCode) -> Result<void> {
  const auto result = startSession(modeId, hostUserId);
  if (result.isErr()) {
    return result;
  }
  m_state.multiplayerMode = mpMode;
  m_state.playerIds       = playerIds;
  m_state.roomCode        = std::string(roomCode);
  // Initialise per-player score slots.
  m_state.playerScores.clear();
  for (const auto& pid : playerIds) {
    m_state.playerScores[pid] = 0.0F;
  }
  NEXUS_LOG_INFO(nexus::LogChannel::kCore,
                 "Arena multiplayer session started mode=" + m_state.modeId +
                     " players=" + std::to_string(playerIds.size()) +
                     " room=" + m_state.roomCode);
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

      // For multiplayer sessions, dispatch a receipt for every remote player
      // using their per-player score from the shared score map.
      if (m_state.multiplayerMode != MultiplayerMode::kSolo) {
        for (const auto& [pid, pScore] : m_state.playerScores) {
          if (pid == m_state.userId) {
            continue;  // host receipt already dispatched above
          }
          SessionResult peerResult = result;
          peerResult.userId  = pid;
          peerResult.score   = pScore;
          // Peer outcome: if their score beats the host's opponent score they win.
          peerResult.outcome = (pScore >= result.opponentScore)
                                   ? MatchOutcome::kWin
                                   : MatchOutcome::kLoss;
          peerResult.resultType = std::string(matchOutcomeToString(peerResult.outcome));
          gameplayManager.dispatchSessionReceipt(peerResult);
        }
      }
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

void ArenaSessionManager::updatePlayerScore(std::string_view playerId, float score) {
  m_state.playerScores[std::string(playerId)] = score;
  // Mirror host player score to the legacy scalar for single-player compatibility.
  if (playerId == m_state.userId) {
    m_state.playerScore = score;
  }
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
      {"multiplayer_mode", static_cast<int>(m_state.multiplayerMode)},
      {"room_code", m_state.roomCode},
  };

  if (!m_state.playerIds.empty()) {
    payload["player_ids"] = m_state.playerIds;
    nlohmann::json scores = nlohmann::json::object();
    for (const auto& [pid, pScore] : m_state.playerScores) {
      scores[pid] = pScore;
    }
    payload["player_scores"] = std::move(scores);
  }

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
