import UIKit

/// Phase 5 — SceneKit arena footprints and cheap sky/horizon helpers. Values are approximate meters for readability; they do not match Unreal Luma scale.
enum ArenaSceneConfig {
    /// Head-to-head: was 8×5; scaled ~25% for a less “tiny box” feel.
    enum BasketballH2H {
        static let courtW: Float = 10
        static let courtL: Float = 6.25
        static var halfW: Float { courtW * 0.5 }
        static var halfD: Float { courtL * 0.5 }
        /// Baseline hoop placement (legacy 3.5 at half-width 4 → ratio 0.875).
        static var hoopX: Float { halfW * 0.875 }
    }

    /// Dunk contest: was 12×8; scaled to match Phase 5 factor.
    enum BasketballDunk {
        static let courtW: Float = 15
        static let courtL: Float = 10
        static var halfW: Float { courtW * 0.5 }
        static var halfD: Float { courtL * 0.5 }
        /// Single rim on one baseline (legacy −4.5 at half-width 6 → 75% of half width).
        static var hoopX: Float { -halfW * 0.75 }
        static let runwayLength: Float = 8.75
        static let runwayZ: Float = 1.25
        /// Lateral offset for stadium tiers vs court center.
        static let standSideBaseX: Float = 8.75
    }

    /// 3v3: was 10×6.
    enum Basketball3v3 {
        static let courtW: Float = 12.5
        static let courtL: Float = 7.5
        static var halfW: Float { courtW * 0.5 }
        static var halfD: Float { courtL * 0.5 }
        static var hoopX: Float { halfW * 0.9 }
        static var homingClampX: Float { halfW - 0.4 }
        static var homingClampZ: Float { halfD - 0.35 }
    }

    /// Vertical gradient for `SCNScene.background` — reads as sky without an HDR dome.
    static func arenaTwilightSkyGradientImage(size: CGSize = CGSize(width: 4, height: 3)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let colors = [
                UIColor(red: 0.01, green: 0.02, blue: 0.09, alpha: 1).cgColor,
                UIColor(red: 0.10, green: 0.20, blue: 0.45, alpha: 1).cgColor,
                UIColor(red: 0.45, green: 0.32, blue: 0.22, alpha: 1).cgColor
            ] as CFArray
            let locs: [CGFloat] = [0, 0.5, 1]
            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors,
                locations: locs
            ) else { return }
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }
    }
}
