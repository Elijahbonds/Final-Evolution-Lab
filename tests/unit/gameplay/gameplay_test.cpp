#include "nexus/ai/agent_server.h"
#include "nexus/ai/command_router.h"
#include "nexus/ai/game_prompt_adapter.h"
#include "nexus/ai/gemini_game_prompt_client.h"
#include "nexus/ai/nexus_ai_studio_config.h"
#include "nexus/ai/text_prompt_adapter.h"
#include "nexus/creative/voxel_world.h"
#include "nexus/creative/world_manipulator.h"
#include "nexus/generative/generative_pipeline.h"
#include "nexus/gameplay/arena_mode_registry.h"
#include "nexus/gameplay/arcade_physics.h"
#include "nexus/gameplay/arena_session_manager.h"
#include "nexus/gameplay/exercise_demo_pipeline.h"
#include "nexus/gameplay/fel_bridge_service.h"
#include "nexus/gameplay/fel_session_types.h"
#include "nexus/gameplay/fitness_data.h"
#include "nexus/gameplay/gameplay_application.h"
#include "nexus/gameplay/gameplay_manager.h"
#include "nexus/gameplay/hud_relay_service.h"
#include "nexus/gameplay/mode_runtime.h"
#include "nexus/gameplay/outcome_sport_mode.h"
#include "nexus/gameplay/prq_engine.h"
#include "nexus/gameplay/session_receipt_client.h"
#include "nexus/gameplay/surfing_mode.h"
#include "nexus/gameplay/throw_catch_physics.h"
#include "nexus/gameplay/voxel_command_parser.h"
#include "nexus/physics/physics_world.h"

#include <cstdio>
#include <cstdlib>
#include <array>
#include <chrono>
#include <cmath>
#include <cstdlib>
#include <cstdint>
#include <filesystem>
#include <fstream>
#include <fstream>
#include <string>
#include <thread>
#include <vector>

#if defined(__unix__) || defined(__APPLE__)
#include <netinet/in.h>
#include <sys/socket.h>
#endif
#include <unistd.h>

namespace {

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

void require(bool condition, const std::string& message) {
  require(condition, message.c_str());
}

void requireNear(float actual, float expected, float tolerance, const char* message) {
  require(std::fabs(actual - expected) <= tolerance, message);
}

void removeTreeBestEffort(const std::filesystem::path& root) {
  for (int attempt = 0; attempt < 5; ++attempt) {
    std::error_code ec;
    std::filesystem::remove_all(root, ec);
    if (!ec || !std::filesystem::exists(root)) {
      return;
    }
    std::this_thread::sleep_for(std::chrono::milliseconds(10 * (attempt + 1)));
  }
}

#if defined(__unix__) || defined(__APPLE__)
class SingleResponseHttpServer {
public:
  explicit SingleResponseHttpServer(int statusCode) {
    const int serverSocket = ::socket(AF_INET, SOCK_STREAM, 0);
    require(serverSocket >= 0, "create receipt test HTTP socket");

    const int reuse = 1;
    (void)::setsockopt(serverSocket, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));

    sockaddr_in address{};
    address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
    address.sin_port = 0;
    require(::bind(serverSocket, reinterpret_cast<sockaddr*>(&address), sizeof(address)) == 0,
            "bind receipt test HTTP socket");
    require(::listen(serverSocket, 1) == 0, "listen receipt test HTTP socket");

    socklen_t length = sizeof(address);
    require(::getsockname(serverSocket, reinterpret_cast<sockaddr*>(&address), &length) == 0,
            "read receipt test HTTP socket port");
    m_port = ntohs(address.sin_port);

    m_thread = std::thread([serverSocket, statusCode]() {
      const int clientSocket = ::accept(serverSocket, nullptr, nullptr);
      if (clientSocket >= 0) {
        char requestBuffer[2048];
        (void)::recv(clientSocket, requestBuffer, sizeof(requestBuffer), 0);
        const std::string body = "{}";
        const std::string response = "HTTP/1.1 " + std::to_string(statusCode) +
                                     " NEXUS\r\nContent-Type: application/json\r\n"
                                     "Content-Length: " +
                                     std::to_string(body.size()) +
                                     "\r\nConnection: close\r\n\r\n" + body;
        (void)::send(clientSocket, response.data(), response.size(), 0);
        (void)::close(clientSocket);
      }
      (void)::close(serverSocket);
    });
  }

  ~SingleResponseHttpServer() {
    if (m_thread.joinable()) {
      m_thread.join();
    }
  }

  [[nodiscard]] auto url() const -> std::string {
    return "http://127.0.0.1:" + std::to_string(m_port) + "/api/games/session";
  }

private:
  std::uint16_t m_port{0};
  std::thread m_thread;
};

[[nodiscard]] auto curlAvailable() -> bool {
  return std::system("command -v curl >/dev/null 2>&1") == 0;
}
#endif

void fitness_data_snapshots_are_thread_safe() {
  nexus::gameplay::ThreadSafeFitnessData fitness;
  fitness.update({0.75F, 0.5F, 0.25F}, {0.8F, 0.9F, 1});

  const auto snapshot = fitness.read_view().snapshot();
  require(snapshot.revision == 1, "fitness revision increments");
  require(snapshot.frc.mobilityScore == 0.75F, "frc mobility stored");
  require(snapshot.iap.breathPhase == 1, "iap breath phase stored");
  require(snapshot.frcComposite > 0.4F, "frc composite computed");
  require(snapshot.powerReadiness > 0.0F, "power readiness computed");
}

void fitness_partial_updates_preserve_other_metrics() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);

  auto response = gameplay.handleGameplayCommand(
      "fel.fitness.update",
      {
          {"frc_mobility", 0.4F},
          {"frc_active_range", 0.5F},
          {"frc_control", 0.6F},
          {"iap_engagement", 0.7F},
          {"iap_confidence", 0.8F},
          {"breath_phase", 1},
      },
      "fitness_full");
  require(response.status == "ok", "full fitness update ok");

  response = gameplay.handleGameplayCommand(
      "fel.fitness.update_frc",
      {{"frc_mobility", 1.0F}},
      "fitness_frc");
  require(response.status == "ok", "partial frc update ok");

  const auto snapshot = gameplay.fitness_data().snapshot();
  require(snapshot.revision == 2, "partial frc increments revision");
  require(snapshot.frc.mobilityScore == 1.0F, "frc mobility updated");
  require(snapshot.frc.activeRangeScore == 0.5F, "frc range preserved");
  require(snapshot.iap.engagementScore == 0.7F, "iap preserved after frc-only update");

  response = gameplay.handleGameplayCommand(
      "fel.fitness.update_iap",
      {{"iap_confidence", 0.2F}, {"breath_phase", -1}},
      "fitness_iap");
  require(response.status == "ok", "partial iap update ok");
  require(gameplay.fitness_data().snapshot().iap.confidence == 0.2F, "iap confidence updated");
  require(gameplay.fitness_data().snapshot().iap.breathPhase == -1, "iap breath phase updated");
  require(gameplay.fitness_data().snapshot().frc.mobilityScore == 1.0F,
          "frc preserved after iap-only update");
}

void fitness_values_are_clamped_and_invalid_params_rejected() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);

  auto response = gameplay.handleGameplayCommand(
      "fel.fitness.update",
      {
          {"frc_mobility", 9.0F},
          {"frc_active_range", -1.0F},
          {"frc_control", 0.5F},
          {"iap_engagement", 2.0F},
          {"iap_confidence", 0.5F},
          {"breath_phase", 99},
      },
      "fitness_clamp");
  require(response.status == "ok", "clamped fitness update ok");

  const auto snapshot = gameplay.fitness_data().snapshot();
  require(snapshot.frc.mobilityScore == 1.0F, "frc mobility clamped to 1");
  require(snapshot.frc.activeRangeScore == 0.0F, "frc range clamped to 0");
  require(snapshot.iap.engagementScore == 1.0F, "iap engagement clamped to 1");
  require(snapshot.iap.breathPhase == 1, "breath phase clamped to 1");

  response = gameplay.handleGameplayCommand(
      "fel.fitness.update",
      {{"frc_mobility", "invalid"}},
      "fitness_bad_type");
  require(response.status == "error", "invalid fitness param rejected");
}

void voxel_parser_maps_fel_creative_commands() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::VoxelCommandParser parser(manipulator, world);

  auto result = parser.apply_command(
      "fel.creative.raise_terrain",
      {{"position", {0, 0, 0}}, {"radius", 1}, {"height", 2}, {"material", 9}});

  require(result.isOk(), "raise terrain command applies");
  require(result.value().contains("creative"), "raise terrain returns creative envelope");
  require(result.value().contains("agent_summary"), "raise terrain returns agent summary");
  require(result.value()["status"].get<std::string>() == "applied", "raise terrain status applied");
  require(result.value()["creative"]["chunk_count"].is_number(), "creative chunk count present");
  require(result.value()["creative"]["region_bounds"]["min"].is_array(),
          "creative region bounds present");
  require(world.voxelAt({0, 0, 0}).material == 9, "center terrain material set");
  require(world.voxelAt({1, 1, 1}).solid, "raised terrain filled");
}

void voxel_parser_lowers_terrain() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::VoxelCommandParser parser(manipulator, world);

  require(parser.apply_command(
              "fel.creative.raise_terrain",
              {{"position", {0, 0, 0}}, {"radius", 0}, {"height", 3}, {"material", 4}})
              .isOk(),
          "seed raised terrain");

  auto result = parser.apply_command(
      "fel.creative.lower_terrain",
      {{"position", {0, 2, 0}}, {"radius", 0}, {"height", 2}, {"material", 4}});
  require(result.isOk(), "lower terrain command applies");
  require(!world.voxelAt({0, 2, 0}).solid, "top voxel cleared");
  require(!world.voxelAt({0, 1, 0}).solid, "middle voxel cleared");
  require(world.voxelAt({0, 0, 0}).solid, "base voxel remains");
}

void voxel_parser_flattens_terrain_above_target() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::VoxelCommandParser parser(manipulator, world);

  require(parser.apply_command(
              "fel.creative.raise_terrain",
              {{"position", {0, 0, 0}}, {"radius", 0}, {"height", 3}, {"material", 2}})
              .isOk(),
          "seed mound");

  auto result = parser.apply_command(
      "fel.creative.flatten_terrain",
      {{"position", {0, 0, 0}}, {"radius", 0}, {"material", 5}});
  require(result.isOk(), "flatten terrain command applies");
  require(!world.voxelAt({0, 1, 0}).solid, "flatten clears above target");
  require(!world.voxelAt({0, 2, 0}).solid, "flatten clears peak");
  require(world.voxelAt({0, 0, 0}).material == 5, "flatten sets target layer material");
}

void voxel_parser_paints_existing_solids_only() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::VoxelCommandParser parser(manipulator, world);

  require(parser.apply_command(
              "fel.creative.raise_terrain",
              {{"position", {0, 0, 0}}, {"radius", 1}, {"height", 1}, {"material", 3}})
              .isOk(),
          "seed terrain for paint");

  auto result = parser.apply_command(
      "fel.creative.paint_terrain",
      {{"position", {0, 0, 0}}, {"radius", 1}, {"material", 8}});
  require(result.isOk(), "paint terrain command applies");
  require(world.voxelAt({0, 0, 0}).material == 8, "center voxel painted");
  require(world.voxelAt({1, 0, 0}).material == 8, "neighbor solid painted");
  require(!world.voxelAt({1, 1, 0}).solid, "air above paint radius stays empty");
}

void voxel_parser_passes_through_set_voxels_and_fill_region() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::VoxelCommandParser parser(manipulator, world);

  auto setResult = parser.apply_command(
      "fel.creative.set_voxels",
      {{"voxels",
        {{{"position", {2, 0, 2}}, {"voxel", {{"material", 11}, {"solid", true}}}}}}});
  require(setResult.isOk(), "set_voxels passthrough");
  require(world.voxelAt({2, 0, 2}).material == 11, "set_voxels applied");

  auto fillResult = parser.apply_command(
      "fel.creative.fill_region",
      {{"min", {0, 0, 0}},
       {"max", {0, 0, 0}},
       {"voxel", {{"material", 6}, {"solid", true}}}});
  require(fillResult.isOk(), "fill_region passthrough");
  require(world.voxelAt({0, 0, 0}).material == 6, "fill_region applied");
}

void voxel_parser_rejects_invalid_creative_params() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::VoxelCommandParser parser(manipulator, world);

  require(parser.apply_command("fel.creative.raise_terrain", {{"radius", 1}}).isErr(),
          "missing position rejected");
  require(parser.apply_command("fel.creative.unsupported", {{"position", {0, 0, 0}}}).isErr(),
          "unsupported creative command rejected");
}

void gameplay_session_state_query_returns_coherent_payload() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  gameplay.handleGameplayCommand(
      "fel.fitness.update",
      {{"frc_mobility", 0.5F},
       {"frc_active_range", 0.5F},
       {"frc_control", 0.5F},
       {"iap_engagement", 0.5F},
       {"iap_confidence", 0.5F},
       {"breath_phase", 0}},
      "fitness_state");

  nexus::ai::AgentResponse okResponse{"cmd_ok", "ok", {}, {}};
  nexus::ai::AgentResponse errorResponse{"cmd_err", "error", {}, "bad command"};
  const std::vector<nexus::ai::AgentResponse> agentResponses{okResponse, errorResponse};
  gameplay.update(0.5, physics, agentResponses);

  const auto response =
      gameplay.handleGameplayQuery("fel.query.get_session_state", {}, "session_query");
  require(response.status == "ok", "session state query ok");
  require(response.payload["fitness"]["revision"].get<std::uint64_t>() == 1,
          "session state includes fitness revision");
  require(response.payload["fitness"]["frc_composite"].is_number(),
          "session state includes frc composite");
  require(response.payload["throw_catch"]["last_pulse"]["impulse_y"].is_number(),
          "session state includes throw pulse envelope");
  require(response.payload["agent"]["processed_messages"].get<std::size_t>() == 2,
          "session state includes processed agent messages");
  require(response.payload["agent"]["latest_errors"].get<std::size_t>() == 1,
          "session state includes agent error count");

  physics.shutdown();
}

void engine_tick_runs_physics_before_gameplay_update() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::ai::CommandRouter router;
  nexus::ai::AgentServer server;
  nexus::physics::PhysicsWorld physics;

  require(router.init(&manipulator, &world).isOk(), "router init");
  router.setGameplayHandler(&gameplay);
  require(server.init(&router).isOk(), "server init");
  require(physics.init({}).isOk(), "physics init");

  const std::string fitnessCommand = R"json({
    "type": "command",
    "id": "fitness_tick",
    "payload": {
      "command": "fel.fitness.update",
      "params": {
        "frc_mobility": 1.0,
        "frc_active_range": 1.0,
        "frc_control": 1.0,
        "iap_engagement": 1.0,
        "iap_confidence": 1.0,
        "breath_phase": 1
      }
    }
  })json";

  require(server.receiveJson(fitnessCommand).isOk(), "receive fitness command");
  const auto agentResponses = server.processQueuedCommands(8);

  // IntegrationManual tick order: agent drain -> physics step -> gameplay update.
  require(physics.pendingIntentCount() == 0, "no intents before first gameplay tick");
  physics.step(1.0 / 60.0);
  require(physics.pendingIntentCount() == 0, "physics step before gameplay consumes nothing");
  gameplay.update(0.5, physics, agentResponses);
  require(physics.pendingIntentCount() == 1, "gameplay update queues throw intent");
  require(gameplay.fitness_data().snapshot().revision == 1, "fitness applied before gameplay");

  physics.step(1.0 / 60.0);
  require(physics.pendingIntentCount() == 0, "next-frame physics consumes gameplay intent");
  require(physics.lastConsumedIntents().size() == 1, "throw intent consumed on physics step");

  server.shutdown();
  router.shutdown();
  physics.shutdown();
}

