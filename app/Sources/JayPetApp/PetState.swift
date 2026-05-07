import Foundation

enum PetVisualState: String, Codable {
    case idle
    case playing
    case paused
    case dragging
}

struct SpriteFrameSequence: Codable, Equatable {
    let frames: [String]
    let frameDuration: TimeInterval?
    let loop: Bool?

    init(frames: [String], frameDuration: TimeInterval? = nil, loop: Bool? = nil) {
        self.frames = frames
        self.frameDuration = frameDuration
        self.loop = loop
    }

    init(from decoder: Decoder) throws {
        let singleValue = try decoder.singleValueContainer()
        if let fileName = try? singleValue.decode(String.self) {
            self = SpriteFrameSequence(frames: [fileName], frameDuration: nil, loop: nil)
            return
        }
        if let fileNames = try? singleValue.decode([String].self) {
            self = SpriteFrameSequence(frames: fileNames, frameDuration: nil, loop: nil)
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let frames = try container.decode([String].self, forKey: .frames)
        let frameDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .frameDuration)
        let loop = try container.decodeIfPresent(Bool.self, forKey: .loop)
        self = SpriteFrameSequence(frames: frames, frameDuration: frameDuration, loop: loop)
    }

    func encode(to encoder: Encoder) throws {
        if frameDuration == nil, loop == nil, frames.count == 1, let only = frames.first {
            var singleValue = encoder.singleValueContainer()
            try singleValue.encode(only)
            return
        }

        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(frames, forKey: .frames)
        try container.encodeIfPresent(frameDuration, forKey: .frameDuration)
        try container.encodeIfPresent(loop, forKey: .loop)
    }

    func assetName(at frameIndex: Int) -> String {
        guard !frames.isEmpty else {
            return ""
        }
        let normalizedIndex = max(frameIndex, 0) % frames.count
        return frames[normalizedIndex]
    }

    var resolvedFrameDuration: TimeInterval {
        frameDuration ?? 0.12
    }

    var resolvedLoop: Bool {
        loop ?? true
    }

    private enum CodingKeys: String, CodingKey {
        case frames
        case frameDuration
        case loop
    }
}

struct SpriteAssetSet: Codable, Equatable {
    let idle: SpriteFrameSequence
    let playing: SpriteFrameSequence
    let paused: SpriteFrameSequence
    let dragging: SpriteFrameSequence?
    let enter: SpriteFrameSequence?
    let exit: SpriteFrameSequence?

    func sequence(for state: PetVisualState) -> SpriteFrameSequence {
        switch state {
        case .idle:
            return idle
        case .playing:
            return playing
        case .paused:
            return paused
        case .dragging:
            return dragging ?? idle
        }
    }
}

struct PetPresentationState: Equatable {
    let albumID: String
    let animationAction: PetAnimationAction
    let visualState: PetVisualState
    let sequence: SpriteFrameSequence
    let frameIndex: Int

    init(albumID: String, animationAction: PetAnimationAction, sequence: SpriteFrameSequence, frameIndex: Int) {
        self.albumID = albumID
        self.animationAction = animationAction
        self.visualState = .idle
        self.sequence = sequence
        self.frameIndex = frameIndex
    }

    init(visualState: PetVisualState, sequence: SpriteFrameSequence, frameIndex: Int) {
        self.albumID = "legacy"
        self.animationAction = .idle
        self.visualState = visualState
        self.sequence = sequence
        self.frameIndex = frameIndex
    }

    var assetName: String {
        sequence.assetName(at: frameIndex)
    }

    var cacheKey: String {
        "\(albumID)::\(animationAction.rawValue)::\(frameIndex)::\(assetName)"
    }
}

struct VisualInsets: Codable, Equatable {
    let left: CGFloat
    let right: CGFloat
    let top: CGFloat
    let bottom: CGFloat

    static let zero = VisualInsets(left: 0, right: 0, top: 0, bottom: 0)
}

struct PixelInsets: Equatable {
    let left: Int
    let right: Int
    let top: Int
    let bottom: Int

    static let zero = PixelInsets(left: 0, right: 0, top: 0, bottom: 0)
}
