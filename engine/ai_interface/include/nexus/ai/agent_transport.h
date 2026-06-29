#pragma once

#include "nexus/ai/command_schema.h"
#include "nexus/core/result.h"

#include <atomic>
#include <cstdint>
#include <memory>
#include <mutex>
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
  /// Shared, mutex-guarded handle to a client socket so a response sink can
  /// safely write back from the render loop thread even after the reader thread
  /// has observed a disconnect and closed the socket.
  struct ClientConnection {
    std::mutex mutex;
    int fd{-1};
    bool open{false};
  };

  void stdinLoop();
  void tcpAcceptLoop();
  void handleClient(int clientFd);
  static void sendResponseLine(const std::shared_ptr<ClientConnection>& connection,
                               const AgentResponse& response);

  AgentServer& m_server;
  AgentTransportConfig m_config{};
  std::thread m_stdinThread;
  std::thread m_tcpThread;
  std::atomic<bool> m_running{false};
  int m_listenFd{-1};
};

} // namespace nexus::ai
