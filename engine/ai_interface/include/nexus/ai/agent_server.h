#pragma once

#include "nexus/ai/agent_transport.h"
#include "nexus/ai/command_router.h"
#include "nexus/core/result.h"

#include <memory>
#include <mutex>
#include <queue>
#include <string>
#include <vector>

namespace nexus::ai {

class AgentServer {
public:
  auto init(CommandRouter* router) -> Result<void>;
  auto receiveJson(std::string_view jsonText) -> Result<void>;
  auto processQueuedCommands(std::size_t maxCommands) -> std::vector<AgentResponse>;
  [[nodiscard]] auto pendingCommandCount() const -> std::size_t;

  /// Starts background stdin/TCP transport (non-blocking for render loop).
  auto startTransport(const AgentTransportConfig& config) -> Result<void>;
  void stopTransport();

  void shutdown();

private:
  mutable std::mutex m_mutex;
  std::queue<AgentMessage> m_queue;
  CommandRouter* m_router{nullptr};
  std::unique_ptr<AgentTransport> m_transport;
};

} // namespace nexus::ai
