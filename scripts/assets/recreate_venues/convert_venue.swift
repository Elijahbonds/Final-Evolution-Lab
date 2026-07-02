#!/usr/bin/env swift
// Recreates venue assets for SceneKit: indexed geometry from the existing
// .nexusmesh.json (desktop LOD: positions/normals/uv/indices) + the PBR
// textures recovered from the source FBX → compiled .scn (textures embedded),
// plus an offscreen render PNG for visual verification.
//
// Usage: swift convert_venue.swift <mesh.nexusmesh.json> <albedo> <metalRough|-> <normal|-> <out.scn> <preview.png>
import Foundation
import SceneKit
import ModelIO
import SceneKit.ModelIO
import AppKit

let args = CommandLine.arguments
guard args.count == 7 else {
    FileHandle.standardError.write("usage: convert_venue.swift <mesh.json> <albedo> <mr|-> <normal|-> <out.scn> <preview.png>\n".data(using: .utf8)!)
    exit(2)
}

// MARK: Geometry source — nexusmesh JSON (indexed, when it has uv) or OBJ
// via ModelIO (preserves the FBX UVs that some JSON conversions dropped).

struct Mesh: Decodable {
    let name: String
    let vertices: [Vertex]
    let indices: [Int32]
    struct Vertex: Decodable {
        let position: [Float]
        let normal: [Float]?
        let uv: [Float]?
    }
}

let inputURL = URL(fileURLWithPath: args[1])
let geometry: SCNGeometry
let meshName = inputURL.deletingPathExtension().deletingPathExtension().lastPathComponent

if inputURL.pathExtension.lowercased() == "obj" {
    // Parse OBJ directly and re-index: dedupe identical v/vt/vn triples so the
    // unindexed OBJ (3 verts per triangle) shrinks back to shared vertices.
    var vPos: [[Float]] = [], vUV: [[Float]] = [], vNrm: [[Float]] = []
    var outPos: [SCNVector3] = [], outUV: [CGPoint] = [], outNrm: [SCNVector3] = []
    var indexOf: [String: Int32] = [:]
    var indices: [Int32] = []

    let text = try String(contentsOf: inputURL, encoding: .utf8)
    for line in text.split(separator: "\n") {
        if line.hasPrefix("v ") {
            let p = line.split(separator: " ").dropFirst().compactMap { Float($0) }
            vPos.append(p)
        } else if line.hasPrefix("vt ") {
            let t = line.split(separator: " ").dropFirst().compactMap { Float($0) }
            vUV.append(t)
        } else if line.hasPrefix("vn ") {
            let n = line.split(separator: " ").dropFirst().compactMap { Float($0) }
            vNrm.append(n)
        } else if line.hasPrefix("f ") {
            let corners = line.split(separator: " ").dropFirst()
            var face: [Int32] = []
            for corner in corners {
                let key = String(corner)
                if let existing = indexOf[key] {
                    face.append(existing)
                    continue
                }
                let parts = corner.split(separator: "/", omittingEmptySubsequences: false)
                func ref(_ i: Int, _ count: Int) -> Int? {
                    guard i < parts.count, let raw = Int(parts[i]) else { return nil }
                    return raw > 0 ? raw - 1 : count + raw
                }
                guard let pi = ref(0, vPos.count), pi < vPos.count, vPos[pi].count >= 3 else { continue }
                let new = Int32(outPos.count)
                outPos.append(SCNVector3(CGFloat(vPos[pi][0]), CGFloat(vPos[pi][1]), CGFloat(vPos[pi][2])))
                if let ti = ref(1, vUV.count), ti < vUV.count, vUV[ti].count >= 2 {
                    outUV.append(CGPoint(x: CGFloat(vUV[ti][0]), y: CGFloat(vUV[ti][1])))
                }
                if let ni = ref(2, vNrm.count), ni < vNrm.count, vNrm[ni].count >= 3 {
                    outNrm.append(SCNVector3(CGFloat(vNrm[ni][0]), CGFloat(vNrm[ni][1]), CGFloat(vNrm[ni][2])))
                }
                indexOf[key] = new
                face.append(new)
            }
            // Triangulate fans for quads/ngons.
            if face.count >= 3 {
                for k in 1..<(face.count - 1) {
                    indices.append(contentsOf: [face[0], face[k], face[k + 1]])
                }
            }
        }
    }
    guard !outPos.isEmpty, indices.count >= 3 else {
        FileHandle.standardError.write("no geometry in OBJ\n".data(using: .utf8)!)
        exit(1)
    }
    var sources: [SCNGeometrySource] = [SCNGeometrySource(vertices: outPos)]
    if outNrm.count == outPos.count { sources.append(SCNGeometrySource(normals: outNrm)) }
    if outUV.count == outPos.count { sources.append(SCNGeometrySource(textureCoordinates: outUV)) }
    let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
    geometry = SCNGeometry(sources: sources, elements: [element])
} else {
    let mesh = try JSONDecoder().decode(Mesh.self, from: Data(contentsOf: inputURL))
    var positions: [SCNVector3] = []
    var normals: [SCNVector3] = []
    var uvs: [CGPoint] = []
    positions.reserveCapacity(mesh.vertices.count)
    for v in mesh.vertices {
        positions.append(SCNVector3(CGFloat(v.position[0]), CGFloat(v.position[1]), CGFloat(v.position[2])))
        if let n = v.normal { normals.append(SCNVector3(CGFloat(n[0]), CGFloat(n[1]), CGFloat(n[2]))) }
        if let t = v.uv { uvs.append(CGPoint(x: CGFloat(t[0]), y: CGFloat(t[1]))) }
    }
    var sources: [SCNGeometrySource] = [SCNGeometrySource(vertices: positions)]
    if normals.count == positions.count { sources.append(SCNGeometrySource(normals: normals)) }
    if uvs.count == positions.count { sources.append(SCNGeometrySource(textureCoordinates: uvs)) }
    let element = SCNGeometryElement(indices: mesh.indices, primitiveType: .triangles)
    geometry = SCNGeometry(sources: sources, elements: [element])
}
geometry.name = meshName
let hasUV = !geometry.sources(for: .texcoord).isEmpty

