#include "nexus/generative/procedural_mesh.h"

#include <cstdint>
#include <fstream>
#include <functional>

namespace nexus::generative {

namespace {

auto hashPrompt(std::string_view prompt) -> std::uint32_t {
  return static_cast<std::uint32_t>(std::hash<std::string_view>{}(prompt));
}

auto colorFromHash(std::uint32_t hash, int channel) -> float {
  const float normalized =
      static_cast<float>((hash >> (channel * 8)) & 0xFFU) / 255.0F;
  return 0.35F + normalized * 0.55F;
}

} // namespace

auto buildProceduralMeshJson(std::string_view name, std::string_view prompt) -> nlohmann::json {
  const std::uint32_t hash = hashPrompt(prompt.empty() ? name : prompt);
  const float scale = 0.35F + static_cast<float>((hash % 100U)) / 200.0F;
  const float r = colorFromHash(hash, 0);
  const float g = colorFromHash(hash, 1);
  const float b = colorFromHash(hash, 2);

  const float half = scale;
  const float height = scale * 1.6F;

  return {
      {"format", "nexusmesh"},
      {"version", "1"},
      {"name", std::string(name)},
      {"generation",
       {
           {"method", "procedural_fallback"},
           {"prompt", std::string(prompt)},
       }},
      {"vertices",
       {
           {{"position", {-half, 0.0F, -half}}, {"color", {r, g, b}}},
           {{"position", {half, 0.0F, -half}}, {"color", {r * 0.9F, g * 0.9F, b}}},
           {{"position", {half, 0.0F, half}}, {"color", {r, g * 0.85F, b * 0.9F}}},
           {{"position", {-half, 0.0F, half}}, {"color", {r * 0.95F, g, b * 0.85F}}},
           {{"position", {-half, height, -half}}, {"color", {r * 1.1F, g * 1.05F, b}}},
           {{"position", {half, height, -half}}, {"color", {r, g * 1.1F, b * 0.95F}}},
           {{"position", {half, height, half}}, {"color", {r * 0.9F, g, b * 1.05F}}},
           {{"position", {-half, height, half}}, {"color", {r, g * 0.95F, b * 1.1F}}},
       }},
      {"indices",
       {
           0, 1, 5, 0, 5, 4, // front
           1, 2, 6, 1, 6, 5, // right
           2, 3, 7, 2, 7, 6, // back
           3, 0, 4, 3, 4, 7, // left
           4, 5, 6, 4, 6, 7, // top
           0, 3, 2, 0, 2, 1  // bottom
       }},
  };
}

auto writeNexusMeshJson(const nlohmann::json& meshJson, const std::string& outputPath) -> Result<void> {
  std::ofstream stream(outputPath);
  if (!stream.is_open()) {
    return Result<void>::err("Unable to write nexus mesh: " + outputPath);
  }
  stream << meshJson.dump(2);
  if (!stream.good()) {
    return Result<void>::err("Failed while writing nexus mesh: " + outputPath);
  }
  return Result<void>::ok();
}

} // namespace nexus::generative
