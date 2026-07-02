#include "agent_http_listener.h"

#include "nexus/core/log.h"

#include <arpa/inet.h>
#include <netinet/in.h>
#include <poll.h>
#include <sys/socket.h>
#include <unistd.h>

#include <cerrno>
#include <cstring>
#include <string>

namespace nexus::tools {

namespace {

auto closeFd(int fd) -> void {
  if (fd >= 0) {
    close(fd);
  }
}

auto toLower(std::string value) -> std::string {
  for (char& character : value) {
    if (character >= 'A' && character <= 'Z') {
      character = static_cast<char>(character - 'A' + 'a');
    }
  }
  return value;
}

} // namespace

AgentHttpListener::AgentHttpListener(AgentHttpDispatchFn dispatch) : m_dispatch(std::move(dispatch)) {}

AgentHttpListener::~AgentHttpListener() = default;

auto AgentHttpListener::buildHttpResponse(int statusCode,
                                          std::string_view statusText,
                                          std::string_view body) -> std::string {
  return "HTTP/1.1 " + std::to_string(statusCode) + " " + std::string(statusText) +
         "\r\nContent-Type: application/json\r\nConnection: close\r\nContent-Length: " +
         std::to_string(body.size()) + "\r\n\r\n" + std::string(body);
}

auto AgentHttpListener::handleConnection(int clientFd) -> void {
  std::string request;
  char chunk[2048];
  std::size_t contentLength = 0;
  std::string requestPath;
  std::string requestMethod;

  while (request.find("\r\n\r\n") == std::string::npos) {
    const ssize_t bytesRead = recv(clientFd, chunk, sizeof(chunk), 0);
    if (bytesRead <= 0) {
      return;
    }
    request.append(chunk, static_cast<std::size_t>(bytesRead));
    if (request.size() > 65536) {
      const std::string response =
          buildHttpResponse(413, "Payload Too Large", R"({"status":"error","error":"request too large"})");
      (void)send(clientFd, response.data(), response.size(), 0);
      return;
    }
  }

  const std::size_t headerEnd = request.find("\r\n\r\n");
  const std::string headers = request.substr(0, headerEnd);
  std::string body = request.substr(headerEnd + 4);

  const std::size_t firstLineEnd = headers.find("\r\n");
  if (firstLineEnd != std::string::npos) {
    const std::string requestLine = headers.substr(0, firstLineEnd);
    const std::size_t methodEnd = requestLine.find(' ');
    const std::size_t pathEnd = requestLine.find(' ', methodEnd + 1);
    if (methodEnd != std::string::npos) {
      requestMethod = requestLine.substr(0, methodEnd);
    }
    if (methodEnd != std::string::npos && pathEnd != std::string::npos) {
      requestPath = requestLine.substr(methodEnd + 1, pathEnd - methodEnd - 1);
    }
  }

  for (std::size_t lineStart = firstLineEnd + 2; lineStart < headers.size();) {
    const std::size_t lineEnd = headers.find("\r\n", lineStart);
    const std::string headerLine =
        headers.substr(lineStart, lineEnd == std::string::npos ? std::string::npos : lineEnd - lineStart);
    const std::size_t colon = headerLine.find(':');
    if (colon != std::string::npos) {
      const std::string headerName = toLower(headerLine.substr(0, colon));
      if (headerName == "content-length") {
        contentLength = static_cast<std::size_t>(std::stoul(headerLine.substr(colon + 1)));
      }
    }
    if (lineEnd == std::string::npos) {
      break;
    }
    lineStart = lineEnd + 2;
  }

  while (body.size() < contentLength) {
    const ssize_t bytesRead = recv(clientFd, chunk, sizeof(chunk), 0);
    if (bytesRead <= 0) {
      break;
    }
    body.append(chunk, static_cast<std::size_t>(bytesRead));
  }

  if (requestMethod != "POST") {
    const std::string response =
        buildHttpResponse(405, "Method Not Allowed", R"({"status":"error","error":"POST required"})");
    (void)send(clientFd, response.data(), response.size(), 0);
    return;
  }

  if (requestPath != "/nexus/agent") {
    const std::string response =
        buildHttpResponse(404, "Not Found", R"({"status":"error","error":"unknown path"})");
    (void)send(clientFd, response.data(), response.size(), 0);
    return;
  }

  const auto responses = m_dispatch(body);
  nlohmann::json payload = nlohmann::json::array();
  for (const ai::AgentResponse& response : responses) {
    payload.push_back(response.serialize());
  }

  nlohmann::json envelope = nlohmann::json::object();
  if (payload.size() == 1) {
    envelope = payload.front();
  } else {
    envelope = {{"status", "ok"}, {"responses", payload}};
  }

  const std::string responseBody = envelope.dump();
  const std::string response = buildHttpResponse(200, "OK", responseBody);
  (void)send(clientFd, response.data(), response.size(), 0);
}

auto AgentHttpListener::serve(const AgentHttpListenerConfig& config) -> Result<void> {
  const int listenFd = socket(AF_INET, SOCK_STREAM, 0);
  if (listenFd < 0) {
    return Result<void>::err(std::string("HTTP listen socket failed: ") + std::strerror(errno));
  }

  const int enable = 1;
  if (setsockopt(listenFd, SOL_SOCKET, SO_REUSEADDR, &enable, sizeof(enable)) != 0) {
    closeFd(listenFd);
    return Result<void>::err(std::string("HTTP setsockopt failed: ") + std::strerror(errno));
  }

  sockaddr_in address{};
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = htonl(INADDR_LOOPBACK);
  address.sin_port = htons(config.port);

  if (bind(listenFd, reinterpret_cast<sockaddr*>(&address), sizeof(address)) != 0) {
    closeFd(listenFd);
    return Result<void>::err(std::string("HTTP bind failed: ") + std::strerror(errno));
  }

  if (listen(listenFd, 8) != 0) {
    closeFd(listenFd);
    return Result<void>::err(std::string("HTTP listen failed: ") + std::strerror(errno));
  }

  NEXUS_LOG_INFO(LogChannel::kAI,
                 "Agent HTTP listener on http://127.0.0.1:" + std::to_string(config.port) +
                     config.path);

  while (true) {
    pollfd listenPoll{};
    listenPoll.fd = listenFd;
    listenPoll.events = POLLIN;
    const int pollResult = poll(&listenPoll, 1, 500);
    if (pollResult < 0) {
      if (errno == EINTR) {
        continue;
      }
      closeFd(listenFd);
      return Result<void>::err(std::string("HTTP poll failed: ") + std::strerror(errno));
    }
    if (pollResult == 0) {
      continue;
    }

    const int clientFd = accept(listenFd, nullptr, nullptr);
    if (clientFd < 0) {
      continue;
    }
    handleConnection(clientFd);
    closeFd(clientFd);
  }
}

} // namespace nexus::tools
