#include "nexus/cell/hardware_telemetry_bridge.h"

#include "nexus/cell/self_improvement_scheduler.h"

#include <nlohmann/json.hpp>

namespace nexus::cell {

HardwareTelemetryBridge::HardwareTelemetryBridge(SelfImprovementScheduler& scheduler)
    : m_scheduler(scheduler) {}

void HardwareTelemetryBridge::ingestFrame(const std::string& device_id,
                                           const nlohmann::json& payload,
                                           double reward) {
  nlohmann::json data = payload;
  data["device_id"]   = device_id;
  m_scheduler.observeManual("hardware:" + device_id, data, reward);
}

void HardwareTelemetryBridge::ingestFrameJson(const std::string& device_id,
                                               const std::string& json_str,
                                               double reward) {
  const nlohmann::json payload =
      nlohmann::json::parse(json_str, nullptr, /*exceptions=*/false);
  if (payload.is_discarded()) {
    // Wrap the raw string so it still enters the observation bus.
    ingestFrame(device_id, {{"raw", json_str}}, reward);
  } else {
    ingestFrame(device_id, payload, reward);
  }
}

} // namespace nexus::cell

// ── C-linkage wrappers ────────────────────────────────────────────────────────

extern "C" {

NexusCellHardwareBridgeHandle nexus_cell_hardware_bridge_create(void* scheduler_ptr) {
  auto* scheduler = static_cast<nexus::cell::SelfImprovementScheduler*>(scheduler_ptr);
  return new nexus::cell::HardwareTelemetryBridge(*scheduler); // NOLINT
}

void nexus_cell_hardware_bridge_ingest(NexusCellHardwareBridgeHandle handle,
                                        const char* device_id,
                                        const char* json_str,
                                        double reward) {
  if (handle == nullptr || device_id == nullptr || json_str == nullptr) { return; }
  static_cast<nexus::cell::HardwareTelemetryBridge*>(handle)
      ->ingestFrameJson(device_id, json_str, reward);
}

void nexus_cell_hardware_bridge_destroy(NexusCellHardwareBridgeHandle handle) {
  delete static_cast<nexus::cell::HardwareTelemetryBridge*>(handle); // NOLINT
}

} // extern "C"
