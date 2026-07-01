#pragma once

#include "nexus/core/result.h"

#include <atomic>
#include <cstdint>
#include <thread>

namespace nexus::ai {

class AgentServer;

struct AgentTransportConfig {
  bool enableStdinReader{false};
  bool enableTcpListener{true};
  std::uint16_t tcpPort{9090};
};

/// Background IO transport for agent JSON commands.
/// Accepts newline-delimited JSON over TCP (port 9090) and/or stdin.
/// Commands are queued on the IO thread via AgentServer::receiveJson.
class AgentTransport {
public:
  explicit AgentTransport(AgentServer& server);
  ~AgentTransport();

  AgentTransport(const AgentTransport&) = delete;
  AgentTransport& operator=(const AgentTransport&) = delete;

  auto start(const AgentTransportConfig& config) -> Result<void>;
  void stop();
  [[nodiscard]] auto isRunning() const -> bool;

private:
  void stdinLoop();
  void tcpAcceptLoop();
  void handleClient(int clientFd);

  AgentServer& m_server;
  AgentTransportConfig m_config{};
  std::thread m_stdinThread;
  std::thread m_tcpThread;
  std::atomic<bool> m_running{false};
  int m_listenFd{-1};
};

} // namespace nexus::ai
