// 3D arena space types shared by Karate, Dunk Contest, and Basketball modes.
// The C++ layer owns positions and clip-name strings; the Swift/Metal renderer
// reads these via stateJson() and drives animation playback.
#pragma once

#include <cstdint>
#include <cmath>
#include <string>
#include <string_view>

namespace nexus::gameplay {

// ──────────────────────────────────────────────────────────────────────────────
// Minimal 3D math — no heap, no SIMD, just the game-logic contract
// ──────────────────────────────────────────────────────────────────────────────
struct Vec3 {
  float x{0.0F};
  float y{0.0F};
  float z{0.0F};

  [[nodiscard]] constexpr auto operator+(Vec3 b) const noexcept -> Vec3 {
    return {x + b.x, y + b.y, z + b.z};
  }
  [[nodiscard]] constexpr auto operator-(Vec3 b) const noexcept -> Vec3 {
    return {x - b.x, y - b.y, z - b.z};
  }
  [[nodiscard]] constexpr auto operator*(float s) const noexcept -> Vec3 {
    return {x * s, y * s, z * s};
  }
  [[nodiscard]] auto length() const noexcept -> float {
    return std::sqrt(x * x + y * y + z * z);
  }
  [[nodiscard]] auto normalized() const noexcept -> Vec3 {
    const float len = length();
    return len > 1e-6F ? Vec3{x / len, y / len, z / len} : Vec3{};
  }
  [[nodiscard]] constexpr auto dot(Vec3 b) const noexcept -> float {
    return x * b.x + y * b.y + z * b.z;
  }
  [[nodiscard]] constexpr auto distanceTo(Vec3 b) const noexcept -> float {
    return (*this - b).length();
  }
};

// ──────────────────────────────────────────────────────────────────────────────
// Animation clip descriptor — maps a game action to a free-asset clip name.
// Clip names follow the convention used by Meshy / Mixamo freebies:
//   "{verb}_{descriptor}"  e.g. "dunk_360_eastbay", "karate_kick_roundhouse"
// The renderer plays the clip by name; blend weight supports crossfade.
// ──────────────────────────────────────────────────────────────────────────────
struct AnimClip {
  std::string name{"idle_stand"};   // clip identifier for renderer
  float blendWeight{1.0F};          // 0 = nothing, 1 = full
  bool  loop{true};                 // true = looping (idle/run), false = one-shot
  float speedScale{1.0F};           // playback rate multiplier
};

// ──────────────────────────────────────────────────────────────────────────────
// Character state in 3D — position, velocity, facing, and current anim clip.
// Updated by each mode's update() and exposed via stateJson().
// ──────────────────────────────────────────────────────────────────────────────
struct CharacterState3D {
  Vec3  position{};
  Vec3  velocity{};
  float yawDegrees{0.0F};    // horizontal facing in world-space degrees
  AnimClip animClip{};

  void moveToward(Vec3 target, float speed, double dt) noexcept {
    const Vec3 dir = (target - position).normalized();
    const float dist = position.distanceTo(target);
    const float step = speed * static_cast<float>(dt);
    if (dist <= step) {
      position = target;
      velocity = {};
    } else {
      velocity = dir * speed;
      position = position + dir * step;
      // update facing from velocity direction
      if (velocity.x != 0.0F || velocity.z != 0.0F) {
        yawDegrees = std::atan2(velocity.x, velocity.z) * (180.0F / 3.14159265F);
      }
    }
  }

  void applyGravity(float gravity, double dt) noexcept {
    velocity.y -= gravity * static_cast<float>(dt);
    position.y += velocity.y * static_cast<float>(dt);
    if (position.y < 0.0F) {
      position.y = 0.0F;
      velocity.y = 0.0F;
    }
  }

  void setClip(std::string clipName, bool looping = true, float speed = 1.0F) {
    animClip.name       = std::move(clipName);
    animClip.loop       = looping;
    animClip.speedScale = speed;
    animClip.blendWeight = 1.0F;
  }
};

// ──────────────────────────────────────────────────────────────────────────────
// Arena layout constants (in meters)
// ──────────────────────────────────────────────────────────────────────────────
struct ArenaLayout3D {
  float width{20.0F};       // x axis span
  float depth{20.0F};       // z axis span
  float ceilingHeight{8.0F}; // max y

  [[nodiscard]] auto clampToFloor(Vec3 pos) const noexcept -> Vec3 {
    return {
      std::max(-width * 0.5F,  std::min(pos.x, width * 0.5F)),
      std::max(0.0F,           std::min(pos.y, ceilingHeight)),
      std::max(-depth * 0.5F,  std::min(pos.z, depth * 0.5F))
    };
  }
};

// Specific arena presets used by each mode
namespace arenas {
  inline constexpr ArenaLayout3D kDojo    { 16.0F,  12.0F,  5.0F };
  inline constexpr ArenaLayout3D kCourt   { 28.0F,  15.0F, 10.0F };
  inline constexpr ArenaLayout3D kSoccer  { 40.0F,  10.0F, 25.0F };
  inline constexpr ArenaLayout3D kFootball{ 91.0F,   6.0F, 49.0F };
} // namespace arenas

} // namespace nexus::gameplay
