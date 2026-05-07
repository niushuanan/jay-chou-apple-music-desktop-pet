import Foundation

private struct AlbumCatalogConfiguration: Decodable {
    let albums: [AlbumPetEntryConfiguration]
}

private struct AlbumPetEntryConfiguration: Decodable {
    let id: String
    let displayName: String
    let aliases: [String]
    let enabled: Bool
    let bubbleLayout: BubbleLayout
    let animationManifest: String?
    let spriteAssets: SpriteAssetSet?

    func entry() -> AlbumPetEntry {
        AlbumPetEntry(
            id: id,
            displayName: displayName,
            aliases: aliases,
            enabled: enabled,
            bubbleLayout: bubbleLayout,
            spriteAssets: resolvedSpriteAssets()
        )
    }

    private func resolvedSpriteAssets() -> SpriteAssetSet {
        if let spriteAssets {
            return spriteAssets
        }
        let manifestPath = animationManifest ?? "album_animations/\(id)/\(id)_manifest"
        return ConfigLoader.loadAnimationManifest(path: manifestPath).spriteAssets
    }
}

enum ConfigLoader {
    static func loadAlbums() -> [AlbumPetEntry] {
        let config: AlbumCatalogConfiguration = decodeJSON(named: "albums", inSubdirectory: "config")
        return config.albums.map { $0.entry() }
    }

    static func loadTrackFallbackMap() -> [String: String] {
        let raw: [String: String] = decodeJSON(named: "track_album_map", inSubdirectory: "config")
        return Dictionary(uniqueKeysWithValues: raw.map { key, value in
            (AlbumCatalog.normalize(key), value)
        })
    }

    static func loadBubblePlacementRules() -> BubblePlacementRulesConfig {
        let raw: BubblePlacementRulesConfig = decodeJSON(named: "bubble_anchor_rules", inSubdirectory: "config")
        let normalizedTrackRules = Dictionary(uniqueKeysWithValues: raw.trackRules.map { key, patch in
            (AlbumCatalog.normalize(key), patch)
        })
        return BubblePlacementRulesConfig(
            albumRules: raw.albumRules,
            trackRules: normalizedTrackRules
        )
    }

    static func loadAnimationManifest(path: String) -> AlbumAnimationManifest {
        decodeJSON(path: path)
    }

    private static func decodeJSON<T: Decodable>(named name: String, inSubdirectory subdirectory: String) -> T {
        let url =
            Bundle.module.url(forResource: name, withExtension: "json", subdirectory: subdirectory) ??
            Bundle.module.url(forResource: name, withExtension: "json")

        guard let url else {
            fatalError("缺少配置文件: \(name).json")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            fatalError("配置文件解析失败: \(name).json, \(error)")
        }
    }

    private static func decodeJSON<T: Decodable>(path: String) -> T {
        let nsPath = NSString(string: path)
        let resourceName = nsPath.lastPathComponent
        let subdirectory = nsPath.deletingLastPathComponent
        let url: URL?
        if subdirectory.isEmpty {
            url = Bundle.module.url(forResource: resourceName, withExtension: "json")
        } else {
            url =
                Bundle.module.url(forResource: resourceName, withExtension: "json", subdirectory: subdirectory) ??
                Bundle.module.url(forResource: resourceName, withExtension: "json")
        }

        guard let url else {
            fatalError("缺少配置文件: \(path).json")
        }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            fatalError("配置文件解析失败: \(path).json, \(error)")
        }
    }
}
