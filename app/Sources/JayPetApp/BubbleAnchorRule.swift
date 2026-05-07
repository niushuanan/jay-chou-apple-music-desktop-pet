import Foundation

struct BubbleLayoutPatch: Codable, Equatable {
    let gap: CGFloat?
    let offsetX: CGFloat?
    let offsetY: CGFloat?
    let minimumCharacterSpacing: CGFloat?
    let headSafetyPadding: CGFloat?
    let preferAbove: Bool?
    let visualInsets: VisualInsets?
}

struct BubblePlacementRulesConfig: Codable {
    let albumRules: [String: BubbleLayoutPatch]
    let trackRules: [String: BubbleLayoutPatch]
}

enum BubblePlacementResolver {
    static func resolveLayout(
        albumID: String?,
        trackTitle: String?,
        baseLayout: BubbleLayout
    ) -> BubbleLayout {
        var layout = baseLayout

        if let albumID, let patch = placementRules.albumRules[albumID] {
            layout = layout.applying(patch)
        }

        if let trackTitle {
            let key = AlbumCatalog.normalize(trackTitle)
            if let patch = placementRules.trackRules[key] {
                layout = layout.applying(patch)
            }
        }

        return layout
    }

    private static let placementRules: BubblePlacementRulesConfig = ConfigLoader.loadBubblePlacementRules()
}
