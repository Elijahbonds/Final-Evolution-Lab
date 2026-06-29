#pragma once

#include "nexus/ai/agent_transport.h"
#include "nexus/ai/command_router.h"
#include "nexus/core/result.h"

#include <functional>
#include <memory>
#include <mutex>
#include <queue>
#include <string>
#include <vector>

namespace nexus::ai {

/// Delivers an AgentResponse back to the origin of its command (stdin, a TCP
/// client socket, an in-memory test buffer, ...). Invoked exactly once per
/// processed command that carries a sink, on the thread that drains the queue.
using ResponseSink = std::function<void(const AgentResponse&)>;

/// A queued command together with the optional channel its response routes to.
struct QueuedCommand {
  AgentMessage message;
  ResponseSink sink; // empty when the origin does not expect a response
};

class AgentServer {
public:
  auto init(CommandRouter* router) -> Result<void>;

  /// Queues a command with no response channel (response only surfaced via the
  /// vector returned from processQueuedCommands). Preserved for existing callers.
  auto receiveJson(std::string_view jsonText) -> Result<void>;

  /// Queues a command and attaches a sink that receives the routed response
  /// when the command is processed. The sink is invoked exactly once.
  auto receiveJson(std::string_view jsonText, ResponseSink sink) -> Result<void>;

  auto processQueuedCommands(std::size_t maxCommands) -> std::vector<AgentResponse>;
  [[nodiscard]] auto pendingCommandCount() const -> std::size_t;

  /// Starts background stdin/TCP transport (non-blocking for render loop).
  auto startTransport(const AgentTransportConfig& config) -> Result<void>;
  void stopTransport();

  void shutdown();

private:
  mutable std::mutex m_mutex;
  std::queue<QueuedCommand> m_queue;
  CommandRouter* m_router{nullptr};
  std::unique_ptr<AgentTransport> m_transport;
};

} // namespace nexus::ai
