#include "nexus/gameplay/gameplay_manager.h"

#include "nexus/core/log.h"
#include "nexus/gameplay/arena_mode_registry.h"

#include <algorithm>
#include <chrono>
#include <cmath>
#include <random>
#include <sstream>

namespace nexus::gameplay {

namespace {

constexpr float kPrqWin = 2.0F;
constexpr float kPrqDraw = 0.5F;
constexpr float kPrqLoss = 0.2F;
constexpr int32_t kShardWin = 50;
constexpr int32_t kShardDraw = 25;
constexpr int32_t kShardLoss = 15;
constexpr int32_t kXpCap = 500;

[[nodiscard]] auto compareScores(float player, float opponent) -> MatchOutcome {
  if (player > opponent) {
    return MatchOutcome::kWin;
  }
  if (player < opponent) {
    return MatchOutcome::kLoss;
  }
  return MatchOutcome::kDraw;
}

} // namespace

auto GameplayManager::modeWeight(std::string_view modeId) const -> float {
  if (const auto config = ArenaModeRegistry::find(modeId)) {
    return config->modeWeight;
  }
  return 1.0F;
}

auto GameplayManager::computeXp(MatchOutcome outcome, float mriScore, float weight) const
    -> int32_t {
  const float base = outcome == MatchOutcome::kWin   ? 200.0F
                     : outcome == MatchOutcome::kDraw ? 100.0F
                                                      : 50.0F;
  const float bonus = std::clamp(mriScore / 100.0F, 0.0F, 1.0F) * 100.0F;
  return std::min(static_cast<int32_t>((base + bonus) * weight), kXpCap);
}

auto GameplayManager::computeShards(MatchOutcome outcome, float pacingScore) const -> int32_t {
  const int32_t base = outcome == MatchOutcome::kWin   ? kShardWin
                       : outcome == MatchOutcome::kDraw ? kShardDraw
                                                        : kShardLoss;
  const float multiplier = pacingScore >= 75.0F ? 1.05F : 1.0F;
  return static_cast<int32_t>(static_cast<float>(base) * multiplier);
}

auto GameplayManager::computePrqDelta(MatchOutcome outcome, float mriScore, float weight) const
    -> float {
  const float prqBase = outcome == MatchOutcome::kWin   ? kPrqWin
                        : outcome == MatchOutcome::kDraw ? kPrqDraw
                                                         : kPrqLoss;
  return prqBase * weight * std::clamp(mriScore / 100.0F + 0.5F, 0.5F, 1.5F);
}

auto GameplayManager::makeSessionId() -> std::string {
  static thread_local std::mt19937_64 rng{static_cast<std::uint64_t>(
      std::chrono::steady_clock::now().time_since_epoch().count())};
  std::uniform_int_distribution<std::uint64_t> dist;
  std::ostringstream stream;
  stream << std::hex << dist(rng);
  return stream.str();
}

auto GameplayManager::computeSessionResult(std::string_view modeId,
                                           MatchOutcome outcome,
                                           float mriScore,
                                           float arv,
                                           float esi,
                                           float pacingScore) const -> SessionResult {
  SessionResult result;
  result.modeId = std::string(modeId);
  result.outcome = outcome;
  result.arv = arv;
  result.esi = esi;
  result.pacingScore = pacingScore;
  result.mriScore = arv * 0.40F + (100.0F - esi) * 0.35F + pacingScore * 0.25F;
  result.completed = true;
  const float weight = modeWeight(modeId);
  result.xpCandidate = static_cast<float>(computeXp(outcome, mriScore, weight));
  result.shardsCandidate = static_cast<float>(computeShards(outcome, pacingScore));
  result.prqDeltaCandidate = computePrqDelta(outcome, mriScore, weight);
  result.sessionId = makeSessionId();
  result.venueId = ArenaModeRegistry::venueTokenForMode(modeId);
  result.resultType = std::string(matchOutcomeToString(outcome));
  return result;
}

auto GameplayManager::onMatchEnd(std::string_view modeId,
                                 float playerScore,
                                 float opponentScore,
                                 float mriScore,
                                 float arv,
                                 float esi,
                                 float pacingScore) -> SessionResult {
  const MatchOutcome outcome = compareScores(playerScore, opponentScore);
  SessionResult result =
      computeSessionResult(modeId, outcome, mriScore, arv, esi, pacingScore);
  result.score = playerScore;
  result.opponentScore = opponentScore;
  dispatchSessionReceipt(result);
  return result;
}

void GameplayManager::dispatchSessionReceipt(const SessionResult& result) {
  const nlohmann::json body = sessionReceiptBody(result);
  m_pendingReceipts.push_back(body);
  m_receiptClient.enqueue(body);
  NEXUS_LOG_INFO(nexus::LogChannel::kAI,
                 "Session receipt queued for POST /api/games/session mode=" + result.modeId);
}

auto GameplayManager::pendingReceipts() const -> std::span<const nlohmann::json> {
  return m_pendingReceipts;
}

void GameplayManager::clearPendingReceipts() {
  m_pendingReceipts.clear();
  m_receiptClient.clearPending();
}

auto GameplayManager::flushPendingReceipts() -> SessionReceiptDispatchResult {
  const auto result = m_receiptClient.flush();
  syncPendingReceiptsFromClient();
  return result;
}

void GameplayManager::tickReceiptClient(double deltaSeconds) {
  m_receiptClient.tick(deltaSeconds);
  syncPendingReceiptsFromClient();
}

void GameplayManager::setReceiptClientConfig(SessionReceiptClientConfig config) {
  m_receiptClient.setConfig(std::move(config));
}

auto GameplayManager::receiptClientConfig() const -> SessionReceiptClientConfig {
  return m_receiptClient.config();
}

auto GameplayManager::receiptQueueDirectory() const -> std::string {
  return m_receiptClient.queueDirectory();
}

void GameplayManager::syncPendingReceiptsFromClient() {
  const auto pending = m_receiptClient.pendingReceipts();
  m_pendingReceipts.assign(pending.begin(), pending.end());
}

auto GameplayManager::evaluateBasketballOutcome(float playerScore, float opponentScore)
    -> MatchOutcome {
  return compareScores(playerScore, opponentScore);
}

auto GameplayManager::evaluateKarateOutcome(float playerHp, float opponentHp, bool /*timeExpired*/)
    -> MatchOutcome {
  if (playerHp > opponentHp) {
    return MatchOutcome::kWin;
  }
  if (playerHp < opponentHp) {
    return MatchOutcome::kLoss;
  }
  return MatchOutcome::kDraw;
}

auto GameplayManager::evaluateBaseballOutcome(int32_t playerRuns,
                                              int32_t opponentRuns,
                                              int32_t inning) -> MatchOutcome {
  if (inning >= 9) {
    return compareScores(static_cast<float>(playerRuns), static_cast<float>(opponentRuns));
  }
  return MatchOutcome::kDraw;
}

auto GameplayManager::evaluateFootballOutcome(int32_t playerTds, int32_t opponentTds)
    -> MatchOutcome {
  return compareScores(static_cast<float>(playerTds), static_cast<float>(opponentTds));
}

auto GameplayManager::evaluateSoccerOutcome(int32_t playerGoals, int32_t opponentGoals)
    -> MatchOutcome {
  return compareScores(static_cast<float>(playerGoals), static_cast<float>(opponentGoals));
}

auto GameplayManager::evaluateGolfOutcome(int32_t playerStrokes, int32_t parStrokes)
    -> MatchOutcome {
  if (playerStrokes <= parStrokes - 2) {
    return MatchOutcome::kWin;
  }
  if (playerStrokes <= parStrokes + 2) {
    return MatchOutcome::kDraw;
  }
  return MatchOutcome::kLoss;
}

auto GameplayManager::evaluateTennisOutcome(int32_t playerSets, int32_t opponentSets)
    -> MatchOutcome {
  return compareScores(static_cast<float>(playerSets), static_cast<float>(opponentSets));
}

auto GameplayManager::evaluateVolleyballOutcome(int32_t playerPoints, int32_t opponentPoints)
    -> MatchOutcome {
  if (playerPoints >= 25 && playerPoints - opponentPoints >= 2) {
    return MatchOutcome::kWin;
  }
  if (opponentPoints >= 25 && opponentPoints - playerPoints >= 2) {
    return MatchOutcome::kLoss;
  }
  return MatchOutcome::kDraw;
}

auto GameplayManager::evaluateSurfingOutcome(float playerScore, float threshold) -> MatchOutcome {
  if (playerScore >= threshold) {
    return MatchOutcome::kWin;
  }
  if (playerScore >= threshold * 0.7F) {
    return MatchOutcome::kDraw;
  }
  return MatchOutcome::kLoss;
}

auto GameplayManager::evaluateGymnasticsOutcome(float judgeScore, float goldThreshold)
    -> MatchOutcome {
  if (judgeScore >= goldThreshold) {
    return MatchOutcome::kWin;
  }
  if (judgeScore >= goldThreshold * 0.85F) {
    return MatchOutcome::kDraw;
  }
  return MatchOutcome::kLoss;
}

auto GameplayManager::evaluateBrainBrawlOutcome(int32_t playerCorrect, int32_t opponentCorrect)
    -> MatchOutcome {
  return compareScores(static_cast<float>(playerCorrect),
                      static_cast<float>(opponentCorrect));
}

auto GameplayManager::evaluateSkateboardingOutcome(int32_t score) -> MatchOutcome {
  return score >= 50 ? MatchOutcome::kWin : MatchOutcome::kLoss;
}

auto GameplayManager::evaluateSnowboardingOutcome(int32_t score) -> MatchOutcome {
  return score >= 50 ? MatchOutcome::kWin : MatchOutcome::kLoss;
}

auto GameplayManager::evaluateWhoSceneItOutcome(int32_t score) -> MatchOutcome {
  return score >= 7 ? MatchOutcome::kWin : MatchOutcome::kLoss;
}

auto GameplayManager::evaluateCourtCarnivalOutcome(int32_t score, int32_t opponentScore)
    -> MatchOutcome {
  return compareScores(static_cast<float>(score), static_cast<float>(opponentScore));
}

auto GameplayManager::evaluateMarketBrowseOutcome() -> MatchOutcome {
  return MatchOutcome::kDraw;
}

auto GameplayManager::evaluateOutcome(std::string_view modeId, const MatchScoreInput& input)
    -> MatchOutcome {
  if (modeId == "basketball_h2h" || modeId == "basketball_dunk" || modeId == "basketball_3v3") {
    return evaluateBasketballOutcome(input.playerScore, input.opponentScore);
  }
  if (modeId == "karate_h2h" || modeId == "karate_endless") {
    return evaluateKarateOutcome(input.playerHp, input.opponentHp, input.timeExpired);
  }
  if (modeId == "baseball") {
    return evaluateBaseballOutcome(input.playerRuns, input.opponentRuns, input.inning);
  }
  if (modeId == "football") {
    return evaluateFootballOutcome(input.playerTouchdowns, input.opponentTouchdowns);
  }
  if (modeId == "soccer") {
    return evaluateSoccerOutcome(input.playerGoals, input.opponentGoals);
  }
  if (modeId == "golf") {
    return evaluateGolfOutcome(input.playerStrokes, input.parStrokes);
  }
  if (modeId == "tennis") {
    return evaluateTennisOutcome(input.playerSets, input.opponentSets);
  }
  if (modeId == "volleyball") {
    return evaluateVolleyballOutcome(input.playerPoints, input.opponentPoints);
  }
  if (modeId == "surfing") {
    return evaluateSurfingOutcome(input.surfingScore, input.surfingThreshold);
  }
  if (modeId == "gymnastics") {
    return evaluateGymnasticsOutcome(input.judgeScore, input.goldThreshold);
  }
  if (modeId == "brain_brawl") {
    return evaluateBrainBrawlOutcome(input.playerCorrect, input.opponentCorrect);
  }
  if (modeId == "skateboarding") {
    return evaluateSkateboardingOutcome(input.stagingScore);
  }
  if (modeId == "snowboarding") {
    return evaluateSnowboardingOutcome(input.stagingScore);
  }
  if (modeId == "who_scene_it") {
    return evaluateWhoSceneItOutcome(input.stagingScore);
  }
  if (modeId == "court_carnival") {
    return evaluateCourtCarnivalOutcome(input.stagingScore, input.stagingOpponentScore);
  }
  if (modeId == "market_browse") {
    return evaluateMarketBrowseOutcome();
  }
  return compareScores(input.playerScore, input.opponentScore);
}

} // namespace nexus::gameplay
