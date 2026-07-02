#include "nexus/core/log.h"

#include <cstdio>

namespace nexus {

namespace {

auto channelName(LogChannel channel) -> const char* {
  switch (channel) {
  case LogChannel::kCore:
    return "core";
  case LogChannel::kRenderer:
    return "renderer";
  case LogChannel::kPhysics:
    return "physics";
  case LogChannel::kAI:
    return "ai";
  case LogChannel::kCreative:
    return "creative";
  case LogChannel::kGenerative:
    return "generative";
  }
  return "unknown";
}

void writeLog(const char* level, LogChannel channel, std::string_view message) {
  std::fprintf(stderr, "[%s][%s] %.*s\n",
               level,
               channelName(channel),
               static_cast<int>(message.size()),
               message.data());
}

} // namespace

void Log::info(LogChannel channel, std::string_view message) {
  writeLog("info", channel, message);
}

void Log::warn(LogChannel channel, std::string_view message) {
  writeLog("warn", channel, message);
}

void Log::error(LogChannel channel, std::string_view message) {
  writeLog("error", channel, message);
}

} // namespace nexus
