import AppKit
import Foundation

@MainActor
extension AppDelegate {
    func updateBubble() {
        guard state.isLyricsBubbleEnabled else {
            bubbleController?.hide()
            return
        }
        guard let content = makeBubbleContent() else {
            bubbleController?.hide()
            return
        }
        layoutBubble(with: content)
    }

    func layoutBubble(with content: BubbleContent? = nil) {
        guard state.isLyricsBubbleEnabled else {
            bubbleController?.hide()
            return
        }
        guard let window else { return }
        guard let bubbleContent = content ?? makeBubbleContent() else {
            bubbleController?.hide()
            return
        }
        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let baseLayout = state.currentAlbum?.bubbleLayout ?? .standard
        let layout = BubblePlacementResolver.resolveLayout(
            albumID: state.currentAlbum?.id,
            trackTitle: state.currentTrack?.title,
            baseLayout: baseLayout
        )
        let anchorFrame = resolvedPetAnchorFrame() ?? window.frame
        bubbleController?.present(content: bubbleContent, near: anchorFrame, visibleFrame: visibleFrame, layout: layout)
    }

    func makeBubbleContent() -> BubbleContent? {
        guard let snapshot = state.currentTrack else {
            return BubbleContent(title: state.currentLyricLine, detail: nil, controlSymbolName: "play.fill")
        }

        let rawTitle = snapshot.title.isEmpty ? state.currentAlbumTitle() : snapshot.title
        let displayTitleParts = splitDisplayTitle(rawTitle)
        let title = displayTitleParts.title
        let lyric = state.currentLyricLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let album = state.currentAlbumTitle()
        let controlSymbolName = snapshot.state == .playing ? "pause.fill" : "play.fill"
        let albumDetail = mergedDetail(extra: displayTitleParts.extra, base: album)

        if lyric.isEmpty {
            return BubbleContent(title: title, detail: album == rawTitle ? displayTitleParts.extra : albumDetail, controlSymbolName: controlSymbolName)
        }

        if isStatusLine(lyric) {
            if lyric == title {
                return BubbleContent(title: lyric, detail: nil, controlSymbolName: controlSymbolName)
            }
            return BubbleContent(title: title, detail: lyric, controlSymbolName: controlSymbolName)
        }

        if looksDuplicated(lyric: lyric, snapshot: snapshot, album: album) {
            let fallbackDetail = album == rawTitle ? displayTitleParts.extra : albumDetail
            return BubbleContent(title: title, detail: fallbackDetail, controlSymbolName: controlSymbolName)
        }

        return BubbleContent(title: title, detail: lyric, controlSymbolName: controlSymbolName)
    }

    private func splitDisplayTitle(_ title: String) -> (title: String, extra: String?) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let candidates = ["(feat.", "（feat.", "(Feat.", "（Feat.", "(with", "（with", "(With", "（With", "(Bonus", "（Bonus"]
        guard let marker = candidates.compactMap({ trimmed.range(of: $0) }).first else {
            return (trimmed, nil)
        }

        let base = String(trimmed[..<marker.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let extra = String(trimmed[marker.lowerBound...])
            .trimmingCharacters(in: CharacterSet(charactersIn: "()（） ").union(.whitespacesAndNewlines))

        guard !base.isEmpty, !extra.isEmpty else {
            return (trimmed, nil)
        }
        return (base, extra)
    }

    private func mergedDetail(extra: String?, base: String?) -> String? {
        let parts = [extra, base]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func isStatusLine(_ text: String) -> Bool {
        text == "等待播放..." ||
            text == "等待播放周杰伦歌曲..." ||
            text == "当前不是周杰伦歌曲" ||
            text == "Music 未运行" ||
            text == "该专辑暂未启用动态形象" ||
            text.contains("接口已预留")
    }

    private func looksDuplicated(lyric: String, snapshot: TrackSnapshot, album: String) -> Bool {
        let normalizedLyric = normalizeBubbleText(lyric)
        let normalizedTitle = normalizeBubbleText(snapshot.title)
        let normalizedAlbum = normalizeBubbleText(album)
        let normalizedTitleArtist = normalizeBubbleText("\(snapshot.title)\(snapshot.artist)")
        let normalizedTitleAlbum = normalizeBubbleText("\(snapshot.title)\(album)")

        return normalizedLyric.isEmpty ||
            normalizedLyric == normalizedTitle ||
            normalizedLyric == normalizedAlbum ||
            normalizedLyric == normalizedTitleArtist ||
            normalizedLyric == normalizedTitleAlbum ||
            normalizedLyric.contains(normalizedTitleArtist) ||
            normalizedLyric.contains(normalizedTitleAlbum)
    }

    private func normalizeBubbleText(_ text: String) -> String {
        AlbumCatalog.normalize(text)
            .replacingOccurrences(of: "·", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: "feat", with: "")
            .replacingOccurrences(of: "featuring", with: "")
    }
}
