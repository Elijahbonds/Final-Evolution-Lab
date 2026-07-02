#include "nexus/gameplay/fel_session_types.h"

#include <algorithm>
#include <chrono>
#include <ctime>
#include <iomanip>
#include <sstream>

namespace nexus::gameplay {

namespace {

[[nodiscard]] auto isoTimestampUtc() -> std::string {
  const auto now = std::chrono::system_clock::now();
  const std::time_t seconds = std::chrono::system_clock::to_time_t(now);
  std::tm utc{};
#if defined(_WIN32)
  gmtime_s(&utc, &seconds);
#else
  gmtime_r(&seconds, &utc);
#endif
  std::ostringstream stream;
  stream << std::put_time(&utc, "%Y-%m-%dT%H:%M:%SZ");
  return stream.str();
}

[[nodiscard]] auto prqGradeForScore(float score) -> std::string_view {
  if (score >= 90.0F) {
    return "ELITE";
  }
  if (score >= 75.0F) {
    return "PRIMED";
  }
  if (score >= 60.0F) {
    return "READY";
  }
  return "BUILDING";
}

} // namespace

auto matchOutcomeToString(MatchOutcome outcome) -> std::string_view {
  switch (outcome) {
  case MatchOutcome::kWin:
    return "win";
  case MatchOutcome::kDraw:
    return "draw";
  case MatchOutcome::kLoss:
    return "loss";
  case MatchOutcome::kForfeit:
    return "forfeit";
  }
  return "loss";
}

auto sessionResultToJson(const SessionResult& result) -> nlohmann::json {
  return {
      {"user_id", result.userId},
      {"session_id", result.sessionId},
      {"mode_id", result.modeId},
      {"venue_id", result.venueId},
      {"outcome", matchOutcomeToString(result.outcome)},
      {"score", result.score},
      {"opponent_score", result.opponentScore},
      {"duration_seconds", result.durationSeconds},
      {"completed", result.completed},
      {"result_type", result.resultType},
      {"arv", result.arv},
      {"esi", result.esi},
      {"pacing_score", result.pacingScore},
      {"mri_score", result.mriScore},
      {"xp_candidate", result.xpCandidate},
      {"shards_candidate", result.shardsCandidate},
      {"prq_delta_candidate", result.prqDeltaCandidate},
      {"combo_count", result.comboCount},
      {"critical_count", result.criticalCount},
      {"mode_specific", result.modeSpecific},
  };
}

auto sessionReceiptBody(const SessionResult& result) -> nlohmann::json {
  const int32_t scoreInt = static_cast<int32_t>(std::max(0.0F, result.score));
  const int32_t durationInt =
      static_cast<int32_t>(std::max(0.0F, result.durationSeconds));

  nlohmann::json telemetry = {
      {"session_id", result.sessionId},
      {"user_id", result.userId},
      {"venue", result.venueId},
      {"timestamp", isoTimestampUtc()},
      {"results",
       {
           {"outcome", result.resultType},
           {"score", scoreInt},
           {"opponent_score", static_cast<int32_t>(std::max(0.0F, result.opponentScore))},
           {"duration_seconds", durationInt},
           {"completed", result.completed},
       }},
      {"combos",
       {
           {"combo_count", result.comboCount},
           {"max_chain", result.comboCount},
           {"critical_count", result.criticalCount},
       }},
      {"economy",
       {
           {"xp_raw", static_cast<int32_t>(result.xpCandidate)},
           {"xp_awarded", static_cast<int32_t>(result.xpCandidate)},
           {"shards_total", static_cast<int32_t>(result.shardsCandidate)},
           {"prq_delta", result.prqDeltaCandidate},
       }},
      {"prq_snapshot",
       {
           {"score", std::clamp(result.mriScore, 0.0F, 100.0F)},
           {"grade", std::string(prqGradeForScore(result.mriScore))},
           {"delta_candidate", result.prqDeltaCandidate},
       }},
      {"device",
       {
           {"engine", "NEXUS 1.0"},
       }},
  };
  if (!result.modeSpecific.empty()) {
    telemetry["mode_specific"] = result.modeSpecific;
  }

  return {
      {"mode_id", result.modeId},
      {"score", scoreInt},
      {"outcome", result.resultType},
      {"duration_seconds", durationInt},
      {"completed", result.completed},
      {"combo_count", result.comboCount},
      {"critical_count", result.criticalCount},
      {"pacing_score", result.pacingScore},
      {"mri_score", result.mriScore},
      {"arv", result.arv},
      {"esi", result.esi},
      {"telemetry", std::move(telemetry)},
  };
}

} // namespace nexus::gameplay
