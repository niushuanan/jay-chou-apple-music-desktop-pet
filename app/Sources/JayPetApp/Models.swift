import Foundation

struct TrackSnapshot: Equatable {
    let title: String
    let artist: String
    let album: String
    let lyrics: String
    let duration: Double
    let position: Double
    let state: PlayerState

    enum PlayerState: String {
        case playing
        case paused
        case stopped
        case unknown
    }
}

struct AlbumPetEntry: Codable {
    let id: String
    let displayName: String
    let aliases: [String]
    let enabled: Bool
    let bubbleLayout: BubbleLayout
    let spriteAssets: SpriteAssetSet

    var defaultImageName: String {
        spriteAssets.idle.assetName(at: 0)
    }
}

struct BubbleLayout: Codable, Equatable {
    let gap: CGFloat
    let offsetX: CGFloat
    let offsetY: CGFloat
    let minimumCharacterSpacing: CGFloat?
    let headSafetyPadding: CGFloat?
    let preferAbove: Bool?
    let visualInsets: VisualInsets?

    static let standard = BubbleLayout(
        gap: 4,
        offsetX: 0,
        offsetY: 0,
        minimumCharacterSpacing: 8,
        headSafetyPadding: 24,
        preferAbove: false,
        visualInsets: .zero
    )

    var resolvedVisualInsets: VisualInsets {
        visualInsets ?? .zero
    }

    var resolvedMinimumCharacterSpacing: CGFloat {
        minimumCharacterSpacing ?? 8
    }

    var resolvedHeadSafetyPadding: CGFloat {
        headSafetyPadding ?? 24
    }

    var resolvedPreferAbove: Bool {
        preferAbove ?? false
    }

    func applying(_ patch: BubbleLayoutPatch) -> BubbleLayout {
        BubbleLayout(
            gap: patch.gap ?? gap,
            offsetX: patch.offsetX ?? offsetX,
            offsetY: patch.offsetY ?? offsetY,
            minimumCharacterSpacing: patch.minimumCharacterSpacing ?? minimumCharacterSpacing,
            headSafetyPadding: patch.headSafetyPadding ?? headSafetyPadding,
            preferAbove: patch.preferAbove ?? preferAbove,
            visualInsets: patch.visualInsets ?? visualInsets
        )
    }
}

enum AlbumCatalog {
    static let all: [AlbumPetEntry] = ConfigLoader.loadAlbums()

    static func match(album: String) -> AlbumPetEntry? {
        let normalized = normalize(album)
        for entry in all {
            if entry.aliases.contains(where: { normalize($0) == normalized }) {
                return entry
            }
        }
        for entry in all {
            if entry.aliases.contains(where: { normalized.contains(normalize($0)) || normalize($0).contains(normalized) }) {
                return entry
            }
        }
        return nil
    }

    static func match(track: String, album: String) -> AlbumPetEntry? {
        if let byAlbum = match(album: album) {
            return byAlbum
        }
        let normalizedTrack = normalize(track)
        guard let albumID = trackFallbackAlbumID[normalizedTrack] else {
            return nil
        }
        return all.first(where: { $0.id == albumID })
    }

    static func normalize(_ text: String) -> String {
        text.lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "!", with: "")
            .replacingOccurrences(of: "，", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "。", with: "")
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "《", with: "")
            .replacingOccurrences(of: "》", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "（", with: "")
            .replacingOccurrences(of: "）", with: "")
    }

    private static let trackFallbackAlbumID: [String: String] = ConfigLoader.loadTrackFallbackMap()
}
