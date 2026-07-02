#include "nexus/ai/agent_transport.h"

#include "nexus/ai/agent_server.h"
#include "nexus/core/log.h"

#include <arpa/inet.h>
#include <netinet/in.h>
#include <poll.h>
#include <sys/socket.h>
#include <unistd.h>

#include <cerrno>
#include <cstring>
#include <iostream>
#include <string>

namespace nexus::ai {

namespace {

auto closeFd(int fd) -> void {
  if (fd >= 0) {
    close(fd);
  }
}

auto setSocketReuseAddr(int fd) -> Result<void> {
  const int enable = 1;
  if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(enable)) != 0) {
    return Result<void>::err(std::string("setsockopt SO_REUSEADDR failed: ") + std::strerror(errno));
  }
  return Result<void>::ok();
}

} // namespace

AgentTransport::AgentTransport(AgentServer& server) : m_server(server) {}

AgentTransport::~AgentTransport() {
  stop();
}

auto AgentTransport::start(const AgentTransportConfig& config) -> Result<void> {
  if (m_running.load()) {
    return Result<void>::err("Agent transport already running");
  }

  m_config = config;
  m_running.store(true);

  if (m_config.enableStdinReader) {
    m_stdinThread = std::thread([this]() { stdinLoop(); });
  }

  if (m_config.enableTcpListener) {
    m_tcpThread = std::thread([this]() { tcpAcceptLoop(); });
  }

  NEXUS_LOG_INFO(LogChannel::kAI, "Agent transport started");
  return Result<void>::ok();
}

void AgentTransport::stop() {
  if (!m_running.exchange(false)) {
    return;
  }

  closeFd(m_listenFd);
  m_listenFd = -1;

  if (m_config.enableStdinReader && m_stdinThread.joinable()) {
    shutdown(STDIN_FILENO, SHUT_RD);
    m_stdinThread.join();
  }

  if (m_config.enableTcpListener && m_tcpThread.joinable()) {
    m_tcpThread.join();
  }

  NEXUS_LOG_INFO(LogChannel::kAI, "Agent transport stopped");
}

auto AgentTransport::isRunning() const -> bool {
  return m_running.load();
}

void AgentTransport::stdinLoop() {
  std::string line;
  while (m_running.load()) {
    if (!std::getline(std::cin, line)) {
      break;
    }
    if (line.empty()) {
      continue;
    }

    const auto result = m_server.receiveJson(line);
    if (result.isErr()) {
      NEXUS_LOG_WARN(LogChannel::kAI, "Stdin agent message rejected: " + result.error());
    }
  }
}

void AgentTransport::tcpAcceptLoop() {
  m_listenFd = socket(AF_INET, SOCK_STREAM, 0);
  if (m_listenFd < 0) {
    NEXUS_LOG_ERROR(LogChannel::kAI,
                    std::string("Agent TCP socket failed: ") + std::strerror(errno));
    m_running.store(false);
    return;
  }

  const auto reuseResult = setSocketReuseAddr(m_listenFd);
  if (reuseResult.isErr()) {
    NEXUS_LOG_ERROR(LogChannel::kAI, reuseResult.error());
    closeFd(m_listenFd);
    m_listenFd = -1;
    m_running.store(false);
    return;
  }

  sockaddr_in address{};
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  address.sin_port = htons(m_config.tcpPort);

  if (bind(m_listenFd, reinterpret_cast<sockaddr*>(&address), sizeof(address)) != 0) {
    NEXUS_LOG_ERROR(LogChannel::kAI,
                    std::string("Agent TCP bind failed: ") + std::strerror(errno));
    closeFd(m_listenFd);
    m_listenFd = -1;
    m_running.store(false);
    return;
  }

  if (listen(m_listenFd, 8) != 0) {
    NEXUS_LOG_ERROR(LogChannel::kAI,
                    std::string("Agent TCP listen failed: ") + std::strerror(errno));
    closeFd(m_listenFd);
    m_listenFd = -1;
    m_running.store(false);
    return;
  }

  NEXUS_LOG_INFO(LogChannel::kAI,
                 "Agent TCP listener on 127.0.0.1:" + std::to_string(m_config.tcpPort));

  while (m_running.load()) {
    pollfd listenPoll{};
    listenPoll.fd = m_listenFd;
    listenPoll.events = POLLIN;
    const int pollResult = poll(&listenPoll, 1, 200);
    if (pollResult < 0) {
      if (errno == EINTR) {
        continue;
      }
      if (m_running.load()) {
        NEXUS_LOG_WARN(LogChannel::kAI,
                       std::string("Agent TCP poll failed: ") + std::strerror(errno));
      }
      break;
    }
    if (pollResult == 0) {
      continue;
    }

    const int clientFd = accept(m_listenFd, nullptr, nullptr);
    if (clientFd < 0) {
      if (m_running.load()) {
        NEXUS_LOG_WARN(LogChannel::kAI,
                       std::string("Agent TCP accept failed: ") + std::strerror(errno));
      }
      continue;
    }

    handleClient(clientFd);
    closeFd(clientFd);
  }

  closeFd(m_listenFd);
  m_listenFd = -1;
}

void AgentTransport::handleClient(int clientFd) {
  std::string buffer;
  char chunk[512];
  while (m_running.load()) {
    pollfd clientPoll{};
    clientPoll.fd = clientFd;
    clientPoll.events = POLLIN;
    const int pollResult = poll(&clientPoll, 1, 200);
    if (pollResult < 0) {
      if (errno == EINTR) {
        continue;
      }
      break;
    }
    if (pollResult == 0) {
      continue;
    }

    const ssize_t bytesRead = recv(clientFd, chunk, sizeof(chunk), 0);
    if (bytesRead <= 0) {
      break;
    }

    buffer.append(chunk, static_cast<std::size_t>(bytesRead));
    std::size_t newlinePos = 0;
    while ((newlinePos = buffer.find('\n')) != std::string::npos) {
      std::string line = buffer.substr(0, newlinePos);
      buffer.erase(0, newlinePos + 1);

      if (line.empty()) {
        continue;
      }

      const auto result = m_server.receiveJson(line);
      if (result.isErr()) {
        NEXUS_LOG_WARN(LogChannel::kAI, "TCP agent message rejected: " + result.error());
      } else {
        NEXUS_LOG_INFO(LogChannel::kAI, "TCP agent message queued");
      }
    }
  }
}

} // namespace nexus::ai
