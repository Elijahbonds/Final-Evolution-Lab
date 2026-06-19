#include "nexus/ai/agent_server.h"
#include "nexus/ai/command_router.h"
#include "nexus/creative/voxel_world.h"
#include "nexus/creative/world_manipulator.h"
#include "nexus/gameplay/fitness_data.h"
#include "nexus/gameplay/gameplay_application.h"
#include "nexus/gameplay/voxel_command_parser.h"
#include "nexus/physics/physics_world.h"

#include <cstdio>
#include <cstdlib>
#include <string>
#include <vector>

namespace {

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

void fitness_data_snapshots_are_thread_safe() {
  nexus::gameplay::ThreadSafeFitnessData fitness;
  fitness.update({0.75F, 0.5F, 0.25F}, {0.8F, 0.9F, 1});

  const auto snapshot = fitness.read_view().snapshot();
  require(snapshot.revision == 1, "fitness revision increments");
  require(snapshot.frc.mobilityScore == 0.75F, "frc mobility stored");
  require(snapshot.iap.breathPhase == 1, "iap breath phase stored");
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
  require(response.payload["throw_catch"]["power_multiplier"].is_number(),
          "session state includes throw-catch power");
  require(response.payload["agent"]["processed_messages"].get<std::size_t>() == 2,
          "session state includes processed agent messages");
  require(response.payload["agent"]["latest_errors"].get<std::size_t>() == 1,
          "session state includes agent error count");

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
  require(physics.pendingIntentCount() == 1, "throw phase queued physics intent");
  physics.step(1.0 / 60.0);
  require(physics.pendingIntentCount() == 0, "throw intent consumed on step");
  require(physics.lastConsumedIntents().size() == 1, "throw intent recorded");
  require(physics.lastConsumedIntents().front().kind ==
              nexus::physics::PhysicsIntentKind::kApplyImpulse,
          "throw intent applies impulse");
  require(physics.lastConsumedIntents().front().impulseOrVelocity.y > 12.0F,
          "throw impulse scales with fitness power");

  server.shutdown();
  router.shutdown();
  physics.shutdown();
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
  physics_intent_queue_is_consumed_on_step();
  gameplay_update_drains_agent_commands_before_throw_catch();
  return 0;
}
