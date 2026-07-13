#pragma once

#include <string_view>

namespace nexus {

enum class LogChannel {
  kCore,
  kRenderer,
  kPhysics,
  kAI,
  kCreative,
  kGenerative,
  kCell,
};

class Log {
public:
  static void info(LogChannel channel, std::string_view message);
  static void warn(LogChannel channel, std::string_view message);
  static void error(LogChannel channel, std::string_view message);
};

} // namespace nexus

#define NEXUS_LOG_INFO(channel, message) ::nexus::Log::info(channel, message)
#define NEXUS_LOG_WARN(channel, message) ::nexus::Log::warn(channel, message)
#define NEXUS_LOG_ERROR(channel, message) ::nexus::Log::error(channel, message)
