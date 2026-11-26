import SpriteKit
import UIKit

enum GameState { case playing, choosing, transition, dead, victory, paused }

final class GameScene: BaseScene {
    let runData: RunState
    let world = SKNode()
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

    init(size: CGSize, runData: RunState) {
        self.runData = runData
        super.init(size: size)
        scaleMode = .resizeFill
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        backgroundColor = Palette.of(runData.depth).bg
        addChild(world)
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
        let s = clamp(560 / max(size.height, 1), 0.7, 1.6)
        cam.setScale(s)
        hud.setScale(1 / s)
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
        updatePlayer(dt)
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

    func depthZ(_ y: CGFloat) -> CGFloat { 10 + (3000 - y) * 0.001 }

    // MARK: Camera

    func clampCam(_ target: CGPoint) -> CGPoint {
        guard let room = room else { return target }
        let vw = size.width * cam.xScale
        let vh = size.height * cam.yScale
        let b = room.bounds
        let ext = CGRect(x: b.minX - 50, y: b.minY - 50, width: b.width + 100, height: b.height + 50 + 140)
        var t = target
        t.x = ext.width <= vw ? ext.midX : clamp(t.x, ext.minX + vw / 2, ext.maxX - vw / 2)
        t.y = ext.height <= vh ? ext.midY : clamp(t.y, ext.minY + vh / 2, ext.maxY - vh / 2)
        return t
    }

    func updateCamera(_ dt: CGFloat) {
        guard let p = player else { return }
        let target = clampCam(p.position + CGPoint(x: 0, y: 30))
        camBase = camBase + (target - camBase) * min(1, dt * 7)
        var off = CGPoint.zero
        if shakeAmt > 0.2 {
            off = CGPoint(x: rnd(-shakeAmt, shakeAmt), y: rnd(-shakeAmt, shakeAmt))
            shakeAmt *= max(0, 1 - dt * 10)
        } else {
            shakeAmt = 0
        }
        cam.position = camBase + off
    }

    func addShake(_ a: CGFloat) { shakeAmt = min(16, max(shakeAmt, a)) }

    // MARK: Run end

    func recordRunEnd(won: Bool) {
        guard !runRecorded else { return }
        runRecorded = true
        let meta = Meta.shared
        meta.data.souls += runData.souls
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
