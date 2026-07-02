import Foundation
import SceneKit
import UIKit

/// Loads bundled `.nexusmesh.json` sidecars for SceneKit fallback when Metal is unavailable.
enum NexusBundledMeshLoader {
    private static let manifestRelativePath = "assets/nexus/manifests/nexus_asset_manifest.json"

    struct VenueAssets {
        let environmentAssetId: String
        let backdropAssetId: String?
    }

    static func hasBundledManifest() -> Bool {
        nexus_metal_bridge_has_bundled_manifest()
    }

    static func isMeshLoadable(assetId: String) -> Bool {
        assetId.withCString { cStr in
            nexus_metal_bridge_bundled_mesh_loadable(cStr)
        }
    }

    static func resolveMeshPath(assetId: String) -> String? {
        var buffer = [CChar](repeating: 0, count: 4096)
        let ok = assetId.withCString { cStr in
            nexus_metal_bridge_resolve_bundled_mesh_path(cStr, &buffer, buffer.count)
        }
        if ok {
            let path = String(cString: buffer)
            if !path.isEmpty { return path }
        }
        // Swift-native fallback so every mode's environment loads even when the
        // C++ bridge can't resolve it (SceneKit-only builds, tests). Resolves
        // the manifest's imported-mesh filename from the app bundle.
        return resolveMeshPathNatively(assetId: assetId)
    }

    /// Resolve `assetId` → bundled `.nexusmesh.json` file path from the manifest
    /// `assets` map, preferring the mobile LOD. No C++ dependency.
    static func resolveMeshPathNatively(assetId: String, preferMobile: Bool = true) -> String? {
        guard let (desktop, mobile) = importedMeshFilenames[assetId] else { return nil }
        let candidates = preferMobile ? [mobile, desktop].compactMap { $0 } : [desktop, mobile].compactMap { $0 }
        for filename in candidates {
            // filename e.g. "zen_dojo_environment_model_fbx_mobile.nexusmesh.json"
            let base = (filename as NSString).deletingPathExtension        // ...nexusmesh
            if let url = Bundle.main.url(forResource: base, withExtension: "json",
                                        subdirectory: "assets/nexus/imported") {
                return url.path
            }
            if let url = Bundle.main.url(forResource: base, withExtension: "json") {
                return url.path
            }
        }
        return nil
    }

    /// `asset_id → (desktopFilename, mobileFilename?)` parsed once from the manifest.
    static let importedMeshFilenames: [String: (desktop: String, mobile: String?)] = {
        guard let url = bundledManifestURL(),
              let data = try? Data(contentsOf: url) else { return [:] }
        return parseImportedMeshFilenames(from: data)
    }()

    static func venueAssets(for mode: GameModeId) -> VenueAssets? {
        guard let manifestURL = bundledManifestURL(),
              let data = try? Data(contentsOf: manifestURL) else {
            return nil
        }
        return venueAssets(for: mode, manifestData: data)
    }

