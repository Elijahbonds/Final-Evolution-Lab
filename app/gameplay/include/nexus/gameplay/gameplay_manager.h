// NEXUS port of archived FEL gameplay manager
#pragma once

#include "nexus/gameplay/fel_session_types.h"
#include "nexus/gameplay/session_receipt_client.h"

#include <nlohmann/json.hpp>
#include <cstdint>
#include <string>
#include <string_view>
#include <vector>

namespace nexus::gameplay {

struct MatchScoreInput {
  float playerScore{0.0F};
  float opponentScore{0.0F};
  int32_t playerRuns{0};
  int32_t opponentRuns{0};
  int32_t inning{0};
  int32_t playerTouchdowns{0};
  int32_t opponentTouchdowns{0};
  int32_t playerGoals{0};
  int32_t opponentGoals{0};
  int32_t playerStrokes{0};
  int32_t parStrokes{0};
  int32_t playerSets{0};
  int32_t opponentSets{0};
  int32_t playerPoints{0};
  int32_t opponentPoints{0};
  float playerHp{100.0F};
  float opponentHp{100.0F};
  bool timeExpired{false};
  float surfingScore{0.0F};
  float surfingThreshold{75.0F};
  float judgeScore{0.0F};
  float goldThreshold{85.0F};
  int32_t playerCorrect{0};
  int32_t opponentCorrect{0};
  int32_t stagingScore{0};
  int32_t stagingOpponentScore{0};
};

class GameplayManager {
public:
  [[nodiscard]] auto computeSessionResult(std::string_view modeId,
                                          MatchOutcome outcome,
                                          float mriScore,
                                          float arv,
                                          float esi,
                                          float pacingScore) const -> SessionResult;

  auto onMatchEnd(std::string_view modeId,
                  float playerScore,
                  float opponentScore,
                  float mriScore,
                  float arv,
                  float esi,
                  float pacingScore) -> SessionResult;

  void dispatchSessionReceipt(const SessionResult& result);

  [[nodiscard]] auto pendingReceipts() const -> std::span<const nlohmann::json>;
  void clearPendingReceipts();
  auto flushPendingReceipts() -> SessionReceiptDispatchResult;
  void tickReceiptClient(double deltaSeconds);
  void setReceiptClientConfig(SessionReceiptClientConfig config);
  [[nodiscard]] auto receiptClientConfig() const -> SessionReceiptClientConfig;
  [[nodiscard]] auto receiptQueueDirectory() const -> std::string;

  [[nodiscard]] static auto evaluateOutcome(std::string_view modeId,
                                            const MatchScoreInput& input) -> MatchOutcome;

  [[nodiscard]] static auto evaluateBasketballOutcome(float playerScore, float opponentScore)
      -> MatchOutcome;
  [[nodiscard]] static auto evaluateKarateOutcome(float playerHp,
                                                    float opponentHp,
                                                    bool timeExpired) -> MatchOutcome;
  [[nodiscard]] static auto evaluateBaseballOutcome(int32_t playerRuns,
                                                    int32_t opponentRuns,
                                                    int32_t inning) -> MatchOutcome;
  [[nodiscard]] static auto evaluateFootballOutcome(int32_t playerTds, int32_t opponentTds)
      -> MatchOutcome;
  [[nodiscard]] static auto evaluateSoccerOutcome(int32_t playerGoals, int32_t opponentGoals)
      -> MatchOutcome;
  [[nodiscard]] static auto evaluateGolfOutcome(int32_t playerStrokes, int32_t parStrokes)
      -> MatchOutcome;
  [[nodiscard]] static auto evaluateTennisOutcome(int32_t playerSets, int32_t opponentSets)
      -> MatchOutcome;
  [[nodiscard]] static auto evaluateVolleyballOutcome(int32_t playerPoints, int32_t opponentPoints)
      -> MatchOutcome;
  [[nodiscard]] static auto evaluateSurfingOutcome(float playerScore, float threshold)
      -> MatchOutcome;
  [[nodiscard]] static auto evaluateGymnasticsOutcome(float judgeScore, float goldThreshold)
      -> MatchOutcome;
  [[nodiscard]] static auto evaluateBrainBrawlOutcome(int32_t playerCorrect,
                                                      int32_t opponentCorrect) -> MatchOutcome;
  [[nodiscard]] static auto evaluateSkateboardingOutcome(int32_t score) -> MatchOutcome;
  [[nodiscard]] static auto evaluateSnowboardingOutcome(int32_t score) -> MatchOutcome;
  [[nodiscard]] static auto evaluateWhoSceneItOutcome(int32_t score) -> MatchOutcome;
  [[nodiscard]] static auto evaluateCourtCarnivalOutcome(int32_t score, int32_t opponentScore)
      -> MatchOutcome;
  [[nodiscard]] static auto evaluateMarketBrowseOutcome() -> MatchOutcome;

private:
  [[nodiscard]] auto modeWeight(std::string_view modeId) const -> float;
  [[nodiscard]] auto computeXp(MatchOutcome outcome, float mriScore, float weight) const -> int32_t;
  [[nodiscard]] auto computeShards(MatchOutcome outcome, float pacingScore) const -> int32_t;
  [[nodiscard]] auto computePrqDelta(MatchOutcome outcome, float mriScore, float weight) const
      -> float;
  [[nodiscard]] static auto makeSessionId() -> std::string;

  SessionReceiptClient m_receiptClient;
  std::vector<nlohmann::json> m_pendingReceipts;
};

} // namespace nexus::gameplay
