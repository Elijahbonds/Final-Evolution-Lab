#include "nexus/core/nexus_cartridge_runtime.h"

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <string>
#include <vector>
#include <unistd.h>

namespace {

using nexus::core::CartridgeOpcode;

void require(bool condition, const char* message) {
  if (!condition) {
    std::fprintf(stderr, "FAIL: %s\n", message);
    std::exit(1);
  }
}

void appendU16(std::vector<std::uint8_t>& b, std::uint16_t v) {
  b.push_back(static_cast<std::uint8_t>(v & 0xFF));
  b.push_back(static_cast<std::uint8_t>((v >> 8) & 0xFF));
}
void appendU32(std::vector<std::uint8_t>& b, std::uint32_t v) {
  b.push_back(static_cast<std::uint8_t>(v & 0xFF));
  b.push_back(static_cast<std::uint8_t>((v >> 8) & 0xFF));
  b.push_back(static_cast<std::uint8_t>((v >> 16) & 0xFF));
  b.push_back(static_cast<std::uint8_t>((v >> 24) & 0xFF));
}
void appendInstr(std::vector<std::uint8_t>& b, CartridgeOpcode op, std::uint8_t reg,
                 std::int32_t imm) {
  b.push_back(static_cast<std::uint8_t>(op));
  b.push_back(reg);
  appendU16(b, 0); // padding
  appendU32(b, static_cast<std::uint32_t>(imm));
}

auto buildHeader(std::uint16_t instrCount, std::uint32_t entry) -> std::vector<std::uint8_t> {
  std::vector<std::uint8_t> b;
  const char magic[8] = {'N', 'E', 'X', 'U', 'S', 'R', 'O', 'M'};
  for (char c : magic) {
    b.push_back(static_cast<std::uint8_t>(c));
  }
  appendU16(b, 1);            // version
  appendU16(b, 60);           // frameRateHz
  appendU32(b, instrCount);   // instruction count
  appendU32(b, entry);        // entry point
  return b;
}

// Cartridge that yields once then halts, scoring 7 and spawning an entity.
void nexusrom_executes_and_scores() {
  std::vector<CartridgeOpcode> ops;
  std::vector<std::uint8_t> body;
  appendInstr(body, CartridgeOpcode::kSet, 0, 42);    // R0 = 42
  appendInstr(body, CartridgeOpcode::kScore, 0, 7);   // score += 7
  appendInstr(body, CartridgeOpcode::kSpawn, 0, 5);   // spawn id=R0 at x=5
  appendInstr(body, CartridgeOpcode::kYield, 0, 0);   // end frame
  appendInstr(body, CartridgeOpcode::kHalt, 0, 0);    // stop

  std::vector<std::uint8_t> rom = buildHeader(5, 0);
  rom.insert(rom.end(), body.begin(), body.end());

  nexus::core::NexusCartridgeRuntime rt;
  require(rt.loadFromMemory(rom).isOk(), "nexusrom loads");
  require(rt.header().hasMagic, "magic detected");
  require(rt.header().frameRateHz == 60, "frame rate parsed");
  require(rt.instructionCount() == 5, "instruction count parsed");

  const auto f1 = rt.tick();
  require(f1.score == 7, "score accumulated to 7");
  require(rt.reg(0) == 42, "register set");
  require(f1.entityCount == 1, "entity spawned");
  require(!f1.halted, "not halted after first yield");
  require(rt.entities().front().id == 42, "entity id from register");
  require(rt.entities().front().x == 5.0F, "entity x from imm");

  const auto f2 = rt.tick();
  require(f2.halted, "halted on second frame");
  require(rt.isHalted(), "runtime reports halted");
}

// Headerless raw .bin stream: countdown loop with JNZ + per-frame YIELD.
void raw_bin_loop_runs_deterministically() {
  std::vector<std::uint8_t> bin;
  appendInstr(bin, CartridgeOpcode::kSet, 1, 3);      // 0: R1 = 3
  appendInstr(bin, CartridgeOpcode::kScore, 0, 10);   // 1: score += 10
  appendInstr(bin, CartridgeOpcode::kSub, 1, 1);      // 2: R1 -= 1
  appendInstr(bin, CartridgeOpcode::kYield, 0, 0);    // 3: end frame
  appendInstr(bin, CartridgeOpcode::kJnz, 1, 1);      // 4: if R1 != 0 goto 1
  appendInstr(bin, CartridgeOpcode::kHalt, 0, 0);     // 5: stop

  nexus::core::NexusCartridgeRuntime rt;
  require(rt.loadFromMemory(bin).isOk(), "raw bin loads");
  require(!rt.header().hasMagic, "no magic for raw bin");
  require(rt.header().frameRateHz == 60, "raw bin defaults to 60Hz");

  const auto end = rt.run(100);
  require(end.halted, "loop halts after countdown");
  // R1=3 -> three SCORE executions total (frames 1,2,3); frame 4 falls through
  // to HALT. Deterministic total = 30.
  require(rt.score() == 30, "deterministic score across loop frames");
}

void unknown_opcode_is_rejected() {
  std::vector<std::uint8_t> bin;
  appendInstr(bin, CartridgeOpcode::kSet, 0, 1);
  // Hand-craft a bogus opcode 0x7E.
  bin.push_back(0x7E);
  bin.push_back(0);
  appendU16(bin, 0);
  appendU32(bin, 0);
  nexus::core::NexusCartridgeRuntime rt;
  require(rt.loadFromMemory(bin).isErr(), "unknown opcode rejected");
}

void loads_from_file() {
  std::vector<std::uint8_t> body;
  appendInstr(body, CartridgeOpcode::kScore, 0, 99);
  appendInstr(body, CartridgeOpcode::kYield, 0, 0);
  appendInstr(body, CartridgeOpcode::kHalt, 0, 0);
  std::vector<std::uint8_t> rom = buildHeader(3, 0);
  rom.insert(rom.end(), body.begin(), body.end());

  const auto path = std::filesystem::temp_directory_path() /
                    ("nexus_cart_" + std::to_string(::getpid()) + ".nexusrom");
  {
    std::ofstream out(path, std::ios::binary);
    out.write(reinterpret_cast<const char*>(rom.data()),
              static_cast<std::streamsize>(rom.size()));
  }
  nexus::core::NexusCartridgeRuntime rt;
  require(rt.loadFromFile(path.string()).isOk(), "load .nexusrom from file");
  rt.run(10);
  require(rt.score() == 99, "file cartridge scored");
  std::filesystem::remove(path);
}

void honest_label_is_not_emulation() {
  const std::string label{nexus::core::NexusCartridgeRuntime::runtimeLabel()};
  require(label.find("virtual") != std::string::npos, "label says virtual");
  require(label.find("not hardware") != std::string::npos,
          "label disclaims hardware emulation");
}

} // namespace

auto main() -> int {
  nexusrom_executes_and_scores();
  raw_bin_loop_runs_deterministically();
  unknown_opcode_is_rejected();
  loads_from_file();
  honest_label_is_not_emulation();
  std::fprintf(stderr, "PASS: nexus_cartridge_test\n");
  return 0;
}