// MARK: PBR material from recovered FBX textures

func image(_ path: String) -> NSImage? { path == "-" ? nil : NSImage(contentsOfFile: path) }
let material = SCNMaterial()
material.lightingModel = .physicallyBased
material.isDoubleSided = true
material.diffuse.contents = hasUV ? (image(args[2]) ?? NSColor.white) : NSColor.white
// The batch driver pre-splits the glTF combined map into *_roughness.png (G)
// and *_metalness.png (B); args[3] is the roughness image, and a sibling
// *_metalness.png is used when present.
if hasUV, let rough = image(args[3]) {
    material.roughness.contents = rough
    let metalPath = args[3].replacingOccurrences(of: "_roughness.png", with: "_metalness.png")
    material.metalness.contents = image(metalPath) ?? NSColor.black
} else {
    material.roughness.contents = 0.85
    material.metalness.contents = 0.0
}
if hasUV, let n = image(args[4]) { material.normal.contents = n }
geometry.materials = [material]

let scene = SCNScene()
let node = SCNNode(geometry: geometry)
node.name = meshName
scene.rootNode.addChildNode(node)

let outURL = URL(fileURLWithPath: args[5])
guard scene.write(to: outURL, options: nil, delegate: nil, progressHandler: nil) else {
    FileHandle.standardError.write("scene.write failed\n".data(using: .utf8)!)
    exit(1)
}

// MARK: Reload + offscreen render for visual verification

let reloaded = try SCNScene(url: outURL, options: nil)
var verts = 0
reloaded.rootNode.enumerateHierarchy { n, _ in
    verts += n.geometry?.sources(for: .vertex).first?.vectorCount ?? 0
}

// Frame the mesh with a camera and light, render to PNG.
let (center, radius): (SCNVector3, CGFloat) = {
    let (minV, maxV) = reloaded.rootNode.boundingBox
    let c = SCNVector3((minV.x + maxV.x) / 2, (minV.y + maxV.y) / 2, (minV.z + maxV.z) / 2)
    let dx = maxV.x - minV.x, dy = maxV.y - minV.y, dz = maxV.z - minV.z
    let r = CGFloat(max(dx, max(dy, dz))) / 2
    return (c, max(r, 0.001))
}()
let cameraNode = SCNNode()
cameraNode.camera = SCNCamera()
cameraNode.camera!.zFar = Double(radius * 10)
cameraNode.position = SCNVector3(center.x + radius * 0.9, center.y + radius * 0.8, center.z + radius * 1.4)
cameraNode.look(at: center)
reloaded.rootNode.addChildNode(cameraNode)
let sun = SCNNode()
sun.light = SCNLight(); sun.light!.type = .directional; sun.light!.intensity = 1100
sun.eulerAngles = SCNVector3(-0.9, 0.4, 0)
reloaded.rootNode.addChildNode(sun)
let ambient = SCNNode()
ambient.light = SCNLight(); ambient.light!.type = .ambient; ambient.light!.intensity = 350
reloaded.rootNode.addChildNode(ambient)

let renderer = SCNRenderer(device: nil, options: nil)
renderer.scene = reloaded
renderer.pointOfView = cameraNode
let img = renderer.snapshot(atTime: 0, with: CGSize(width: 900, height: 600), antialiasingMode: .multisampling4X)
if let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff),
   let png = rep.representation(using: .png, properties: [:]) {
    try png.write(to: URL(fileURLWithPath: args[6]))
}

print("OK \(outURL.lastPathComponent): \(verts) indexed vertices, uv=\(hasUV), reload verified, preview \(args[6])")