void gameplay_update_drains_agent_commands_before_throw_catch() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::ai::CommandRouter router;
  nexus::ai::AgentServer server;
  nexus::physics::PhysicsWorld physics;

  require(router.init(&manipulator, &world).isOk(), "router init");
  router.setGameplayHandler(&gameplay);
  require(server.init(&router).isOk(), "server init");
  require(physics.init({}).isOk(), "physics init");

  const std::string fitnessCommand = R"json({
    "type": "command",
    "id": "fitness_001",
    "payload": {
      "command": "fel.fitness.update",
      "params": {
        "frc_mobility": 1.0,
        "frc_active_range": 1.0,
        "frc_control": 1.0,
        "iap_engagement": 1.0,
        "iap_confidence": 1.0,
        "breath_phase": 1
      }
    }
  })json";

  require(server.receiveJson(fitnessCommand).isOk(), "receive fitness command");
  const auto agentResponses = server.processQueuedCommands(8);
  gameplay.update(0.5, physics, agentResponses);

  require(gameplay.stats().processedAgentMessages == 1, "agent command processed in update");
  require(gameplay.fitness_data().snapshot().revision == 1, "fitness command updated state");
  require(gameplay.throw_catch_state().throwsTriggered == 1, "throw-catch advanced after fitness");
  require(gameplay.throw_catch_state().powerMultiplier > 1.5F, "fitness affects throw power");
  require(gameplay.throw_catch_state().catchRadiusNormalized > 0.8F,
          "high control expands catch radius");
  require(physics.pendingIntentCount() == 1, "throw phase queued physics intent");
  physics.step(1.0 / 60.0);
  require(physics.pendingIntentCount() == 0, "throw intent consumed on step");
  require(physics.lastConsumedIntents().size() == 1, "throw intent recorded");
  require(physics.lastConsumedIntents().front().kind ==
              nexus::physics::PhysicsIntentKind::kApplyImpulse,
          "throw intent applies impulse");
  require(physics.lastConsumedIntents().front().impulseOrVelocity.y > 11.0F,
          "throw impulse scales with fitness power and breath boost");

  server.shutdown();
  router.shutdown();
  physics.shutdown();
}

void arena_mode_registry_lists_nineteen_modes() {
  require(nexus::gameplay::ArenaModeRegistry::allModes().size() == 19,
          "arena registry exposes 19 modes");
  const auto dunk = nexus::gameplay::ArenaModeRegistry::find("basketball_dunk");
  require(dunk.has_value(), "basketball_dunk found");
  require(dunk->venueToken == "Venice_Beach_Court", "dunk venue token");
  require(dunk->nexusMeshPath.find(".nexusmesh.json") != std::string_view::npos,
          "dunk nexus mesh path");
  require(dunk->legacyUeMapAlias.find("/Game/FEL/Maps/") == 0, "dunk legacy ue alias");

  const auto splitDunk3D = nexus::gameplay::ArenaModeRegistry::find("basketball_dunk_3d");
  require(splitDunk3D.has_value(), "basketball_dunk_3d aliases to canonical dunk runtime");
  require(splitDunk3D->id == "basketball_dunk", "basketball_dunk_3d resolves to basketball_dunk");
  const auto irlDunk = nexus::gameplay::ArenaModeRegistry::find("basketball_dunk_irl");
  require(!irlDunk.has_value(), "IRL dunk bypasses C++ arena runtime");
}

void arena_mode_registry_production_modes_match_validate_script() {
  const auto production = nexus::gameplay::ArenaModeRegistry::productionModes();
  require(production.size() == nexus::gameplay::kProductionModeCount,
          "production mode count matches validate script");
  for (std::string_view expectedId : nexus::gameplay::kProductionModeIds) {
    const auto mode = nexus::gameplay::ArenaModeRegistry::find(expectedId);
    require(mode.has_value(), std::string("production mode registered: ") + std::string(expectedId));
    require(mode->releaseState == nexus::gameplay::ArenaReleaseState::kProduction,
            std::string("production release state: ") + std::string(expectedId));
  }
}

void gameplay_manager_evaluates_volleyball_outcome() {
  using nexus::gameplay::GameplayManager;
  using nexus::gameplay::MatchOutcome;
  require(GameplayManager::evaluateVolleyballOutcome(25, 20) == MatchOutcome::kWin,
          "volleyball win at 25");
  require(GameplayManager::evaluateVolleyballOutcome(20, 18) == MatchOutcome::kDraw,
          "volleyball in-progress draw");
}

void outcome_sport_mode_mechanics_and_session_scores() {
  using nexus::gameplay::GameplayManager;
  using nexus::gameplay::MatchOutcome;
  using nexus::gameplay::OutcomeSportMode;

  OutcomeSportMode tennis;
  tennis.reset("tennis");
  for (int i = 0; i < 2; ++i) {
    require(tennis.pulse({{"success", true}, {"timing", 0.9F}, {"shot_type", "ace"}}).isOk(),
            "tennis ace pulse ok");
  }
  require(tennis.sessionScoreInput().playerSets >= 1, "tennis ace closes first set");
  require(!tennis.isMatchComplete(), "tennis match continues after one set");

  OutcomeSportMode golf;
  golf.reset("golf");
  require(golf.sessionScoreInput().parStrokes == 36, "golf nine-hole par is 36");
  for (int i = 0; i < 9; ++i) {
    require(golf.pulse({{"success", true}, {"timing", 0.93F}, {"club", "putt"}}).isOk(),
            "golf putt pulse ok");
  }
  require(golf.isMatchComplete(), "golf completes after nine holes");
  require(GameplayManager::evaluateGolfOutcome(golf.sessionScoreInput().playerStrokes,
                                               golf.sessionScoreInput().parStrokes) !=
              MatchOutcome::kLoss,
          "golf birdie-capable round is not a loss vs nine-hole par");

  OutcomeSportMode basketball;
  basketball.reset("basketball_3v3");
  require(basketball.pulse({{"success", true},
                            {"timing", 0.95F},
                            {"shot_type", "three_pointer"}})
              .isOk(),
          "basketball three-pointer pulse ok");
  require(basketball.stateJson().value("player_metric", 0) >= 4,
          "three-pointer awards bonus points");

  OutcomeSportMode volleyball;
  volleyball.reset("volleyball");
  require(volleyball.pulse({{"success", true},
                              {"timing", 0.95F},
                              {"rally_type", "ace_serve"}})
              .isOk(),
          "volleyball ace serve pulse ok");
  require(volleyball.stateJson().value("player_metric", 0) == 2,
          "ace serve awards two rally points");

  OutcomeSportMode baseball;
  baseball.reset("baseball");
  require(baseball.pulse({{"success", true},
                          {"timing", 0.93F},
                          {"play_type", "home_run"}})
              .isOk(),
          "baseball home run pulse ok");
  require(baseball.stateJson().value("player_metric", 0) >= 4,
          "home run awards four runs at elite timing");
  require(baseball.pulse({{"success", false}, {"play_type", "strikeout"}}).isOk(),
          "baseball strikeout pulse ok");
  require(baseball.stateJson().value("inning", 0) >= 1,
          "baseball seeds inning 1 on reset");

  OutcomeSportMode football;
  football.reset("football");
  require(football.pulse({{"success", true}, {"play_type", "touchdown"}}).isOk(),
          "football touchdown pulse ok");
  require(football.pulse({{"success", true}, {"play_type", "field_goal"}}).isOk(),
          "football field goal pulse ok");
  require(football.pulse({{"success", false}, {"play_type", "turnover"}}).isOk(),
          "football turnover pulse ok");
  require(football.stateJson().value("player_metric", 0) >= 1,
          "touchdown increments player TD metric");

  OutcomeSportMode soccer;
  soccer.reset("soccer");
  require(soccer.pulse({{"success", true}, {"shot_type", "penalty"}}).isOk(),
          "soccer penalty goal pulse ok");
  require(soccer.pulse({{"success", false}, {"shot_type", "penalty"}}).isOk(),
          "soccer penalty miss pulse ok");
  require(soccer.stateJson().value("player_metric", 0) == 1,
          "penalty goal increments player goals");
  require(soccer.stateJson().value("opponent_metric", 0) == 1,
          "penalty miss increments opponent goals");
  require(soccer.stateJson().value("win_target", 0) == 5,
          "soccer win target is five goals");
  require(soccer.stateJson().value("penalty_round", 0) == 2,
          "two penalty pulses tracked");
}

void soccer_penalty_validate_only_integration() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  const auto mode = nexus::gameplay::ArenaModeRegistry::find("soccer");
  require(mode.has_value(), "soccer mode registered");
  require(mode->venueToken == "Soccer_Stadium", "soccer uses soccer stadium");
  require(mode->nexusMeshPath.find("soccer_stadium") != std::string::npos,
          "soccer bundled stadium pitch mesh");

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "soccer"}, {"user_id", "flagship_soccer"}},
              "soccer_start")
              .status == "ok",
          "soccer session starts");

  for (int i = 0; i < 12; ++i) {
    if (gameplay.mode_runtime().shouldAutoEndSession()) {
      break;
    }
    const bool playerShot = (i % 2) == 0;
    const auto pulse = gameplay.handleGameplayCommand(
        "fel.sport.pulse",
        {{"success", playerShot},
         {"timing", playerShot ? 0.9F : 0.35F},
         {"shot_type", "penalty"}},
        "soccer_penalty_pulse");
    require(pulse.status == "ok", "soccer penalty pulse ok");
    gameplay.update(0.05, physics, {});
  }

  const auto state =
      gameplay.handleGameplayQuery("fel.query.get_mode_state", {}, "soccer_state");
  require(state.status == "ok", "soccer mode state ok");
  require(state.payload["outcome_sport"]["win_target"].get<int>() == 5,
          "soccer HUD exposes win target");
  require(state.payload["outcome_sport"]["shot_type"].get<std::string>() == "penalty",
          "soccer shot type is penalty");
  require(gameplay.mode_runtime().shouldAutoEndSession(), "soccer match completes at five goals");

  const auto end = gameplay.handleGameplayCommand(
      "fel.arena.end_session", {{"use_live_scores", true}}, "soccer_end");
  require(end.status == "ok", "soccer session ends with live scores");
  require(end.payload.contains("outcome"), "soccer outcome present");

  physics.shutdown();
}

void karate_h2h_sport_pulse_hp_combat() {
  using nexus::gameplay::GameplayManager;
  using nexus::gameplay::MatchOutcome;
  using nexus::gameplay::OutcomeSportMode;

  OutcomeSportMode karate;
  karate.reset("karate_h2h");
  require(karate.stateJson().value("player_score", 0.0F) == 100.0F, "karate player HP seed");
  require(karate.stateJson().value("opponent_score", 0.0F) == 100.0F, "karate opponent HP seed");
  require(karate.pulse({{"success", true}, {"timing", 0.9F}, {"action", "heavy_strike"}}).isOk(),
          "karate heavy strike pulse ok");
  require(karate.stateJson().value("opponent_score", 100.0F) < 100.0F,
          "heavy strike damages opponent HP");
  require(karate.pulse({{"success", true}, {"timing", 0.88F}, {"action", "counter"}}).isOk(),
          "karate counter pulse ok");

  const auto input = karate.sessionScoreInput();
  require(input.opponentHp < 100.0F, "counter chain reduced opponent HP");
  require(!karate.isMatchComplete(), "karate duel continues while both fighters have HP");

  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "karate_h2h"}, {"user_id", "karate_h2h_user"}},
              "h2h_start")
              .status == "ok",
          "karate h2h session starts");

  const auto initialState =
      gameplay.handleGameplayQuery("fel.query.get_mode_state", {}, "h2h_state");
  require(initialState.status == "ok", "karate h2h mode state ok");
  require(initialState.payload["outcome_sport"]["player_score"].get<float>() == 100.0F,
          "player HP starts at 100");
  require(initialState.payload["outcome_sport"]["opponent_score"].get<float>() == 100.0F,
          "opponent HP starts at 100");

  auto strike = gameplay.handleGameplayCommand(
      "fel.sport.pulse",
      {{"success", true}, {"timing", 0.92F}, {"action", "heavy_strike"}},
      "h2h_strike");
  require(strike.status == "ok", "karate h2h heavy strike pulse ok");
  require(strike.payload["outcome_sport"]["opponent_score"].get<float>() < 100.0F,
          "heavy strike reduces opponent HP in session");

  const auto hud = gameplay.handleGameplayQuery("fel.hud.poll", {}, "h2h_hud");
  require(hud.status == "ok", "karate h2h hud poll ok");
  require(hud.payload["payload"]["mode_id"].get<std::string>() == "karate_h2h",
          "h2h mode id on hud");
  require(hud.payload["payload"]["mode_state"]["outcome_sport"].is_object(),
          "outcome_sport nested on hud");

  physics.shutdown();
}

void arena_session_end_dispatches_receipt_and_bridge_messages() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  auto start = gameplay.handleGameplayCommand(
      "fel.arena.start_session",
      {{"mode_id", "basketball_h2h"}, {"user_id", "test_user"}},
      "arena_start");
  require(start.status == "ok", "arena session starts");

  auto end = gameplay.handleGameplayCommand(
      "fel.arena.end_session",
      {{"player_score", 21.0F}, {"opponent_score", 18.0F}},
      "arena_end");
  require(end.status == "ok", "arena session ends");
  require(end.payload["outcome"].get<std::string>() == "win", "win outcome");

  const auto receipts =
      gameplay.handleGameplayQuery("fel.query.get_pending_session_receipts", {}, "receipts");
  require(receipts.status == "ok", "receipt query ok");
  require(receipts.payload["receipts"].size() == 1, "one session receipt queued");
  const auto& receipt = receipts.payload["receipts"][0];
  require(receipt.contains("mode_id"), "receipt has mode_id");
  require(receipt.contains("score"), "receipt has score");
  require(receipt.contains("telemetry"), "receipt has telemetry envelope");

  const auto bridge =
      gameplay.handleGameplayQuery("fel.query.get_bridge_outbound", {}, "bridge");
  require(bridge.status == "ok", "bridge query ok");
  require(bridge.payload["messages"].size() >= 2, "bridge queued vault + match messages");

  physics.shutdown();
}

void dunk_contest_lifecycle_generates_win_receipt() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "basketball_dunk"}, {"user_id", "dunk_player"}},
              "dunk_start")
              .status == "ok",
          "dunk session starts");

  for (int dunk = 0; dunk < 12; ++dunk) {
    if (gameplay.arena_session().state().phase ==
        nexus::gameplay::ArenaSessionPhase::kEnded) {
      break;
    }
    const auto charge =
        gameplay.handleGameplayCommand("fel.dunk.charge_begin", {}, "charge");
    if (charge.status != "ok") {
      break;
    }
    require(gameplay.handleGameplayCommand("fel.dunk.charge_release", {{"power", 0.95F}}, "release")
                .status == "ok",
            "charge release");
    for (int step = 0; step < 12; ++step) {
      gameplay.update(0.05, physics, {});
    }
    require(gameplay.handleGameplayCommand("fel.dunk.apex_tap", {}, "apex").status == "ok",
            "apex tap");
    for (int step = 0; step < 20; ++step) {
      gameplay.update(0.05, physics, {});
    }
  }

  const auto arena =
      gameplay.handleGameplayQuery("fel.query.get_arena_state", {}, "arena_state");
  require(arena.status == "ok", "arena state query ok");
  require(arena.payload["player_score"].get<float>() >= 21.0F ||
              arena.payload.value("last_result", nlohmann::json::object()).contains("outcome"),
          "dunk reached win threshold or auto-ended");

  const auto receipts =
      gameplay.handleGameplayQuery("fel.query.get_pending_session_receipts", {}, "dunk_receipts");
  require(receipts.status == "ok", "dunk receipt query ok");
  require(receipts.payload["receipts"].size() >= 1, "dunk session receipt queued");

  physics.shutdown();
}

