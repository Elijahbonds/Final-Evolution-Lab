// Port of UFELExerciseDemoPipelineSubsystem — maps production arena modes to Academy modules.
#pragma once

#include <nlohmann/json.hpp>
#include <optional>
#include <string>
#include <string_view>

namespace nexus::gameplay {

struct ExerciseDemoMapping {
  std::string moduleId;
  std::string montagePath;
  std::string displayLabel;
};

class ExerciseDemoPipeline {
public:
  [[nodiscard]] static auto mappingForMode(std::string_view modeId)
      -> std::optional<ExerciseDemoMapping>;
  [[nodiscard]] static auto mappingJson(std::string_view modeId) -> nlohmann::json;
  [[nodiscard]] static auto allProductionMappings() -> nlohmann::json;
};

} // namespace nexus::gameplay
