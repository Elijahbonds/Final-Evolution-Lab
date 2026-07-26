import CoreGraphics

/// Consistent layout rhythm for arena / gameplay surfaces (8-pt grid).
nonisolated enum FELSpacing: Sendable {
    static let xxs: CGFloat = 4
    static let xs: CGFloat = 8
    static let sm: CGFloat = 12
    static let md: CGFloat = 16
    static let lg: CGFloat = 20
    static let xl: CGFloat = 24
    static let xxl: CGFloat = 32

    static let cardRadius: CGFloat = 16
    static let cardRadiusLarge: CGFloat = 18
    static let chipRadius: CGFloat = 12
}
