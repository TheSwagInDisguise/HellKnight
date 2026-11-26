import SpriteKit
import UIKit

enum GameState { case playing, choosing, transition, dead, victory, paused }

final class GameScene: BaseScene {
    let runData: RunState
    let isoRoot = SKNode()
    let world = SKNode()
    let topLayer = SKNode()
    let cam = SKCameraNode()
    let hud = HUD()
    let controls = Controls()
    var player: Player!
    var room: Room!
    var enemies: [Enemy] = []
    var projectiles: [Projectile] = []
    var pickups: [Pickup] = []
    var doors: [Door] = []
    var boss: Boss?
    var state: GameState = .playing
    var lastTime: TimeInterval = 0
    var hitstop: CGFloat = 0
    var shakeAmt: CGFloat = 0
    var camBase = CGPoint.zero
    var waves: [[EnemyKind]] = []
    var pendingSpawns = 0
    var combatStarted = false
    var roomCleared = false
    var doorsOpen = false
    var overlay: SKNode?
    var runRecorded = false
    let lightLayer = SKEffectNode()
    let lightBase = SKSpriteNode(color: .white, size: CGSize(width: 10, height: 10))
    let fogLayer = SKNode()
    var playerLight: SKSpriteNode?
    var camBaseScale: CGFloat = 1
    var zoomPunch: CGFloat = 0
    var shot: String?
    var breakables: [Breakable] = []
    var spikes: [SpikeTrap] = []
    var spikeClock: CGFloat = 0
    var hazardTick: CGFloat = 0
    var flowTimer: CGFloat = 0
    var playerGhost: SKSpriteNode?
    var shotTimer: CGFloat = 0

    init(size: CGSize, runData: RunState) {
        self.runData = runData
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        backgroundColor = Palette.of(runData.depth).bg
        isoRoot.yScale = 0.5
        world.zRotation = .pi / 4
        isoRoot.addChild(world)
        addChild(isoRoot)
        topLayer.zPosition = 800
        addChild(topLayer)
        setupLighting()
        addChild(cam)
        camera = cam
        hud.zPosition = 1000
        cam.addChild(hud)
        hud.setup()
        hud.onPause = { [weak self] in self?.showPause() }
        controls.zPosition = 10
        hud.addChild(controls)
        layoutUI()
        buildRoom()
        hud.fade(to: 0, duration: 0.6) {}
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if cam.parent != nil { layoutUI() }
    }

    override func relayout() { layoutUI() }

    func layoutUI() {
        // Camera children (the HUD) are not affected by camera scale, so the HUD stays at 1:1.
        camBaseScale = clamp(600 / max(size.height, 1), 0.75, 1.7)
        cam.setScale(camBaseScale)
        let insets = view?.safeAreaInsets ?? .zero
        hud.layout(size, insets)
        controls.layout(size, insets)
    }

    // MARK: Input

    override func touchDown(_ t: UITouch) {
        if state == .playing { controls.began(t, t.location(in: hud)) }
    }

    override func touchMove(_ t: UITouch) {
        controls.moved(t, t.location(in: hud))
    }

    override func touchUp(_ t: UITouch) {
        controls.ended(t)
    }

    // MARK: Loop

    override func update(_ currentTime: TimeInterval) {
        var dt = CGFloat(lastTime == 0 ? 1.0 / 60.0 : currentTime - lastTime)
        lastTime = currentTime
        dt = min(max(dt, 0), 1.0 / 30.0)
        controls.tick(dt)
        updateCamera(dt)
        updateLighting(dt)
        hud.refresh(runData, player, boss)
        if let p = player {
            controls.setReady(.special, p.specialCD <= 0)
            controls.setReady(.cast, p.castCharges > 0)
            controls.setReady(.dash, p.dashCharges > 0)
            controls.castLabel.text = "\(p.castCharges)"
        }
        guard state == .playing, player != nil, room != nil else { return }
        if hitstop > 0 {
            hitstop -= dt
            return
        }
        if shot != nil { updateShot(dt) }
        updatePlayer(dt)
        updateHazards(dt)
        for e in enemies {
            if state != .playing { break }
            e.update(dt, game: self)
        }
        separateEnemies()
        updateProjectiles(dt)
        updatePickups(dt)
        enemies.removeAll { !$0.alive }
        if state == .playing {
            checkRoomProgress()
            checkDoors()
        }
    }

