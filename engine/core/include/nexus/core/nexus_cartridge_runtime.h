#pragma once

// NEXUS virtual cartridge runtime (Workstream 3).
//
// HONEST LABELING: This is a *virtual* instruction/frame loop that loads NEXUS
// cartridge payloads (`.nexusrom` / raw `.bin`) and drives gameplay state. It is
// NOT a hardware-accurate console emulator (no PS2/PS3 CPU/GPU silicon model).
// It executes a small, well-defined NEXUS virtual ISA on a deterministic VM so
// authored cartridges run identically across mobile/desktop builds.
//
// Cartridge binary layout (.nexusrom):
//   [0..7]   magic  "NEXUSROM"
//   [8..9]   u16    version (little-endian)
//   [10..11] u16    frameRateHz
//   [12..15] u32    instructionCount
//   [16..19] u32    entryPoint (instruction index)
//   [20..]   instructions, 8 bytes each: [op u8][reg u8][pad u16][imm i32 LE]
// Raw `.bin` payloads with no magic are treated as a headerless instruction
// stream (version 0, 60 Hz, entry 0).

#include "nexus/core/result.h"

#include <array>
#include <cstddef>
#include <cstdint>
#include <span>
#include <string>
#include <string_view>
#include <vector>

namespace nexus::core {

enum class CartridgeOpcode : std::uint8_t {
  kNop = 0x00,
  kSet = 0x01,    // R[reg] = imm
  kAdd = 0x02,    // R[reg] += imm
  kSub = 0x03,    // R[reg] -= imm
  kMul = 0x04,    // R[reg] *= imm
  kAddReg = 0x05, // R[reg] += R[imm]
  kSpawn = 0x10,  // spawn entity id=R[reg] at x=imm
  kMove = 0x11,   // entity[R[reg]].vx = imm
  kScore = 0x12,  // score += imm
  kJmp = 0x20,    // pc = imm
  kJnz = 0x21,    // if R[reg] != 0 -> pc = imm
  kYield = 0x30,  // end current frame
  kHalt = 0xFF,   // stop execution
};

struct CartridgeInstruction {
  CartridgeOpcode opcode{CartridgeOpcode::kNop};
  std::uint8_t reg{0};
  std::int32_t imm{0};
};

struct CartridgeHeader {
  bool hasMagic{false};
  std::uint16_t version{0};
  std::uint16_t frameRateHz{60};
  std::uint32_t instructionCount{0};
  std::uint32_t entryPoint{0};
};

struct CartridgeEntity {
  std::int32_t id{0};
  float x{0.0F};
  float y{0.0F};
  float vx{0.0F};
  float vy{0.0F};
};

struct CartridgeFrameState {
  std::uint64_t frameIndex{0};
  std::int64_t score{0};
  std::size_t entityCount{0};
  bool halted{false};
  bool faulted{false};
};

class NexusCartridgeRuntime {
public:
  static constexpr std::size_t kRegisterCount = 16;
  static constexpr std::size_t kMaxEntities = 256;
  static constexpr std::uint32_t kMaxCyclesPerFrame = 100'000; // watchdog

  auto loadFromMemory(std::span<const std::uint8_t> payload) -> Result<void>;
  auto loadFromFile(const std::string& path) -> Result<void>;

  void reset();

  /// Executes instructions until a YIELD, HALT, fault, or cycle watchdog trip.
  /// Returns the frame snapshot. Deterministic for a given cartridge.
  auto tick() -> CartridgeFrameState;

  /// Runs up to maxFrames ticks or until halted.
  auto run(std::uint64_t maxFrames) -> CartridgeFrameState;

  [[nodiscard]] auto header() const -> const CartridgeHeader& { return m_header; }
  [[nodiscard]] auto isHalted() const -> bool { return m_halted; }
  [[nodiscard]] auto isFaulted() const -> bool { return m_faulted; }
  [[nodiscard]] auto frameIndex() const -> std::uint64_t { return m_frameIndex; }
  [[nodiscard]] auto score() const -> std::int64_t { return m_score; }
  [[nodiscard]] auto reg(std::size_t index) const -> std::int32_t;
  [[nodiscard]] auto entities() const -> const std::vector<CartridgeEntity>& {
    return m_entities;
  }
  [[nodiscard]] auto instructionCount() const -> std::size_t {
    return m_program.size();
  }

  /// Honest description of what this runtime is (and is not).
  [[nodiscard]] static auto runtimeLabel() -> std::string_view {
    return "NEXUS virtual cartridge runtime (deterministic VM; not hardware "
           "console emulation)";
  }

private:
  CartridgeHeader m_header{};
  std::vector<CartridgeInstruction> m_program;
  std::array<std::int32_t, kRegisterCount> m_registers{};
  std::vector<CartridgeEntity> m_entities;
  std::uint32_t m_pc{0};
  std::uint64_t m_frameIndex{0};
  std::int64_t m_score{0};
  bool m_halted{false};
  bool m_faulted{false};
};

} // namespace nexus::core
