// NEXUS multiplayer — thread-safe in-process message queue
#pragma once

#include "nexus/net/net_message.h"

#include <cstddef>
#include <mutex>
#include <vector>

namespace nexus::net {

/// Thread-safe FIFO bridge between the NetSession transport thread and the
/// single-threaded gameplay update loop.  The gameplay tick calls drain() once
/// per frame; the transport layer (or local router) calls push() from any thread.
class NetMessageBus {
public:
  void push(NetMessage message);

  /// Moves all queued messages into `out`.  Returns the number of messages drained.
  auto drain(std::vector<NetMessage>& out) -> std::size_t;

  [[nodiscard]] auto size() const -> std::size_t;
  void clear();

private:
  mutable std::mutex      m_mutex;
  std::vector<NetMessage> m_queue;
};

} // namespace nexus::net
