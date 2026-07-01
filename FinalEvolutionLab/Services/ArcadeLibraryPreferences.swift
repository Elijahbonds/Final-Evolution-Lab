import Foundation

/// Recent / favorite cartridge pins for the emulator library (max 4 combined).
enum ArcadeLibraryPreferences {
    static let maxPinnedCartridges = 4
    private static let recentKey = "fel_arcade_recent_cartridges"
    private static let favoritesKey = "fel_arcade_favorite_cartridges"
    private static let bootSkippedKey = "fel_nexus_boot_skipped"

    static var skipBootSequence: Bool {
        get { UserDefaults.standard.bool(forKey: bootSkippedKey) }
        set { UserDefaults.standard.set(newValue, forKey: bootSkippedKey) }
    }

    static func loadFavorites() -> [GameModeId] {
        decodeIds(forKey: favoritesKey)
    }

    static func loadRecent() -> [GameModeId] {
        decodeIds(forKey: recentKey)
    }

    /// Favorites first, then recents — deduped, capped at ``maxPinnedCartridges``.
    static func pinnedCartridges() -> [GameModeId] {
        var ordered: [GameModeId] = []
        for id in loadFavorites() + loadRecent() {
            guard !ordered.contains(id) else { continue }
            ordered.append(id)
            if ordered.count >= maxPinnedCartridges { break }
        }
        return ordered
    }

    static func isFavorite(_ modeId: GameModeId) -> Bool {
        loadFavorites().contains(modeId)
    }

    static func toggleFavorite(_ modeId: GameModeId) {
        var favorites = loadFavorites()
        if let index = favorites.firstIndex(of: modeId) {
            favorites.remove(at: index)
        } else {
            favorites.insert(modeId, at: 0)
        }
        encodeIds(favorites, forKey: favoritesKey)
    }

    /// Called when a cartridge launches — auto-pins to recent row and last-selected arena id.
    static func recordCartridgeLaunch(_ modeId: GameModeId) {
        SaveSystem.saveLastSelectedArenaModeId(modeId.rawValue)

        var recent = loadRecent().filter { $0 != modeId }
        recent.insert(modeId, at: 0)
        if recent.count > maxPinnedCartridges {
            recent = Array(recent.prefix(maxPinnedCartridges))
        }
        encodeIds(recent, forKey: recentKey)
    }

    private static func decodeIds(forKey key: String) -> [GameModeId] {
        guard let rawList = UserDefaults.standard.stringArray(forKey: key) else { return [] }
        return rawList.compactMap { GameModeId(rawValue: $0) }
    }

    private static func encodeIds(_ ids: [GameModeId], forKey key: String) {
        UserDefaults.standard.set(ids.map(\.rawValue), forKey: key)
    }
}