    /// Data-injectable resolution (testable from the repo manifest without a bundle).
    static func venueAssets(for mode: GameModeId, manifestData data: Data) -> VenueAssets? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let venues = json["venues"] as? [[String: Any]] else {
            return nil
        }
        let runtimeMode = mode.nexusRuntimeModeId
        for venue in venues {
            guard let modeIds = venue["mode_ids"] as? [String],
                  modeIds.contains(runtimeMode),
                  let environmentId = venue["environment_asset_id"] as? String else {
                continue
            }
            let backdropId = venue["backdrop_asset_id"] as? String
            return VenueAssets(environmentAssetId: environmentId, backdropAssetId: backdropId)
        }
        return nil
    }

    /// Parse `asset_id → (desktopFilename, mobileFilename?)` from manifest data.
    static func parseImportedMeshFilenames(from data: Data) -> [String: (desktop: String, mobile: String?)] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let assets = json["assets"] as? [[String: Any]] else {
            return [:]
        }
        var map: [String: (desktop: String, mobile: String?)] = [:]
        for asset in assets {
            guard let id = asset["id"] as? String,
                  let desktop = asset["imported_mesh"] as? String else { continue }
            map[id] = (desktop, asset["imported_mesh_mobile"] as? String)
        }
        return map
    }

    /// Backdrop mesh from manifest (`backdrop_asset_id` or scaled primary environment).
    @discardableResult
    static func attachBackdropFromManifest(for mode: GameModeId, to scene: SCNScene) -> Bool {
        guard let assets = venueAssets(for: mode) else { return false }
        let placement = PremiumViewpointConfig.backdropPlacement(for: mode)

        if let backdropId = assets.backdropAssetId,
           let backdrop = loadNode(
               assetId: backdropId,
               nodeName: "bundledVenueBackdrop",
               position: placement.manifestPosition,
               scale: placement.manifestScale
           ) {
            PremiumViewpointConfig.applyBackdropTuning(to: backdrop, for: mode)
            scene.rootNode.addChildNode(backdrop)
            return true
        }

        if mode == .marketBrowse,
           let primary = loadNode(
               assetId: assets.environmentAssetId,
               nodeName: "bundledVenueEnvironment",
               position: SCNVector3(0, 0, 0),
               scale: SCNVector3(1, 1, 1)
           ) {
            PremiumViewpointConfig.applyBackdropTuning(to: primary, for: mode)
            scene.rootNode.addChildNode(primary)
            return true
        }

        return false
    }

    /// Distant primary environment mesh for SceneKit-only modes without a separate backdrop entry.
    @discardableResult
    static func attachEnvironmentBackdrop(for mode: GameModeId, to scene: SCNScene) -> Bool {
        guard let assets = venueAssets(for: mode),
              assets.backdropAssetId == nil else {
            return false
        }
        let placement = PremiumViewpointConfig.backdropPlacement(for: mode)
        guard let environment = loadNode(
            assetId: assets.environmentAssetId,
            nodeName: "bundledVenueEnvironment",
            position: placement.environmentPosition,
            scale: placement.environmentScale
        ) else {
            return false
        }
        PremiumViewpointConfig.applyBackdropTuning(to: environment, for: mode)
        scene.rootNode.addChildNode(environment)
        return true
    }

    static func loadNode(
        assetId: String,
        nodeName: String,
        position: SCNVector3,
        scale: SCNVector3
    ) -> SCNNode? {
        guard let path = resolveMeshPath(assetId: assetId),
              let geometry = loadGeometry(from: path) else {
            return nil
        }
        let node = SCNNode(geometry: geometry)
        node.name = nodeName
        node.position = position
        node.scale = scale
        node.renderingOrder = -100
        return node
    }

    private static func bundledManifestURL() -> URL? {
        if let url = Bundle.main.url(
            forResource: "nexus_asset_manifest",
            withExtension: "json",
            subdirectory: "assets/nexus/manifests"
        ) {
            return url
        }
        return Bundle.main.resourceURL?
            .appendingPathComponent(manifestRelativePath)
    }

    private static func loadGeometry(from path: String) -> SCNGeometry? {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return nil }
        return buildGeometry(fromJSONData: data)
    }

    /// Builds lit SceneKit geometry from a `.nexusmesh.json` payload.
    ///
    /// Quality notes vs. the prior implementation:
    ///  - Loads the per-vertex `normal` array (previously discarded), enabling
    ///    real physically-based shading instead of flat `.constant` lighting.
    ///  - Loads vertices faithfully with 1:1 indices — the prior stride-sampling
    ///    decimation dropped vertices then discarded any triangle referencing a
    ///    removed vertex, shredding meshes into holes. The bundled `_mobile`
    ///    LODs are already decimated (~40k verts), well within SceneKit budget.
    ///  - Vertex colors drive albedo (mobile LODs carry no textures).
    /// Internal (not private) so unit tests can exercise it directly.
    static func buildGeometry(fromJSONData data: Data) -> SCNGeometry? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let verticesJson = json["vertices"] as? [[String: Any]],
              let indicesJson = json["indices"] as? [Int],
              !verticesJson.isEmpty,
              indicesJson.count >= 3 else {
            return nil
        }

        var positions = [SCNVector3](); positions.reserveCapacity(verticesJson.count)
        var normals = [SCNVector3](); normals.reserveCapacity(verticesJson.count)
        var colors = [Float](); colors.reserveCapacity(verticesJson.count * 3)
        var hasNormals = true

        for vertexJson in verticesJson {
            guard let position = vertexJson["position"] as? [Double], position.count == 3 else {
                return nil // faithful load — a malformed vertex invalidates the index mapping
            }
            positions.append(SCNVector3(Float(position[0]), Float(position[1]), Float(position[2])))

            if let n = vertexJson["normal"] as? [Double], n.count == 3 {
                normals.append(SCNVector3(Float(n[0]), Float(n[1]), Float(n[2])))
            } else {
                hasNormals = false
            }

            let c = vertexJson["color"] as? [Double] ?? [0.8, 0.85, 0.9]
            colors.append(Float(c[safe: 0] ?? 0.8))
            colors.append(Float(c[safe: 1] ?? 0.85))
            colors.append(Float(c[safe: 2] ?? 0.9))
        }

        let vertexCount = positions.count
        let indices = indicesJson.map { Int32($0) }
        guard indices.allSatisfy({ $0 >= 0 && Int($0) < vertexCount }) else { return nil }

        let vertexSource = SCNGeometrySource(vertices: positions)
        var sources = [vertexSource]
        if hasNormals, normals.count == vertexCount {
            sources.append(SCNGeometrySource(normals: normals))
        }
        sources.append(SCNGeometrySource(
            data: colors.withUnsafeBufferPointer { Data(buffer: $0) },
            semantic: .color,
            vectorCount: vertexCount,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.stride * 3
        ))

        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: sources, elements: [element])

        let material = SCNMaterial()
        // Real lighting when normals are present; fall back to unlit only if a
        // mesh genuinely lacks them.
        material.lightingModel = (hasNormals && normals.count == vertexCount) ? .physicallyBased : .constant
        material.isDoubleSided = true
        material.diffuse.contents = UIColor.white   // vertex colors modulate albedo
        material.roughness.contents = 0.85
        geometry.materials = [material]
        return geometry
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
