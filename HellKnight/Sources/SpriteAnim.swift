import SpriteKit

struct AnimInfo {
    let row: Int
    let count: Int
    let loops: Bool
}

struct SheetInfo {
    let file: String
    let frame: CGSize
    let ground: CGFloat
    let cols: Int
    let rows: Int
    let anims: [String: AnimInfo]

    /// Anchor that puts the character's feet on the node's origin.
    var anchor: CGPoint { CGPoint(x: 0.5, y: ground / frame.height) }
}

/// A loaded sprite sheet, sliced into per-animation frame textures on demand.
final class SpriteSheet {
    let info: SheetInfo
    let texture: SKTexture
    private var cache: [String: [SKTexture]] = [:]
    private static var loaded: [String: SpriteSheet] = [:]

    private init(_ info: SheetInfo) {
        self.info = info
        texture = SKTexture(imageNamed: info.file)
        texture.filteringMode = .linear
    }

    static func get(_ info: SheetInfo) -> SpriteSheet {
        if let s = loaded[info.file] { return s }
        let s = SpriteSheet(info)
        loaded[info.file] = s
        return s
    }

    func frames(_ name: String) -> [SKTexture] {
        if let f = cache[name] { return f }
        guard let a = info.anims[name] ?? info.anims["idle"] else { return [texture] }
        let w = 1 / CGFloat(info.cols), h = 1 / CGFloat(info.rows)
        var out: [SKTexture] = []
        for i in 0..<a.count {
            let r = CGRect(x: CGFloat(i) * w, y: 1 - CGFloat(a.row + 1) * h, width: w, height: h)
            out.append(SKTexture(rect: r, in: texture))
        }
        cache[name] = out
        return out
    }

    func has(_ name: String) -> Bool { info.anims[name] != nil }
}

/// Drives a sprite through looping and one-shot animations, updated from the game loop.
final class Animator {
    let sheet: SpriteSheet
    weak var sprite: SKSpriteNode?
    private(set) var current = ""
    private var frames: [SKTexture] = []
    private var time: CGFloat = 0
    private var fps: CGFloat = 12
    private var loops = true

    init(sheet: SpriteSheet, sprite: SKSpriteNode) {
        self.sheet = sheet
        self.sprite = sprite
        play("idle", fps: 9)
    }

    /// True while a non-looping animation is still running.
    var busy: Bool { !loops && time * fps < CGFloat(frames.count) }

    /// Loop an animation (keeps its phase if it is already playing).
    func play(_ name: String, fps: CGFloat) {
        self.fps = fps
        if name == current && loops { return }
        start(name, loops: true)
    }

    /// Play a one-shot animation stretched over `duration` seconds.
    func once(_ name: String, duration: CGFloat) {
        start(name, loops: false)
        fps = CGFloat(frames.count) / max(0.05, duration)
    }

    private func start(_ name: String, loops: Bool) {
        let n = sheet.has(name) ? name : "idle"
        current = n
        frames = sheet.frames(n)
        self.loops = loops
        time = 0
        sprite?.texture = frames.first
    }

    func update(_ dt: CGFloat) {
        guard !frames.isEmpty else { return }
        time += dt
        var i = Int(time * fps)
        i = loops ? i % frames.count : min(frames.count - 1, i)
        sprite?.texture = frames[i]
    }

    /// An SKAction playing a one-shot (for nodes that no longer receive updates, e.g. dying enemies).
    func action(_ name: String, duration: CGFloat) -> SKAction {
        let f = sheet.frames(name)
        return .animate(with: f, timePerFrame: TimeInterval(duration / CGFloat(max(1, f.count))))
    }
}
