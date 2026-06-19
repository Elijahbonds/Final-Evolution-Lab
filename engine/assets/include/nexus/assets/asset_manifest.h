#pragma once

#include "nexus/core/result.h"

#include <optional>
#include <string>
#include <string_view>
#include <vector>

namespace nexus::assets {

enum class AssetSource {
  kMeshy,
  kLuma,
  kUnreal,
  kSeele,
  kProcedural,
};

enum class ProceduralFallback {
  kArenaGrid,
  kFlatPlane,
  kNone,
};

enum class AssetKind {
  kEnvironment,
  kCharacter,
  kProp,
  kMarker,
};

struct AssetRecord {
  std::string id;
  std::string name;
  AssetSource source{AssetSource::kProcedural};
  AssetKind kind{AssetKind::kEnvironment};
  std::string sourceUrl;
  std::string sourceDescriptor;
  std::string unrealPackage;
  std::string importedMesh;
  ProceduralFallback fallback{ProceduralFallback::kArenaGrid};
  std::string generationMethod;
};

struct VenueRecord {
  std::string venueKey;
  std::string displayName;
  std::string felVenueId;
  std::vector<std::string> modeIds;
  std::string environmentAssetId;
  std::string unrealOpenLevel;
};

class AssetManifest {
public:
  [[nodiscard]] static auto loadFromFile(const std::string& path) -> Result<AssetManifest>;

  [[nodiscard]] auto defaultMode() const -> std::string_view { return m_defaultMode; }
  [[nodiscard]] auto importRoot() const -> std::string_view { return m_importRoot; }
  [[nodiscard]] auto sourceRoot() const -> std::string_view { return m_sourceRoot; }

  [[nodiscard]] auto assets() const -> const std::vector<AssetRecord>& { return m_assets; }
  [[nodiscard]] auto venues() const -> const std::vector<VenueRecord>& { return m_venues; }

  [[nodiscard]] auto findAsset(std::string_view assetId) const -> const AssetRecord*;
  [[nodiscard]] auto findVenueForMode(std::string_view modeId) const -> const VenueRecord*;
  [[nodiscard]] auto resolveImportedPath(const AssetRecord& asset) const -> std::string;

private:
  std::string m_defaultMode{"basketball_h2h"};
  std::string m_importRoot{"assets/nexus/imported"};
  std::string m_sourceRoot{"assets/nexus/source"};
  std::vector<AssetRecord> m_assets;
  std::vector<VenueRecord> m_venues;
};

[[nodiscard]] auto parseAssetSource(std::string_view value) -> AssetSource;
[[nodiscard]] auto parseProceduralFallback(std::string_view value) -> ProceduralFallback;
[[nodiscard]] auto parseAssetKind(std::string_view value) -> AssetKind;

} // namespace nexus::assets
