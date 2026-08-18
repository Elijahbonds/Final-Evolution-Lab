// NEXUS port of archived FEL session types
#pragma once

#include <nlohmann/json.hpp>
#include <string>
#include <cstdint>

namespace nexus::gameplay {

enum class MatchOutcome : std::uint8_t {
  kWin = 0,
  kDraw = 1,
  kLoss = 2,
  kForfeit = 3,
};

struct SessionResult {
  std::string userId;
  std::string sessionId;
  std::string modeId;
  std::string venueId;
  MatchOutcome outcome{MatchOutcome::kLoss};
  float score{0.0F};
  float opponentScore{0.0F};
  float durationSeconds{0.0F};
  bool completed{false};
  std::string resultType;
  float arv{0.0F};
  float esi{0.0F};
  float pacingScore{0.0F};
  float mriScore{0.0F};
  float xpCandidate{0.0F};
  float shardsCandidate{0.0F};
  float prqDeltaCandidate{0.0F};
  int32_t comboCount{0};
  int32_t criticalCount{0};
  nlohmann::json modeSpecific{nlohmann::json::object()};
};

[[nodiscard]] auto matchOutcomeToString(MatchOutcome outcome) -> std::string_view;
[[nodiscard]] auto sessionResultToJson(const SessionResult& result) -> nlohmann::json;
[[nodiscard]] auto sessionReceiptBody(const SessionResult& result) -> nlohmann::json;

} // namespace nexus::gameplay
