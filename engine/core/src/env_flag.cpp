#include "nexus/core/env_flag.h"

#include <cstdlib>
#include <string>

namespace nexus::core {

auto envFlagEnabled(std::string_view key) -> bool {
  const char* flag = std::getenv(std::string(key).c_str());
  return flag != nullptr &&
         (std::string_view{flag} == "1" || std::string_view{flag} == "true");
}

} // namespace nexus::core
