#include "nexus/core/nexus_cartridge_runtime.h"

#include "nexus/core/log.h"

#include <array>
#include <cstring>
#include <fstream>
#include <iterator>

namespace nexus::core {

namespace {

constexpr std::array<char, 8> kMagic{'N', 'E', 'X', 'U', 'S', 'R', 'O', 'M'};
constexpr std::size_t kHeaderBytes = 20;
constexpr std::size_t kInstructionBytes = 8;

auto readU16(const std::uint8_t* p) -> std::uint16_t {
  return static_cast<std::uint16_t>(p[0]) |
         (static_cast<std::uint16_t>(p[1]) << 8);
}

auto readU32(const std::uint8_t* p) -> std::uint32_t {
  return static_cast<std::uint32_t>(p[0]) |
         (static_cast<std::uint32_t>(p[1]) << 8) |
         (static_cast<std::uint32_t>(p[2]) << 16) |
         (static_cast<std::uint32_t>(p[3]) << 24);
}

auto readI32(const std::uint8_t* p) -> std::int32_t {
  return static_cast<std::int32_t>(readU32(p));
}

auto isKnownOpcode(std::uint8_t op) -> bool {
  switch (static_cast<CartridgeOpcode>(op)) {
  case CartridgeOpcode::kNop:
  case CartridgeOpcode::kSet:
  case CartridgeOpcode::kAdd:
  case CartridgeOpcode::kSub:
  case CartridgeOpcode::kMul:
  case CartridgeOpcode::kAddReg:
  case CartridgeOpcode::kSpawn:
  case CartridgeOpcode::kMove:
  case CartridgeOpcode::kScore:
  case CartridgeOpcode::kJmp:
  case CartridgeOpcode::kJnz:
  case CartridgeOpcode::kYield:
  case CartridgeOpcode::kHalt:
    return true;
  }
  return false;
}

} // namespace

auto NexusCartridgeRuntime::loadFromMemory(std::span<const std::uint8_t> payload)
    -> Result<void> {
  m_program.clear();
  m_header = CartridgeHeader{};

  const std::uint8_t* data = payload.data();
  std::size_t size = payload.size();
  std::size_t cursor = 0;

  const bool hasMagic =
      size >= kHeaderBytes &&
      std::memcmp(data, kMagic.data(), kMagic.size()) == 0;

  if (hasMagic) {
    m_header.hasMagic = true;
    m_header.version = readU16(data + 8);
    m_header.frameRateHz = readU16(data + 10);
    m_header.instructionCount = readU32(data + 12);
    m_header.entryPoint = readU32(data + 16);
    cursor = kHeaderBytes;
  } else {
    // Headerless raw .bin stream.
    m_header.hasMagic = false;
    m_header.version = 0;
    m_header.frameRateHz = 60;
    m_header.entryPoint = 0;
  }

  if (m_header.frameRateHz == 0) {
    m_header.frameRateHz = 60;
  }

  const std::size_t bodyBytes = size - cursor;
  std::size_t available = bodyBytes / kInstructionBytes;
  std::size_t count = available;
  if (hasMagic && m_header.instructionCount > 0) {
    count = m_header.instructionCount < available ? m_header.instructionCount
                                                  : available;
  }
  if (count == 0) {
    return Result<void>::err("Cartridge has no decodable instructions");
  }

  m_program.reserve(count);
  for (std::size_t i = 0; i < count; ++i) {
    const std::uint8_t* p = data + cursor + i * kInstructionBytes;
    if (!isKnownOpcode(p[0])) {
      return Result<void>::err("Cartridge contains unknown opcode at index " +
                               std::to_string(i));
    }
    CartridgeInstruction instr{};
    instr.opcode = static_cast<CartridgeOpcode>(p[0]);
    instr.reg = p[1];
    instr.imm = readI32(p + 4);
    m_program.push_back(instr);
  }
  m_header.instructionCount = static_cast<std::uint32_t>(m_program.size());

  reset();
  NEXUS_LOG_INFO(LogChannel::kCore,
                 std::string("Loaded cartridge (") +
                     (hasMagic ? "nexusrom" : "raw bin") + ", " +
                     std::to_string(m_program.size()) + " instr, " +
                     std::to_string(m_header.frameRateHz) + "Hz) — " +
                     std::string(runtimeLabel()));
  return Result<void>::ok();
}

auto NexusCartridgeRuntime::loadFromFile(const std::string& path) -> Result<void> {
  std::ifstream file(path, std::ios::binary);
  if (!file.is_open()) {
    return Result<void>::err("Cannot open cartridge file: " + path);
  }
  std::vector<std::uint8_t> bytes((std::istreambuf_iterator<char>(file)),
                                  std::istreambuf_iterator<char>());
  if (bytes.empty()) {
    return Result<void>::err("Cartridge file is empty: " + path);
  }
  return loadFromMemory(bytes);
}

void NexusCartridgeRuntime::reset() {
  m_registers.fill(0);
  m_entities.clear();
  m_pc = m_header.entryPoint < m_program.size() ? m_header.entryPoint : 0;
  m_frameIndex = 0;
  m_score = 0;
  m_halted = false;
  m_faulted = false;
}

auto NexusCartridgeRuntime::reg(std::size_t index) const -> std::int32_t {
  return index < m_registers.size() ? m_registers[index] : 0;
}

auto NexusCartridgeRuntime::tick() -> CartridgeFrameState {
  CartridgeFrameState frame{};
  frame.frameIndex = m_frameIndex;

  if (m_halted || m_faulted) {
    frame.halted = m_halted;
    frame.faulted = m_faulted;
    frame.score = m_score;
    frame.entityCount = m_entities.size();
    return frame;
  }

  std::uint32_t cycles = 0;
  bool yielded = false;
  while (cycles < kMaxCyclesPerFrame) {
    ++cycles;
    if (m_pc >= m_program.size()) {
      m_halted = true; // ran off the end -> halt
      break;
    }
    const CartridgeInstruction in = m_program[m_pc];
    const std::size_t r = in.reg % kRegisterCount;
    bool branched = false;

    switch (in.opcode) {
    case CartridgeOpcode::kNop:
      break;
    case CartridgeOpcode::kSet:
      m_registers[r] = in.imm;
      break;
    case CartridgeOpcode::kAdd:
      m_registers[r] += in.imm;
      break;
    case CartridgeOpcode::kSub:
      m_registers[r] -= in.imm;
      break;
    case CartridgeOpcode::kMul:
      m_registers[r] *= in.imm;
      break;
    case CartridgeOpcode::kAddReg:
      m_registers[r] +=
          m_registers[static_cast<std::size_t>(in.imm) % kRegisterCount];
      break;
    case CartridgeOpcode::kSpawn:
      if (m_entities.size() < kMaxEntities) {
        CartridgeEntity e{};
        e.id = m_registers[r];
        e.x = static_cast<float>(in.imm);
        m_entities.push_back(e);
      }
      break;
    case CartridgeOpcode::kMove: {
      const auto idx = static_cast<std::size_t>(m_registers[r]);
      if (idx < m_entities.size()) {
        m_entities[idx].vx = static_cast<float>(in.imm);
      }
      break;
    }
    case CartridgeOpcode::kScore:
      m_score += in.imm;
      break;
    case CartridgeOpcode::kJmp:
      if (in.imm >= 0 && static_cast<std::size_t>(in.imm) < m_program.size()) {
        m_pc = static_cast<std::uint32_t>(in.imm);
        branched = true;
      } else {
        m_faulted = true;
      }
      break;
    case CartridgeOpcode::kJnz:
      if (m_registers[r] != 0) {
        if (in.imm >= 0 &&
            static_cast<std::size_t>(in.imm) < m_program.size()) {
          m_pc = static_cast<std::uint32_t>(in.imm);
          branched = true;
        } else {
          m_faulted = true;
        }
      }
      break;
    case CartridgeOpcode::kYield:
      yielded = true;
      break;
    case CartridgeOpcode::kHalt:
      m_halted = true;
      break;
    }

    if (m_faulted) {
      break;
    }
    if (!branched) {
      ++m_pc;
    }
    if (yielded || m_halted) {
      break;
    }
  }

  if (cycles >= kMaxCyclesPerFrame && !m_halted && !yielded) {
    // Watchdog: a frame that never yields is treated as a fault, not a hang.
    m_faulted = true;
    NEXUS_LOG_WARN(LogChannel::kCore,
                   "Cartridge frame watchdog tripped (no YIELD/HALT) — faulting");
  }

  // Advance entity positions by their per-frame velocity (1 frame step).
  for (CartridgeEntity& e : m_entities) {
    e.x += e.vx;
    e.y += e.vy;
  }

  ++m_frameIndex;
  frame.frameIndex = m_frameIndex;
  frame.score = m_score;
  frame.entityCount = m_entities.size();
  frame.halted = m_halted;
  frame.faulted = m_faulted;
  return frame;
}

auto NexusCartridgeRuntime::run(std::uint64_t maxFrames) -> CartridgeFrameState {
  CartridgeFrameState frame{};
  frame.frameIndex = m_frameIndex;
  frame.score = m_score;
  frame.entityCount = m_entities.size();
  for (std::uint64_t i = 0; i < maxFrames; ++i) {
    frame = tick();
    if (m_halted || m_faulted) {
      break;
    }
  }
  return frame;
}

} // namespace nexus::core
