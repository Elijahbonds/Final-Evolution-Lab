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

add_library(nexus_ai_interface
  engine/ai_interface/src/agent_server.cpp
  engine/ai_interface/src/agent_transport.cpp
  engine/ai_interface/src/command_router.cpp
  engine/ai_interface/src/command_schema.cpp
)
target_include_directories(nexus_ai_interface PUBLIC engine/ai_interface/include)
target_link_libraries(nexus_ai_interface PUBLIC nexus_core nexus_creative nlohmann_json::nlohmann_json)
if(UNIX AND NOT APPLE)
  target_link_libraries(nexus_ai_interface PUBLIC pthread)
endif()

add_library(nexus_gameplay
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
  nexus_physics
  nlohmann_json::nlohmann_json
)

if(NEXUS_ENABLE_RENDERER)
  add_library(nexus_renderer
    engine/renderer/src/vulkan_renderer.cpp
  )
  target_include_directories(nexus_renderer PUBLIC engine/renderer/include)
  target_link_libraries(nexus_renderer PUBLIC nexus_core SDL3::SDL3 Vulkan::Vulkan)

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
endif()