void arena_pause_resume_preserves_session() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "basketball_dunk"}, {"user_id", "pause_user"}},
              "pause_start")
              .status == "ok",
          "session starts");

  require(gameplay.handleGameplayCommand("fel.arena.pause_session", {}, "pause").status == "ok",
          "session pauses");
  require(gameplay.arena_session().state().paused, "paused flag set");

  require(gameplay.handleGameplayCommand("fel.arena.resume_session", {}, "resume").status == "ok",
          "session resumes");
  require(!gameplay.arena_session().state().paused, "paused flag cleared");
}

void session_receipt_flush_keeps_queue_when_http_disabled() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "basketball_dunk"}, {"user_id", "flush_user"}},
              "flush_start")
              .status == "ok",
          "session starts");
  require(gameplay.handleGameplayCommand(
              "fel.arena.end_session",
              {{"player_score", 21.0F}, {"opponent_score", 10.0F}},
              "flush_end")
              .status == "ok",
          "session ends");

  const auto flush = gameplay.handleGameplayCommand(
      "fel.arena.flush_receipts", {{"persist_to_disk", true}}, "flush");
  require(flush.status == "ok", "flush command ok");
  require(flush.payload["delivered"].get<std::size_t>() >= 1, "receipt delivered to disk queue");
  require(!flush.payload["queue_directory"].get<std::string>().empty(), "queue directory returned");

  const auto receipts =
      gameplay.handleGameplayQuery("fel.query.get_pending_session_receipts", {}, "flush_receipts");
  require(receipts.payload["receipts"].size() == 0, "receipt cleared after successful flush");

  const auto configFlush = gameplay.handleGameplayCommand(
      "fel.arena.flush_receipts",
      {{"persist_to_disk", false}, {"http_enabled", false}, {"use_stub_http", false}},
      "flush_config");
  require(configFlush.status == "ok", "flush config command ok");
  require(!configFlush.payload["http_enabled"].get<bool>(), "flush command applies http_enabled");
  require(!configFlush.payload["use_stub_http"].get<bool>(), "flush command applies use_stub_http");
}

void session_receipt_disk_keyed_by_session_id() {
  const auto tempDir = std::filesystem::temp_directory_path() /
                       ("fel_receipt_dedup_test_" + std::to_string(getpid()));
  removeTreeBestEffort(tempDir);
  std::error_code ec;
  std::filesystem::create_directories(tempDir, ec);

  nexus::gameplay::SessionReceiptClient client(
      {.queueDirectory = tempDir.string(), .persistToDisk = true});

  nlohmann::json receipt = {
      {"mode_id", "karate_endless"},
      {"score", 42},
      {"telemetry", {{"session_id", "abc123session"}}},
  };

  client.enqueue(receipt);
  const auto first = client.flush();
  require(first.delivered == 1, "first flush delivers receipt");

  const auto receiptPath = tempDir / "abc123session.json";
  require(std::filesystem::exists(receiptPath), "receipt file keyed by telemetry.session_id");

  receipt["score"] = 99;
  client.enqueue(receipt);
  const auto second = client.flush();
  require(second.delivered == 1, "re-flush delivers updated receipt");

  std::size_t jsonFileCount = 0;
  for (const auto& entry : std::filesystem::directory_iterator(tempDir)) {
    if (entry.path().extension() == ".json") {
      ++jsonFileCount;
    }
  }
  require(jsonFileCount == 1, "re-flush overwrites — one file per session_id");

  std::ifstream input(receiptPath);
  const nlohmann::json loaded = nlohmann::json::parse(input);
  require(loaded["score"].get<int>() == 99, "re-flush overwrites receipt contents");

  removeTreeBestEffort(tempDir);
}

void hud_poll_returns_tick_frame_payload() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  require(gameplay.handleGameplayCommand(
              "fel.fitness.update",
              {{"frc_mobility", 0.9F},
               {"frc_active_range", 0.8F},
               {"frc_control", 0.7F},
               {"iap_engagement", 0.6F},
               {"iap_confidence", 0.5F},
               {"breath_phase", 1}},
              "hud_fitness")
              .status == "ok",
          "hud fitness update ok");
  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "basketball_dunk"}, {"user_id", "hud_user"}},
              "hud_start")
              .status == "ok",
          "session starts");

  gameplay.update(0.5, physics, {});

  const auto hud = gameplay.handleGameplayQuery("fel.hud.poll", {}, "hud_poll");
  require(hud.status == "ok", "hud poll ok");
  require(hud.payload["type"].get<std::string>() == "fel.hud.frame", "hud frame type");
  require(hud.payload["payload"]["mode_id"].get<std::string>() == "basketball_dunk",
          "hud mode id");
  require(hud.payload["payload"]["session_state"].get<std::string>() == "active",
          "hud session state");
  require(hud.payload["payload"]["throw_catch"]["catch_radius_normalized"].is_number(),
          "hud throw catch radius");
  require(hud.payload["payload"]["fitness"]["power_readiness"].is_number(),
          "hud fitness readiness");
  requireNear(hud.payload["payload"]["prq"].get<float>(), 60.75F, 0.01F,
              "hud measured prq");
  require(hud.payload["payload"]["prq_grade"].get<std::string>() == "PRIMED",
          "hud measured prq grade");
  requireNear(hud.payload["payload"]["neural_drive"].get<float>(), 52.5F, 0.01F,
              "hud measured neural drive");
  requireNear(hud.payload["payload"]["fitness"]["prq_score"].get<float>(), 60.75F, 0.01F,
              "hud fitness embeds measured prq");
  require(hud.payload["payload"]["mode_state"].contains("dunk"), "hud mode_state dunk nested");
  requireNear(hud.payload["payload"]["mode_state"]["prq"].get<float>(), 60.75F, 0.01F,
              "hud mode_state uses measured prq");
  requireNear(hud.payload["payload"]["mode_state"]["arcade_physics"]["critical_hit_chance"].get<float>(),
              0.224F, 0.001F, "hud mode_state physics uses measured prq");

  physics.shutdown();
}

void bridge_map_loaded_uses_measured_prq() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);

  require(gameplay.handleGameplayCommand(
              "fel.fitness.update",
              {{"frc_mobility", 0.9F},
               {"frc_active_range", 0.8F},
               {"frc_control", 0.7F},
               {"iap_engagement", 0.6F},
               {"iap_confidence", 0.5F},
               {"breath_phase", 1}},
              "bridge_fitness")
              .status == "ok",
          "bridge fitness update ok");
  const auto mapLoaded = gameplay.handleGameplayCommand(
      "fel.bridge.broadcast_map_loaded",
      {{"map", "Venice"}, {"mode_id", "basketball_dunk"}},
      "bridge_map_loaded");
  require(mapLoaded.status == "ok", "map loaded bridge command ok");

  const auto messages = gameplay.fel_bridge().outboundMessages();
  require(!messages.empty(), "map loaded bridge message queued");
  const auto& payload = messages.back();
  require(payload["type"].get<std::string>() == "map_loaded", "map loaded payload type");
  requireNear(payload["prq"].get<float>(), 60.75F, 0.01F,
              "map loaded bridge uses measured prq");
}

void karate_mode_input_strike_advances_wave() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "karate_endless"}, {"user_id", "karate_user"}},
              "karate_start")
              .status == "ok",
          "karate session starts");

  gameplay.update(0.1, physics, {});

  auto strike = gameplay.handleGameplayCommand(
      "fel.arena.mode_input", {{"action", "heavy_strike"}}, "karate_strike");
  require(strike.status == "ok", "karate mode_input strike ok");
  require(strike.payload.contains("wave"), "karate wave in response");

  for (int step = 0; step < 40; ++step) {
    auto hit = gameplay.handleGameplayCommand(
        "fel.arena.mode_input", {{"action", "heavy_strike"}}, "karate_hit");
    if (hit.status != "ok") {
      break;
    }
    gameplay.update(0.05, physics, {});
  }

  const auto modeState =
      gameplay.handleGameplayQuery("fel.query.get_mode_state", {}, "karate_state");
  require(modeState.status == "ok", "karate mode state ok");
  require(modeState.payload["karate"]["score"].get<int>() > 0, "karate score increased");

  physics.shutdown();
}

void mode_runtime_tracks_dunk_combo_metrics() {
  nexus::gameplay::ModeRuntime runtime;
  require(runtime.setMode("basketball_dunk").isOk(), "dunk mode set");
  require(runtime.handleCommand("fel.dunk.charge_begin", {}).isOk(), "charge");
  require(runtime.handleCommand("fel.dunk.charge_release", {{"power", 0.9F}}).isOk(), "release");
  for (int step = 0; step < 8; ++step) {
    runtime.update(0.05);
  }
  require(runtime.handleCommand("fel.dunk.apex_tap", {}).isOk(), "apex");
  for (int step = 0; step < 24; ++step) {
    runtime.update(0.05);
  }
  require(runtime.comboCount() >= 0, "combo count available");
  require(runtime.criticalCount() >= 0, "critical count available");
  require(runtime.modeSpecificPayload().contains("dunk_details"), "dunk details payload");
}

void mode_runtime_uses_measured_prq_for_state_and_physics() {
  nexus::gameplay::ThreadSafeFitnessData fitness;
  fitness.update({0.9F, 0.8F, 0.7F}, {0.6F, 0.5F, 1});

  nexus::gameplay::ModeRuntime runtime;
  require(runtime.setMode("basketball_dunk").isOk(), "measured dunk mode set");
  runtime.setFitnessSnapshot(fitness.snapshot());

  const auto state = runtime.stateJson();
  requireNear(state["prq"].get<float>(), 60.75F, 0.01F,
              "mode runtime state uses measured prq");
  require(state["prq_grade"].get<std::string>() == "PRIMED",
          "mode runtime state uses measured grade");
  requireNear(state["neural_drive"].get<float>(), 52.5F, 0.01F,
              "mode runtime state uses measured neural drive");
  requireNear(state["arcade_physics"]["hang_time_multiplier"].get<float>(), 2.3035F, 0.001F,
              "mode runtime physics uses measured prq");
  requireNear(state["arcade_physics"]["critical_hit_chance"].get<float>(), 0.224F, 0.001F,
              "mode runtime critical chance uses measured prq");

  require(runtime.handleCommand("fel.dunk.charge_begin", {}).isOk(), "measured charge");
  require(runtime.handleCommand("fel.dunk.charge_release", {{"power", 0.9F}}).isOk(),
          "measured release");
  for (int step = 0; step < 8; ++step) {
    runtime.update(0.05);
  }
  const auto apex = runtime.handleCommand("fel.dunk.apex_tap", {});
  require(apex.isOk(), "measured apex");
  requireNear(apex.value()["physics_feedback"]["hang_time_multiplier"].get<float>(), 2.3035F,
              0.001F, "dunk physics feedback uses measured prq");
}

void venue_volume_overlap_triggers_travel() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);

  auto registerVolume = gameplay.handleGameplayCommand(
      "fel.venue.register_volume",
      {{"venue_token", "Zen_Dojo"},
       {"mode_id", "karate_h2h"},
       {"min", {{"x", 0.0F}, {"y", 0.0F}, {"z", 0.0F}}},
       {"max", {{"x", 10.0F}, {"y", 5.0F}, {"z", 10.0F}}}},
      "register_volume");
  require(registerVolume.status == "ok", "venue volume registered");

  auto move = gameplay.handleGameplayCommand(
      "fel.venue.set_player_position",
      {{"x", 5.0F}, {"y", 1.0F}, {"z", 5.0F}},
      "move_player");
  require(move.status == "ok", "player moved into volume");

  require(std::string(gameplay.fel_bridge().activeVenueToken()) == "Zen_Dojo",
          "venue travel updates bridge");
  require(std::string(gameplay.fel_bridge().activeArenaGameModeId()) == "karate_h2h",
          "venue travel updates mode");
}

void exercise_demo_pipeline_maps_production_modes() {
  const auto mapping = nexus::gameplay::ExerciseDemoPipeline::mappingForMode("basketball_dunk");
  require(mapping.has_value(), "dunk demo mapping exists");
  require(mapping->moduleId == "mod2", "dunk maps to mod2");
  require(mapping->montagePath.find("mod2") != std::string::npos, "montage path contains mod2");
}

void physics_intent_queue_is_consumed_on_step() {
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  nexus::physics::PhysicsIntent impulse{};
  impulse.kind = nexus::physics::PhysicsIntentKind::kApplyImpulse;
  impulse.bodyId = 42;
  impulse.impulseOrVelocity = {0.0F, 10.0F, 0.0F};
  physics.queueIntent(impulse);

  require(physics.pendingIntentCount() == 1, "intent queued");
  physics.step(1.0 / 60.0);
  require(physics.pendingIntentCount() == 0, "intent consumed on step");
  require(physics.totalConsumedIntents() == 1, "intent counted");
  require(physics.lastConsumedIntents().size() == 1, "last consumed recorded");

  physics.shutdown();
}

void prq_engine_uses_baseline_until_fitness_metrics_arrive() {
  nexus::gameplay::FitnessSnapshot emptySnapshot;
  require(nexus::gameplay::PRQEngine::getScore() == 75.0F, "prq baseline default");
  require(nexus::gameplay::PRQEngine::getNeuralDrive() == 60.0F,
          "prq neural drive baseline default");
  require(nexus::gameplay::PRQEngine::getScore(emptySnapshot) == 75.0F,
          "prq baseline before fitness revision");
  require(nexus::gameplay::PRQEngine::getGrade() == nexus::gameplay::PRQGrade::kPrimed,
          "baseline prq grade primed");
}

void prq_engine_scores_measured_fitness_snapshot() {
  nexus::gameplay::ThreadSafeFitnessData fitness;
  fitness.update({0.9F, 0.8F, 0.7F}, {0.6F, 0.5F, 1});
  const auto snapshot = fitness.snapshot();

  requireNear(nexus::gameplay::PRQEngine::getScore(snapshot), 60.75F, 0.01F,
              "measured prq score blends frc/iap/readiness");
  requireNear(nexus::gameplay::PRQEngine::getNeuralDrive(snapshot), 52.5F, 0.01F,
              "measured neural drive blends iap/control/breath");
  require(nexus::gameplay::PRQEngine::getGrade(snapshot) ==
              nexus::gameplay::PRQGrade::kPrimed,
          "measured prq grade primed");

  fitness.update({0.0F, 0.0F, 0.0F}, {0.0F, 0.0F, -1});
  require(nexus::gameplay::PRQEngine::getGrade(fitness.snapshot()) ==
              nexus::gameplay::PRQGrade::kRecovering,
          "low measured prq grade recovering");
}

void arcade_physics_maps_prq_75() {
  const auto params =
      nexus::gameplay::ArcadePhysics::fromPRQ(75.0F, 60.0F);
  require(params.hangTimeMultiplier > 2.3F, "hang time multiplier at PRQ 75");
  require(params.explosiveFirstStep > 0.82F && params.explosiveFirstStep < 0.83F,
          "explosive first step at PRQ 75");
}

