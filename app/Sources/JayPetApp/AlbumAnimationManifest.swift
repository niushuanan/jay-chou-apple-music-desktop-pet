import Foundation

struct AlbumAnimationManifest: Decodable {
    let id: String
    let displayName: String
    let canvas: AnimationCanvas?
    let actions: [String: AlbumAnimationAction]

    var spriteAssets: SpriteAssetSet {
        let idle = requiredSequence(named: "idle")
        return SpriteAssetSet(
            idle: idle,
            playing: sequence(named: "playing") ?? idle,
            paused: sequence(named: "paused") ?? idle,
            dragging: sequence(named: "dragging"),
            enter: sequence(named: "enter"),
            exit: sequence(named: "exit")
        )
    }

    private func requiredSequence(named name: String) -> SpriteFrameSequence {
        guard let sequence = sequence(named: name) else {
            fatalError("缺少动作配置: \(id).\(name)")
        }
        return sequence
    }

    private func sequence(named name: String) -> SpriteFrameSequence? {
        actions[name]?.sequence
    }
}

struct AnimationCanvas: Decodable {
    let width: Int
    let height: Int
}

struct AlbumAnimationAction: Decodable {
    let fps: Int?
    let frameDuration: TimeInterval?
    let loop: Bool?
    let frameCount: Int?
    let frames: [String]

    var sequence: SpriteFrameSequence {
        SpriteFrameSequence(
            frames: frames,
            frameDuration: frameDuration,
            loop: loop
        )
    }
}
