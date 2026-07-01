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
  std::string importedMeshMobile;
  std::string importedMeshDesktop;
  std::string importedMeshFull;
  ProceduralFallback fallback{ProceduralFallback::kArenaGrid};
  std::string generationMethod;
  int vertexCount{0};
  int triCount{0};
};

struct VenueRecord {
  std::string venueKey;
  std::string displayName;
  std::string felVenueId;
  std::vector<std::string> modeIds;
  std::string environmentAssetId;
  /// Optional distant ambient layer (e.g. Luma Venice shop skyline behind playable court).
  std::string backdropAssetId;
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
  [[nodiscard]] auto findVenueByKey(std::string_view venueKey) const -> const VenueRecord*;
  [[nodiscard]] auto resolveImportedPath(const AssetRecord& asset) const -> std::string;
  [[nodiscard]] auto resolveMeshPath(const AssetRecord& asset) const -> std::string;
  [[nodiscard]] auto resolveMeshPathForProfile(const AssetRecord& asset,
                                                 std::string_view profile) const -> std::string;
  [[nodiscard]] auto resolveMeshPathAtDistance(const AssetRecord& asset,
                                                float cameraDistanceMeters) const -> std::string;

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

/// Active mesh profile from `NEXUS_MESH_PROFILE` (`desktop` default, `mobile` for iOS budget).
[[nodiscard]] auto activeMeshProfileName() -> std::string_view;
[[nodiscard]] auto meshProfilePrefersMobile() -> bool;
[[nodiscard]] auto devDrawStatsEnabled() -> bool;
[[nodiscard]] auto distanceLodEnabled() -> bool;

} // namespace nexus::assets