    /// Draw order for upright objects: things lower on screen are drawn in front.
    func depthZ(_ p: CGPoint) -> CGFloat { 10 + (8000 - (p.x + p.y)) * 0.0005 }

    /// Joystick input converted to a ground-plane direction.
    var moveInput: CGPoint { groundFromScreen(controls.move) }

    /// Scene-space (screen) position of a ground point, raised by `height`.
    func screenPoint(_ p: CGPoint, height: CGFloat = 0) -> CGPoint {
        isoProject(p) + CGPoint(x: 0, y: height)
    }

    // MARK: Camera

    func clampCam(_ target: CGPoint) -> CGPoint {
        guard let room = room else { return target }
        let vw = size.width * cam.xScale
        let vh = size.height * cam.yScale
        let b = room.bounds
        let left = isoProject(CGPoint(x: b.minX, y: b.maxY)).x - 60
        let right = isoProject(CGPoint(x: b.maxX, y: b.minY)).x + 60
        let bottom = isoProject(CGPoint(x: b.minX, y: b.minY)).y - 60
        let top = isoProject(CGPoint(x: b.maxX, y: b.maxY)).y + Tex.wallH + 30
        var t = target
        t.x = right - left <= vw ? (left + right) / 2 : clamp(t.x, left + vw / 2, right - vw / 2)
        t.y = top - bottom <= vh ? (top + bottom) / 2 : clamp(t.y, bottom + vh / 2, top - vh / 2)
        return t
    }

    func updateCamera(_ dt: CGFloat) {
        guard let p = player else { return }
        let target = clampCam(isoProject(p.position) + CGPoint(x: 0, y: 40))
        camBase = camBase + (target - camBase) * min(1, dt * 7)
        var off = CGPoint.zero
        if shakeAmt > 0.2 {
            off = CGPoint(x: rnd(-shakeAmt, shakeAmt), y: rnd(-shakeAmt, shakeAmt))
            shakeAmt *= max(0, 1 - dt * 10)
        } else {
            shakeAmt = 0
        }
        cam.position = camBase + off
        if zoomPunch > 0.001 {
            zoomPunch *= max(0, 1 - dt * 9)
            cam.setScale(camBaseScale * (1 - zoomPunch))
        } else if zoomPunch != 0 {
            zoomPunch = 0
            cam.setScale(camBaseScale)
        }
    }

    func addShake(_ a: CGFloat) { shakeAmt = min(16, max(shakeAmt, a)) }

    /// Brief camera zoom-in for impact.
    func punch(_ amount: CGFloat) { zoomPunch = min(0.08, max(zoomPunch, amount)) }

    // MARK: Run end

    func recordRunEnd(won: Bool) {
        guard !runRecorded else { return }
        runRecorded = true
        let meta = Meta.shared
        runData.souls = Int((CGFloat(runData.souls) * Meta.heatMult(runData.heat)).rounded())
        meta.data.souls += runData.souls
        if won { meta.data.bestHeat = max(meta.data.bestHeat, runData.heat) }
        meta.data.runs += 1
        if won { meta.data.wins += 1 }
        meta.data.bestDepth = max(meta.data.bestDepth, runData.depth + 1)
        meta.save()
    }

    func goToSanctum() {
        guard let v = view else { return }
        let s = SanctumScene(size: size)
        s.scaleMode = .resizeFill
        v.presentScene(s, transition: .fade(with: .black, duration: 0.8))
    }
}