void dunk_contest_charge_release_scores() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);

  auto start = gameplay.handleGameplayCommand(
      "fel.arena.start_session",
      {{"mode_id", "basketball_dunk"}, {"user_id", "test"}},
      "dunk_start");
  require(start.status == "ok", "dunk session starts");

  auto charge = gameplay.handleGameplayCommand("fel.dunk.charge_begin", {}, "charge");
  if (charge.status != "ok") {
    std::fprintf(stderr, "charge error: %s\n", charge.error.c_str());
  }
  require(charge.status == "ok", "charge begin ok");

  auto release = gameplay.handleGameplayCommand(
      "fel.dunk.charge_release", {{"power", 0.8F}}, "release");
  require(release.status == "ok", "charge release ok");

  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");
  for (int frame = 0; frame < 120; ++frame) {
    gameplay.update(1.0 / 60.0, physics, {});
  }

  const auto modeState =
      gameplay.handleGameplayQuery("fel.query.get_mode_state", {}, "mode_state");
  require(modeState.status == "ok", "mode state query ok");
  require(modeState.payload.contains("dunk"), "dunk state present");
  require(modeState.payload["dunk"]["player_score"].get<int>() > 0, "dunk scored points");

  physics.shutdown();
}

void karate_endless_wave_spawns() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);

  auto start = gameplay.handleGameplayCommand(
      "fel.arena.start_session",
      {{"mode_id", "karate_endless"}, {"user_id", "test"}},
      "karate_start");
  require(start.status == "ok", "karate session starts");

  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");
  gameplay.update(0.1, physics, {});

  const auto modeState =
      gameplay.handleGameplayQuery("fel.query.get_mode_state", {}, "karate_state");
  require(modeState.status == "ok", "karate mode state ok");
  require(modeState.payload["karate"]["wave"].get<int>() >= 1, "wave 1 spawned");

  auto strike = gameplay.handleGameplayCommand(
      "fel.karate.action", {{"action", "heavy_strike"}}, "strike");
  require(strike.status == "ok", "karate strike ok");

  physics.shutdown();
}

void karate_endless_local_coop_wave_survival() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "karate_endless"}, {"user_id", "coop_user"}},
              "coop_start")
              .status == "ok",
          "coop session starts");

  auto configure = gameplay.handleGameplayCommand(
      "fel.karate.wave", {{"player_count", 2}}, "coop_configure");
  require(configure.status == "ok", "coop player_count configured");
  require(configure.payload["player_count"].get<int>() == 2, "two coop slots");
  require(configure.payload["multiplayer"].get<std::string>() == "local_coop",
          "local_coop framing");

  gameplay.update(0.1, physics, {});

  const auto modeState =
      gameplay.handleGameplayQuery("fel.query.get_mode_state", {}, "coop_state");
  require(modeState.status == "ok", "coop mode state ok");
  require(modeState.payload["karate"]["wave_state"].get<std::string>() == "combat",
          "combat wave state");
  require(modeState.payload["karate"]["players"].is_array(), "per-player state present");
  require(modeState.payload["karate"]["players"].size() == 2, "two player chips");

  auto strike = gameplay.handleGameplayCommand(
      "fel.karate.action", {{"action", "heavy_strike"}, {"player_index", 0}}, "coop_strike");
  require(strike.status == "ok", "coop strike ok");
  require(strike.payload["active_player"].get<int>() == 0, "active player tracked");

  auto perkReject = gameplay.handleGameplayCommand(
      "fel.karate.wave", {{"perk", "power"}}, "coop_perk_reject");
  require(perkReject.status == "error", "perk rejected outside intermission");

  for (int attempt = 0; attempt < 12; ++attempt) {
    auto clearStrike = gameplay.handleGameplayCommand(
        "fel.karate.action", {{"action", "heavy_strike"}, {"player_index", 0}}, "coop_clear");
    if (clearStrike.status != "ok") {
      break;
    }
    gameplay.update(0.05, physics, {});
  }

  bool inIntermission = false;
  nlohmann::json intermissionKarate;
  for (int step = 0; step < 40 && !inIntermission; ++step) {
    gameplay.update(0.05, physics, {});
    const auto poll =
        gameplay.handleGameplayQuery("fel.query.get_mode_state", {}, "coop_intermission_poll");
    require(poll.status == "ok", "coop intermission poll ok");
    intermissionKarate = poll.payload["karate"];
    if (intermissionKarate["wave_state"].get<std::string>() == "intermission") {
      inIntermission = true;
    }
  }
  require(inIntermission, "shrine intermission after wave clear");
  require(intermissionKarate["perk_available"].get<bool>(), "shrine perk available");

  auto perkClaim = gameplay.handleGameplayCommand(
      "fel.karate.wave", {{"perk", "power"}}, "coop_perk_claim");
  require(perkClaim.status == "ok", "shrine perk claimed in intermission");
  require(perkClaim.payload["perk_applied"].get<std::string>() == "power", "power perk applied");
  require(perkClaim.payload["perks"]["power"].get<bool>(), "power perk active");

  physics.shutdown();
}

void end_session_use_live_scores_resolves_mode_runtime() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "basketball_dunk"}, {"user_id", "live_score_user"}},
              "live_start")
              .status == "ok",
          "dunk session starts");

  require(gameplay.handleGameplayCommand("fel.dunk.charge_begin", {}, "charge").status == "ok",
          "charge begin");
  require(gameplay.handleGameplayCommand("fel.dunk.charge_release", {{"power", 0.9F}}, "release")
              .status == "ok",
          "charge release");
  for (int step = 0; step < 30; ++step) {
    gameplay.update(0.05, physics, {});
  }
  require(gameplay.handleGameplayCommand("fel.dunk.apex_tap", {}, "apex").status == "ok",
          "apex tap");
  for (int step = 0; step < 20; ++step) {
    gameplay.update(0.05, physics, {});
  }

  const auto end = gameplay.handleGameplayCommand(
      "fel.arena.end_session",
      {{"use_live_scores", true}, {"player_score", 0.0F}, {"opponent_score", 0.0F}},
      "live_end");
  require(end.status == "ok", "live-score end ok");
  require(end.payload["final_scores"]["player_score"].get<float>() > 0.0F,
          "live scores override zero passthrough");
  require(end.payload.contains("arena"), "end payload includes arena state");
  require(end.payload["final_scores"]["mode_id"].get<std::string>() == "basketball_dunk",
          "final scores mode id");

  physics.shutdown();
}

void end_session_idempotent_returns_last_result() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "basketball_h2h"}, {"user_id", "idem_user"}},
              "idem_start")
              .status == "ok",
          "session starts");

  const auto first = gameplay.handleGameplayCommand(
      "fel.arena.end_session",
      {{"player_score", 24.0F}, {"opponent_score", 20.0F}},
      "idem_first");
  require(first.status == "ok", "first end ok");
  require(first.payload["final_scores"]["player_score"].get<float>() == 24.0F,
          "first end player score");

  const auto second = gameplay.handleGameplayCommand(
      "fel.arena.end_session",
      {{"player_score", 0.0F}, {"opponent_score", 99.0F}},
      "idem_second");
  require(second.status == "ok", "second end idempotent ok");
  require(second.payload["final_scores"]["player_score"].get<float>() == 24.0F,
          "idempotent end preserves first result");

  const auto arena =
      gameplay.handleGameplayQuery("fel.query.get_arena_state", {}, "idem_arena");
  require(arena.status == "ok", "arena state after idempotent end");
  require(arena.payload.contains("last_result"), "arena exposes last_result");
  require(arena.payload["last_result"]["score"].get<float>() == 24.0F,
          "last_result score readable by bridge");
}

void fitness_partial_update_rejects_empty_params() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);

  const auto response = gameplay.handleGameplayCommand(
      "fel.fitness.update_frc", {{"unknown_field", 1.0F}}, "empty_partial");
  require(response.status == "error", "empty partial frc update rejected");
}

void fitness_update_rejects_non_finite_values() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);

  const auto response = gameplay.handleGameplayCommand(
      "fel.fitness.update",
      {{"frc_mobility", nlohmann::json()}, {"frc_active_range", 0.5F}},
      "nan_fitness");
  require(response.status == "error", "non-finite fitness rejected");
}

void mode_runtime_rejects_non_object_snow_and_scene_params() {
  nexus::gameplay::ModeRuntime runtime;
  require(runtime.setMode("snowboarding").isOk(), "snowboarding mode set");
  require(runtime.handleCommand("fel.snow.carve", nlohmann::json()).isErr(),
          "snow carve rejects null params");
  require(runtime.handleCommand("fel.snow.carve", nlohmann::json::array({1, 2, 3})).isErr(),
          "snow carve rejects array params");

  require(runtime.setMode("surfing").isOk(), "surfing mode set");
  require(runtime.handleCommand("fel.surf.carve", nlohmann::json()).isErr(),
          "surf carve rejects null params");
  require(runtime.handleCommand("fel.surf.carve", nlohmann::json::array({1, 2, 3})).isErr(),
          "surf carve rejects array params");

  require(runtime.setMode("who_scene_it").isOk(), "who_scene_it mode set");
  require(runtime.handleCommand("fel.scene.buzz_in", nlohmann::json()).isErr(),
          "scene buzz rejects null params");
  require(runtime.handleCommand("fel.scene.buzz_in", nlohmann::json::array({1, 2, 3})).isErr(),
          "scene buzz rejects array params");

  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::ai::CommandRouter router;
  nexus::ai::AgentServer server;
  require(router.init(&manipulator, &world).isOk(), "error envelope router init");
  router.setGameplayHandler(&gameplay);
  require(server.init(&router).isOk(), "error envelope server init");

  const std::string nullParamsAction = R"json({
    "type": "command",
    "id": "snow_null_agent",
    "payload": {"command": "fel.snow.carve", "params": null}
  })json";
  require(server.receiveJson(nullParamsAction).isOk(), "receive null params snow carve");
  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "snowboarding"}, {"user_id", "error_envelope_test"}},
              "snow_agent_start")
              .status == "ok",
          "snowboarding session for agent null-params test");
  auto nullResponses = server.processQueuedCommands(4);
  require(nullResponses.size() == 1, "one response for null params carve");
  require(nullResponses[0].status == "ok", "agent path coerces null params to defaults");

  const std::string arrayParamsAction = R"json({
    "type": "command",
    "id": "snow_array_agent",
    "payload": {"command": "fel.snow.carve", "params": [1, 2, 3]}
  })json";
  require(server.receiveJson(arrayParamsAction).isOk(), "receive array params snow carve");
  auto arrayResponses = server.processQueuedCommands(4);
  require(arrayResponses.size() == 1, "one response for array params carve");
  require(arrayResponses[0].status == "error", "agent path rejects array params carve");
  require(!arrayResponses[0].error.empty(), "array params carve error envelope message");

  server.shutdown();
  router.shutdown();
}

void snowboarding_action_payloads_are_objects() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "snowboarding"}, {"user_id", "payload_shape_test"}},
              "snow_payload_start")
              .status == "ok",
          "snowboarding session starts for payload shape test");

  const std::array<std::pair<const char*, const char*>, 4> commands{{
      {"fel.snow.carve", "carve"},
      {"fel.snow.jump", "jump"},
      {"fel.snow.butter", "butter"},
      {"fel.snow.wipeout", "wipeout"},
  }};
  for (const auto& [command, actionKey] : commands) {
    const auto response = gameplay.handleGameplayCommand(
        command, nlohmann::json::object(), std::string(command) + "_shape");
    require(response.status == "ok", std::string(command) + " returns ok");
    require(response.payload.is_object(), std::string(command) + " payload is object");
    require(response.payload.contains(actionKey) && response.payload[actionKey].is_object(),
              std::string(command) + " action envelope is object");
    require(response.payload.contains("line_score") && response.payload["line_score"].is_number(),
              std::string(command) + " line_score present");
    require(response.payload.contains("agent_envelope") &&
                  response.payload["agent_envelope"].is_object(),
              std::string(command) + " agent_envelope is object");
  }
}

void flagship_basketball_dunk_validate_only_integration() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  const auto mode = nexus::gameplay::ArenaModeRegistry::find("basketball_dunk");
  require(mode.has_value(), "dunk mode registered");
  require(mode->venueToken == "Venice_Beach_Court", "dunk uses venice venue");

  require(gameplay.handleGameplayCommand(
              "fel.fitness.update",
              {{"frc_mobility", 0.9F},
               {"frc_active_range", 0.85F},
               {"frc_control", 0.95F},
               {"iap_engagement", 0.8F},
               {"iap_confidence", 0.9F},
               {"breath_phase", 1}},
              "dunk_fitness")
              .status == "ok",
          "prime fitness for dunk");

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "basketball_dunk"}, {"user_id", "flagship_dunk"}},
              "dunk_flagship_start")
              .status == "ok",
          "dunk flagship session starts");

  require(gameplay.handleGameplayCommand("fel.dunk.charge_begin", {}, "dunk_charge").status == "ok",
          "dunk charge");
  require(gameplay.handleGameplayCommand("fel.dunk.charge_release", {{"power", 0.92F}}, "dunk_release")
              .status == "ok",
          "dunk release");

  for (int step = 0; step < 16; ++step) {
    gameplay.update(0.05, physics, {});
  }

  const auto hud = gameplay.handleGameplayQuery("fel.hud.poll", {}, "dunk_hud");
  require(hud.payload["payload"]["mode_id"].get<std::string>() == "basketball_dunk",
          "hud reports dunk mode");
  require(hud.payload["payload"]["fitness"]["power_readiness"].get<float>() > 0.7F,
          "hud power readiness visible");
  require(hud.payload["payload"]["throw_catch"]["last_pulse"].is_object(),
          "hud throw pulse envelope");
  require(hud.payload["payload"]["mode_state"]["dunk"].is_object(), "hud dunk nested state");
  require(hud.payload["payload"]["throw_catch"]["agent_envelope"].is_object(),
          "hud throw-catch agent envelope");

  const auto demo = gameplay.handleGameplayQuery(
      "fel.query.get_exercise_demo", {{"mode_id", "basketball_dunk"}}, "dunk_demo");
  require(demo.payload["module_id"].get<std::string>() == "mod2", "dunk demo mapping");

  physics.shutdown();
}

void flagship_karate_kata_validate_only_integration() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "karate_endless"}, {"user_id", "flagship_kata"}},
              "kata_start")
              .status == "ok",
          "karate kata proxy session starts");

  gameplay.update(0.1, physics, {});

  const auto modeState =
      gameplay.handleGameplayQuery("fel.query.get_mode_state", {}, "kata_state");
  require(modeState.payload["karate"]["wave"].get<int>() >= 1, "kata wave spawned");

  auto strike = gameplay.handleGameplayCommand(
      "fel.karate.action", {{"action", "heavy_strike"}}, "kata_strike");
  require(strike.status == "ok", "kata strike");
  require(strike.payload["combat"]["action"].is_string(), "combat envelope in response");

  for (int step = 0; step < 24; ++step) {
    gameplay.update(0.05, physics, {});
    strike = gameplay.handleGameplayCommand(
        "fel.karate.action", {{"action", "light_strike"}}, "kata_chain");
    if (strike.status != "ok") {
      break;
    }
  }

  const auto hud = gameplay.handleGameplayQuery("fel.hud.poll", {}, "kata_hud");
  require(hud.payload["payload"]["mode_state"]["karate"]["score"].get<int>() >= 0,
          "kata score on hud");
  require(hud.payload["payload"]["mode_id"].get<std::string>() == "karate_endless",
          "kata mode id on hud");

  const auto venue = nexus::gameplay::ArenaModeRegistry::venueTokenForMode("karate_endless");
  require(venue == "Zen_Dojo", "kata venue token");

  physics.shutdown();
}

