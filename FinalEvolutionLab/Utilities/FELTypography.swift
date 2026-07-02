import SwiftUI

/// SF Pro hierarchy helpers — premium sports UI tier.
nonisolated enum FELTypography {
    static func display(_ size: CGFloat = 56) -> Font {
        .system(size: size, weight: .black, design: .default)
    }

    static func title(_ size: CGFloat = 32) -> Font {
        .system(size: size, weight: .bold, design: .default)
    }

    static func headline(_ size: CGFloat = 17) -> Font {
        .system(size: size, weight: .semibold, design: .default)
    }

    static func body(_ size: CGFloat = 15) -> Font {
        .system(size: size, weight: .regular, design: .default)
    }

    static func caption(_ size: CGFloat = 11) -> Font {
        .system(size: size, weight: .medium, design: .default)
    }

    static func mono(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }

    static func overline(_ tracking: CGFloat = 3) -> Font {
        .system(.caption2, design: .monospaced, weight: .black)
    }
}
