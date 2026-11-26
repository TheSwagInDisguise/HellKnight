import SpriteKit
import UIKit

// MARK: - Room geometry

struct Pillar {
    let pos: CGPoint
    let r: CGFloat
}

final class Room {
    let bounds: CGRect
    let type: RoomType
    var pillars: [Pillar] = []

    init(bounds: CGRect, type: RoomType) {
        self.bounds = bounds
        self.type = type
    }

    /// Pushes a circle out of pillars and keeps it inside the room.
    func resolve(_ p: CGPoint, _ r: CGFloat) -> CGPoint {
        var q = p
        for pl in pillars {
            let d = q - pl.pos
            let md = pl.r + r
            let l = d.length
            if l < md {
                let n = l > 0.001 ? d * (1 / l) : CGPoint(x: 0, y: 1)
                q = pl.pos + n * md
            }
        }
        q.x = clamp(q.x, bounds.minX + r, bounds.maxX - r)
        q.y = clamp(q.y, bounds.minY + r, bounds.maxY - r)
        return q
    }

    func blocked(_ p: CGPoint, _ r: CGFloat) -> Bool {
        if !bounds.insetBy(dx: r, dy: r).contains(p) { return true }
        return pillars.contains { $0.pos.distance(to: p) < $0.r + r }
    }

    func randomOpenPoint(margin: CGFloat, avoid: CGPoint, minDist: CGFloat) -> CGPoint {
        var best = CGPoint(x: bounds.midX, y: bounds.midY)
        var bestD: CGFloat = -1
        for _ in 0..<40 {
            let p = CGPoint(x: rnd(bounds.minX + margin, bounds.maxX - margin),
                            y: rnd(bounds.minY + margin, bounds.maxY - margin))
            if blocked(p, margin) { continue }
            let d = p.distance(to: avoid)
            if d >= minDist { return p }
            if d > bestD {
                bestD = d
                best = p
            }
        }
        return best
    }
}

// MARK: - Player

final class Player: SKNode {
    let radius: CGFloat = 18
    let weapon: WeaponKind
    let body: SKSpriteNode
    let pivot = SKNode()
    let weaponSprite: SKSpriteNode
    let weaponBase: CGPoint
    let shadow: SKSpriteNode

    var facing: CGFloat = .pi / 2
    var invuln: CGFloat = 0
    var dashTime: CGFloat = 0
    var dashDir = CGPoint.zero
    var dashCharges = 1
    var dashRecharge: CGFloat = 0
    var attackTimer: CGFloat = 0
    var comboIndex = 0
    var comboReset: CGFloat = 0
    var specialCD: CGFloat = 0
    var castCharges = 2
    var castRecharge: CGFloat = 0
    var lungeVel = CGPoint.zero
    var lungeTime: CGFloat = 0
    var afterimageTimer: CGFloat = 0
    var moving = false
    var walkPhase: CGFloat = 0
    var swingCount = 0

    init(weapon: WeaponKind) {
        self.weapon = weapon
        body = SKSpriteNode(texture: Tex.knight(), size: CGSize(width: 54, height: 54))
        let wt = Tex.weapon(weapon)
        let ws: SKSpriteNode
        switch weapon {
        case .blade:
            ws = SKSpriteNode(texture: wt, size: CGSize(width: 58, height: 13))
            ws.anchorPoint = CGPoint(x: 0.12, y: 0.5)
            weaponBase = CGPoint(x: 12, y: 0)
        case .pike:
            ws = SKSpriteNode(texture: wt, size: CGSize(width: 90, height: 13))
            ws.anchorPoint = CGPoint(x: 0.25, y: 0.5)
            weaponBase = CGPoint(x: 8, y: 0)
        case .fists:
            ws = SKSpriteNode(texture: wt, size: CGSize(width: 22, height: 22))
            ws.anchorPoint = CGPoint(x: 0.4, y: 0.5)
            weaponBase = CGPoint(x: 20, y: 0)
        }
        weaponSprite = ws
        shadow = SKSpriteNode(texture: Tex.shadow(), size: CGSize(width: 44, height: 20))
        super.init()
        shadow.position = CGPoint(x: 0, y: -18)
        shadow.zPosition = -2
        addChild(shadow)
        weaponSprite.position = weaponBase
        pivot.addChild(weaponSprite)
        addChild(pivot)
        addChild(body)
        setFacing(.pi / 2)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var isSwinging: Bool { pivot.action(forKey: "swing") != nil }

    func setFacing(_ a: CGFloat) {
        facing = a
        pivot.zRotation = a
        pivot.zPosition = sin(a) > 0.3 ? -1 : 1
    }

    func playSwing(angle a: CGFloat, arcDeg: CGFloat) {
        swingCount += 1
        pivot.removeAction(forKey: "swing")
        weaponSprite.removeAction(forKey: "thrust")
        facing = a
        pivot.zPosition = sin(a) > 0.3 ? -1 : 1
        switch weapon {
        case .blade:
            let half = arcDeg * .pi / 360
            let dir: CGFloat = swingCount % 2 == 0 ? 1 : -1
            pivot.zRotation = a + half * dir
            pivot.run(.rotate(toAngle: a - half * dir, duration: 0.09), withKey: "swing")
        case .pike, .fists:
            pivot.zRotation = a
            let dist: CGFloat = weapon == .pike ? 34 : 20
            let side: CGFloat = weapon == .fists ? (swingCount % 2 == 0 ? 7 : -7) : 0
            weaponSprite.position = weaponBase + CGPoint(x: 0, y: side)
            weaponSprite.run(.sequence([
                .moveBy(x: dist, y: 0, duration: 0.05),
                .move(to: weaponBase, duration: 0.12),
            ]), withKey: "thrust")
            pivot.run(.wait(forDuration: 0.12), withKey: "swing")
        }
    }

    func spin() {
        pivot.removeAction(forKey: "swing")
        pivot.run(.rotate(byAngle: .pi * 2, duration: 0.25), withKey: "swing")
    }

    func animate(_ dt: CGFloat) {
        if moving {
            walkPhase += dt * 14
            body.position = CGPoint(x: 0, y: abs(sin(walkPhase)) * 3)
        } else {
            body.position = .zero
        }
        if invuln > 0 && dashTime <= 0 {
            body.alpha = sin(invuln * 40) > 0 ? 0.45 : 1
        } else {
            body.alpha = 1
        }
    }

    func flashHurt() {
        body.removeAction(forKey: "hurt")
        body.run(.sequence([
            .colorize(with: .red, colorBlendFactor: 0.8, duration: 0),
            .colorize(withColorBlendFactor: 0, duration: 0.3),
        ]), withKey: "hurt")
    }
}

// MARK: - Projectile

final class Projectile: SKSpriteNode {
    var vel = CGPoint.zero
    var damage: CGFloat = 10
    var radius: CGFloat = 8
    var hostile = true
    var life: CGFloat = 3
    var pierce = 0
    var slot: Slot?
    var knock: CGFloat = 30
    var dead = false
    var hitSet = Set<ObjectIdentifier>()
}

// MARK: - Pickup (room rewards, shop items, coins)

final class Pickup: SKNode {
    let reward: Reward?
    let coinValue: Int
    var price: Int
    var taken = false
    var denyCD: CGFloat = 0
    let radius: CGFloat

