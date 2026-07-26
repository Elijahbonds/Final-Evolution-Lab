#pragma once

#include "nexus/core/result.h"

#include <nlohmann/json.hpp>

#include <memory>
#include <string>
#include <string_view>

namespace nexus::luma {

/// Optional Luma API adapter — stub only; no API keys required in repo.
class ILumaAdapter {
public:
  virtual ~ILumaAdapter() = default;

  [[nodiscard]] virtual auto fetchCapture(std::string_view captureId) -> Result<nlohmann::json> = 0;
  [[nodiscard]] virtual auto downloadMeshExport(std::string_view captureId,
                                                std::string_view outputPath) -> Result<void> = 0;
};

class StubLumaAdapter final : public ILumaAdapter {
public:
  [[nodiscard]] auto fetchCapture(std::string_view captureId) -> Result<nlohmann::json> override;
  [[nodiscard]] auto downloadMeshExport(std::string_view captureId,
                                        std::string_view outputPath) -> Result<void> override;
};

[[nodiscard]] auto defaultLumaAdapter() -> std::shared_ptr<ILumaAdapter>;

} // namespace nexus::luma
