#include "nexus/net/net_message_bus.h"

#include <utility>

namespace nexus::net {

void NetMessageBus::push(NetMessage message) {
  const std::lock_guard<std::mutex> lock(m_mutex);
  m_queue.push_back(std::move(message));
}

auto NetMessageBus::drain(std::vector<NetMessage>& out) -> std::size_t {
  const std::lock_guard<std::mutex> lock(m_mutex);
  const std::size_t count = m_queue.size();
  if (count == 0) {
    return 0;
  }
  out.insert(out.end(),
             std::make_move_iterator(m_queue.begin()),
             std::make_move_iterator(m_queue.end()));
  m_queue.clear();
  return count;
}

auto NetMessageBus::size() const -> std::size_t {
  const std::lock_guard<std::mutex> lock(m_mutex);
  return m_queue.size();
}

void NetMessageBus::clear() {
  const std::lock_guard<std::mutex> lock(m_mutex);
  m_queue.clear();
}

} // namespace nexus::net
