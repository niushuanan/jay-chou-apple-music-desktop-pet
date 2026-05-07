import Foundation

enum PetAnimationAction: String, Codable, Equatable {
    case idle
    case enter
    case exit
    case dragging
}

struct PetAnimationInput: Equatable {
    let albumID: String?
    let spriteAssets: SpriteAssetSet?
    let isDragging: Bool
}

@MainActor
final class PetAnimationRuntime {
    private var activeAlbumID: String?
    private var activeAssets: SpriteAssetSet?
    private var targetAlbumID: String?
    private var targetAssets: SpriteAssetSet?
    private var queuedAlbumID: String?
    private var queuedAssets: SpriteAssetSet?
    private var action: PetAnimationAction = .idle
    private var actionStartedAt: TimeInterval = 0
    private var lastInput: PetAnimationInput?
    private var isDragging = false

    func apply(input: PetAnimationInput, now: TimeInterval) {
        if input == lastInput {
            return
        }
        lastInput = input

        if input.isDragging {
            isDragging = true
            if input.albumID != targetAlbumID {
                queuedAlbumID = input.albumID
                queuedAssets = input.spriteAssets
            }
            if action != .dragging {
                start(.dragging, now: now)
            }
            return
        }

        if isDragging {
            isDragging = false
            if let queuedAlbumID, queuedAlbumID != activeAlbumID {
                requestAlbumChange(albumID: queuedAlbumID, assets: queuedAssets, now: now)
                self.queuedAlbumID = nil
                self.queuedAssets = nil
                return
            }
            self.queuedAlbumID = nil
            self.queuedAssets = nil
            start(.idle, now: now)
        }

        if input.albumID != targetAlbumID || input.albumID != activeAlbumID {
            requestAlbumChange(albumID: input.albumID, assets: input.spriteAssets, now: now)
        }
    }

    func frame(now: TimeInterval) -> PetPresentationState? {
        completeFinishedActionIfNeeded(now: now)
        guard let activeAlbumID, let activeAssets else {
            return nil
        }
        let sequence = sequence(for: action, assets: activeAssets)
        guard !sequence.frames.isEmpty else {
            return nil
        }
        let index = currentFrameIndex(for: sequence, now: now)
        return PetPresentationState(albumID: activeAlbumID, animationAction: action, sequence: sequence, frameIndex: index)
    }

    private func requestAlbumChange(albumID: String?, assets: SpriteAssetSet?, now: TimeInterval) {
        targetAlbumID = albumID
        targetAssets = assets

        guard let albumID, let assets else {
            if activeAlbumID != nil {
                if activeAssets?.exit != nil {
                    start(.exit, now: now, force: true)
                } else {
                    activateTargetAlbum(now: now)
                }
            }
            return
        }

        if activeAlbumID == nil {
            activeAlbumID = albumID
            activeAssets = assets
            start(assets.enter == nil ? .idle : .enter, now: now, force: true)
            return
        }

        if activeAlbumID == albumID {
            activeAssets = assets
            if action == .exit {
                start(assets.enter == nil ? .idle : .enter, now: now, force: true)
            }
            return
        }

        if activeAssets?.exit != nil {
            start(.exit, now: now, force: true)
        } else {
            activateTargetAlbum(now: now)
        }
    }

    private func completeFinishedActionIfNeeded(now: TimeInterval) {
        guard let currentAssets = activeAssets else { return }
        let sequence = sequence(for: action, assets: currentAssets)
        guard !sequence.resolvedLoop, !sequence.frames.isEmpty else { return }
        let duration = sequence.resolvedFrameDuration * Double(sequence.frames.count)
        guard now - actionStartedAt >= duration else { return }

        switch action {
        case .enter:
            start(.idle, now: now)
        case .exit:
            activateTargetAlbum(now: now)
        case .idle, .dragging:
            start(.idle, now: now)
        }
    }

    private func activateTargetAlbum(now: TimeInterval) {
        activeAlbumID = targetAlbumID
        activeAssets = targetAssets
        guard let activeAssets else {
            start(.idle, now: now, force: true)
            return
        }
        start(activeAssets.enter == nil ? .idle : .enter, now: now, force: true)
    }

    private func start(_ nextAction: PetAnimationAction, now: TimeInterval, force: Bool = false) {
        if !force, action == nextAction, now - actionStartedAt >= 0 {
            return
        }
        action = nextAction
        actionStartedAt = now
    }

    private func currentFrameIndex(for sequence: SpriteFrameSequence, now: TimeInterval) -> Int {
        let duration = max(sequence.resolvedFrameDuration, 0.016)
        let rawIndex = max(Int((now - actionStartedAt) / duration), 0)
        if sequence.resolvedLoop {
            return rawIndex % sequence.frames.count
        }
        return min(rawIndex, sequence.frames.count - 1)
    }

    private func sequence(for action: PetAnimationAction, assets: SpriteAssetSet) -> SpriteFrameSequence {
        switch action {
        case .idle:
            return assets.idle
        case .enter:
            return assets.enter ?? assets.idle
        case .exit:
            return assets.exit ?? assets.idle
        case .dragging:
            return assets.dragging ?? assets.idle
        }
    }
}