void flagship_venice_pickup_validate_only_integration() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  const auto mode = nexus::gameplay::ArenaModeRegistry::find("basketball_h2h");
  require(mode.has_value(), "venice pickup proxy mode registered");
  require(mode->venueToken == "Venice_Beach_Court", "venice pickup venue");

  require(gameplay.handleGameplayCommand(
              "fel.venue.register_volume",
              {{"venue_token", "Venice_Beach_Court"},
               {"mode_id", "basketball_h2h"},
               {"min", {{"x", 0.0F}, {"y", 0.0F}, {"z", 0.0F}}},
               {"max", {{"x", 20.0F}, {"y", 5.0F}, {"z", 20.0F}}}},
              "venice_volume")
              .status == "ok",
          "venice court volume registered");

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "basketball_h2h"}, {"user_id", "venice_pickup"}},
              "pickup_start")
              .status == "ok",
          "venice pickup session starts");

  require(gameplay.handleGameplayCommand(
              "fel.venue.set_player_position",
              {{"x", 10.0F}, {"y", 1.0F}, {"z", 10.0F}},
              "pickup_move")
              .status == "ok",
          "player enters venice court");

  require(std::string(gameplay.fel_bridge().activeVenueToken()) == "Venice_Beach_Court",
          "bridge venue travel on pickup overlap");

  require(gameplay.handleGameplayCommand(
              "fel.fitness.update",
              {{"frc_mobility", 0.7F},
               {"frc_active_range", 0.6F},
               {"frc_control", 0.75F},
               {"iap_engagement", 0.65F},
               {"iap_confidence", 0.8F},
               {"breath_phase", 0}},
              "pickup_fitness")
              .status == "ok",
          "pickup fitness primed");

  gameplay.update(0.55, physics, {});
  require(gameplay.throw_catch_state().throwsTriggered >= 1, "pickup throw-catch cycles");
  require(gameplay.throw_catch_state().lastPulse.impulseY > 0.0F,
          "pickup throw pulse recorded");

  const auto session =
      gameplay.handleGameplayQuery("fel.query.get_session_state", {}, "pickup_session");
  require(session.payload["arena"]["mode_id"].get<std::string>() == "basketball_h2h",
          "pickup arena mode in session state");
  require(session.payload["mode_runtime"]["pickup"].is_object(),
          "pickup mode state in session");
  require(session.payload["fel_bridge"]["active_venue_token"].get<std::string>() ==
              "Venice_Beach_Court",
          "pickup bridge venue in session state");

  physics.shutdown();
}

void flagship_court_carnival_validate_only_integration() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  const auto mode = nexus::gameplay::ArenaModeRegistry::find("court_carnival");
  require(mode.has_value(), "court carnival mode registered");
  require(mode->venueToken == "Venice_Beach_Court", "carnival uses venice venue");

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "court_carnival"}, {"user_id", "flagship_carnival"}},
              "carnival_start")
              .status == "ok",
          "carnival session starts");

  auto pad = gameplay.handleGameplayCommand(
      "fel.carnival.trigger_pad",
      {{"pad", "trick_shot"}, {"timing", 0.95F}},
      "carnival_pad");
  require(pad.status == "ok", "carnival pad trigger");
  require(pad.payload["pad_trigger"]["grade"].get<std::string>() == "perfect",
          "carnival pad perfect grade");
  require(pad.payload["player_score"].get<int>() > 0, "carnival score after pad");

  auto dice = gameplay.handleGameplayCommand("fel.carnival.roll_dice", {}, "carnival_dice");
  require(dice.status == "ok", "carnival dice roll");
  require(dice.payload["dice"]["value"].get<int>() >= 1, "dice value in range");

  require(gameplay.handleGameplayCommand(
              "fel.fitness.update",
              {{"frc_mobility", 0.8F},
               {"frc_active_range", 0.7F},
               {"frc_control", 0.85F},
               {"iap_engagement", 0.75F},
               {"iap_confidence", 0.8F},
               {"breath_phase", 1}},
              "carnival_fitness")
              .status == "ok",
          "carnival fitness primed");

  gameplay.handleGameplayCommand(
      "fel.carnival.trigger_pad", {{"pad", "hot_potato"}, {"timing", 0.9F}}, "hot_potato");
  for (int step = 0; step < 20; ++step) {
    gameplay.update(0.05, physics, {});
  }

  const auto hud = gameplay.handleGameplayQuery("fel.hud.poll", {}, "carnival_hud");
  require(hud.payload["payload"]["mode_id"].get<std::string>() == "court_carnival",
          "hud reports carnival mode");
  require(hud.payload["payload"]["mode_state"]["carnival"].is_object(),
          "hud carnival nested state");
  require(hud.payload["payload"]["throw_catch"]["agent_envelope"].is_object(),
          "hud throw-catch agent envelope");

  const auto fitnessQuery =
      gameplay.handleGameplayQuery("fel.query.get_fitness_state", {}, "carnival_fitness_q");
  require(fitnessQuery.payload["throw_catch_hints"].is_object(),
          "fitness query includes throw-catch hints");

  physics.shutdown();
}

void flagship_gymnastics_validate_only_integration() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  const auto mode = nexus::gameplay::ArenaModeRegistry::find("gymnastics");
  require(mode.has_value(), "gymnastics mode registered");
  require(mode->venueToken == "Training_Floor", "gymnastics uses training floor");

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "gymnastics"}, {"user_id", "flagship_gymnastics"}},
              "gym_start")
              .status == "ok",
          "gymnastics session starts");

  auto tap = gameplay.handleGameplayCommand(
      "fel.gymnastics.tap", {{"timing", 0.95F}, {"difficulty", 0.8F}}, "gym_tap");
  require(tap.status == "ok", "gymnastics rhythm tap");
  require(tap.payload["gymnastics"].is_object(), "gymnastics nested mode envelope");
  require(tap.payload["tap"]["grade"].get<std::string>() == "perfect", "gymnastics perfect tap");
  require(tap.payload["gymnastics"]["judge_score"].get<float>() > 0.0F, "gymnastics judge score");

  for (int step = 0; step < 5; ++step) {
    gameplay.handleGameplayCommand(
        "fel.gymnastics.tap", {{"timing", 0.9F}, {"difficulty", 0.75F}}, "gym_chain");
  }

  const auto modeState =
      gameplay.handleGameplayQuery("fel.query.get_mode_state", {}, "gym_state");
  require(modeState.payload["gymnastics"]["elements_completed"].get<int>() >= 6,
          "gymnastics routine completes");

  physics.shutdown();
}

void flagship_brain_brawl_validate_only_integration() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  const auto mode = nexus::gameplay::ArenaModeRegistry::find("brain_brawl");
  require(mode.has_value(), "brain brawl mode registered");
  require(mode->venueToken == "Neuro_Arena", "brain brawl uses neuro arena");

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "brain_brawl"}, {"user_id", "flagship_brain"}},
              "brain_start")
              .status == "ok",
          "brain brawl session starts");

  auto answer = gameplay.handleGameplayCommand(
      "fel.brain.answer",
      {{"correct", true}, {"response_time", 4.0F}, {"category", "BodyIQ"}},
      "brain_answer");
  require(answer.status == "ok", "brain brawl answer");
  require(answer.payload["player_correct"].get<int>() == 1,
          "brain brawl correct count");

  for (int step = 0; step < 9; ++step) {
    gameplay.handleGameplayCommand(
        "fel.brain.answer",
        {{"correct", step % 4 != 0}, {"response_time", 6.0F}, {"category", "SportsIQ"}},
        "brain_chain");
    gameplay.update(0.05, physics, {});
  }

  const auto hud = gameplay.handleGameplayQuery("fel.hud.poll", {}, "brain_hud");
  require(hud.payload["payload"]["mode_id"].get<std::string>() == "brain_brawl",
          "hud reports brain brawl mode");
  require(hud.payload["payload"]["mode_state"]["brain_brawl"].is_object(),
          "hud brain brawl nested state");

  physics.shutdown();
}

void flagship_skateboarding_validate_only_integration() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  const auto mode = nexus::gameplay::ArenaModeRegistry::find("skateboarding");
  require(mode.has_value(), "skateboarding mode registered");
  require(mode->venueToken == "Skate_Park", "skateboarding uses skate park");

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "skateboarding"}, {"user_id", "flagship_skate"}},
              "skate_start")
              .status == "ok",
          "skateboarding session starts");

  auto trick = gameplay.handleGameplayCommand(
      "fel.skate.trick", {{"difficulty", 0.85F}, {"combo_multiplier", 3}}, "skate_trick");
  require(trick.status == "ok", "skateboarding trick land");
  require(trick.payload["trick_score"].get<int>() > 0, "skateboarding score");

  int guard = 0;
  while (gameplay.handleGameplayQuery("fel.query.get_mode_state", {}, "skate_state")
             .payload["skateboarding"]["run_complete"]
             .get<bool>() == false &&
         guard++ < 12) {
    gameplay.handleGameplayCommand(
        "fel.skate.trick", {{"difficulty", 0.9F}, {"combo_multiplier", 4}}, "skate_chain");
  }

  const auto finalState =
      gameplay.handleGameplayQuery("fel.query.get_mode_state", {}, "skate_final");
  require(finalState.payload["skateboarding"]["trick_score"].get<int>() >= 50,
          "skateboarding reaches win threshold");

  physics.shutdown();
}

void flagship_snowboarding_validate_only_integration() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  const auto mode = nexus::gameplay::ArenaModeRegistry::find("snowboarding");
  require(mode.has_value(), "snowboarding mode registered");
  require(mode->venueToken == "Mountain_Slope", "snowboarding uses mountain slope");

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "snowboarding"}, {"user_id", "flagship_snow"}},
              "snow_start")
              .status == "ok",
          "snowboarding session starts");

  const auto modeCheck =
      gameplay.handleGameplayQuery("fel.query.get_mode_state", {}, "snow_mode_check");
  require(modeCheck.payload.is_object(), "snow mode state is object");
  require(modeCheck.payload["kind"].get<int>() == 9, "snowboarding runtime kind active");

  auto carve = gameplay.handleGameplayCommand(
      "fel.snow.carve", {{"timing", 0.95F}, {"line_difficulty", 0.8F}}, "snow_carve");
  require(carve.status == "ok", "snowboarding carve");
  require(carve.payload["agent_envelope"]["command"].get<std::string>() == "fel.snow.carve",
          "snow carve agent envelope");

  auto jump = gameplay.handleGameplayCommand(
      "fel.snow.jump", {{"air_difficulty", 0.9F}, {"combo_multiplier", 3}}, "snow_jump");
  require(jump.status == "ok", "snowboarding jump");

  const auto modeState =
      gameplay.handleGameplayQuery("fel.query.get_mode_state", {}, "snow_final");
  require(modeState.payload["snowboarding"]["line_score"].get<int>() >= 50,
          "snowboarding reaches win threshold");

  gameplay.update(0.05, physics, {});
  const auto hud = gameplay.handleGameplayQuery("fel.hud.poll", {}, "snow_hud");
  require(hud.payload["payload"]["mode_id"].get<std::string>() == "snowboarding",
          "hud reports snowboarding mode");
  require(hud.payload["payload"]["mode_state"]["snowboarding"].is_object(),
          "hud snowboarding nested state");

  physics.shutdown();
}

void flagship_surfing_validate_only_integration() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  const auto mode = nexus::gameplay::ArenaModeRegistry::find("surfing");
  require(mode.has_value(), "surfing mode registered");
  require(mode->releaseState == nexus::gameplay::ArenaReleaseState::kProduction,
          "surfing is production");
  require(mode->venueToken == "Venice_Beach_Surf", "surfing uses venice surf venue");

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "surfing"}, {"user_id", "flagship_surf"}},
              "surf_start")
              .status == "ok",
          "surfing session starts");

  const auto modeCheck = gameplay.handleGameplayQuery("fel.query.get_mode_state", {}, "surf_kind");
  require(modeCheck.payload["kind"].get<int>() == 12, "surfing runtime kind active");

  const auto carve = gameplay.handleGameplayCommand(
      "fel.surf.carve", {{"timing", 0.94F}, {"wave_difficulty", 0.8F}}, "surf_carve");
  require(carve.status == "ok", "surfing carve");
  require(carve.payload["carve"]["grade"].get<std::string>() == "perfect", "surf perfect carve");
  require(carve.payload["wave_score"].get<int>() > 0, "surfing wave score advances");

  for (int i = 0; i < 8 && !gameplay.mode_runtime().shouldAutoEndSession(); ++i) {
    const auto aerial = gameplay.handleGameplayCommand(
        "fel.surf.aerial", {{"air_difficulty", 0.9F}, {"combo_multiplier", 3}}, "surf_aerial");
    require(aerial.status == "ok", "surfing aerial chain");
    gameplay.update(0.05, physics, {});
  }

  const auto modeState = gameplay.handleGameplayQuery("fel.query.get_mode_state", {}, "surf_state");
  require(gameplay.mode_runtime().shouldAutoEndSession(), "surfing run completes");
  require(modeState.payload["surfing"]["wave_score"].get<int>() >=
              nexus::gameplay::SurfingMode::kWinScore,
          "surfing reaches win threshold");

  gameplay.update(0.05, physics, {});
  const auto hud = gameplay.handleGameplayQuery("fel.hud.poll", {}, "surf_hud");
  require(hud.payload["payload"]["mode_id"].get<std::string>() == "surfing",
          "hud reports surfing mode");
  require(hud.payload["payload"]["mode_state"]["surfing"].is_object(),
          "hud surfing nested state");

  physics.shutdown();
}

void flagship_outcome_sport_validate_only_integration() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "baseball"}, {"user_id", "flagship_baseball"}},
              "baseball_start")
              .status == "ok",
          "baseball session starts");

  for (int i = 0; i < 48; ++i) {
    if (gameplay.mode_runtime().shouldAutoEndSession()) {
      break;
    }
    const auto pulse = gameplay.handleGameplayCommand(
        "fel.sport.pulse", {{"success", true}, {"timing", 0.9F}}, "baseball_pulse");
    require(pulse.status == "ok", "baseball sport pulse ok");
    gameplay.update(0.05, physics, {});
  }

  const auto end = gameplay.handleGameplayCommand(
      "fel.arena.end_session", {{"use_live_scores", true}}, "baseball_end");
  require(end.status == "ok", "baseball session ends with live scores");
  require(end.payload.contains("outcome"), "baseball outcome present");

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "volleyball"}, {"user_id", "flagship_volleyball"}},
              "volleyball_start")
              .status == "ok",
          "volleyball session starts");

  for (int i = 0; i < 60; ++i) {
    if (gameplay.mode_runtime().shouldAutoEndSession()) {
      break;
    }
    require(gameplay.handleGameplayCommand(
                "fel.sport.pulse", {{"success", true}, {"timing", 0.88F}}, "volleyball_pulse")
                .status == "ok",
            "volleyball sport pulse ok");
    gameplay.update(0.05, physics, {});
  }

  require(gameplay.mode_runtime().shouldAutoEndSession(), "volleyball match completes");

  physics.shutdown();
}

void flagship_who_scene_it_validate_only_integration() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  const auto mode = nexus::gameplay::ArenaModeRegistry::find("who_scene_it");
  require(mode.has_value(), "who scene it mode registered");
  require(mode->venueToken == "Neuro_Arena", "who scene it uses neuro arena");

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "who_scene_it"}, {"user_id", "flagship_scene"}},
              "scene_start")
              .status == "ok",
          "who scene it session starts");

  auto buzz = gameplay.handleGameplayCommand(
      "fel.scene.buzz_in", {{"timing", 0.94F}}, "scene_buzz");
  require(buzz.status == "ok", "who scene it buzz in");
  require(buzz.payload["buzz"]["won_buzz"].get<bool>(), "player wins buzz");
  require(buzz.payload["agent_envelope"]["command"].get<std::string>() == "fel.scene.buzz_in",
          "scene buzz agent envelope");

  for (int step = 0; step < 7; ++step) {
    gameplay.handleGameplayCommand("fel.scene.buzz_in", {{"timing", 0.9F}}, "scene_buzz_chain");
    auto answer = gameplay.handleGameplayCommand(
        "fel.scene.answer",
        {{"correct", true}, {"response_time", 4.0F}, {"category", "ClassicFilm"}},
        "scene_answer");
    require(answer.status == "ok", "who scene it answer");
    gameplay.update(0.05, physics, {});
  }

  const auto finalState =
      gameplay.handleGameplayQuery("fel.query.get_mode_state", {}, "scene_final");
  require(finalState.payload["who_scene_it"]["correct_count"].get<int>() >= 7,
          "who scene it reaches win threshold");
  require(finalState.payload["who_scene_it"]["match_complete"].get<bool>(),
          "who scene it match complete");

  physics.shutdown();
}

