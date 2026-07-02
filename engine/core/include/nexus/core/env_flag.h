#pragma once

#include <string_view>

namespace nexus::core {

/// True when `key` is set to `1` or `true` (case-sensitive).
[[nodiscard]] auto envFlagEnabled(std::string_view key) -> bool;

} // namespace nexus::core
