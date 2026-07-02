#!/usr/bin/env swift
// Procedural placeholder for the Veniceball Shop at Venice Beach.
// Replace with a real Luma capture of the shop; the sourced FBX contained a
// person scan, not the building. Usage: swift generate_shop_placeholder.swift <out.scn> <preview.png>
import Foundation
import SceneKit
import AppKit

let args = CommandLine.arguments
guard args.count == 3 else { FileHandle.standardError.write("usage: <out.scn> <preview.png>\n".data(using: .utf8)!); exit(2) }

let scene = SCNScene()
let root = SCNNode(); root.name = "veniceball_shop_placeholder"
scene.rootNode.addChildNode(root)

func mat(_ c: NSColor, rough: CGFloat = 0.8, metal: CGFloat = 0.0, emissive: NSColor? = nil) -> SCNMaterial {
    let m = SCNMaterial(); m.lightingModel = .physicallyBased
    m.diffuse.contents = c; m.roughness.contents = rough; m.metalness.contents = metal
    if let e = emissive { m.emission.contents = e }
    return m
}
func box(_ w: CGFloat, _ h: CGFloat, _ l: CGFloat, _ m: SCNMaterial, at p: SCNVector3, chamfer: CGFloat = 0) -> SCNNode {
    let g = SCNBox(width: w, height: h, length: l, chamferRadius: chamfer); g.materials = [m]
    let n = SCNNode(geometry: g); n.position = p; return n
}

let sand = mat(NSColor(calibratedRed: 0.87, green: 0.80, blue: 0.62, alpha: 1))
let stucco = mat(NSColor(calibratedRed: 0.95, green: 0.93, blue: 0.86, alpha: 1), rough: 0.9)
let brick = mat(NSColor(calibratedRed: 0.72, green: 0.32, blue: 0.22, alpha: 1), rough: 0.95)
let navy = mat(NSColor(calibratedRed: 0.08, green: 0.16, blue: 0.32, alpha: 1))
let orange = mat(NSColor(calibratedRed: 1.0, green: 0.45, blue: 0.10, alpha: 1), emissive: NSColor(calibratedRed: 0.5, green: 0.22, blue: 0.05, alpha: 1))
let glass = mat(NSColor(calibratedRed: 0.45, green: 0.62, blue: 0.70, alpha: 1), rough: 0.15, metal: 0.4)
let wood = mat(NSColor(calibratedRed: 0.45, green: 0.31, blue: 0.18, alpha: 1), rough: 0.85)

// Boardwalk slab + building shell
root.addChildNode(box(14, 0.2, 10, sand, at: SCNVector3(0, -0.1, 0)))
root.addChildNode(box(10, 4.2, 6, stucco, at: SCNVector3(0, 2.1, -2)))
root.addChildNode(box(10.2, 0.5, 6.2, brick, at: SCNVector3(0, 4.45, -2)))
// Storefront glass + door
root.addChildNode(box(3.4, 2.2, 0.1, glass, at: SCNVector3(-2.6, 1.3, 1.02)))
root.addChildNode(box(3.4, 2.2, 0.1, glass, at: SCNVector3(2.6, 1.3, 1.02)))
root.addChildNode(box(1.4, 2.4, 0.12, navy, at: SCNVector3(0, 1.2, 1.03)))
// Striped awning
for i in 0..<7 {
    let stripe = i % 2 == 0 ? orange : navy
    root.addChildNode(box(10.0 / 7.0, 0.08, 1.8, stripe,
                          at: SCNVector3(-5.0 + 10.0 / 7.0 * (CGFloat(i) + 0.5), 2.9, 1.9)))
}
// Sign board ("VENICEBALL" abstracted as emissive band) + hoop emblem
root.addChildNode(box(7.5, 0.9, 0.15, navy, at: SCNVector3(0, 3.8, 1.1), chamfer: 0.05))
root.addChildNode(box(6.8, 0.45, 0.18, orange, at: SCNVector3(0, 3.8, 1.12), chamfer: 0.05))
let rim = SCNNode(geometry: SCNTorus(ringRadius: 0.45, pipeRadius: 0.05))
rim.geometry!.materials = [orange]; rim.position = SCNVector3(4.6, 3.8, 1.15); rim.eulerAngles.x = .pi / 2
root.addChildNode(rim)
// Palms (trunk + canopy blobs)
for x: CGFloat in [-6.3, 6.3] {
    let trunk = SCNNode(geometry: SCNCylinder(radius: 0.12, height: 4.6))
    trunk.geometry!.materials = [wood]; trunk.position = SCNVector3(x, 2.3, 2.6)
    root.addChildNode(trunk)
    for (dx, dz): (CGFloat, CGFloat) in [(0.5, 0), (-0.5, 0.2), (0, -0.5), (0.3, 0.45), (-0.35, -0.3)] {
        let frond = SCNNode(geometry: SCNSphere(radius: 0.55))
        frond.geometry!.materials = [mat(NSColor(calibratedRed: 0.18, green: 0.45, blue: 0.20, alpha: 1))]
        frond.position = SCNVector3(x + dx, 4.7, 2.6 + dz)
        frond.scale = SCNVector3(1.6, 0.35, 1.0)
        root.addChildNode(frond)
    }
}

let out = URL(fileURLWithPath: args[1])
guard scene.write(to: out, options: nil, delegate: nil, progressHandler: nil) else { exit(1) }
// Preview
let cam = SCNNode(); cam.camera = SCNCamera(); cam.position = SCNVector3(9, 5, 12); cam.look(at: SCNVector3(0, 2, 0))
scene.rootNode.addChildNode(cam)
let sun = SCNNode(); sun.light = SCNLight(); sun.light!.type = .directional; sun.light!.intensity = 1000
sun.eulerAngles = SCNVector3(-0.8, 0.5, 0); scene.rootNode.addChildNode(sun)
let amb = SCNNode(); amb.light = SCNLight(); amb.light!.type = .ambient; amb.light!.intensity = 400
scene.rootNode.addChildNode(amb)
let r = SCNRenderer(device: nil, options: nil); r.scene = scene; r.pointOfView = cam
let img = r.snapshot(atTime: 0, with: CGSize(width: 900, height: 600), antialiasingMode: .multisampling4X)
if let t = img.tiffRepresentation, let rep = NSBitmapImageRep(data: t), let png = rep.representation(using: .png, properties: [:]) {
    try? png.write(to: URL(fileURLWithPath: args[2]))
}
print("OK \(out.lastPathComponent)")
