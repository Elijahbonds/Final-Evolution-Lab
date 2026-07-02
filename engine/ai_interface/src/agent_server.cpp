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
  nlohmann::json json = nlohmann::json::parse(jsonText, nullptr, false);
  if (json.is_discarded()) {
    return Result<void>::err("Invalid JSON");
  }

  auto message = parseAgentMessage(json);
  if (message.isErr()) {
    return Result<void>::err(message.error());
  }

  std::scoped_lock lock(m_mutex);
  m_queue.push(std::move(message.value()));
  return Result<void>::ok();
}

auto AgentServer::processQueuedCommands(std::size_t maxCommands) -> std::vector<AgentResponse> {
  std::vector<AgentResponse> responses;
  responses.reserve(maxCommands);

  for (std::size_t processed = 0; processed < maxCommands; ++processed) {
    AgentMessage message;
    {
      std::scoped_lock lock(m_mutex);
      if (m_queue.empty()) {
        break;
      }
      message = std::move(m_queue.front());
      m_queue.pop();
    }

    responses.push_back(m_router->route(message));
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
    std::queue<AgentMessage> empty;
    m_queue.swap(empty);
  }
  m_router = nullptr;
  NEXUS_LOG_INFO(LogChannel::kAI, "Agent server shutdown");
}

} // namespace nexus::ai
