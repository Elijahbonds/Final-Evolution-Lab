#include "nexus/ai/command_schema.h"

namespace nexus::ai {

namespace {

auto parseType(std::string_view typeText) -> Result<MessageType> {
  if (typeText == "auth") {
    return Result<MessageType>::ok(MessageType::kAuth);
  }
  if (typeText == "command") {
    return Result<MessageType>::ok(MessageType::kCommand);
  }
  if (typeText == "query") {
    return Result<MessageType>::ok(MessageType::kQuery);
  }
  return Result<MessageType>::err("Unknown message type");
}

} // namespace

auto AgentResponse::serialize() const -> nlohmann::json {
  nlohmann::json json{
      {"status", status},
      {"payload", payload},
  };
  if (!id.empty()) {
    json["id"] = id;
  }
  if (!error.empty()) {
    json["error"] = error;
  }
  return json;
}

auto parseAgentMessage(const nlohmann::json& message) -> Result<AgentMessage> {
  if (!message.is_object()) {
    return Result<AgentMessage>::err("Agent message must be an object");
  }

  const auto typeIt = message.find("type");
  if (typeIt == message.end() || !typeIt->is_string()) {
    return Result<AgentMessage>::err("Agent message requires string field 'type'");
  }

  auto type = parseType(typeIt->get<std::string>());
  if (type.isErr()) {
    return Result<AgentMessage>::err(type.error());
  }

  AgentMessage parsed{};
  parsed.type = type.value();

  const auto idIt = message.find("id");
  if (idIt != message.end()) {
    if (!idIt->is_string()) {
      return Result<AgentMessage>::err("Agent message field 'id' must be a string");
    }
    parsed.id = idIt->get<std::string>();
  }

  const auto payloadIt = message.find("payload");
  if (payloadIt != message.end()) {
    parsed.payload = *payloadIt;
  } else {
    parsed.payload = nlohmann::json::object();
  }

  return Result<AgentMessage>::ok(std::move(parsed));
}

} // namespace nexus::ai
