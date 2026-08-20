#pragma once

#include <string_view>

namespace nexus::runtime {

[[nodiscard]] auto validateVenueMesh(std::string_view modeId, std::string_view venueHint) -> int;

} // namespace nexus::runtime
