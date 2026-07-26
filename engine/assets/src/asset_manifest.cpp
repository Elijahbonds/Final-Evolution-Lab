#include "nexus/assets/asset_manifest.h"

#include "nexus/core/log.h"

#include <nlohmann/json.hpp>

#include <filesystem>
#include <fstream>
#include <cstdlib>
#include <optional>
#include <sstream>
#include <string_view>

namespace nexus::assets {

namespace {

auto readFileToString(const std::string& path) -> std::optional<std::string> {
  std::ifstream stream(path);
  if (!stream.is_open()) {
    return std::nullopt;
  }
  std::ostringstream buffer;
  buffer << stream.rdbuf();
  return buffer.str();
}

auto prefixResourceRootIfRelative(const std::string& path) -> std::string {
  if (path.empty() || path.front() == '/') {
    return path;
  }
  if (const char* root = std::getenv("NEXUS_RESOURCE_ROOT")) {
    if (root[0] != '\0') {
      return std::string{root} + "/" + path;
    }
  }
  return path;
}

} // namespace

auto parseAssetSource(std::string_view value) -> AssetSource {
  if (value == "meshy") {
    return AssetSource::kMeshy;
  }
  if (value == "luma") {
    return AssetSource::kLuma;
  }
  if (value == "unreal") {
    return AssetSource::kUnreal;
  }
  if (value == "seele") {
    return AssetSource::kSeele;
  }
  return AssetSource::kProcedural;
}

auto parseProceduralFallback(std::string_view value) -> ProceduralFallback {
  if (value == "flat_plane") {
    return ProceduralFallback::kFlatPlane;
  }
  if (value == "none") {
    return ProceduralFallback::kNone;
  }
  return ProceduralFallback::kArenaGrid;
}

auto parseAssetKind(std::string_view value) -> AssetKind {
  if (value == "character") {
    return AssetKind::kCharacter;
  }
  if (value == "prop") {
    return AssetKind::kProp;
  }
  if (value == "marker") {
    return AssetKind::kMarker;
  }
  return AssetKind::kEnvironment;
}

auto AssetManifest::loadFromFile(const std::string& path) -> Result<AssetManifest> {
  const auto fileContents = readFileToString(path);
  if (!fileContents.has_value()) {
    return Result<AssetManifest>::err("Unable to open manifest: " + path);
  }

  try {
    const auto json = nlohmann::json::parse(*fileContents);
    AssetManifest manifest;

    if (json.contains("default_mode")) {
      manifest.m_defaultMode = json.at("default_mode").get<std::string>();
    }
    if (json.contains("import_root")) {
      manifest.m_importRoot = json.at("import_root").get<std::string>();
    }
    if (json.contains("source_root")) {
      manifest.m_sourceRoot = json.at("source_root").get<std::string>();
    }

    for (const auto& assetJson : json.at("assets")) {
      AssetRecord record{};
      record.id = assetJson.at("id").get<std::string>();
      if (assetJson.contains("name")) {
        record.name = assetJson.at("name").get<std::string>();
      }
      if (assetJson.contains("source")) {
        record.source = parseAssetSource(assetJson.at("source").get<std::string>());
      }
      if (assetJson.contains("kind")) {
        record.kind = parseAssetKind(assetJson.at("kind").get<std::string>());
      }
      if (assetJson.contains("source_url")) {
        record.sourceUrl = assetJson.at("source_url").get<std::string>();
      }
      if (assetJson.contains("source_descriptor")) {
        record.sourceDescriptor = assetJson.at("source_descriptor").get<std::string>();
      }
      if (assetJson.contains("unreal_package")) {
        record.unrealPackage = assetJson.at("unreal_package").get<std::string>();
      }
      if (assetJson.contains("imported_mesh")) {
        record.importedMesh = assetJson.at("imported_mesh").get<std::string>();
        record.importedMeshDesktop = record.importedMesh;
      }
      if (assetJson.contains("imported_mesh_mobile")) {
        record.importedMeshMobile = assetJson.at("imported_mesh_mobile").get<std::string>();
      }
      if (assetJson.contains("imported_mesh_desktop")) {
        record.importedMeshDesktop = assetJson.at("imported_mesh_desktop").get<std::string>();
      }
      if (assetJson.contains("imported_mesh_full")) {
        record.importedMeshFull = assetJson.at("imported_mesh_full").get<std::string>();
      }
      if (assetJson.contains("fallback")) {
        record.fallback = parseProceduralFallback(assetJson.at("fallback").get<std::string>());
      }
      if (assetJson.contains("generation_method")) {
        record.generationMethod = assetJson.at("generation_method").get<std::string>();
      }
      if (assetJson.contains("vertex_count")) {
        record.vertexCount = assetJson.at("vertex_count").get<int>();
      }
      if (assetJson.contains("tri_count")) {
        record.triCount = assetJson.at("tri_count").get<int>();
      }
      manifest.m_assets.push_back(std::move(record));
    }

    for (const auto& venueJson : json.at("venues")) {
      VenueRecord record{};
      record.venueKey = venueJson.at("venue_key").get<std::string>();
      record.displayName = venueJson.at("display_name").get<std::string>();
      if (venueJson.contains("fel_venue_id")) {
        record.felVenueId = venueJson.at("fel_venue_id").get<std::string>();
      }
      record.modeIds = venueJson.at("mode_ids").get<std::vector<std::string>>();
      record.environmentAssetId = venueJson.at("environment_asset_id").get<std::string>();
      if (venueJson.contains("backdrop_asset_id")) {
        record.backdropAssetId = venueJson.at("backdrop_asset_id").get<std::string>();
      }
      if (venueJson.contains("unreal_open_level")) {
        record.unrealOpenLevel = venueJson.at("unreal_open_level").get<std::string>();
      }
      manifest.m_venues.push_back(std::move(record));
    }

    return Result<AssetManifest>::ok(std::move(manifest));
  } catch (const std::exception& exception) {
    return Result<AssetManifest>::err(std::string("Manifest parse error: ") + exception.what());
  }
}

auto AssetManifest::findAsset(std::string_view assetId) const -> const AssetRecord* {
  for (const AssetRecord& record : m_assets) {
    if (record.id == assetId) {
      return &record;
    }
  }
  return nullptr;
}

auto AssetManifest::findVenueForMode(std::string_view modeId) const -> const VenueRecord* {
  for (const VenueRecord& record : m_venues) {
    for (const std::string& mode : record.modeIds) {
      if (mode == modeId) {
        return &record;
      }
    }
  }
  return nullptr;
}

auto AssetManifest::findVenueByKey(std::string_view venueKey) const -> const VenueRecord* {
  for (const VenueRecord& record : m_venues) {
    if (record.venueKey == venueKey) {
      return &record;
    }
  }
  return nullptr;
}

auto AssetManifest::resolveImportedPath(const AssetRecord& asset) const -> std::string {
  if (asset.importedMesh.empty()) {
    return {};
  }
  if (asset.importedMesh.front() == '/') {
    return asset.importedMesh;
  }
  if (m_importRoot.empty()) {
    return prefixResourceRootIfRelative(asset.importedMesh);
  }
  return prefixResourceRootIfRelative(m_importRoot + "/" + asset.importedMesh);
}

namespace {

auto envPrefersFullMeshLod() -> bool {
  const char* profile = std::getenv("NEXUS_MESH_PROFILE");
  if (profile != nullptr) {
    return std::string_view{profile} == "full" || std::string_view{profile} == "desktop";
  }
  const char* lod = std::getenv("NEXUS_MESH_LOD");
  if (lod != nullptr) {
    return std::string_view{lod} == "full";
  }
  const char* legacyMobile = std::getenv("NEXUS_USE_MOBILE_MESH");
  if (legacyMobile != nullptr) {
    return std::string_view{legacyMobile} == "0";
  }
  return false;
}

auto joinImportPath(std::string_view importRoot, std::string_view relativePath) -> std::string {
  if (relativePath.empty()) {
    return {};
  }
  if (relativePath.front() == '/') {
    return std::string{relativePath};
  }
  if (importRoot.empty()) {
    return prefixResourceRootIfRelative(std::string{relativePath});
  }
  return prefixResourceRootIfRelative(std::string{importRoot} + "/" + std::string{relativePath});
}

auto pathExists(const std::string& path) -> bool {
  return !path.empty() && std::filesystem::exists(path);
}

auto inferredMobileFilename(std::string_view desktopFilename) -> std::string {
  constexpr std::string_view kSuffix = ".nexusmesh.json";
  if (desktopFilename.size() > kSuffix.size() &&
      desktopFilename.substr(desktopFilename.size() - kSuffix.size()) == kSuffix) {
    return std::string(desktopFilename.substr(0, desktopFilename.size() - kSuffix.size())) +
           "_mobile.nexusmesh.json";
  }
  return std::string(desktopFilename) + "_mobile.nexusmesh.json";
}

constexpr float kDefaultDistanceLodThresholdMeters = 25.0F;

} // namespace

auto devDrawStatsEnabled() -> bool {
  const char* flag = std::getenv("NEXUS_DEV_DRAW_STATS");
  if (flag == nullptr) {
    return true;
  }
  return std::string_view{flag} != "0" && std::string_view{flag} != "false";
}

auto distanceLodEnabled() -> bool {
  const char* flag = std::getenv("NEXUS_DISTANCE_LOD");
  return flag != nullptr && flag[0] != '\0' && flag[0] != '0';
}

auto activeMeshProfileName() -> std::string_view {
  const char* profile = std::getenv("NEXUS_MESH_PROFILE");
  if (profile != nullptr && profile[0] != '\0') {
    return profile;
  }
  if (envPrefersFullMeshLod()) {
    return "desktop";
  }
  return "desktop";
}

auto meshProfilePrefersMobile() -> bool {
  const char* profile = std::getenv("NEXUS_MESH_PROFILE");
  if (profile != nullptr) {
    return std::string_view{profile} == "mobile";
  }
  if (envPrefersFullMeshLod()) {
    return false;
  }
  const char* legacyMobile = std::getenv("NEXUS_USE_MOBILE_MESH");
  if (legacyMobile != nullptr) {
    return std::string_view{legacyMobile} != "0";
  }
  return false;
}

auto AssetManifest::resolveMeshPathForProfile(const AssetRecord& asset,
                                              std::string_view profile) const -> std::string {
  const bool wantMobile = profile == "mobile";
  const std::string desktopRelative =
      !asset.importedMeshDesktop.empty() ? asset.importedMeshDesktop : asset.importedMesh;

  if (!wantMobile) {
    if (!asset.importedMeshFull.empty()) {
      const std::string fullPath = joinImportPath(m_importRoot, asset.importedMeshFull);
      if (pathExists(fullPath)) {
        return fullPath;
      }
    }
    if (!desktopRelative.empty()) {
      return joinImportPath(m_importRoot, desktopRelative);
    }
    return resolveImportedPath(asset);
  }

  if (!asset.importedMeshMobile.empty()) {
    const std::string mobileRelative = asset.importedMeshMobile;
    if (mobileRelative != desktopRelative) {
      const std::string mobilePath = joinImportPath(m_importRoot, mobileRelative);
      if (pathExists(mobilePath)) {
        return mobilePath;
      }
    }
  }

  if (!desktopRelative.empty()) {
    const std::string inferredRelative = inferredMobileFilename(desktopRelative);
    const std::string inferredPath = joinImportPath(m_importRoot, inferredRelative);
    if (pathExists(inferredPath)) {
      return inferredPath;
    }
  }

  if (!asset.importedMeshMobile.empty()) {
    const std::string mobilePath = joinImportPath(m_importRoot, asset.importedMeshMobile);
    if (pathExists(mobilePath)) {
      return mobilePath;
    }
    NEXUS_LOG_WARN(nexus::LogChannel::kRenderer,
                   "Mobile mesh missing, falling back to desktop: " + asset.importedMeshMobile);
  }

  if (!desktopRelative.empty()) {
    return joinImportPath(m_importRoot, desktopRelative);
  }
  return resolveImportedPath(asset);
}

auto AssetManifest::resolveMeshPathAtDistance(const AssetRecord& asset,
                                              float cameraDistanceMeters) const -> std::string {
  if (distanceLodEnabled()) {
    const char* profile =
        cameraDistanceMeters >= kDefaultDistanceLodThresholdMeters ? "mobile" : "desktop";
    return resolveMeshPathForProfile(asset, profile);
  }
  if (meshProfilePrefersMobile()) {
    return resolveMeshPathForProfile(asset, "mobile");
  }
  return resolveMeshPathForProfile(asset, "desktop");
}

auto AssetManifest::resolveMeshPath(const AssetRecord& asset) const -> std::string {
  if (meshProfilePrefersMobile()) {
    return resolveMeshPathForProfile(asset, "mobile");
  }
  return resolveMeshPathForProfile(asset, "desktop");
}

} // namespace nexus::assets
