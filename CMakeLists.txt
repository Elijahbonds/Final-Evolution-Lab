cmake_minimum_required(VERSION 3.24)

project(NEXUSEngine VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

option(NEXUS_BUILD_TESTS "Build NEXUS tests" ON)
option(NEXUS_BUILD_RUNTIME "Build the NEXUS runtime executable" ON)
option(NEXUS_ENABLE_RENDERER "Build SDL3/Vulkan renderer targets" ON)

if(NEXUS_BUILD_RUNTIME AND NOT NEXUS_ENABLE_RENDERER)
  message(STATUS "NEXUS_BUILD_RUNTIME disabled because renderer is off")
  set(NEXUS_BUILD_RUNTIME OFF CACHE BOOL "Build the NEXUS runtime executable" FORCE)
endif()

if(NEXUS_ENABLE_RENDERER)
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

add_library(nexus_core
  engine/core/src/log.cpp
)
target_include_directories(nexus_core PUBLIC engine/core/include)

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
)
target_include_directories(nexus_ai_interface PUBLIC engine/ai_interface/include)
target_link_libraries(nexus_ai_interface PUBLIC nexus_core nexus_creative nexus_generative nlohmann_json::nlohmann_json)
if(UNIX AND NOT APPLE)
  target_link_libraries(nexus_ai_interface PUBLIC pthread)
endif()

add_library(nexus_gameplay
  app/gameplay/src/dunk_contest.cpp
  app/gameplay/src/fitness_data.cpp
  app/gameplay/src/gameplay_application.cpp
  app/gameplay/src/throw_catch_physics.cpp
  app/gameplay/src/voxel_command_parser.cpp
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

if(NEXUS_ENABLE_RENDERER)
  add_library(nexus_renderer
    engine/assets/src/mesh_importer.cpp
    engine/renderer/src/arena_scene.cpp
    engine/renderer/src/camera.cpp
    engine/renderer/src/mesh.cpp
    engine/renderer/src/scene.cpp
    engine/renderer/src/vulkan_renderer.cpp
  )
  target_include_directories(nexus_renderer PUBLIC engine/renderer/include engine/assets/include)
  target_link_libraries(nexus_renderer PUBLIC nexus_core nexus_assets SDL3::SDL3 Vulkan::Vulkan)

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

if(NEXUS_BUILD_TESTS)
  enable_testing()
  add_executable(nexus_protocol_test tests/unit/ai_interface/command_test.cpp)
  target_link_libraries(nexus_protocol_test PRIVATE nexus_ai_interface)
  add_test(NAME nexus_protocol_test COMMAND nexus_protocol_test)

  add_executable(nexus_gameplay_test tests/unit/gameplay/gameplay_test.cpp)
  target_link_libraries(nexus_gameplay_test PRIVATE nexus_gameplay)
  add_test(NAME nexus_gameplay_test COMMAND nexus_gameplay_test)

  add_executable(nexus_generative_test tests/unit/generative/generative_test.cpp)
  target_link_libraries(nexus_generative_test PRIVATE nexus_generative nexus_ai_interface)
  add_test(NAME nexus_generative_test COMMAND nexus_generative_test)
  set_tests_properties(nexus_generative_test PROPERTIES WORKING_DIRECTORY ${CMAKE_SOURCE_DIR})

  add_executable(nexus_physics_test tests/unit/physics/physics_test.cpp)
  target_link_libraries(nexus_physics_test PRIVATE nexus_physics)
  add_test(NAME nexus_physics_test COMMAND nexus_physics_test)
endif()
