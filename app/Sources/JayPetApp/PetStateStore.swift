import AppKit
import Foundation

final class PetStateStore: @unchecked Sendable {
    private(set) var currentTrack: TrackSnapshot?
    private(set) var currentAlbum: AlbumPetEntry?
    private(set) var currentLyricLine: String = "等待播放周杰伦歌曲..."
    private(set) var isLyricsBubbleEnabled: Bool = true

    private let music = AppleMusicController()
    private var pollTimer: Timer?
    private let pollQueue = DispatchQueue(label: "jaypet.music.poll", qos: .userInitiated)
    private let commandQueue = DispatchQueue(label: "jaypet.music.command", qos: .userInitiated)
    private let lyricQueue = DispatchQueue(label: "jaypet.music.lyrics", qos: .utility)
    private var pollInFlight = false
    private var onUpdate: (() -> Void)?
    private var lastValidJayTrack: TrackSnapshot?
    private var lyricsByTrackKey: [String: [String]] = [:]
    private var lyricFetchInFlightForKey: String?
    private var isDraggingPet = false
    private var stableAnimationAlbum: AlbumPetEntry?
    private var albumIdentityBecameUncertainAt: Date?
    private let albumIdentityGraceInterval: TimeInterval = 1.2
    private var albumIdentityGeneration = 0

    func start(onUpdate: @escaping () -> Void) {
        self.onUpdate = onUpdate
        listenMusicPlayerInfo()
        poll()
        self.pollTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        DistributedNotificationCenter.default().removeObserver(self)
    }

    func toggleLyricsBubble() {
        isLyricsBubbleEnabled.toggle()
        onUpdate?()
    }

    func beginDraggingPet() {
        guard !isDraggingPet else { return }
        isDraggingPet = true
        onUpdate?()
    }

    func endDraggingPet() {
        guard isDraggingPet else { return }
        isDraggingPet = false
        onUpdate?()
    }

    func playPauseToggle() { runCommand { $0.playPauseToggle() } }
    func play() { runCommand { $0.play() } }
    func pause() { runCommand { $0.pause() } }
    func stopPlayback() { runCommand { $0.stop() } }
    func nextTrack() { runCommand { $0.nextTrack() } }
    func previousTrack() { runCommand { $0.previousTrack() } }
    func openMusic() { runCommand { $0.openApp() } }

    private func runCommand(_ command: @Sendable @escaping (AppleMusicController) -> Void) {
        commandQueue.async { [music] in
            command(music)
        }
    }

    private func poll() {
        if pollInFlight { return }
        pollInFlight = true
        pollQueue.async { [weak self] in
            guard let self else { return }
            let snapshot = self.music.fetchSnapshotFast()
            DispatchQueue.main.async {
                self.applySnapshot(snapshot, allowClearingValidTrack: false)
                self.pollInFlight = false
                self.onUpdate?()
            }
        }
    }