    var isCoin: Bool { reward == nil }

    init(reward: Reward?, coinValue: Int = 0, price: Int = 0) {
        self.reward = reward
        self.coinValue = coinValue
        self.price = price
        radius = reward == nil ? 10 : 26
        super.init()
        if let r = reward {
            let g = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: 120, height: 120))
            g.color = r.color
            g.colorBlendFactor = 1
            g.blendMode = .add
            g.alpha = 0.55
            g.zPosition = -1
            g.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.7), .fadeAlpha(to: 0.6, duration: 0.7)])))
            addChild(g)
            let sh = SKSpriteNode(texture: Tex.shadow(), size: CGSize(width: 44, height: 18))
            sh.position = CGPoint(x: 0, y: -26)
            sh.zPosition = -0.5
            addChild(sh)
            let icon = SKSpriteNode(texture: Tex.icon(r), size: CGSize(width: 48, height: 48))
            icon.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 7, duration: 0.8),
                .moveBy(x: 0, y: -7, duration: 0.8),
            ])))
            addChild(icon)
            let text = price > 0 ? "\(r.title) · \(price) gold" : r.title
            let l = makeLabel(text, size: 13, color: price > 0 ? UIColor(hex: 0xf0c040) : .white, font: Font.bold)
            l.position = CGPoint(x: 0, y: -46)
            l.zPosition = 1
            addChild(l)
        } else {
            let c = SKSpriteNode(texture: Tex.icon(.gold), size: CGSize(width: 18, height: 18))
            addChild(c)
        }
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Door

final class Door: SKNode {
    let reward: Reward
    var isOpen = false
    let frameSprite = SKSpriteNode(texture: Tex.door(), size: CGSize(width: 110, height: 130))
    let bars = SKSpriteNode(texture: Tex.bars(), size: CGSize(width: 110, height: 130))
    let glow = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: 160, height: 160))
    let icon: SKSpriteNode
    let label: SKLabelNode

    init(reward: Reward, text: String) {
        self.reward = reward
        icon = SKSpriteNode(texture: Tex.icon(reward), size: CGSize(width: 42, height: 42))
        label = makeLabel(text, size: 13, color: reward.color.scaled(1.1), font: Font.bold)
        super.init()
        frameSprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        addChild(frameSprite)
        glow.position = CGPoint(x: 0, y: 58)
        glow.color = reward.color
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.alpha = 0
        glow.zPosition = 1
        addChild(glow)
        icon.position = CGPoint(x: 0, y: 62)
        icon.zPosition = 2
        icon.alpha = 0.45
        addChild(icon)
        bars.anchorPoint = CGPoint(x: 0.5, y: 0)
        bars.zPosition = 3
        addChild(bars)
        label.position = CGPoint(x: 0, y: -16)
        label.zPosition = 3
        label.alpha = 0.6
        addChild(label)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setOpen() {
        guard !isOpen else { return }
        isOpen = true
        bars.run(.group([.moveBy(x: 0, y: 30, duration: 0.5), .fadeOut(withDuration: 0.5)]))
        icon.run(.fadeIn(withDuration: 0.4))
        label.run(.fadeIn(withDuration: 0.4))
        glow.run(.sequence([
            .fadeAlpha(to: 0.8, duration: 0.4),
            .repeatForever(.sequence([.fadeAlpha(to: 0.45, duration: 0.8), .fadeAlpha(to: 0.85, duration: 0.8)])),
        ]))
        icon.run(.repeatForever(.sequence([.moveBy(x: 0, y: 5, duration: 0.7), .moveBy(x: 0, y: -5, duration: 0.7)])))
    }
}
