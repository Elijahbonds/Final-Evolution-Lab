#include "nexus/ai/agent_server.h"

#include "nexus/core/log.h"

#include <memory>

namespace nexus::ai {

auto AgentServer::init(CommandRouter* router) -> Result<void> {
  if (router == nullptr) {
    return Result<void>::err("AgentServer requires CommandRouter");
  }
  m_router = router;
  NEXUS_LOG_INFO(LogChannel::kAI, "Agent server initialized");
  return Result<void>::ok();
}

auto AgentServer::receiveJson(std::string_view jsonText) -> Result<void> {
  return receiveJson(jsonText, ResponseSink{});
}

auto AgentServer::receiveJson(std::string_view jsonText, ResponseSink sink) -> Result<void> {
  nlohmann::json json = nlohmann::json::parse(jsonText, nullptr, false);
  if (json.is_discarded()) {
    return Result<void>::err("Invalid JSON");
  }

  auto message = parseAgentMessage(json);
  if (message.isErr()) {
    return Result<void>::err(message.error());
  }

  std::scoped_lock lock(m_mutex);
  m_queue.push(QueuedCommand{std::move(message.value()), std::move(sink)});
  return Result<void>::ok();
}

auto AgentServer::processQueuedCommands(std::size_t maxCommands) -> std::vector<AgentResponse> {
  std::vector<AgentResponse> responses;
  responses.reserve(maxCommands);

  for (std::size_t processed = 0; processed < maxCommands; ++processed) {
    QueuedCommand command;
    {
      std::scoped_lock lock(m_mutex);
      if (m_queue.empty()) {
        break;
      }
      command = std::move(m_queue.front());
      m_queue.pop();
    }

    AgentResponse response = m_router->route(command.message);
    if (command.sink) {
      // Route the response back to its origin. The sink runs outside the queue
      // lock and must never throw/crash the caller (transport thread or render
      // loop) on a dead connection.
      command.sink(response);
    }
    responses.push_back(std::move(response));
  }

  return responses;
}

auto AgentServer::pendingCommandCount() const -> std::size_t {
  std::scoped_lock lock(m_mutex);
  return m_queue.size();
}

auto AgentServer::startTransport(const AgentTransportConfig& config) -> Result<void> {
  if (m_transport != nullptr && m_transport->isRunning()) {
    return Result<void>::err("Agent transport already started");
  }

  m_transport = std::make_unique<AgentTransport>(*this);
  return m_transport->start(config);
}

void AgentServer::stopTransport() {
  if (m_transport != nullptr) {
    m_transport->stop();
    m_transport.reset();
  }
}

void AgentServer::shutdown() {
  stopTransport();
  {
    std::scoped_lock lock(m_mutex);
    std::queue<QueuedCommand> empty;
    m_queue.swap(empty);
  }
  m_router = nullptr;
  NEXUS_LOG_INFO(LogChannel::kAI, "Agent server shutdown");
}

} // namespace nexus::ai
