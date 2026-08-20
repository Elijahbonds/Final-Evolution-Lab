#include "nexus/gameplay/mode_runtime.h"

#include "nexus/gameplay/arena_mode_registry.h"
#include "nexus/gameplay/prq_engine.h"
#include "nexus/gameplay/qte_system.h"
#include "nexus/core/log.h"

#include <algorithm>

namespace nexus::gameplay {

namespace {

[[nodiscard]] auto isOutcomeSportMode(std::string_view modeId) -> bool {
  return modeId == "basketball_3v3" || modeId == "karate_h2h" || modeId == "baseball" ||
         modeId == "football" || modeId == "soccer" || modeId == "golf" || modeId == "tennis" ||
         modeId == "volleyball";
}

} // namespace

auto ModeRuntime::physicsParams() const -> ArcadePhysicsParams {
  return ArcadePhysics::fromPRQ(PRQEngine::scoreForSnapshot(m_fitnessSnapshot),
                                PRQEngine::neuralDriveForSnapshot(m_fitnessSnapshot));
}

auto ModeRuntime::parseCarnivalPad(std::string_view label) -> std::optional<CarnivalPad> {
  if (label == "trick_shot") {
    return CarnivalPad::kTrickShot;
  }
  if (label == "hot_potato") {
    return CarnivalPad::kHotPotato;
  }
  if (label == "rhythm_board") {
    return CarnivalPad::kRhythmBoard;
  }
  if (label == "atw_landmark") {
    return CarnivalPad::kAtwLandmark;
  }
  return std::nullopt;
}

auto ModeRuntime::setMode(std::string_view modeId) -> Result<void> {
  const auto config = ArenaModeRegistry::find(modeId);
  if (!config.has_value()) {
    return Result<void>::err("unknown mode_id");
  }
  const std::string_view activeModeId = config->id;

  m_modeId = std::string(activeModeId);
  m_dunk.reset();
  m_karate.reset();
  m_pickup.reset();
  m_carnival.reset();
  m_gymnastics.reset();
  m_brainBrawl.reset();
  m_skateboarding.reset();
  m_snowboarding.reset();
  m_surfing.reset();
  m_whoSceneIt.reset();
  m_outcomeSport.reset();
  m_lastThrowPulseCount = 0;
  m_browseItemsViewed = 0;

  if (activeModeId == "basketball_dunk") {
    m_kind = ActiveModeKind::kDunkContest;
  } else if (activeModeId == "karate_endless") {
    m_kind = ActiveModeKind::kKarateEndless;
  } else if (activeModeId == "basketball_h2h") {
    m_kind = ActiveModeKind::kVenicePickup;
  } else if (activeModeId == "court_carnival") {
    m_kind = ActiveModeKind::kCourtCarnival;
  } else if (activeModeId == "gymnastics") {
    m_kind = ActiveModeKind::kGymnastics;
  } else if (activeModeId == "brain_brawl") {
    m_kind = ActiveModeKind::kBrainBrawl;
  } else if (activeModeId == "skateboarding") {
    m_kind = ActiveModeKind::kSkateboarding;
  } else if (activeModeId == "snowboarding") {
    m_kind = ActiveModeKind::kSnowboarding;
  } else if (activeModeId == "surfing") {
    m_kind = ActiveModeKind::kSurfing;
  } else if (activeModeId == "who_scene_it") {
    m_kind = ActiveModeKind::kWhoSceneIt;
  } else if (activeModeId == "market_browse") {
    m_kind = ActiveModeKind::kMarketBrowse;
    m_browseItemsViewed = 0;
  } else if (isOutcomeSportMode(activeModeId)) {
    m_kind = ActiveModeKind::kOutcomeSport;
    m_outcomeSport.reset(activeModeId);
  } else if (config->releaseState == ArenaReleaseState::kProduction ||
             config->releaseState == ArenaReleaseState::kStaging) {
    m_kind = ActiveModeKind::kComingSoon;
    NEXUS_LOG_WARN(nexus::LogChannel::kCore,
                   "Mode " + m_modeId + " registered as coming soon in NEXUS sprint build");
  } else {
    m_kind = ActiveModeKind::kComingSoon;
  }

  return Result<void>::ok();
}

void ModeRuntime::reset() {
  m_modeId.clear();
  m_kind = ActiveModeKind::kNone;
  m_dunk.reset();
  m_karate.reset();
  m_pickup.reset();
  m_carnival.reset();
  m_gymnastics.reset();
  m_brainBrawl.reset();
  m_skateboarding.reset();
  m_snowboarding.reset();
  m_surfing.reset();
  m_whoSceneIt.reset();
  m_outcomeSport.reset();
  m_lastThrowPulseCount = 0;
  m_browseItemsViewed = 0;
}

void ModeRuntime::setFitnessSnapshot(FitnessSnapshot snapshot) {
  m_fitnessSnapshot = snapshot;
}

void ModeRuntime::update(double deltaSeconds) {
  const ArcadePhysicsParams physics = physicsParams();
  if (m_kind == ActiveModeKind::kDunkContest) {
    m_dunk.update(deltaSeconds, physics);
  } else if (m_kind == ActiveModeKind::kKarateEndless) {
    m_karate.update(deltaSeconds);
  } else if (m_kind == ActiveModeKind::kVenicePickup) {
    m_pickup.update(deltaSeconds);
  } else if (m_kind == ActiveModeKind::kCourtCarnival) {
    m_carnival.update(deltaSeconds);
  } else if (m_kind == ActiveModeKind::kGymnastics) {
    m_gymnastics.update(deltaSeconds);
  } else if (m_kind == ActiveModeKind::kBrainBrawl) {
    m_brainBrawl.update(deltaSeconds);
  } else if (m_kind == ActiveModeKind::kSkateboarding) {
    m_skateboarding.update(deltaSeconds);
  } else if (m_kind == ActiveModeKind::kSnowboarding) {
    m_snowboarding.update(deltaSeconds);
  } else if (m_kind == ActiveModeKind::kSurfing) {
    m_surfing.update(deltaSeconds);
  } else if (m_kind == ActiveModeKind::kWhoSceneIt) {
    m_whoSceneIt.update(deltaSeconds);
  } else if (m_kind == ActiveModeKind::kOutcomeSport) {
    m_outcomeSport.update(deltaSeconds);
  }
}

void ModeRuntime::onThrowCatchPulse(const ThrowCatchState& throwCatch) {
  if (throwCatch.throwsTriggered <= m_lastThrowPulseCount) {
    return;
  }
  m_lastThrowPulseCount = throwCatch.throwsTriggered;

  if (m_kind == ActiveModeKind::kVenicePickup) {
    m_pickup.onThrowPulse(throwCatch.lastPulse);
  } else if (m_kind == ActiveModeKind::kCourtCarnival) {
    m_carnival.onThrowPulse(throwCatch.lastPulse);
  }
}

auto ModeRuntime::handleCommand(std::string_view command, const nlohmann::json& params)
    -> Result<nlohmann::json> {
  if (m_kind == ActiveModeKind::kMarketBrowse) {
    if (command == "fel.arena.mode_input") {
      const std::string action = params.value("action", "");
      if (action == "browse" || action == "details" || action == "Browse" || action == "Details") {
        ++m_browseItemsViewed;
        return Result<nlohmann::json>::ok({
            {"mode_id", m_modeId},
            {"items_viewed", m_browseItemsViewed},
            {"venue_token", ArenaModeRegistry::venueTokenForMode(m_modeId)},
        });
      }
    }
  }

  if (m_kind == ActiveModeKind::kDunkContest) {
    if (command == "fel.dunk.charge_begin") {
      const auto result = m_dunk.onChargeBegin();
      if (result.isErr()) {
        return Result<nlohmann::json>::err(result.error());
      }
      return Result<nlohmann::json>::ok(m_dunk.stateJson());
    }
    if (command == "fel.dunk.charge_release") {
      const float power = params.value("power", m_dunk.chargePower());
      const auto result = m_dunk.onChargeRelease(power);
      if (result.isErr()) {
        return Result<nlohmann::json>::err(result.error());
      }
      return Result<nlohmann::json>::ok(m_dunk.stateJson());
    }
    if (command == "fel.dunk.apex_tap") {
      const auto result = m_dunk.onApexTap();
      if (result.isErr()) {
        return Result<nlohmann::json>::err(result.error());
      }
      nlohmann::json payload = m_dunk.stateJson();
      payload["timing_grade"] = QTESystem::gradeLabel(result.value());
      payload["physics_feedback"] = {
          {"hang_time_multiplier", physicsParams().hangTimeMultiplier},
          {"charge_power", m_dunk.chargePower()},
      };
      return Result<nlohmann::json>::ok(std::move(payload));
    }
    if (command == "fel.dunk.register_signature") {
      const std::string animationId = params.value("animation_id", "");
      const nlohmann::json keyframes = params.contains("keyframes") ? params.at("keyframes") : nlohmann::json::array();
      const auto result = m_dunk.onRegisterSignature(animationId, keyframes);
      if (result.isErr()) {
        return Result<nlohmann::json>::err(result.error());
      }
      return Result<nlohmann::json>::ok(m_dunk.stateJson());
    }
  }

  if (m_kind == ActiveModeKind::kKarateEndless) {
    if (command == "fel.karate.wave") {
      const auto result = m_karate.handleWaveCommand(params);
      if (result.isErr()) {
        return Result<nlohmann::json>::err(result.error());
      }
      nlohmann::json payload = result.value();
      payload["karate"] = m_karate.stateJson();
      return Result<nlohmann::json>::ok(std::move(payload));
    }
    if (command == "fel.karate.action") {
      const std::string actionName = params.value("action", "light_strike");
      CombatAction action = CombatAction::kLightStrike;
      if (actionName == "heavy_strike") {
        action = CombatAction::kHeavyStrike;
      } else if (actionName == "block") {
        action = CombatAction::kBlock;
      } else if (actionName == "dodge") {
        action = CombatAction::kDodge;
      } else if (actionName == "counter") {
        action = CombatAction::kCounter;
      }
      const int playerIndex = params.value("player_index", -1);
      const auto result = m_karate.performAction(action, playerIndex);
      if (result.isErr()) {
        return Result<nlohmann::json>::err(result.error());
      }
      const nlohmann::json karateState = m_karate.stateJson();
      nlohmann::json payload = karateState;
      payload["combat"] = {
          {"action", CombatSystem::actionLabel(result.value().action)},
          {"damage", result.value().damageDealt},
          {"blocked", result.value().blocked},
          {"countered", result.value().countered},
          {"special_move", karateState.value("combo_chain", 0) >= 8},
      };
      payload["physics_feedback"] = {
          {"critical_hit_chance", physicsParams().criticalHitChance},
          {"explosive_first_step", physicsParams().explosiveFirstStep},
      };
      return Result<nlohmann::json>::ok(std::move(payload));
    }
  }

  if (m_kind == ActiveModeKind::kVenicePickup) {
    if (command == "fel.pickup.action") {
      const std::string action = params.value("action", "shoot");
      const float timing = params.value("timing", 0.85F);
      const bool success = params.value("success", true);
      auto result = m_pickup.onAction(action, timing, success);
      if (result.isErr()) {
        return result;
      }
      nlohmann::json payload = result.value();
      payload["physics_feedback"] = {
          {"explosive_first_step", physicsParams().explosiveFirstStep},
          {"critical_hit_chance", physicsParams().criticalHitChance},
      };
      return Result<nlohmann::json>::ok(std::move(payload));
    }
  }

  if (m_kind == ActiveModeKind::kCourtCarnival) {
    if (command == "fel.carnival.trigger_pad") {
      const std::string padName = params.value("pad", "trick_shot");
      const auto pad = parseCarnivalPad(padName);
      if (!pad.has_value()) {
        return Result<nlohmann::json>::err("unknown carnival pad");
      }
      const float timing = params.value("timing", 0.85F);
      auto result = m_carnival.triggerPad(*pad, timing);
      if (result.isErr()) {
        return result;
      }
      nlohmann::json payload = result.value();
      payload["physics_feedback"] = {
          {"explosive_first_step", physicsParams().explosiveFirstStep},
          {"critical_hit_chance", physicsParams().criticalHitChance},
      };
      return Result<nlohmann::json>::ok(std::move(payload));
    }
    if (command == "fel.carnival.roll_dice") {
      return m_carnival.rollDice();
    }
  }

  if (m_kind == ActiveModeKind::kGymnastics) {
    if (command == "fel.gymnastics.tap") {
      const float timing = params.value("timing", 0.85F);
      const float difficulty = params.value("difficulty", 0.7F);
      auto result = m_gymnastics.rhythmTap(timing, difficulty);
      if (result.isErr()) {
        return result;
      }
      nlohmann::json payload = result.value();
      payload["physics_feedback"] = {
          {"hang_time_multiplier", physicsParams().hangTimeMultiplier},
          {"critical_hit_chance", physicsParams().criticalHitChance},
      };
      return Result<nlohmann::json>::ok(std::move(payload));
    }
    if (command == "fel.gymnastics.deduct") {
      const float value = params.value("value", 0.5F);
      return m_gymnastics.applyDeduction(value);
    }
  }

  if (m_kind == ActiveModeKind::kBrainBrawl) {
    if (command == "fel.brain.answer") {
      const bool correct = params.value("correct", false);
      const float responseTime = params.value("response_time", 5.0F);
      const std::string category = params.value("category", "SportsIQ");
      auto result = m_brainBrawl.submitAnswer(correct, responseTime, category);
      if (result.isErr()) {
        return result;
      }
      nlohmann::json payload = result.value();
      payload["physics_feedback"] = {
          {"critical_hit_chance", physicsParams().criticalHitChance},
      };
      return Result<nlohmann::json>::ok(std::move(payload));
    }
  }

  if (m_kind == ActiveModeKind::kSkateboarding) {
    if (command == "fel.skate.trick") {
      const float difficulty = params.value("difficulty", 0.6F);
      const int32_t combo = params.value("combo_multiplier", 1);
      auto result = m_skateboarding.landTrick(difficulty, combo);
      if (result.isErr()) {
        return result;
      }
      nlohmann::json payload = result.value();
      payload["physics_feedback"] = {
          {"explosive_first_step", physicsParams().explosiveFirstStep},
          {"hang_time_multiplier", physicsParams().hangTimeMultiplier},
      };
      return Result<nlohmann::json>::ok(std::move(payload));
    }
    if (command == "fel.skate.bail") {
      return m_skateboarding.bail();
    }
  }

  if (m_kind == ActiveModeKind::kSnowboarding) {
    if (!params.is_object()) {
      return Result<nlohmann::json>::err("snow command params must be object");
    }
    if (command == "fel.snow.carve") {
      const float timing = params.value("timing", 0.85F);
      const float lineDifficulty = params.value("line_difficulty", 0.7F);
      return m_snowboarding.carve(timing, lineDifficulty);
    }
    if (command == "fel.snow.jump") {
      const float airDifficulty = params.value("air_difficulty", 0.65F);
      const int32_t combo = params.value("combo_multiplier", 1);
      return m_snowboarding.jump(airDifficulty, combo);
    }
    if (command == "fel.snow.butter") {
      const float style = params.value("style", 0.75F);
      return m_snowboarding.butter(style);
    }
    if (command == "fel.snow.wipeout") {
      return m_snowboarding.wipeout();
    }
  }

  if (m_kind == ActiveModeKind::kSurfing) {
    if (!params.is_object()) {
      return Result<nlohmann::json>::err("surf command params must be object");
    }
    if (command == "fel.surf.carve") {
      const float timing = params.value("timing", 0.85F);
      const float waveDifficulty = params.value("wave_difficulty", 0.7F);
      return m_surfing.carve(timing, waveDifficulty);
    }
    if (command == "fel.surf.aerial") {
      const float airDifficulty = params.value("air_difficulty", 0.65F);
      const int32_t combo = params.value("combo_multiplier", 1);
      return m_surfing.aerial(airDifficulty, combo);
    }
    if (command == "fel.surf.wipeout") {
      return m_surfing.wipeout();
    }
  }

  if (m_kind == ActiveModeKind::kOutcomeSport) {
    if (command == "fel.sport.pulse") {
      if (!params.is_object()) {
        return Result<nlohmann::json>::err("sport pulse params must be object");
      }
      auto result = m_outcomeSport.pulse(params);
      if (result.isErr()) {
        return result;
      }
      nlohmann::json payload = result.value();
      payload["physics_feedback"] = {
          {"explosive_first_step", physicsParams().explosiveFirstStep},
          {"critical_hit_chance", physicsParams().criticalHitChance},
      };
      return Result<nlohmann::json>::ok(std::move(payload));
    }
  }

  if (m_kind == ActiveModeKind::kWhoSceneIt) {
    if (!params.is_object()) {
      return Result<nlohmann::json>::err("scene command params must be object");
    }
    if (command == "fel.scene.buzz_in") {
      const float timing = params.value("timing", 0.85F);
      return m_whoSceneIt.buzzIn(timing);
    }
    if (command == "fel.scene.answer") {
      const bool correct = params.value("correct", false);
      const float responseTime = params.value("response_time", 5.0F);
      const std::string category = params.value("category", "ClassicFilm");
      return m_whoSceneIt.submitAnswer(correct, responseTime, category);
    }
  }

  if (command == "fel.mode.get_state") {
    return Result<nlohmann::json>::ok(stateJson());
  }

  return Result<nlohmann::json>::err("unsupported mode command");
}

auto ModeRuntime::stateJson() const -> nlohmann::json {
  const float prqScore = PRQEngine::scoreForSnapshot(m_fitnessSnapshot);
  const float neuralDrive = PRQEngine::neuralDriveForSnapshot(m_fitnessSnapshot);
  nlohmann::json payload{
      {"mode_id", m_modeId},
      {"kind", static_cast<int>(m_kind)},
      {"prq", prqScore},
      {"prq_grade", PRQEngine::gradeLabel(PRQEngine::gradeForScore(prqScore))},
      {"prq_source", m_fitnessSnapshot.revision == 0 ? "sprint_default" : "fitness_snapshot"},
      {"fitness_revision", m_fitnessSnapshot.revision},
      {"neural_drive", neuralDrive},
  };

  const ArcadePhysicsParams physics = physicsParams();
  payload["arcade_physics"] = {
      {"hang_time_multiplier", physics.hangTimeMultiplier},
      {"explosive_first_step", physics.explosiveFirstStep},
      {"critical_hit_chance", physics.criticalHitChance},
      {"neural_burst_active", physics.neuralBurstActive},
      {"neural_burst_multiplier", physics.neuralBurstMultiplier},
  };

  if (m_kind == ActiveModeKind::kDunkContest) {
    payload["dunk"] = m_dunk.stateJson();
  } else if (m_kind == ActiveModeKind::kKarateEndless) {
    payload["karate"] = m_karate.stateJson();
  } else if (m_kind == ActiveModeKind::kVenicePickup) {
    payload["pickup"] = m_pickup.stateJson();
  } else if (m_kind == ActiveModeKind::kCourtCarnival) {
    payload["carnival"] = m_carnival.stateJson();
  } else if (m_kind == ActiveModeKind::kGymnastics) {
    payload["gymnastics"] = m_gymnastics.stateJson();
  } else if (m_kind == ActiveModeKind::kBrainBrawl) {
    payload["brain_brawl"] = m_brainBrawl.stateJson();
  } else if (m_kind == ActiveModeKind::kSkateboarding) {
    payload["skateboarding"] = m_skateboarding.stateJson();
  } else if (m_kind == ActiveModeKind::kSnowboarding) {
    payload["snowboarding"] = m_snowboarding.stateJson();
  } else if (m_kind == ActiveModeKind::kSurfing) {
    payload["surfing"] = m_surfing.stateJson();
  } else if (m_kind == ActiveModeKind::kWhoSceneIt) {
    payload["who_scene_it"] = m_whoSceneIt.stateJson();
  } else if (m_kind == ActiveModeKind::kOutcomeSport) {
    payload["outcome_sport"] = m_outcomeSport.stateJson();
  } else if (m_kind == ActiveModeKind::kMarketBrowse) {
    payload["market_browse"] = {
        {"items_viewed", m_browseItemsViewed},
        {"venue_token", ArenaModeRegistry::venueTokenForMode(m_modeId)},
    };
  }

  return payload;
}

auto ModeRuntime::shouldAutoEndSession() const -> bool {
  if (m_kind == ActiveModeKind::kDunkContest) {
    return m_dunk.isMatchComplete();
  }
  if (m_kind == ActiveModeKind::kKarateEndless) {
    return m_karate.isSessionOver();
  }
  if (m_kind == ActiveModeKind::kVenicePickup) {
    return m_pickup.isMatchComplete();
  }
  if (m_kind == ActiveModeKind::kCourtCarnival) {
    return m_carnival.isMatchComplete();
  }
  if (m_kind == ActiveModeKind::kGymnastics) {
    return m_gymnastics.isRoutineComplete();
  }
  if (m_kind == ActiveModeKind::kBrainBrawl) {
    return m_brainBrawl.isMatchComplete();
  }
  if (m_kind == ActiveModeKind::kSkateboarding) {
    return m_skateboarding.isRunComplete();
  }
  if (m_kind == ActiveModeKind::kSnowboarding) {
    return m_snowboarding.isRunComplete();
  }
  if (m_kind == ActiveModeKind::kSurfing) {
    return m_surfing.isRunComplete();
  }
  if (m_kind == ActiveModeKind::kWhoSceneIt) {
    return m_whoSceneIt.isMatchComplete();
  }
  if (m_kind == ActiveModeKind::kOutcomeSport) {
    return m_outcomeSport.isMatchComplete();
  }
  if (m_kind == ActiveModeKind::kMarketBrowse) {
    return false;
  }
  return false;
}

auto ModeRuntime::sessionScoreInput() const -> MatchScoreInput {
  MatchScoreInput input{};
  if (m_kind == ActiveModeKind::kDunkContest) {
    input.playerScore = static_cast<float>(m_dunk.playerScore());
    input.opponentScore = static_cast<float>(m_dunk.opponentScore());
  } else if (m_kind == ActiveModeKind::kKarateEndless) {
    const nlohmann::json karateState = m_karate.stateJson();
    input.playerScore = static_cast<float>(m_karate.score());
    input.stagingScore = m_karate.score();
    if (m_karate.isVictory()) {
      input.playerHp = 100.0F;
      input.opponentHp = 0.0F;
    } else if (karateState.value("wave_state", "") == "defeat") {
      input.playerHp = 0.0F;
      input.opponentHp = 1.0F;
    } else {
      input.playerHp = karateState.value("player_hp", 0.0F);
      input.opponentHp = 0.0F;
    }
  } else if (m_kind == ActiveModeKind::kVenicePickup) {
    input.playerScore = static_cast<float>(m_pickup.playerScore());
    input.opponentScore = static_cast<float>(m_pickup.opponentScore());
  } else if (m_kind == ActiveModeKind::kCourtCarnival) {
    input.stagingScore = m_carnival.playerScore();
    input.stagingOpponentScore = m_carnival.opponentScore();
    input.playerScore = static_cast<float>(m_carnival.playerScore());
    input.opponentScore = static_cast<float>(m_carnival.opponentScore());
  } else if (m_kind == ActiveModeKind::kGymnastics) {
    input.judgeScore = m_gymnastics.judgeScore();
    input.goldThreshold = GymnasticsMode::kGoldThreshold;
    input.playerScore = m_gymnastics.judgeScore();
  } else if (m_kind == ActiveModeKind::kBrainBrawl) {
    input.playerCorrect = m_brainBrawl.playerCorrect();
    input.opponentCorrect = m_brainBrawl.opponentCorrect();
    input.playerScore = static_cast<float>(m_brainBrawl.playerCorrect());
    input.opponentScore = static_cast<float>(m_brainBrawl.opponentCorrect());
  } else if (m_kind == ActiveModeKind::kSkateboarding) {
    input.stagingScore = m_skateboarding.trickScore();
    input.playerScore = static_cast<float>(m_skateboarding.trickScore());
  } else if (m_kind == ActiveModeKind::kSnowboarding) {
    input.stagingScore = m_snowboarding.lineScore();
    input.playerScore = static_cast<float>(m_snowboarding.lineScore());
  } else if (m_kind == ActiveModeKind::kSurfing) {
    input.stagingScore = m_surfing.waveScore();
    input.playerScore = static_cast<float>(m_surfing.waveScore());
    input.surfingScore = static_cast<float>(m_surfing.waveScore());
    input.surfingThreshold = static_cast<float>(SurfingMode::kWinScore);
  } else if (m_kind == ActiveModeKind::kWhoSceneIt) {
    input.stagingScore = m_whoSceneIt.correctCount();
    input.playerCorrect = m_whoSceneIt.correctCount();
    input.playerScore = static_cast<float>(m_whoSceneIt.correctCount());
  } else if (m_kind == ActiveModeKind::kOutcomeSport) {
    return m_outcomeSport.sessionScoreInput();
  }
  return input;
}

auto ModeRuntime::comboCount() const -> int32_t {
  if (m_kind == ActiveModeKind::kDunkContest) {
    int32_t chain = 0;
    int32_t maxChain = 0;
    for (const DunkResult& dunk : m_dunk.dunkHistory()) {
      if (dunk.timingGrade == QTEGrade::kPerfect || dunk.timingGrade == QTEGrade::kGreat) {
        ++chain;
        maxChain = std::max(maxChain, chain);
      } else {
        chain = 0;
      }
    }
    return maxChain;
  }
  if (m_kind == ActiveModeKind::kKarateEndless) {
    return m_karate.stateJson().value("max_combo", 0);
  }
  if (m_kind == ActiveModeKind::kVenicePickup) {
    return static_cast<int32_t>(m_pickup.perfectCatches());
  }
  if (m_kind == ActiveModeKind::kCourtCarnival) {
    return m_carnival.stateJson().value("rounds_won", 0);
  }
  if (m_kind == ActiveModeKind::kGymnastics) {
    return m_gymnastics.stateJson().value("elements_completed", 0);
  }
  if (m_kind == ActiveModeKind::kBrainBrawl) {
    return m_brainBrawl.stateJson().value("peak_streak", 0);
  }
  if (m_kind == ActiveModeKind::kSkateboarding) {
    return m_skateboarding.stateJson().value("peak_combo", 0);
  }
  if (m_kind == ActiveModeKind::kSnowboarding) {
    return m_snowboarding.stateJson().value("peak_combo", 0);
  }
  if (m_kind == ActiveModeKind::kSurfing) {
    return m_surfing.stateJson().value("peak_combo", 0);
  }
  if (m_kind == ActiveModeKind::kWhoSceneIt) {
    return m_whoSceneIt.stateJson().value("peak_streak", 0);
  }
  if (m_kind == ActiveModeKind::kOutcomeSport) {
    return m_outcomeSport.stateJson().value("pulses", 0);
  }
  return 0;
}

auto ModeRuntime::criticalCount() const -> int32_t {
  if (m_kind == ActiveModeKind::kDunkContest) {
    int32_t count = 0;
    for (const DunkResult& dunk : m_dunk.dunkHistory()) {
      if (dunk.timingGrade == QTEGrade::kPerfect) {
        ++count;
      }
    }
    return count;
  }
  if (m_kind == ActiveModeKind::kKarateEndless) {
    return m_karate.stateJson().value("critical_hits", 0);
  }
  if (m_kind == ActiveModeKind::kVenicePickup) {
    return static_cast<int32_t>(m_pickup.perfectCatches());
  }
  return 0;
}

auto ModeRuntime::modeSpecificPayload() const -> nlohmann::json {
  if (m_kind == ActiveModeKind::kDunkContest) {
    return {{"dunk_details", m_dunk.stateJson().value("dunk_details", nlohmann::json::array())}};
  }
  if (m_kind == ActiveModeKind::kKarateEndless) {
    return {{"karate", m_karate.stateJson()}};
  }
  if (m_kind == ActiveModeKind::kVenicePickup) {
    return {{"pickup", m_pickup.stateJson()}};
  }
  if (m_kind == ActiveModeKind::kCourtCarnival) {
    return {{"carnival", m_carnival.stateJson()}};
  }
  if (m_kind == ActiveModeKind::kGymnastics) {
    return {{"gymnastics", m_gymnastics.stateJson()}};
  }
  if (m_kind == ActiveModeKind::kBrainBrawl) {
    return {{"brain_brawl", m_brainBrawl.stateJson()}};
  }
  if (m_kind == ActiveModeKind::kSkateboarding) {
    return {{"skateboarding", m_skateboarding.stateJson()}};
  }
  if (m_kind == ActiveModeKind::kSnowboarding) {
    return {{"snowboarding", m_snowboarding.stateJson()}};
  }
  if (m_kind == ActiveModeKind::kSurfing) {
    return {{"surfing", m_surfing.stateJson()}};
  }
  if (m_kind == ActiveModeKind::kWhoSceneIt) {
    return {{"who_scene_it", m_whoSceneIt.stateJson()}};
  }
  if (m_kind == ActiveModeKind::kOutcomeSport) {
    return {{"outcome_sport", m_outcomeSport.stateJson()}};
  }
  return nlohmann::json::object();
}

} // namespace nexus::gameplay
