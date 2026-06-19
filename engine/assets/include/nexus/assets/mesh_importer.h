#pragma once

#include "nexus/core/result.h"
#include "nexus/renderer/mesh.h"

#include <string>

namespace nexus::assets {

// Converts external mesh interchange into NEXUS renderer::Mesh.
// glTF/FBX paths are stubbed; .nexusmesh.json is fully supported.
class MeshImporter {
public:
  [[nodiscard]] static auto importFile(const std::string& path) -> Result<renderer::Mesh>;

  [[nodiscard]] static auto importNexusMeshJson(const std::string& path) -> Result<renderer::Mesh>;
  [[nodiscard]] static auto importGltf(const std::string& path) -> Result<renderer::Mesh>;
  [[nodiscard]] static auto importFbx(const std::string& path) -> Result<renderer::Mesh>;
};

} // namespace nexus::assets