void fel_bridge_websocket_stub_sends_outbound() {
  nexus::gameplay::FelBridgeService bridge;
  bridge.setWebSocketUrl("ws://127.0.0.1:8787/ws/vault");
  require(bridge.connectTransport().isOk(), "fel bridge transport connect");
  bridge.notifyVenueTravel("Venice_Beach_Court", "basketball_dunk");
  require(bridge.transportState() == nexus::core::WebSocketClientState::kConnected,
          "fel bridge transport connected");
  require(!bridge.outboundMessages().empty(), "fel bridge queued outbound json");
  require(!bridge.sentTransportFrames().empty(), "fel bridge stub sent WS frame");

  const nlohmann::json receipt = {
      {"mode_id", "basketball_dunk"},
      {"score", 21},
      {"outcome", "win"},
      {"duration_seconds", 60},
      {"completed", true},
      {"telemetry", {{"session_id", "bridge_stub_session"}}},
  };
  require(bridge.postSessionPayload(receipt).isOk(), "fel bridge session POST stub");
  require(!bridge.postedSessionRequests().empty(), "fel bridge recorded HTTP POST");
  require(bridge.postedSessionRequests().front().body.find("basketball_dunk") != std::string::npos,
          "fel bridge POST body includes mode_id");
}

void hud_relay_websocket_stub_emits_frames() {
  nexus::gameplay::HudRelayService relay;
  relay.setWebSocketUrl("ws://127.0.0.1:8787/ws/hud");
  require(relay.connectRelay().isOk(), "hud relay connect");
  relay.emitTickFrame({{"prq", 72.5F}, {"mode_id", "basketball_dunk"}});
  require(relay.relayState() == nexus::core::WebSocketClientState::kConnected, "hud relay connected");
  require(relay.latestFrame()["type"].get<std::string>() == "fel.hud.frame", "hud frame type");
  require(!relay.pendingFrames().empty(), "hud pending frames");
  require(!relay.sentTransportFrames().empty(), "hud relay stub sent WS frame");
  require(relay.sentTransportFrames().front().find("fel.hud.frame") != std::string::npos,
          "hud relay WS payload type");
}

void session_receipt_http_stub_posts_localhost_contract() {
  const auto tempDir = std::filesystem::temp_directory_path() /
                       ("fel_receipt_http_stub_test_" + std::to_string(getpid()));
  removeTreeBestEffort(tempDir);

  nexus::gameplay::SessionReceiptClient client({
      .queueDirectory = tempDir.string(),
      .baseUrl = "http://127.0.0.1:8000/api/games/session",
      .persistToDisk = false,
      .httpEnabled = true,
      .useStubHttpTransport = true,
  });

  nlohmann::json receipt = {
      {"mode_id", "karate_endless"},
      {"score", 15},
      {"outcome", "win"},
      {"duration_seconds", 90},
      {"completed", true},
      {"combo_count", 2},
      {"critical_count", 1},
      {"pacing_score", 70.0F},
      {"mri_score", 55.0F},
      {"arv", 75.0F},
      {"esi", 60.0F},
      {"telemetry",
       {{"session_id", "http_stub_session"}, {"user_id", "test_user"}, {"device", {{"engine", "NEXUS 1.0"}}}}},
  };

  client.enqueue(receipt);
  const auto flush = client.flush();
  require(flush.delivered == 1, "stub HTTP flush delivers receipt");
  require(client.pendingCount() == 0, "receipt cleared after stub POST");
  require(client.postedRequests().size() == 1, "one stub POST recorded");
  require(client.postedRequests().front().url.find("/api/games/session") != std::string::npos,
          "POST targets session contract path");
  require(client.postedRequests().front().body.find("karate_endless") != std::string::npos,
          "POST body includes mode_id");
}

void session_receipt_live_http_success_does_not_count_disk_queue() {
#if defined(__unix__) || defined(__APPLE__)
  if (!curlAvailable()) {
    std::fprintf(stderr, "SKIP: curl unavailable for live receipt success test\n");
    return;
  }

  const auto tempDir = std::filesystem::temp_directory_path() /
                       ("fel_receipt_live_success_test_" + std::to_string(getpid()));
  removeTreeBestEffort(tempDir);

  SingleResponseHttpServer server(204);
  nexus::gameplay::SessionReceiptClient client({
      .queueDirectory = tempDir.string(),
      .baseUrl = server.url(),
      .persistToDisk = false,
      .httpEnabled = true,
      .useStubHttpTransport = false,
  });

  client.enqueue({
      {"mode_id", "basketball_dunk"},
      {"score", 21},
      {"telemetry", {{"session_id", "live_success_session"}}},
  });

  const auto flush = client.flush();
  require(flush.attempted == 1, "live success flush attempted");
  require(flush.delivered == 1, "live success flush delivered");
  require(flush.requeued == 0, "live success flush not requeued");
  require(flush.queued_on_disk == 0, "HTTP-only success does not count disk queue");
  require(client.pendingCount() == 0, "HTTP-only success clears pending receipt");
  require(client.postedRequests().size() == 1, "live success POST recorded");
  require(client.postedRequests().front().statusCode == 204, "live success status recorded");
  require(!std::filesystem::exists(tempDir), "HTTP-only success does not create disk queue");
#else
  std::fprintf(stderr, "SKIP: live receipt success test requires POSIX sockets\n");
#endif
}

void session_receipt_live_http_non_2xx_requeues_without_disk() {
#if defined(__unix__) || defined(__APPLE__)
  if (!curlAvailable()) {
    std::fprintf(stderr, "SKIP: curl unavailable for live receipt retry test\n");
    return;
  }

  const auto tempDir = std::filesystem::temp_directory_path() /
                       ("fel_receipt_live_retry_test_" + std::to_string(getpid()));
  removeTreeBestEffort(tempDir);

  SingleResponseHttpServer server(503);
  nexus::gameplay::SessionReceiptClient client({
      .queueDirectory = tempDir.string(),
      .baseUrl = server.url(),
      .persistToDisk = false,
      .httpEnabled = true,
      .useStubHttpTransport = false,
  });

  client.enqueue({
      {"mode_id", "basketball_dunk"},
      {"score", 8},
      {"telemetry", {{"session_id", "live_retry_session"}}},
  });

  const auto flush = client.flush();
  require(flush.attempted == 1, "live non-2xx flush attempted");
  require(flush.delivered == 0, "live non-2xx flush not delivered");
  require(flush.requeued == 1, "live non-2xx flush requeued");
  require(flush.queued_on_disk == 0, "HTTP-only retry does not count disk queue");
  require(client.pendingCount() == 1, "live non-2xx keeps pending receipt");
  require(client.postedRequests().size() == 1, "live non-2xx POST recorded");
  require(client.postedRequests().front().statusCode == 503, "live non-2xx status recorded");
  require(!std::filesystem::exists(tempDir), "HTTP-only retry does not create disk queue");
#else
  std::fprintf(stderr, "SKIP: live receipt retry test requires POSIX sockets\n");
#endif
}

struct TextGenTempWorkspace {
  std::filesystem::path root;
  std::string manifestPath;
  std::string importRoot;

  explicit TextGenTempWorkspace(const std::string& name) {
    root = std::filesystem::temp_directory_path() / (name + "_" + std::to_string(getpid()));
    removeTreeBestEffort(root);
    std::filesystem::create_directories(root / "imported");
    std::filesystem::create_directories(root / "manifests");
    manifestPath = (root / "manifests" / "test_manifest.json").string();
    importRoot = (root / "imported").string();
    std::ofstream manifest(manifestPath);
    manifest << R"json({
      "schema": "nexus-asset-manifest",
      "version": "1.0",
      "import_root": ")json"
               << importRoot << R"json(",
      "assets": [],
      "venues": [],
      "environment_scans": []
    })json";
  }

  ~TextGenTempWorkspace() { removeTreeBestEffort(root); }
};

void text_prompt_adapter_maps_beach_arena_prompt() {
  const auto plan = nexus::ai::parseTextPrompt(
      "Describe a beach court with a sand dune at center and orange basketball hoops");
  require(plan.isOk(), "parse beach arena prompt");
  require(plan.value().intent == "mixed" || plan.value().intent == "terrain" ||
              plan.value().intent == "prop",
          "beach prompt yields actionable intent");
  require(!plan.value().steps.empty(), "beach prompt yields steps");

  bool hasCreative = false;
  bool hasGenerate = false;
  for (const nexus::ai::ParsedAgentStep& step : plan.value().steps) {
    if (step.command.rfind("fel.creative.", 0) == 0) {
      hasCreative = true;
    }
    if (step.command == "fel.generate.create_model") {
      hasGenerate = true;
    }
  }
  require(hasCreative, "beach prompt includes creative terrain step");
  require(hasGenerate, "beach prompt includes prop generation step");
}

void gameplay_from_text_executes_mixed_plan() {
  TextGenTempWorkspace workspace("nexus_gameplay_text_gen");

  nexus::generative::GenerativePipelineConfig config{};
  config.scan.importRoot = workspace.importRoot;
  config.scan.manifestPath = workspace.manifestPath;
  config.generate.importRoot = workspace.importRoot;
  config.generate.manifestPath = workspace.manifestPath;
  config.environmentScan.importRoot = workspace.importRoot + "/environments";
  config.environmentScan.manifestPath = workspace.manifestPath;

  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::generative::GenerativePipeline pipeline(config);
  pipeline.setVoxelWorld(&world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  gameplay.setGenerativePipeline(&pipeline);

  const auto response = gameplay.handleGameplayCommand(
      "fel.generate.from_text",
      {{"text", "Small sand mound at center with a training cone prop"}},
      "text_gen_test");
  require(response.status == "ok", "from_text command ok");
  require(response.payload["steps_applied"].get<std::size_t>() >= 2,
          "mixed plan applied multiple steps");
  require(response.payload["jobs"].is_array(), "jobs array returned");
  require(!response.payload["jobs"].empty(), "prop job enqueued");

  const auto hud =
      gameplay.handleGameplayQuery("fel.query.get_hud_pending_frames", {}, "hud_frames");
  require(hud.status == "ok", "hud frames query ok");
}

void agent_router_routes_from_text_to_gameplay() {
  TextGenTempWorkspace workspace("nexus_agent_text_gen");

  nexus::generative::GenerativePipelineConfig config{};
  config.generate.importRoot = workspace.importRoot;
  config.generate.manifestPath = workspace.manifestPath;

  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::generative::GenerativePipeline pipeline(config);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  gameplay.setGenerativePipeline(&pipeline);
  nexus::ai::CommandRouter router;
  nexus::ai::AgentServer server;

  require(router.init(&manipulator, &world, &pipeline).isOk(), "router init");
  router.setGameplayHandler(&gameplay);
  require(server.init(&router).isOk(), "server init");

  const std::string parseQuery = R"json({
    "type": "query",
    "id": "parse_prompt_router",
    "payload": {
      "query": "fel.generate.parse_prompt",
      "text": "Paint sand court and import luma beach venue scan"
    }
  })json";

  require(server.receiveJson(parseQuery).isOk(), "receive parse query");
  auto parseResponses = server.processQueuedCommands(8);
  require(parseResponses.size() == 1, "one parse response");
  require(parseResponses[0].status == "ok", "parse query ok");
  require(parseResponses[0].payload["steps"].is_array(), "plan steps returned");

  const std::string command = R"json({
    "type": "command",
    "id": "text_gen_router",
    "payload": {
      "command": "fel.generate.from_text",
      "params": {
        "text": "Flatten court floor and add orange hoop prop"
      }
    }
  })json";

  require(server.receiveJson(command).isOk(), "receive from_text command");
  const auto responses = server.processQueuedCommands(8);
  require(responses.size() == 1, "one from_text response");
  require(responses[0].status == "ok", "from_text routed through gameplay");
  require(responses[0].payload.contains("step_results"), "step results returned");

  server.shutdown();
  router.shutdown();
}

void game_prompt_adapter_maps_dunk_contest_prompt() {
  const auto plan = nexus::ai::parseGamePrompt(
      "Hard basketball dunk contest on Venice beach court",
      {.forceTemplate = true});
  require(plan.isOk(), "dunk game prompt parses");
  require(plan.value().modeId == "basketball_dunk", "dunk mode inferred");
  require(plan.value().rules["difficulty_tier"].get<std::string>() == "hard", "hard tier inferred");
  require(plan.value().hudTheme.contains("primary_color"), "hud theme present");
  require(plan.value().toJson().contains("export_path_hint"), "export path hint present");
  require(plan.value().metadata.value("adapter", "") == "template_mvp", "template adapter tag");
  require(plan.value().metadata.value("ai_backend", "") == "template_mvp", "template ai backend tag");
}

void game_prompt_adapter_builds_spec_from_gemini_hints() {
  const nlohmann::json hints = {
      {"mode_id", "karate_endless"},
      {"difficulty_tier", "hard"},
      {"wants_arena_generation", true},
      {"duration_modifier", "longer"},
      {"rationale", "Endless dojo survival with arena mesh"},
  };
  const auto spec = nexus::ai::buildSpecFromGeminiHints(
      "Karate endless wave dojo challenge with voxel terrain", hints);
  require(spec.isOk(), "gemini hints merge ok");
  require(spec.value().modeId == "karate_endless", "gemini mode_id applied");
  require(spec.value().rules["difficulty_tier"].get<std::string>() == "hard", "gemini difficulty");
  require(!spec.value().arenaPrompt.empty(), "arena prompt set from hints");
  require(spec.value().metadata.value("adapter", "") == "ai_studio_assisted", "ai studio adapter tag");
  require(spec.value().metadata.value("ai_backend", "") == "google_ai_studio", "ai studio backend tag");
  require(spec.value().metadata.value("generator_tier", "") == "ai_studio_assisted", "ai studio tier tag");
}

void game_prompt_adapter_rejects_invalid_gemini_mode_id() {
  const nlohmann::json hints = {
      {"mode_id", "not_a_real_mode"},
      {"difficulty_tier", "normal"},
      {"wants_arena_generation", false},
  };
  const auto spec = nexus::ai::buildSpecFromGeminiHints("mystery sport", hints);
  require(spec.isErr(), "invalid gemini mode rejected");
}

void game_prompt_adapter_force_template_skips_gemini() {
  const auto plan = nexus::ai::parseGamePrompt(
      "Brain brawl trivia quiz on hard difficulty",
      {.forceTemplate = true});
  require(plan.isOk(), "force template parses");
  require(plan.value().modeId == "brain_brawl", "brain brawl inferred");
  require(plan.value().metadata.value("adapter", "") == "template_mvp", "template adapter when forced");
}

