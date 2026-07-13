cmake_minimum_required(VERSION 3.24)

project(NEXUSEngine VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

option(NEXUS_BUILD_TESTS "Build NEXUS tests" ON)
option(NEXUS_BUILD_RUNTIME "Build the NEXUS runtime executable" ON)
option(NEXUS_BUILD_AGENT_CLI "Build headless nexus_agent_cli for external agents" ON)
if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
  set(NEXUS_BUILD_AGENT_CLI OFF CACHE BOOL "Build headless nexus_agent_cli for external agents" FORCE)
endif()
option(NEXUS_ENABLE_RENDERER "Build SDL3/Vulkan renderer targets" ON)
option(NEXUS_ENABLE_METAL_RENDERER "Build Metal-only renderer for iOS embed (no Vulkan/SDL)" OFF)

set(NEXUS_BUILD_ANY_RENDERER OFF)
if(NEXUS_ENABLE_RENDERER OR NEXUS_ENABLE_METAL_RENDERER)
  set(NEXUS_BUILD_ANY_RENDERER ON)
endif()

if(NEXUS_BUILD_RUNTIME AND NOT NEXUS_ENABLE_RENDERER)
  message(STATUS "NEXUS_BUILD_RUNTIME disabled because renderer is off")
  set(NEXUS_BUILD_RUNTIME OFF CACHE BOOL "Build the NEXUS runtime executable" FORCE)
endif()

if(NEXUS_ENABLE_RENDERER AND NOT NEXUS_ENABLE_METAL_RENDERER)
  find_package(Vulkan REQUIRED)
  find_package(SDL3 REQUIRED CONFIG COMPONENTS SDL3-shared)
endif()

find_package(nlohmann_json QUIET)

if(NOT nlohmann_json_FOUND)
  include(FetchContent)
  FetchContent_Declare(
    nlohmann_json
    URL https://github.com/nlohmann/json/releases/download/v3.11.3/json.tar.xz
  )
  FetchContent_MakeAvailable(nlohmann_json)
endif()

# FetchContent INTERFACE includes do not always propagate under iOS cross-compile.
if(DEFINED nlohmann_json_SOURCE_DIR)
  include_directories(BEFORE SYSTEM "${nlohmann_json_SOURCE_DIR}/include")
elseif(EXISTS "${CMAKE_BINARY_DIR}/_deps/nlohmann_json-src/include")
  include_directories(BEFORE SYSTEM "${CMAKE_BINARY_DIR}/_deps/nlohmann_json-src/include")
endif()

add_library(nexus_core
  engine/core/src/log.cpp
  engine/core/src/env_flag.cpp
  engine/core/src/dev_stats.cpp
  engine/core/src/perf_monitor.cpp
  engine/core/src/engine_scale_policy.cpp
  engine/core/src/job_system.cpp
  engine/core/src/nexus_cartridge_runtime.cpp
  engine/core/src/http_client.cpp
  engine/core/src/websocket_client.cpp
)
find_package(Threads REQUIRED)
target_include_directories(nexus_core PUBLIC engine/core/include)
target_link_libraries(nexus_core PUBLIC nlohmann_json::nlohmann_json Threads::Threads)

add_library(nexus_physics
  engine/physics/src/physics_world.cpp
)
target_include_directories(nexus_physics PUBLIC engine/physics/include)
target_link_libraries(nexus_physics PUBLIC nexus_core)

add_library(nexus_creative
  engine/creative/src/voxel_world.cpp
  engine/creative/src/world_manipulator.cpp
)
target_include_directories(nexus_creative PUBLIC engine/creative/include)
target_link_libraries(nexus_creative PUBLIC nexus_core nlohmann_json::nlohmann_json)

add_library(nexus_assets
  engine/assets/src/asset_manifest.cpp
)
target_include_directories(nexus_assets PUBLIC engine/assets/include)
target_link_libraries(nexus_assets PUBLIC nexus_core nlohmann_json::nlohmann_json)

add_library(nexus_luma
  engine/luma/src/luma_adapter.cpp
)
target_include_directories(nexus_luma PUBLIC engine/luma/include)
target_link_libraries(nexus_luma PUBLIC nexus_core nlohmann_json::nlohmann_json)

add_library(nexus_generative
  engine/generative/src/environment_chunk_index.cpp
  engine/generative/src/environment_chunk_merger.cpp
  engine/generative/src/environment_scan_importer.cpp
  engine/generative/src/environment_scan_types.cpp
  engine/generative/src/generative_adapter.cpp
  engine/generative/src/generative_pipeline.cpp
  engine/generative/src/generative_types.cpp
  engine/generative/src/manifest_registrar.cpp
  engine/generative/src/model_generator.cpp
  engine/generative/src/procedural_mesh.cpp
  engine/generative/src/scan_importer.cpp
)
target_include_directories(nexus_generative PUBLIC engine/generative/include)
target_link_libraries(nexus_generative PUBLIC
  nexus_assets
  nexus_core
  nexus_creative
  nexus_luma
  nlohmann_json::nlohmann_json
)

add_library(nexus_ai_interface
  engine/ai_interface/src/agent_server.cpp
  engine/ai_interface/src/agent_transport.cpp
  engine/ai_interface/src/command_router.cpp
  engine/ai_interface/src/command_schema.cpp
  engine/ai_interface/src/gemini_game_prompt_client.cpp
  engine/ai_interface/src/nexus_ai_studio_config.cpp
  engine/ai_interface/src/text_prompt_adapter.cpp
)
target_include_directories(nexus_ai_interface PUBLIC engine/ai_interface/include)
target_link_libraries(nexus_ai_interface PUBLIC nexus_core nexus_creative nexus_generative nlohmann_json::nlohmann_json)
if(UNIX AND NOT APPLE)
  target_link_libraries(nexus_ai_interface PUBLIC pthread)
endif()

add_library(nexus_gameplay
  app/gameplay/src/arena_mode_registry.cpp
  app/gameplay/src/arena_session_manager.cpp
  app/gameplay/src/arcade_physics.cpp
  app/gameplay/src/brain_brawl_mode.cpp
  app/gameplay/src/combat_system.cpp
  app/gameplay/src/court_carnival_mode.cpp
  app/gameplay/src/dunk_contest_mode.cpp
  app/gameplay/src/enemy_ai.cpp
  app/gameplay/src/exercise_demo_pipeline.cpp
  app/gameplay/src/fel_bridge_service.cpp
  app/gameplay/src/fel_session_types.cpp
  app/gameplay/src/fitness_data.cpp
  app/gameplay/src/football_kick_return_mode.cpp
  app/gameplay/src/game_prompt_adapter.cpp
  app/gameplay/src/gameplay_application.cpp
  app/gameplay/src/gameplay_manager.cpp
  app/gameplay/src/gymnastics_mode.cpp
  app/gameplay/src/health_system.cpp
  app/gameplay/src/home_run_derby_mode.cpp
  app/gameplay/src/hud_relay_service.cpp
  app/gameplay/src/karate_endless_mode.cpp
  app/gameplay/src/mode_runtime.cpp
  app/gameplay/src/outcome_sport_mode.cpp
  app/gameplay/src/prq_engine.cpp
  app/gameplay/src/qte_system.cpp
  app/gameplay/src/scan_envelope_mapper.cpp
  app/gameplay/src/session_receipt_client.cpp
  app/gameplay/src/soccer_penalty_mode.cpp
  app/gameplay/src/skateboarding_mode.cpp
  app/gameplay/src/snowboarding_mode.cpp
  app/gameplay/src/surfing_mode.cpp
  app/gameplay/src/tennis_rally_mode.cpp
  app/gameplay/src/golf_closest_pin_mode.cpp
  app/gameplay/src/volleyball_rally_mode.cpp
  app/gameplay/src/throw_catch_physics.cpp
  app/gameplay/src/venue_volume_registry.cpp
  app/gameplay/src/venice_pickup_mode.cpp
  app/gameplay/src/voxel_command_parser.cpp
  app/gameplay/src/wave_spawner.cpp
  app/gameplay/src/who_scene_it_mode.cpp
)
target_include_directories(nexus_gameplay PUBLIC app/gameplay/include)
target_link_libraries(nexus_gameplay PUBLIC
  nexus_core
  nexus_ai_interface
  nexus_creative
  nexus_generative
  nexus_physics
  nlohmann_json::nlohmann_json
)

if(NEXUS_BUILD_ANY_RENDERER)
  set(NEXUS_RENDERER_SOURCES
    engine/assets/src/mesh_importer.cpp
    engine/renderer/src/animation_player.cpp
    engine/renderer/src/arena_scene.cpp
    engine/renderer/src/camera.cpp
    engine/renderer/src/frustum.cpp
    engine/renderer/src/lighting.cpp
    engine/renderer/src/material.cpp
    engine/renderer/src/mesh.cpp
    engine/renderer/src/mesh_lod.cpp
    engine/renderer/src/post_process.cpp
    engine/renderer/src/scene.cpp
    engine/renderer/src/shadow_runtime.cpp
    engine/renderer/src/bloom_runtime.cpp
    engine/renderer/src/console_tier_lod.cpp
  )
  if(NEXUS_ENABLE_RENDERER AND NOT NEXUS_ENABLE_METAL_RENDERER)
    list(APPEND NEXUS_RENDERER_SOURCES engine/renderer/src/vulkan_renderer.cpp)
  endif()
  if(APPLE)
    list(APPEND NEXUS_RENDERER_SOURCES engine/renderer/src/metal_renderer.mm)
  else()
    list(APPEND NEXUS_RENDERER_SOURCES engine/renderer/src/metal_renderer_stub.cpp)
  endif()

  add_library(nexus_renderer ${NEXUS_RENDERER_SOURCES})
  target_include_directories(nexus_renderer PUBLIC engine/renderer/include engine/assets/include)
  target_link_libraries(nexus_renderer PUBLIC nexus_core nexus_assets nlohmann_json::nlohmann_json)
  if(NEXUS_ENABLE_RENDERER AND NOT NEXUS_ENABLE_METAL_RENDERER)
    target_link_libraries(nexus_renderer PUBLIC SDL3::SDL3 Vulkan::Vulkan)
  endif()
  if(APPLE)
    target_link_libraries(nexus_renderer PUBLIC "-framework Metal" "-framework QuartzCore" "-framework Foundation")
  endif()
endif()

if(NEXUS_ENABLE_RENDERER)
  add_library(nexus_engine
    engine/core/src/engine.cpp
  )
  target_link_libraries(nexus_engine PUBLIC
    nexus_core
    nexus_physics
    nexus_renderer
    nexus_ai_interface
  )
endif()

if(NEXUS_BUILD_RUNTIME)
  add_executable(nexus_runtime runtime/src/main.cpp)
  target_link_libraries(nexus_runtime PRIVATE
    nexus_engine
    nexus_gameplay
  )
endif()

if(NEXUS_BUILD_AGENT_CLI)
  add_library(nexus_agent_cli_lib STATIC
    tools/nexus_agent_cli/agent_cli_session.cpp
    tools/nexus_agent_cli/agent_http_listener.cpp
  )
  target_include_directories(nexus_agent_cli_lib PUBLIC tools/nexus_agent_cli)
  target_link_libraries(nexus_agent_cli_lib PUBLIC nexus_gameplay)

  add_executable(nexus_agent_cli tools/nexus_agent_cli/main.cpp)
  target_link_libraries(nexus_agent_cli PRIVATE nexus_agent_cli_lib)
endif()

if(NEXUS_BUILD_TESTS)
  enable_testing()
  add_executable(nexus_protocol_test tests/unit/ai_interface/command_test.cpp)
  target_link_libraries(nexus_protocol_test PRIVATE nexus_ai_interface)
  add_test(NAME nexus_protocol_test COMMAND nexus_protocol_test)

  if(NEXUS_BUILD_AGENT_CLI)
    add_executable(nexus_agent_cli_test tests/unit/ai_interface/agent_cli_test.cpp)
    target_link_libraries(nexus_agent_cli_test PRIVATE nexus_agent_cli_lib)
    add_test(NAME nexus_agent_cli_test COMMAND nexus_agent_cli_test)
  endif()

  add_executable(nexus_gameplay_test tests/unit/gameplay/gameplay_test.cpp)
  target_link_libraries(nexus_gameplay_test PRIVATE nexus_gameplay)
  if(APPLE)
    target_link_options(nexus_gameplay_test PRIVATE
      "LINKER:-force_load,$<TARGET_FILE:nexus_gameplay>")
  endif()
  add_test(NAME nexus_gameplay_test COMMAND nexus_gameplay_test)

  add_executable(nexus_scan_envelope_test tests/unit/gameplay/scan_envelope_test.cpp)
  target_link_libraries(nexus_scan_envelope_test PRIVATE nexus_gameplay)
  if(APPLE)
    target_link_options(nexus_scan_envelope_test PRIVATE
      "LINKER:-force_load,$<TARGET_FILE:nexus_gameplay>")
  endif()
  add_test(NAME nexus_scan_envelope_test COMMAND nexus_scan_envelope_test)

  add_executable(nexus_generative_test tests/unit/generative/generative_test.cpp)
  target_link_libraries(nexus_generative_test PRIVATE nexus_generative nexus_ai_interface)
  add_test(NAME nexus_generative_test COMMAND nexus_generative_test)
  set_tests_properties(nexus_generative_test PROPERTIES WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})

  add_executable(nexus_physics_test tests/unit/physics/physics_test.cpp)
  target_link_libraries(nexus_physics_test PRIVATE nexus_physics)
  add_test(NAME nexus_physics_test COMMAND nexus_physics_test)

  add_executable(nexus_physics_advanced_test tests/unit/physics/physics_advanced_test.cpp)
  target_link_libraries(nexus_physics_advanced_test PRIVATE nexus_physics)
  add_test(NAME nexus_physics_advanced_test COMMAND nexus_physics_advanced_test)

  add_executable(nexus_job_system_test tests/unit/core/job_system_test.cpp)
  target_link_libraries(nexus_job_system_test PRIVATE nexus_core)
  add_test(NAME nexus_job_system_test COMMAND nexus_job_system_test)

  add_executable(nexus_cartridge_test tests/unit/core/cartridge_runtime_test.cpp)
  target_link_libraries(nexus_cartridge_test PRIVATE nexus_core)
  add_test(NAME nexus_cartridge_test COMMAND nexus_cartridge_test)

  add_executable(nexus_scale_policy_test tests/unit/core/engine_scale_policy_test.cpp)
  target_link_libraries(nexus_scale_policy_test PRIVATE nexus_core)
  add_test(NAME nexus_scale_policy_test COMMAND nexus_scale_policy_test)

  add_executable(nexus_realtime_test tests/unit/core/websocket_test.cpp)
  target_link_libraries(nexus_realtime_test PRIVATE nexus_core)
  add_test(NAME nexus_realtime_test COMMAND nexus_realtime_test)

  if(NEXUS_ENABLE_RENDERER OR NEXUS_ENABLE_METAL_RENDERER)
    add_executable(nexus_renderer_test tests/unit/renderer/renderer_test.cpp)
    target_link_libraries(nexus_renderer_test PRIVATE nexus_renderer)
    add_test(NAME nexus_renderer_test COMMAND nexus_renderer_test)
    set_tests_properties(nexus_renderer_test PROPERTIES WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})

    add_executable(nexus_console_tier_test tests/unit/renderer/console_tier_test.cpp)
    target_link_libraries(nexus_console_tier_test PRIVATE nexus_renderer nexus_core)
    add_test(NAME nexus_console_tier_test COMMAND nexus_console_tier_test)
    set_tests_properties(nexus_console_tier_test PROPERTIES WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})
  endif()
endif()
