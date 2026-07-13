#include "nexus/cell/observation_bus.h"

namespace nexus::cell {

auto ObservationBus::push(Observation obs) -> bool {
  std::scoped_lock lock(m_mutex);
  bool dropped = false;
  if (m_buffer.size() >= kCapacity) {
    m_buffer.erase(m_buffer.begin()); // evict oldest
    dropped = true;
  }
  m_buffer.push_back(std::move(obs));
  return !dropped;
}

auto ObservationBus::drainAll() -> std::vector<Observation> {
  std::scoped_lock lock(m_mutex);
  std::vector<Observation> out;
  out.swap(m_buffer);
  return out;
}

auto ObservationBus::size() const -> std::size_t {
  std::scoped_lock lock(m_mutex);
  return m_buffer.size();
}

} // namespace nexus::cell
