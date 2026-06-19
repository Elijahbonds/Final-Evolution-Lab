#include "nexus/assets/asset_manifest.h"

#include <nlohmann/json.hpp>

#include <fstream>
#include <optional>
#include <sstream>

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
      }
      if (assetJson.contains("fallback")) {
        record.fallback = parseProceduralFallback(assetJson.at("fallback").get<std::string>());
      }
      if (assetJson.contains("generation_method")) {
        record.generationMethod = assetJson.at("generation_method").get<std::string>();
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

auto AssetManifest::resolveImportedPath(const AssetRecord& asset) const -> std::string {
  if (asset.importedMesh.empty()) {
    return {};
  }
  if (asset.importedMesh.front() == '/') {
    return asset.importedMesh;
  }
  if (m_importRoot.empty()) {
    return asset.importedMesh;
  }
  return m_importRoot + "/" + asset.importedMesh;
}

} // namespace nexus::assets
