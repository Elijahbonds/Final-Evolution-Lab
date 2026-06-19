#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>
#include <string>

namespace nexus::ai {

enum class MessageType {
  kAuth,
  kCommand,
  kQuery,
};

struct AgentMessage {
  MessageType type{MessageType::kCommand};
  std::string id;
  nlohmann::json payload;
};

struct AgentResponse {
  std::string id;
  std::string status;
  nlohmann::json payload;
  std::string error;

  [[nodiscard]] auto serialize() const -> nlohmann::json;
};

auto parseAgentMessage(const nlohmann::json& message) -> Result<AgentMessage>;

} // namespace nexus::ai
