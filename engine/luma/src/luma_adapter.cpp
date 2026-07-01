#include "nexus/luma/luma_adapter.h"

#include "nexus/core/log.h"

#include <memory>

namespace nexus::luma {

auto StubLumaAdapter::fetchCapture(std::string_view captureId) -> Result<nlohmann::json> {
  (void)captureId;
  NEXUS_LOG_INFO(LogChannel::kGenerative,
                 "StubLumaAdapter: Luma API not configured — use fel.scan.import_environment");
  return Result<nlohmann::json>::err("Luma API adapter not configured");
}

auto StubLumaAdapter::downloadMeshExport(std::string_view captureId,
                                         std::string_view outputPath) -> Result<void> {
  (void)captureId;
  (void)outputPath;
  return Result<void>::err("Luma API adapter not configured");
}

auto defaultLumaAdapter() -> std::shared_ptr<ILumaAdapter> {
  return std::make_shared<StubLumaAdapter>();
}

} // namespace nexus::luma
