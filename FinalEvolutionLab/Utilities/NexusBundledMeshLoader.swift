import Foundation
import SceneKit

/// Loads bundled `.nexusmesh.json` sidecars for SceneKit fallback when Metal is unavailable.
enum NexusBundledMeshLoader {
    private static let manifestRelativePath = "assets/nexus/manifests/nexus_asset_manifest.json"
    private static let sceneKitVertexBudget = 18_000

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
        guard ok else { return nil }
        let path = String(cString: buffer)
        return path.isEmpty ? nil : path
    }

    static func venueAssets(for mode: GameModeId) -> VenueAssets? {
        guard let manifestURL = bundledManifestURL(),
              let data = try? Data(contentsOf: manifestURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
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
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let verticesJson = json["vertices"] as? [[String: Any]],
              let indicesJson = json["indices"] as? [Int],
              !verticesJson.isEmpty,
              indicesJson.count >= 3 else {
            return nil
        }

        let vertexSampleStride = max(1, verticesJson.count / sceneKitVertexBudget)
        var remappedIndices = [Int32]()
        var positions = [SCNVector3]()
        var colors = [SCNVector3]()
        positions.reserveCapacity(min(verticesJson.count, sceneKitVertexBudget + 1))
        colors.reserveCapacity(min(verticesJson.count, sceneKitVertexBudget + 1))

        var oldToNew = [Int: Int]()
        for (oldIndex, vertexJson) in verticesJson.enumerated() where oldIndex % vertexSampleStride == 0 {
            guard let position = vertexJson["position"] as? [Double], position.count == 3 else {
                continue
            }
            let colorComponents = vertexJson["color"] as? [Double] ?? [0.8, 0.85, 0.9]
            let newIndex = positions.count
            oldToNew[oldIndex] = newIndex
            positions.append(SCNVector3(Float(position[0]), Float(position[1]), Float(position[2])))
            colors.append(SCNVector3(
                Float(colorComponents[safe: 0] ?? 0.8),
                Float(colorComponents[safe: 1] ?? 0.85),
                Float(colorComponents[safe: 2] ?? 0.9)
            ))
        }

        for triStart in stride(from: 0, to: indicesJson.count - 2, by: 3) {
            let a = indicesJson[triStart]
            let b = indicesJson[triStart + 1]
            let c = indicesJson[triStart + 2]
            guard let na = oldToNew[a], let nb = oldToNew[b], let nc = oldToNew[c] else {
                continue
            }
            remappedIndices.append(contentsOf: [Int32(na), Int32(nb), Int32(nc)])
        }

        guard remappedIndices.count >= 3, !positions.isEmpty else { return nil }

        let vertexSource = SCNGeometrySource(
            data: Data(bytes: positions, count: MemoryLayout<SCNVector3>.stride * positions.count),
            semantic: .vertex,
            vectorCount: positions.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<SCNVector3>.stride
        )

        let colorData = colors.flatMap { [Float($0.x), Float($0.y), Float($0.z)] }
        let colorSource = SCNGeometrySource(
            data: colorData.withUnsafeBufferPointer { Data(buffer: $0) },
            semantic: .color,
            vectorCount: colors.count,
            usesFloatComponents: true,
            componentsPerVector: 3,
            bytesPerComponent: MemoryLayout<Float>.size,
            dataOffset: 0,
            dataStride: MemoryLayout<Float>.stride * 3
        )

        let indexData = Data(bytes: remappedIndices, count: MemoryLayout<Int32>.stride * remappedIndices.count)
        let element = SCNGeometryElement(
            data: indexData,
            primitiveType: .triangles,
            primitiveCount: remappedIndices.count / 3,
            bytesPerIndex: MemoryLayout<Int32>.size
        )

        let geometry = SCNGeometry(sources: [vertexSource, colorSource], elements: [element])
        let material = SCNMaterial()
        material.lightingModel = .constant
        material.isDoubleSided = true
        geometry.materials = [material]
        return geometry
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
