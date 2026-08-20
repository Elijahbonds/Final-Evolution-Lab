#include "nexus/runtime/venue_mesh_validator.h"

#include <cstdlib>
#include <iostream>
#include <string>
#include <string_view>

namespace {

struct ValidatorOptions {
  std::string modeId{"basketball_dunk"};
  std::string venueId{"venice_beach"};
};

auto parseArgs(int argc, char** argv) -> ValidatorOptions {
  ValidatorOptions options;
  for (int index = 1; index < argc; ++index) {
    const std::string_view arg{argv[index]};
    if (arg == "--mode" && index + 1 < argc) {
      options.modeId = argv[++index];
    } else if (arg == "--venue" && index + 1 < argc) {
      options.venueId = argv[++index];
    } else if (arg == "--validate-only") {
      // Accepted for script compatibility with nexus_runtime.
    } else if (arg == "--help" || arg == "-h") {
      std::cerr << "Usage: nexus_mode_validator [--mode basketball_dunk] [--venue venice_beach]\n"
                << "                            [--validate-only]\n";
      std::exit(0);
    }
  }
  return options;
}

} // namespace

auto main(int argc, char** argv) -> int {
  const ValidatorOptions options = parseArgs(argc, argv);
  return nexus::runtime::validateVenueMesh(options.modeId, options.venueId);
}
