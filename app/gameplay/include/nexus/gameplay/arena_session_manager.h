// Port of AFELGameModeBase session lifecycle + arena mode selection
#pragma once


#include <cstdint>

#include "nexus/core/result.h"
#include "nexus/gameplay/fel_session_types.h"
#include "nexus/gameplay/fitness_data.h"
#include "nexus/gameplay/gameplay_manager.h"

#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <unordered_map>
#include <vector>

// GCC 13.3 workaround: forward-declare enum classes before large STL includes.
namespace nexus { namespace gameplay {
  enum class ArenaSessionPhase : std::uint8_t;
  enum class MultiplayerMode   : std::uint8_t;
} } // namespace nexus::gameplay

namespace nexus::gameplay {

enum class ArenaSessionPhase : std::uint8_t {
  kIdle = 0,
  kActive = 1,
  kEnded = 2,
};

enum class MultiplayerMode : std::uint8_t {
  kSolo       = 0,
  kLocalMulti = 1,
  kOnline     = 2,
};

struct ArenaSessionState {
  ArenaSessionPhase phase{ArenaSessionPhase::kIdle};
  std::string modeId;
  std::string venueToken;
  std::string userId{"anonymous"};
  float elapsedSeconds{0.0F};
  float playerScore{0.0F};
  float opponentScore{0.0F};
  bool matchActive{false};
  bool paused{false};
  int32_t comboCount{0};
  int32_t criticalCount{0};
  nlohmann::json modeState{nlohmann::json::object()};
  std::optional<SessionResult> lastResult;

  // ── Multiplayer extensions ────────────────────────────────────────────────
  MultiplayerMode multiplayerMode{MultiplayerMode::kSolo};
  std::vector<std::string>                     playerIds;
  std::unordered_map<std::string, float>       playerScores;
  std::string                                  roomCode;
};

class ArenaSessionManager {
public:
  [[nodiscard]] auto startSession(std::string_view modeId, std::string_view userId) -> Result<void>;

  /// Start a multiplayer session with multiple player IDs.
  [[nodiscard]] auto startMultiplayerSession(std::string_view modeId,
                                              std::string_view hostUserId,
                                              const std::vector<std::string>& playerIds,
                                              MultiplayerMode mpMode,
                                              std::string_view roomCode = {}) -> Result<void>;

  void update(double deltaSeconds, const FitnessSnapshot& fitness);
  [[nodiscard]] auto endSession(const MatchScoreInput& scoreInput,
                                GameplayManager& gameplayManager,
                                const FitnessSnapshot& fitness,
                                const nlohmann::json& modeSpecific = nlohmann::json::object())
      -> Result<SessionResult>;
  [[nodiscard]] auto setMode(std::string_view modeId) -> Result<void>;
  void updateScores(float playerScore, float opponentScore);
  void syncLiveState(float playerScore,
                     float opponentScore,
                     int32_t comboCount,
                     int32_t criticalCount,
                     nlohmann::json modeState);
  void updatePlayerScore(std::string_view playerId, float score);
  void pauseSession();
  void resumeSession();
  [[nodiscard]] auto state() const -> const ArenaSessionState&;
  [[nodiscard]] auto lastResult() const -> const std::optional<SessionResult>&;
  [[nodiscard]] auto finalScoresJson() const -> nlohmann::json;
  [[nodiscard]] auto stateJson() const -> nlohmann::json;

private:
  [[nodiscard]] static auto deriveMriInputs(const FitnessSnapshot& fitness,
                                            float elapsedSeconds,
                                            float& outArv,
                                            float& outEsi,
                                            float& outPacing) -> float;

  ArenaSessionState m_state;
};

} // namespace nexus::gameplay
