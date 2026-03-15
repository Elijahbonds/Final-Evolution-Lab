import Foundation

enum SafeURL {
    private static let fallbackURL = URL(string: "https://www.apple.com")!

    /// Returns a valid URL; uses fallback if string is malformed. Use for static resource strings to avoid force unwrap.
    static func make(_ string: String) -> URL {
        URL(string: string) ?? fallbackURL
    }
}
