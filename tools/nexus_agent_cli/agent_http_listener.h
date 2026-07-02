#pragma once

#include "nexus/ai/command_schema.h"
#include "nexus/core/result.h"

#include <cstdint>
#include <functional>
#include <string_view>
#include <vector>

namespace nexus::tools {

using AgentHttpDispatchFn =
    std::function<std::vector<ai::AgentResponse>(std::string_view requestBody)>;

struct AgentHttpListenerConfig {
  std::uint16_t port{8765};
  std::string path{"/nexus/agent"};
};

/// Minimal localhost HTTP POST listener for Cursor MCP integration.
class AgentHttpListener {
public:
  explicit AgentHttpListener(AgentHttpDispatchFn dispatch);
  ~AgentHttpListener();

  AgentHttpListener(const AgentHttpListener&) = delete;
  AgentHttpListener& operator=(const AgentHttpListener&) = delete;

  auto serve(const AgentHttpListenerConfig& config) -> Result<void>;

private:
  auto handleConnection(int clientFd) -> void;
  static auto buildHttpResponse(int statusCode,
                                std::string_view statusText,
                                std::string_view body) -> std::string;

  AgentHttpDispatchFn m_dispatch;
};

} // namespace nexus::tools