void game_prompt_adapter_covers_all_playable_modes() {
  static constexpr std::array<std::pair<std::string_view, std::string_view>, 18> kCanonicalPrompts{{
      {"basketball_h2h", "Head to head basketball pickup game on Venice beach court"},
      {"basketball_dunk", "Hard basketball dunk contest on Venice beach court"},
      {"basketball_3v3", "Intense 3v3 streetball on Venice beach court"},
      {"karate_h2h", "Karate sparring match in zen dojo"},
      {"karate_endless", "Karate endless wave challenge in zen dojo"},
      {"baseball", "Home run derby at the baseball park"},
      {"football", "Kick return challenge at gridiron stadium"},
      {"soccer", "Penalty shootout at soccer stadium"},
      {"golf", "Closest to pin golf challenge on links course"},
      {"tennis", "Tennis rally ace match on hard court"},
      {"volleyball", "Volleyball sand court rally match"},
      {"gymnastics", "Gymnastics floor routine on training floor"},
      {"surfing", "Surfing rhythm session at Venice surf break"},
      {"skateboarding", "Skateboard trick lines at skate park"},
      {"snowboarding", "Snowboarding halfpipe run on mountain slope"},
      {"brain_brawl", "Brain brawl trivia quiz in neuro arena"},
      {"who_scene_it", "Who scene it film quiz party in neuro arena"},
      {"court_carnival", "Court carnival party mode with trick shot pads"},
  }};

  for (const auto& [expectedMode, promptText] : kCanonicalPrompts) {
    const auto plan = nexus::ai::parseGamePrompt(promptText, {.forceTemplate = true});
    require(plan.isOk(), std::string("template parse ok for ") + std::string(expectedMode));
    require(plan.value().modeId == expectedMode,
            std::string("mode inferred for ") + std::string(expectedMode));
  }
}

void game_prompt_adapter_normalizes_mode_aliases() {
  require(nexus::ai::normalizeGameModeId("venice_pickup") == "basketball_h2h", "venice_pickup alias");
  require(nexus::ai::normalizeGameModeId("karate_kata") == "karate_endless", "karate_kata alias");
  require(nexus::ai::normalizeGameModeId("market_browse").empty(), "market_browse excluded");
}

void game_prompt_adapter_sanitize_llm_json_strips_markdown_fence() {
  const std::string fenced =
      "```json\n{\"mode_id\":\"soccer\",\"difficulty_tier\":\"hard\"}\n```";
  const std::string sanitized = nexus::ai::sanitizeLlmJsonText(fenced);
  require(sanitized.find("```") == std::string::npos, "fence stripped");
  const auto parsed = nlohmann::json::parse(sanitized);
  require(parsed["mode_id"].get<std::string>() == "soccer", "fenced json parses");
}

void game_prompt_adapter_gemini_partial_fallback_keeps_hints() {
  const nlohmann::json hints = {
      {"mode_id", "not_a_real_mode"},
      {"difficulty_tier", "hard"},
      {"wants_arena_generation", false},
      {"duration_modifier", "longer"},
      {"rationale", "Invalid mode but useful difficulty"},
  };
  const auto normalized = nexus::ai::normalizeGeminiGameHints(hints, "Penalty shootout at soccer stadium");
  require(normalized["mode_id"].get<std::string>() == "soccer", "fallback mode from prompt");
  require(normalized["difficulty_tier"].get<std::string>() == "hard", "gemini difficulty preserved");
}

void game_prompt_adapter_refine_swaps_to_soccer_from_follow_up() {
  const auto base = nexus::ai::parseGamePrompt("Basketball dunk contest on Venice court", {.forceTemplate = true});
  require(base.isOk(), "base spec ok");
  const auto refined = nexus::ai::refineGameSpec(base.value(), "switch to penalty shootout at soccer stadium");
  require(refined.isOk(), "refine to soccer ok");
  require(refined.value().modeId == "soccer", "refine mode swap");
  require(refined.value().rules["difficulty_tier"].get<std::string>() == "normal",
          "refine preserves difficulty when not requested");
}

void gemini_game_prompt_client_stub_transport_returns_hints() {
  nexus::ai::GeminiGamePromptClientOptions options{
      .apiKey = "test_key",
      .useStubTransport = true,
      .stubResponse =
          nlohmann::json{{"mode_id", "court_carnival"},
                         {"difficulty_tier", "easy"},
                         {"wants_arena_generation", false}},
  };
  const auto hints =
      nexus::ai::requestGeminiGamePromptHints("Party trick shot carnival", options);
  require(hints.isOk(), "stub gemini hints ok");
  require(hints.value()["mode_id"].get<std::string>() == "court_carnival", "stub mode_id");
}

void nexus_ai_studio_config_parses_api_key_env_reference() {
  const auto tempPath =
      std::filesystem::temp_directory_path() /
      ("nexus_aistudio_cfg_" + std::to_string(static_cast<unsigned long long>(getpid())) + ".json");
  {
    std::ofstream out(tempPath);
    require(out.good(), "write temp ai studio config");
    out << R"({"apiKeyEnvVar":"NEXUS_AI_STUDIO_TEST_KEY","model":"gemini-2.0-flash"})";
  }

  const char* previous = std::getenv("NEXUS_AI_STUDIO_TEST_KEY");
  const std::string previousValue = previous != nullptr ? std::string(previous) : std::string{};
  setenv("NEXUS_AI_STUDIO_TEST_KEY", "AIza_test_phase3_key", 1);

  const auto config = nexus::ai::NexusAIStudioConfig::fromAIStudioJsonFile(tempPath.string());
  require(config.isConfigured(), "ai studio config resolves env reference");
  require(config.model == "gemini-2.0-flash", "ai studio config model from json");
  require(config.apiKeySource.find("NEXUS_AI_STUDIO_TEST_KEY") != std::string::npos,
          "ai studio config source names env var");

  if (previous != nullptr) {
    setenv("NEXUS_AI_STUDIO_TEST_KEY", previousValue.c_str(), 1);
  } else {
    unsetenv("NEXUS_AI_STUDIO_TEST_KEY");
  }
  std::error_code ignored;
  std::filesystem::remove(tempPath, ignored);
}

void nexus_ai_studio_config_builds_generate_content_url() {
  nexus::ai::NexusAIStudioConfig config{};
  config.apiKey = "AIza_test";
  config.model = "gemini-2.0-flash";
  config.baseUrl = "https://generativelanguage.googleapis.com";
  const std::string url = config.generateContentUrl();
  require(url.find("generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent") !=
              std::string::npos,
          "generateContent url uses v1beta model path");
  require(url.find("key=AIza_test") != std::string::npos, "generateContent url includes api key");
}

void parse_game_prompt_without_key_uses_template_backend() {
  const auto plan = nexus::ai::parseGamePrompt(
      "Brain brawl trivia quiz on hard difficulty",
      {.forceTemplate = true});
  require(plan.isOk(), "template parse without ai studio key");
  require(plan.value().metadata.value("ai_backend", "") == "template_mvp", "template ai backend tag");
}

void gameplay_generate_game_produces_spec_and_session() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);

  const auto response = gameplay.handleGameplayCommand(
      "fel.generate.game",
      {{"text", "Karate endless wave dojo challenge"}},
      "game_gen_test");
  require(response.status == "ok", "fel.generate.game ok");
  require(response.payload["game_spec"].is_object(), "game_spec envelope");
  require(response.payload["game_spec"]["mode_id"].get<std::string>() == "karate_endless",
          "karate endless mode");
  require(response.payload["session_started"].get<bool>(), "session started");
  require(response.payload["session_state"].is_object(), "session state returned");
  require(response.payload.contains("preview_label"), "preview label honest");
}

void gameplay_refine_game_harder_adjusts_difficulty() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);

  const auto initial = gameplay.handleGameplayCommand(
      "fel.generate.game",
      {{"text", "Casual basketball dunk"}, {"start_session", false}},
      "game_gen_base");
  require(initial.status == "ok", "base game spec ok");

  const auto refined = gameplay.handleGameplayCommand(
      "fel.generate.refine_game",
      {{"text", "make it harder and add dunk contest"}},
      "game_gen_refine");
  require(refined.status == "ok", "refine game ok");
  require(refined.payload["game_spec"]["mode_id"].get<std::string>() == "basketball_dunk",
          "refine keeps dunk mode");
  require(refined.payload["game_spec"]["rules"]["difficulty_tier"].get<std::string>() == "hard",
          "refine escalates difficulty");
}

void session_receipt_body_matches_api_contract() {
  nexus::gameplay::SessionResult result{};
  result.modeId = "basketball_dunk";
  result.sessionId = "nexus-test-session";
  result.userId = "ios_player";
  result.score = 42.0F;
  result.opponentScore = 18.0F;
  result.durationSeconds = 90.0F;
  result.completed = true;
  result.resultType = "win";
  result.outcome = nexus::gameplay::MatchOutcome::kWin;
  result.pacingScore = 72.0F;
  result.arv = 78.0F;
  result.esi = 65.0F;
  result.mriScore = 68.0F;
  result.comboCount = 3;
  result.criticalCount = 1;
  result.shardsCandidate = 50.0F;
  result.prqDeltaCandidate = 2.0F;

  const nlohmann::json body = nexus::gameplay::sessionReceiptBody(result);
  require(body["mode_id"].get<std::string>() == "basketball_dunk", "receipt mode_id");
  require(body["score"].get<int>() == 42, "receipt score");
  require(body["outcome"].get<std::string>() == "win", "receipt outcome");
  require(body["completed"].get<bool>(), "receipt completed");
  require(body.contains("telemetry"), "receipt telemetry envelope");
  require(body["telemetry"]["session_id"].get<std::string>() == "nexus-test-session",
          "telemetry session_id");
  require(body["telemetry"]["device"]["engine"].get<std::string>() == "NEXUS 1.0",
          "telemetry engine tag");
  require(body["telemetry"]["economy"]["shards_total"].get<int>() == 50, "economy shards candidate");
  require(body.contains("mri_score"), "receipt mri_score contract field");
  require(body["mri_score"].get<float>() == 68.0F, "receipt mri_score value");
  require(body["combo_count"].get<int>() == 3, "receipt combo_count");
  require(body["critical_count"].get<int>() == 1, "receipt critical_count");
  require(body["pacing_score"].get<float>() == 72.0F, "receipt pacing_score");
}

void require_json_object(const nlohmann::json& value, const char* label) {
  require(value.is_object(), std::string(label) + " must be object");
}

void require_nested_object(const nlohmann::json& root,
                           std::string_view key,
                           const char* label) {
  require_json_object(root, label);
  require(root.contains(std::string(key)), std::string(label) + " missing " + std::string(key));
  require(root[std::string(key)].is_object(),
          std::string(label) + " nested " + std::string(key) + " must be object");
}

void nexus_sprint_live_modes_agent_contract_integration() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "sprint agent physics init");
  nexus::ai::CommandRouter router;
  nexus::ai::AgentServer server;

  require(router.init(&manipulator, &world).isOk(), "sprint router init");
  router.setGameplayHandler(&gameplay);
  require(server.init(&router).isOk(), "sprint agent server init");

  struct SprintProbe {
    const char* modeId;
    const char* actionCommand;
    nlohmann::json actionParams;
    const char* envelopeCommand;
    const char* nestedStateKey;
  };

  const std::array<SprintProbe, 9> probes{{
      {"basketball_dunk", "fel.dunk.charge_begin", {}, "fel.dunk.charge_begin", "dunk"},
      {"karate_endless", "fel.karate.action", {{"action", "heavy_strike"}},
       "fel.karate.action", "karate"},
      {"basketball_h2h", "fel.fitness.update",
       {{"frc_mobility", 0.6F},
        {"frc_active_range", 0.6F},
        {"frc_control", 0.6F},
        {"iap_engagement", 0.6F},
        {"iap_confidence", 0.6F},
        {"breath_phase", 0}},
       "", "pickup"},
      {"court_carnival", "fel.carnival.trigger_pad", {{"pad", "trick_shot"}, {"timing", 0.9F}},
       "fel.carnival.trigger_pad", "carnival"},
      {"gymnastics", "fel.gymnastics.tap", {{"timing", 0.92F}, {"difficulty", 0.75F}},
       "fel.gymnastics.tap", "gymnastics"},
      {"brain_brawl", "fel.brain.answer",
       {{"correct", true}, {"response_time", 5.0F}, {"category", "BodyIQ"}},
       "fel.brain.answer", "brain_brawl"},
      {"skateboarding", "fel.skate.trick", {{"difficulty", 0.85F}, {"combo_multiplier", 2}},
       "fel.skate.trick", "skateboarding"},
      {"snowboarding", "fel.snow.carve", {{"timing", 0.93F}, {"line_difficulty", 0.75F}},
       "fel.snow.carve", "snowboarding"},
      {"who_scene_it", "fel.scene.buzz_in", {{"timing", 0.91F}}, "fel.scene.buzz_in",
       "who_scene_it"},
  }};

  for (const SprintProbe& probe : probes) {
    const std::string startJson = std::string(R"json({"type":"command","id":"sprint_start","payload":{"command":"fel.arena.start_session","params":{"mode_id":")json") +
                                probe.modeId +
                                R"json(","user_id":"sprint_agent"}}})json";
    require(server.receiveJson(startJson).isOk(), "receive start for sprint mode");
    auto startResponses = server.processQueuedCommands(4);
    require(startResponses.size() == 1, "one start response");
    require(startResponses[0].status == "ok", std::string("start ok for ") + probe.modeId);
    require_json_object(startResponses[0].payload, "start payload");

    nlohmann::json actionMsg = {
        {"type", "command"},
        {"id", "sprint_action"},
        {"payload", {{"command", probe.actionCommand}, {"params", probe.actionParams}}},
    };
    require(server.receiveJson(actionMsg.dump()).isOk(), "receive action for sprint mode");
    auto actionResponses = server.processQueuedCommands(4);
    require(actionResponses.size() == 1, "one action response");
    require(actionResponses[0].status == "ok", std::string("action ok for ") + probe.modeId);
    require_json_object(actionResponses[0].payload, "action payload");

    if (actionResponses[0].payload.contains("agent_envelope") &&
        probe.envelopeCommand[0] != '\0') {
      require(actionResponses[0].payload["agent_envelope"].is_object(),
              "agent_envelope object");
      require(actionResponses[0].payload["agent_envelope"].value("command", "") ==
                  probe.envelopeCommand,
              std::string("agent envelope command for ") + probe.modeId);
    }

    gameplay.update(0.05, physics, {});

    const std::string modeQuery = R"json({"type":"query","id":"sprint_mode","payload":{"query":"fel.query.get_mode_state"}})json";
    require(server.receiveJson(modeQuery).isOk(), "receive mode state query");
    auto modeResponses = server.processQueuedCommands(4);
    require(modeResponses.size() == 1, "one mode state response");
    require(modeResponses[0].status == "ok", std::string("mode state ok for ") + probe.modeId);
    require_nested_object(modeResponses[0].payload, probe.nestedStateKey,
                          "mode_runtime state");

    const std::string hudQuery =
        R"json({"type":"query","id":"sprint_hud","payload":{"query":"fel.hud.poll"}})json";
    require(server.receiveJson(hudQuery).isOk(), "receive hud poll query");
    auto hudResponses = server.processQueuedCommands(4);
    require(hudResponses.size() == 1, "one hud poll response");
    require(hudResponses[0].status == "ok", std::string("hud poll ok for ") + probe.modeId);
    const nlohmann::json& hudFrame = hudResponses[0].payload;
    require(hudFrame.is_object(), "hud poll envelope must be object");
    require(hudFrame.contains("payload"), "hud poll nested payload key");
    require(hudFrame["payload"].is_object(), "hud poll payload object");
    require(hudFrame["payload"].value("mode_id", "") == probe.modeId,
            std::string("hud mode_id for ") + probe.modeId);
    require(hudFrame["payload"].contains("mode_state"), "hud mode_state key");
    require(hudFrame["payload"]["mode_state"].is_object(), "hud mode_state object");
    require(hudFrame["payload"]["mode_state"].contains(probe.nestedStateKey),
            std::string("hud nested mode state for ") + probe.modeId);
  }

  server.shutdown();
  router.shutdown();
  physics.shutdown();
}