    private func listenMusicPlayerInfo() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self else { return }
            guard let userInfo = notification.userInfo else {
                self.poll()
                return
            }
            if let snapshot = self.music.parseFromPlayerInfo(userInfo: userInfo) {
                self.applySnapshot(snapshot, allowClearingValidTrack: true)
                self.onUpdate?()
            } else {
                self.poll()
            }
        }
    }

    private func applySnapshot(_ snapshot: TrackSnapshot?, allowClearingValidTrack: Bool) {
        if let snapshot, isJayArtist(snapshot.artist), !snapshot.title.isEmpty {
            lastValidJayTrack = snapshot
            currentTrack = snapshot
            scheduleLyricsFetchIfNeeded(for: snapshot)
            refreshAlbumAndLyrics(with: snapshot)
            return
        }

        if !allowClearingValidTrack, let lastValidJayTrack {
            currentTrack = lastValidJayTrack
            refreshAlbumAndLyrics(with: lastValidJayTrack)
            return
        }

        currentTrack = snapshot
        refreshAlbumAndLyrics(with: snapshot)
    }

    private func refreshAlbumAndLyrics(with snapshot: TrackSnapshot?) {
        guard let snapshot else {
            currentAlbum = nil
            markAlbumIdentityUncertain()
            currentLyricLine = "Music 未运行"
            return
        }

        if !isJayArtist(snapshot.artist) {
            currentAlbum = nil
            markAlbumIdentityUncertain()
            currentLyricLine = "当前不是周杰伦歌曲"
            return
        }

        if let matched = AlbumCatalog.match(track: snapshot.title, album: snapshot.album), matched.enabled {
            currentAlbum = matched
            markStableAnimationAlbum(matched)
        } else if let matched = AlbumCatalog.match(track: snapshot.title, album: snapshot.album), !matched.enabled {
            currentAlbum = nil
            markAlbumIdentityUncertain()
            currentLyricLine = "该专辑暂未启用动态形象"
            return
        } else {
            currentAlbum = nil
            markAlbumIdentityUncertain()
        }

        currentLyricLine = lyricLineStream(track: snapshot)
    }

    private func markStableAnimationAlbum(_ album: AlbumPetEntry) {
        albumIdentityGeneration += 1
        stableAnimationAlbum = album
        albumIdentityBecameUncertainAt = nil
    }

    private func markAlbumIdentityUncertain() {
        if stableAnimationAlbum != nil, albumIdentityBecameUncertainAt == nil {
            albumIdentityBecameUncertainAt = Date()
            albumIdentityGeneration += 1
            let generation = albumIdentityGeneration
            DispatchQueue.main.asyncAfter(deadline: .now() + albumIdentityGraceInterval) { [weak self] in
                guard let self, self.albumIdentityGeneration == generation else { return }
                self.onUpdate?()
            }
        }
    }

    private func lyricLineStream(track: TrackSnapshot) -> String {
        guard track.state == .playing || track.state == .paused else {
            return "等待播放..."
        }
        let key = trackKey(track)
        let lines = lyricsByTrackKey[key] ?? []

        guard !lines.isEmpty, track.duration > 0 else {
            return "\(track.title) · \(track.artist)"
        }
        let progress = min(max(track.position / track.duration, 0), 0.9999)
        let index = min(Int(Double(lines.count) * progress), lines.count - 1)
        return lines[index]
    }

    private func isJayArtist(_ artist: String) -> Bool {
        let aliases = ["周杰伦", "周杰倫", "jay chou", "周董"]
        let text = artist.lowercased()
        return aliases.contains { text.contains($0.lowercased()) }
    }

    private func trackKey(_ track: TrackSnapshot) -> String {
        [
            AlbumCatalog.normalize(track.artist),
            AlbumCatalog.normalize(track.album),
            AlbumCatalog.normalize(track.title)
        ].joined(separator: "::")
    }

    private func scheduleLyricsFetchIfNeeded(for track: TrackSnapshot) {
        let key = trackKey(track)
        if lyricsByTrackKey[key] != nil { return }
        if lyricFetchInFlightForKey == key { return }
        lyricFetchInFlightForKey = key

        lyricQueue.async { [weak self] in
            guard let self else { return }
            let rawLyrics = self.music.fetchLyricsCurrentTrack() ?? ""
            let lines = rawLyrics
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            DispatchQueue.main.async {
                self.lyricsByTrackKey[key] = lines
                if self.lyricFetchInFlightForKey == key {
                    self.lyricFetchInFlightForKey = nil
                }
                if let currentTrack = self.currentTrack, self.trackKey(currentTrack) == key {
                    self.currentLyricLine = self.lyricLineStream(track: currentTrack)
                    self.onUpdate?()
                }
            }
        }
    }

    @MainActor
    func currentImage() -> NSImage? {
        ResourceLoader.albumImage(named: currentPresentation().assetName)
    }

    @MainActor
    func currentOpaqueInsets() -> PixelInsets {
        ResourceLoader.opaqueInsets(named: currentPresentation().assetName)
    }

    func currentImageName() -> String {
        currentPresentation().assetName
    }

    func currentAlbumTitle() -> String {
        currentAlbum?.displayName ?? "未匹配专辑"
    }

    func currentAnimationInput() -> PetAnimationInput {
        let album = resolvedAnimationAlbum()
        return PetAnimationInput(
            albumID: album?.id,
            spriteAssets: album?.spriteAssets,
            isDragging: isDraggingPet
        )
    }

    private func resolvedAnimationAlbum() -> AlbumPetEntry? {
        guard let uncertainSince = albumIdentityBecameUncertainAt else {
            return stableAnimationAlbum
        }
        if Date().timeIntervalSince(uncertainSince) < albumIdentityGraceInterval {
            return stableAnimationAlbum
        }
        return nil
    }

    func currentPresentation() -> PetPresentationState {
        let visualState = currentVisualState()
        let sequence = currentAlbum?.spriteAssets.sequence(for: visualState) ?? SpriteFrameSequence(frames: ["jay.png"])
        return PetPresentationState(visualState: visualState, sequence: sequence, frameIndex: 0)
    }

    func currentVisualState() -> PetVisualState {
        if isDraggingPet {
            return .dragging
        }
        guard let track = currentTrack else {
            return .idle
        }
        switch track.state {
        case .playing:
            return .playing
        case .paused:
            return .paused
        case .stopped, .unknown:
            return .idle
        }
    }
}
