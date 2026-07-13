#pragma once

// CELL Hardware Telemetry Bridge
//
// A thin adapter that ingests raw JSON telemetry frames from an external
// hardware device (e.g. a robotic AI tracking camera) and routes them into
// the SelfImprovementScheduler as kHardwareTelemetry observations.
//
// The ResearchLoop and ModelTrainer require no changes — hardware observations
// are analysed identically to frame telemetry, enabling CELL to learn about
// real-world movement mechanics directly from hardware sensors.
//
// Swift bridging: C-linkage wrappers at the bottom of this header allow the
// Swift iOS shell to call the bridge without C++ headers in the Swift target.

#include <nlohmann/json.hpp>
#include <string>

namespace nexus::cell {
class SelfImprovementScheduler;
} // namespace nexus::cell

namespace nexus::cell {

class HardwareTelemetryBridge {
public:
  /// Attach this bridge to a running scheduler. The scheduler must outlive
  /// the bridge.
  explicit HardwareTelemetryBridge(SelfImprovementScheduler& scheduler);

  /// Ingest a structured JSON telemetry frame.
  /// @param device_id  Unique identifier for the hardware source (e.g. "cam_0").
  /// @param payload    Arbitrary JSON (position, velocity, joint angles, etc.)
  /// @param reward     Optional engagement/quality hint in [-1, 1].
  void ingestFrame(const std::string& device_id,
                   const nlohmann::json& payload,
                   double reward = 0.5);

  /// Convenience overload that parses a raw null-terminated JSON string.
  void ingestFrameJson(const std::string& device_id,
                       const std::string& json_str,
                       double reward = 0.5);

private:
  SelfImprovementScheduler& m_scheduler;
};

} // namespace nexus::cell

// ── C-linkage wrappers for Swift bridging ────────────────────────────────────
extern "C" {

/// Opaque handle to a HardwareTelemetryBridge instance.
typedef void* NexusCellHardwareBridgeHandle;

/// Create a bridge attached to the given scheduler.
/// scheduler_ptr must be a nexus::cell::SelfImprovementScheduler*.
NexusCellHardwareBridgeHandle nexus_cell_hardware_bridge_create(void* scheduler_ptr);

/// Ingest a JSON frame. device_id and json_str must be null-terminated UTF-8.
void nexus_cell_hardware_bridge_ingest(NexusCellHardwareBridgeHandle handle,
                                        const char* device_id,
                                        const char* json_str,
                                        double reward);

/// Destroy the bridge and free its resources.
void nexus_cell_hardware_bridge_destroy(NexusCellHardwareBridgeHandle handle);

} // extern "C"