void flagship_modes_emit_post_ready_receipts() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);
  nexus::physics::PhysicsWorld physics;
  require(physics.init({}).isOk(), "physics init");

  const std::array<std::string, 5> modes = {
      "basketball_dunk", "karate_endless", "basketball_h2h", "basketball_3v3",
      "court_carnival"};
  for (const auto& modeId : modes) {
    require(gameplay.handleGameplayCommand(
                "fel.arena.start_session",
                {{"mode_id", modeId}, {"user_id", "receipt_chain"}},
                "chain_start")
                .status == "ok",
            "chain session starts for " + modeId);

    require(gameplay.handleGameplayCommand(
                "fel.arena.end_session",
                {{"player_score", 21.0F}, {"opponent_score", 12.0F}},
                "chain_end")
                .status == "ok",
            "chain session ends for " + modeId);

    const auto receipts =
        gameplay.handleGameplayQuery("fel.query.get_pending_session_receipts", {}, "chain_receipts");
    require(!receipts.payload["receipts"].empty(), "receipt queued for " + modeId);
    const auto& receipt = receipts.payload["receipts"].back();
    require(receipt["mode_id"].get<std::string>() == modeId, "receipt mode matches");
    require(receipt.contains("telemetry"), "receipt telemetry for " + modeId);
    require(receipt.contains("score"), "receipt score for " + modeId);

    gameplay.handleGameplayCommand("fel.arena.flush_receipts", {{"persist_to_disk", true}}, "chain_flush");
  }

  physics.shutdown();
}

void venice_pickup_action_scores_and_reaches_win_target() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "basketball_h2h"}, {"user_id", "pickup_action"}},
              "pickup_action_start")
              .status == "ok",
          "pickup action session starts");

  bool matchComplete = false;
  for (int attempt = 0; attempt < 12 && !matchComplete; ++attempt) {
    const auto action = gameplay.handleGameplayCommand(
        "fel.pickup.action",
        {{"action", attempt % 3 == 0 ? "shoot" : (attempt % 3 == 1 ? "drive" : "crossover")},
         {"timing", 0.96F},
         {"success", true}},
        "pickup_action");
    require(action.status == "ok", "pickup action ok");
    require(action.payload["player_score"].get<int>() > 0, "pickup action scores");
    matchComplete = action.payload["match_complete"].get<bool>();
  }

  const auto modeState =
      gameplay.handleGameplayQuery("fel.query.get_mode_state", {}, "pickup_action_state");
  require(modeState.payload["pickup"]["win_target"].get<int>() == 21,
          "pickup win target aligned to 21");
  require(modeState.payload["pickup"]["player_score"].get<int>() >= 21 ||
              modeState.payload["pickup"]["match_complete"].get<bool>(),
          "pickup reaches win threshold");
}

void basketball_3v3_hot_streak_three_pointer() {
  using nexus::gameplay::OutcomeSportMode;

  OutcomeSportMode basketball;
  basketball.reset("basketball_3v3");
  for (int i = 0; i < 3; ++i) {
    require(basketball.pulse({{"success", true},
                              {"timing", 0.95F},
                              {"shot_type", "three_pointer"}})
                .isOk(),
            "3v3 three-pointer pulse for hot streak");
  }
  require(basketball.stateJson().value("hot_streak", false) == true,
          "hot streak flag at 3+ successes");
  require(basketball.stateJson().value("streak", 0) >= 3, "streak counter at 3+");
  require(basketball.stateJson().value("last_action", std::string()) == "three_pointer",
          "last action records three_pointer shot_type");
}

void basketball_3v3_session_end_dispatches_receipt() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "basketball_3v3"}, {"user_id", "streetball_receipt"}},
              "3v3_start")
              .status == "ok",
          "3v3 session starts");

  require(!gameplay.mode_runtime().shouldAutoEndSession(), "3v3 session starts incomplete");

  for (int i = 0; i < 8 && !gameplay.mode_runtime().shouldAutoEndSession(); ++i) {
    const auto pulse = gameplay.handleGameplayCommand(
        "fel.sport.pulse",
        {{"success", true}, {"timing", 0.95F}, {"shot_type", "three_pointer"}},
        "3v3_pulse");
    require(pulse.status == "ok", "3v3 three-pointer pulse");
  }

  const auto end = gameplay.handleGameplayCommand(
      "fel.arena.end_session",
      {{"use_live_scores", true}},
      "3v3_end");
  require(end.status == "ok", "3v3 session ends");
  require(end.payload["outcome"].get<std::string>() == "win", "3v3 win outcome");

  const auto receipts =
      gameplay.handleGameplayQuery("fel.query.get_pending_session_receipts", {}, "3v3_receipts");
  require(!receipts.payload["receipts"].empty(), "3v3 receipt queued");
  require(receipts.payload["receipts"].back()["mode_id"].get<std::string>() == "basketball_3v3",
          "3v3 receipt mode id");
}

void court_carnival_session_end_dispatches_receipt() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);

  const auto mode = nexus::gameplay::ArenaModeRegistry::find("court_carnival");
  require(mode.has_value(), "court carnival registered");
  require(mode->scoringEnabled, "court carnival scoring enabled");

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "court_carnival"}, {"user_id", "carnival_receipt"}},
              "carnival_receipt_start")
              .status == "ok",
          "carnival receipt session starts");

  require(gameplay.handleGameplayCommand(
              "fel.carnival.trigger_pad",
              {{"pad", "trick_shot"}, {"timing", 0.95F}},
              "carnival_receipt_pad")
              .status == "ok",
          "carnival pad for receipt");
  require(gameplay.handleGameplayCommand("fel.carnival.roll_dice", {}, "carnival_receipt_dice")
              .status == "ok",
          "carnival dice for receipt");

  const auto end = gameplay.handleGameplayCommand(
      "fel.arena.end_session",
      {{"use_live_scores", true}},
      "carnival_receipt_end");
  require(end.status == "ok", "carnival session ends");
  require(end.payload["final_scores"]["player_score"].get<float>() > 0.0F,
          "carnival receipt uses C++ live player score");

  const auto receipts =
      gameplay.handleGameplayQuery("fel.query.get_pending_session_receipts", {}, "carnival_receipts");
  require(!receipts.payload["receipts"].empty(), "carnival receipt queued");
  require(receipts.payload["receipts"].back()["mode_id"].get<std::string>() == "court_carnival",
          "carnival receipt mode id");
  require(receipts.payload["receipts"].back()["score"].get<int>() > 0, "carnival receipt score from sim");
  require(receipts.payload["receipts"].back()["telemetry"]["mode_specific"]["carnival"].is_object(),
          "carnival receipt includes mode_specific carnival state");
}

void venice_pickup_session_end_dispatches_receipt() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);

  const auto mode = nexus::gameplay::ArenaModeRegistry::find("basketball_h2h");
  require(mode.has_value(), "venice pickup mode registered");
  require(mode->scoringEnabled, "venice pickup scoring enabled");

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "venice_pickup"}, {"user_id", "pickup_receipt"}},
              "pickup_receipt_start")
              .status == "ok",
          "venice_pickup alias session starts");

  const auto session =
      gameplay.handleGameplayQuery("fel.query.get_session_state", {}, "pickup_receipt_session");
  require(session.payload["arena"]["mode_id"].get<std::string>() == "basketball_h2h",
          "venice_pickup alias resolves to basketball_h2h");

  for (int attempt = 0; attempt < 12 && !gameplay.mode_runtime().shouldAutoEndSession(); ++attempt) {
    const auto action = gameplay.handleGameplayCommand(
        "fel.pickup.action",
        {{"action", attempt % 3 == 0 ? "shoot" : (attempt % 3 == 1 ? "drive" : "crossover")},
         {"timing", 0.96F},
         {"success", true}},
        "pickup_receipt_action");
    require(action.status == "ok", "pickup receipt action ok");
  }

  require(gameplay.mode_runtime().shouldAutoEndSession(), "pickup match complete before end_session");

  const auto end = gameplay.handleGameplayCommand(
      "fel.arena.end_session",
      {{"use_live_scores", true}},
      "pickup_receipt_end");
  require(end.status == "ok", "pickup session ends");
  require(end.payload["outcome"].get<std::string>() == "win", "pickup win outcome");
  require(end.payload["final_scores"]["player_score"].get<float>() >= 21.0F,
          "pickup receipt uses C++ live player score");

  const auto receipts =
      gameplay.handleGameplayQuery("fel.query.get_pending_session_receipts", {}, "pickup_receipts");
  require(!receipts.payload["receipts"].empty(), "pickup receipt queued");
  require(receipts.payload["receipts"].back()["mode_id"].get<std::string>() == "basketball_h2h",
          "pickup receipt mode id");
  require(receipts.payload["receipts"].back()["score"].get<int>() >= 21, "pickup receipt score from sim");
}

void karate_h2h_session_end_dispatches_receipt() {
  nexus::creative::VoxelWorld world;
  nexus::creative::WorldManipulator manipulator(world);
  nexus::gameplay::GameplayApplication gameplay(manipulator, world);

  const auto mode = nexus::gameplay::ArenaModeRegistry::find("karate_h2h");
  require(mode.has_value(), "karate h2h registered");
  require(mode->scoringEnabled, "karate h2h scoring enabled");

  require(gameplay.handleGameplayCommand(
              "fel.arena.start_session",
              {{"mode_id", "karate_h2h"}, {"user_id", "karate_h2h_receipt"}},
              "karate_h2h_receipt_start")
              .status == "ok",
          "karate h2h receipt session starts");

  require(!gameplay.mode_runtime().shouldAutoEndSession(), "karate h2h starts at full HP");

  for (int i = 0; i < 12 && !gameplay.mode_runtime().shouldAutoEndSession(); ++i) {
    const auto pulse = gameplay.handleGameplayCommand(
        "fel.sport.pulse",
        {{"success", true}, {"timing", 0.95F}, {"action", "heavy_strike"}},
        "karate_h2h_receipt_pulse");
    require(pulse.status == "ok", "karate h2h heavy strike pulse");
  }

  require(gameplay.mode_runtime().shouldAutoEndSession(), "karate h2h KO ends match");

  const auto end = gameplay.handleGameplayCommand(
      "fel.arena.end_session",
      {{"use_live_scores", true}},
      "karate_h2h_receipt_end");
  require(end.status == "ok", "karate h2h session ends");
  require(end.payload["outcome"].get<std::string>() == "win", "karate h2h win by HP KO");

  const auto receipts =
      gameplay.handleGameplayQuery("fel.query.get_pending_session_receipts", {}, "karate_h2h_receipts");
  require(!receipts.payload["receipts"].empty(), "karate h2h receipt queued");
  require(receipts.payload["receipts"].back()["mode_id"].get<std::string>() == "karate_h2h",
          "karate h2h receipt mode id");
  require(receipts.payload["receipts"].back().contains("telemetry"), "karate h2h receipt telemetry");
  require(
      receipts.payload["receipts"].back()["telemetry"]["mode_specific"]["outcome_sport"].is_object(),
      "karate h2h receipt includes outcome_sport state");
}

} // namespace

auto main() -> int {
  fitness_data_snapshots_are_thread_safe();
  fitness_partial_updates_preserve_other_metrics();
  fitness_values_are_clamped_and_invalid_params_rejected();
  voxel_parser_maps_fel_creative_commands();
  voxel_parser_lowers_terrain();
  voxel_parser_flattens_terrain_above_target();
  voxel_parser_paints_existing_solids_only();
  voxel_parser_passes_through_set_voxels_and_fill_region();
  voxel_parser_rejects_invalid_creative_params();
  gameplay_session_state_query_returns_coherent_payload();
  arena_mode_registry_lists_nineteen_modes();
  arena_mode_registry_production_modes_match_validate_script();
  gameplay_manager_evaluates_volleyball_outcome();
  outcome_sport_mode_mechanics_and_session_scores();
  karate_h2h_sport_pulse_hp_combat();
  arena_session_end_dispatches_receipt_and_bridge_messages();
  dunk_contest_lifecycle_generates_win_receipt();
  arena_pause_resume_preserves_session();
  session_receipt_flush_keeps_queue_when_http_disabled();
  session_receipt_disk_keyed_by_session_id();
  hud_poll_returns_tick_frame_payload();
  fel_bridge_websocket_stub_sends_outbound();
  hud_relay_websocket_stub_emits_frames();
  session_receipt_http_stub_posts_localhost_contract();
  session_receipt_live_http_success_does_not_count_disk_queue();
  session_receipt_live_http_non_2xx_requeues_without_disk();
  karate_mode_input_strike_advances_wave();
  mode_runtime_tracks_dunk_combo_metrics();
  venue_volume_overlap_triggers_travel();
  exercise_demo_pipeline_maps_production_modes();
  physics_intent_queue_is_consumed_on_step();
  engine_tick_runs_physics_before_gameplay_update();
  gameplay_update_drains_agent_commands_before_throw_catch();
  prq_engine_uses_baseline_until_fitness_metrics_arrive();
  prq_engine_scores_measured_fitness_snapshot();
  arcade_physics_maps_prq_75();
  mode_runtime_uses_measured_prq_for_state_and_physics();
  dunk_contest_charge_release_scores();
  karate_endless_wave_spawns();
  karate_endless_local_coop_wave_survival();
  end_session_use_live_scores_resolves_mode_runtime();
  end_session_idempotent_returns_last_result();
  fitness_partial_update_rejects_empty_params();
  fitness_update_rejects_non_finite_values();
  bridge_map_loaded_uses_measured_prq();
  mode_runtime_rejects_non_object_snow_and_scene_params();
  snowboarding_action_payloads_are_objects();
  flagship_basketball_dunk_validate_only_integration();
  flagship_karate_kata_validate_only_integration();
  flagship_venice_pickup_validate_only_integration();
  flagship_court_carnival_validate_only_integration();
  flagship_gymnastics_validate_only_integration();
  flagship_brain_brawl_validate_only_integration();
  flagship_skateboarding_validate_only_integration();
  flagship_snowboarding_validate_only_integration();
  flagship_surfing_validate_only_integration();
  flagship_outcome_sport_validate_only_integration();
  soccer_penalty_validate_only_integration();
  flagship_who_scene_it_validate_only_integration();
  session_receipt_body_matches_api_contract();
  flagship_modes_emit_post_ready_receipts();
  venice_pickup_action_scores_and_reaches_win_target();
  venice_pickup_session_end_dispatches_receipt();
  basketball_3v3_hot_streak_three_pointer();
  basketball_3v3_session_end_dispatches_receipt();
  court_carnival_session_end_dispatches_receipt();
  karate_h2h_session_end_dispatches_receipt();
  text_prompt_adapter_maps_beach_arena_prompt();
  gameplay_from_text_executes_mixed_plan();
  agent_router_routes_from_text_to_gameplay();
  game_prompt_adapter_maps_dunk_contest_prompt();
  game_prompt_adapter_builds_spec_from_gemini_hints();
  game_prompt_adapter_rejects_invalid_gemini_mode_id();
  game_prompt_adapter_force_template_skips_gemini();
  game_prompt_adapter_covers_all_playable_modes();
  game_prompt_adapter_normalizes_mode_aliases();
  game_prompt_adapter_sanitize_llm_json_strips_markdown_fence();
  game_prompt_adapter_gemini_partial_fallback_keeps_hints();
  game_prompt_adapter_refine_swaps_to_soccer_from_follow_up();
  gemini_game_prompt_client_stub_transport_returns_hints();
  nexus_ai_studio_config_parses_api_key_env_reference();
  nexus_ai_studio_config_builds_generate_content_url();
  parse_game_prompt_without_key_uses_template_backend();
  gameplay_generate_game_produces_spec_and_session();
  gameplay_refine_game_harder_adjusts_difficulty();
  nexus_sprint_live_modes_agent_contract_integration();
  std::fprintf(stderr, "PASS: nexus_gameplay_test\n");
  return 0;
}
