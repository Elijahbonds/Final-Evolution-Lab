// Spec §12.4 — active mode orchestration for P0/P1 sims
#pragma once

#include "nexus/core/result.h"
#include "nexus/gameplay/arcade_physics.h"
#include "nexus/gameplay/combat_system.h"
#include "nexus/gameplay/brain_brawl_mode.h"
#include "nexus/gameplay/court_carnival_mode.h"
#include "nexus/gameplay/dunk_contest_mode.h"
#include "nexus/gameplay/fitness_data.h"
#include "nexus/gameplay/gymnastics_mode.h"
#include "nexus/gameplay/karate_endless_mode.h"
#include "nexus/gameplay/gameplay_manager.h"
#include "nexus/gameplay/skateboarding_mode.h"
#include "nexus/gameplay/snowboarding_mode.h"
#include "nexus/gameplay/surfing_mode.h"
#include "nexus/gameplay/throw_catch_physics.h"
#include "nexus/gameplay/venice_pickup_mode.h"
#include "nexus/gameplay/outcome_sport_mode.h"
#include "nexus/gameplay/who_scene_it_mode.h"

#include <nlohmann/json.hpp>
#include <cstdint>
#include <optional>
#include <string>

namespace nexus::gameplay {

enum class ActiveModeKind : std::uint8_t {
  kNone = 0,
  kDunkContest = 1,
  kKarateEndless = 2,
  kVenicePickup = 3,
  kCourtCarnival = 4,
  kComingSoon = 5,
  kGymnastics = 6,
  kBrainBrawl = 7,
  kSkateboarding = 8,
  kSnowboarding = 9,
  kWhoSceneIt = 10,
  kOutcomeSport = 11,
  kSurfing = 12,
  kMarketBrowse = 13,
};

class ModeRuntime {
public:
  auto setMode(std::string_view modeId) -> Result<void>;
  void reset();
  void setFitnessSnapshot(const FitnessSnapshot& snapshot);
  void update(double deltaSeconds);

  auto handleCommand(std::string_view command, const nlohmann::json& params) -> Result<nlohmann::json>;
  void onThrowCatchPulse(const ThrowCatchState& throwCatch);

  [[nodiscard]] auto activeModeId() const -> std::string_view { return m_modeId; }
  [[nodiscard]] auto activeKind() const -> ActiveModeKind { return m_kind; }
  [[nodiscard]] auto stateJson() const -> nlohmann::json;
  [[nodiscard]] auto shouldAutoEndSession() const -> bool;
  [[nodiscard]] auto sessionScoreInput() const -> MatchScoreInput;
  [[nodiscard]] auto comboCount() const -> int32_t;
  [[nodiscard]] auto criticalCount() const -> int32_t;
  [[nodiscard]] auto modeSpecificPayload() const -> nlohmann::json;

private:
  [[nodiscard]] auto physicsParams() const -> ArcadePhysicsParams;
  [[nodiscard]] static auto parseCarnivalPad(std::string_view label) -> std::optional<CarnivalPad>;

  std::string m_modeId;
  ActiveModeKind m_kind{ActiveModeKind::kNone};
  DunkContestMode m_dunk;
  KarateEndlessMode m_karate;
  VenicePickupMode m_pickup;
  CourtCarnivalMode m_carnival;
  GymnasticsMode m_gymnastics;
  BrainBrawlMode m_brainBrawl;
  SkateboardingMode m_skateboarding;
  SnowboardingMode m_snowboarding;
  SurfingMode m_surfing;
  WhoSceneItMode m_whoSceneIt;
  OutcomeSportMode m_outcomeSport;
  FitnessSnapshot m_fitnessSnapshot;
  std::uint64_t m_lastThrowPulseCount{0};
  std::int32_t m_browseItemsViewed{0};
};

} // namespace nexus::gameplay
