import SpriteKit
import UIKit

// MARK: - Player

final class Player: SKNode {
    let radius: CGFloat = 18
    let weapon: WeaponKind
    let up = Billboard()
    let body: SKSpriteNode
    let cape = SKSpriteNode(texture: Tex.knightCape(), size: Player.bodySize)
    var capeAngle: CGFloat = 0
    var lean: CGFloat = 0
    var idleTime: CGFloat = 0
    let pivot = SKNode()
    let weaponSprite: SKSpriteNode
    let weaponBase: CGPoint
    let shadow = SKSpriteNode(texture: Tex.softShadow(), size: CGSize(width: 46, height: 46))
    let lightPool = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: 260, height: 260))

    var facing: CGFloat = .pi / 4
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

    static let bodySize = CGSize(width: 64, height: 84)
    static let bodyAnchor = CGPoint(x: 0.5, y: 0.04)

    init(weapon: WeaponKind) {
        self.weapon = weapon
        let b = SKSpriteNode(texture: Tex.knightBody(), size: Player.bodySize)
        b.anchorPoint = Player.bodyAnchor
        body = b
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
        super.init()
        lightPool.color = Ink.bone
        lightPool.colorBlendFactor = 1
        lightPool.blendMode = .add
        lightPool.alpha = 0.12
        lightPool.zPosition = -3
        addChild(lightPool)
        shadow.zPosition = -2
        addChild(shadow)
        addChild(up)
        weaponSprite.position = weaponBase
        pivot.position = CGPoint(x: 0, y: 34)
        pivot.addChild(weaponSprite)
        up.addChild(pivot)
        up.addChild(body)
        // Cape hangs from the shoulders (y=30 of 84 in the texture) and sways behind the body.
        cape.anchorPoint = CGPoint(x: 0.5, y: (84 - 30) / 84)
        cape.position = CGPoint(x: 0, y: 84 * (1 - Player.bodyAnchor.y) - 30)
        cape.zPosition = -0.5
        body.addChild(cape)
        setFacing(.pi / 4)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var isSwinging: Bool { pivot.action(forKey: "swing") != nil }

    func setFacing(_ a: CGFloat) {
        facing = a
        let sa = screenAngle(a)
        pivot.zRotation = sa
        pivot.zPosition = sin(sa) > 0.3 ? -1 : 1
        let cx = cos(sa)
        if cx < -0.15 { body.xScale = -1 } else if cx > 0.15 { body.xScale = 1 }
    }

    func playSwing(angle a: CGFloat, arcDeg: CGFloat) {
        swingCount += 1
        pivot.removeAction(forKey: "swing")
        weaponSprite.removeAction(forKey: "thrust")
        setFacing(a)
        let sa = screenAngle(a)
        body.removeAction(forKey: "squash")
        body.yScale = 0.9
        body.run(.scaleY(to: 1, duration: 0.14), withKey: "squash")
        switch weapon {
        case .blade:
            let half = arcDeg * .pi / 360
            let dir: CGFloat = swingCount % 2 == 0 ? 1 : -1
            pivot.zRotation = sa + half * dir
            pivot.run(.rotate(toAngle: sa - half * dir, duration: 0.09), withKey: "swing")
        case .pike, .fists:
            pivot.zRotation = sa
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
        idleTime += dt
        let k = 1 - exp(-dt * 12)
        let facingSign: CGFloat = body.xScale < 0 ? -1 : 1
        let dashing = dashTime > 0
        if moving || dashing {
            walkPhase += dt * (dashing ? 0 : 14)
            body.position = CGPoint(x: 0, y: dashing ? 2 : abs(sin(walkPhase)) * 3.5)
            lean += ((dashing ? -0.16 : -0.07) - lean) * k
            if body.action(forKey: "squash") == nil { body.yScale = dashing ? 0.93 : 1 + abs(cos(walkPhase)) * 0.015 }
        } else {
            body.position = .zero
            lean += (0 - lean) * k
            if body.action(forKey: "squash") == nil { body.yScale = 1 + sin(idleTime * 2.6) * 0.022 }
        }
        body.zRotation = (lean + (moving ? sin(walkPhase) * 0.035 : 0)) * facingSign
        // Cape trails behind when moving and flutters, eased so it never snaps.
        let capeTarget: CGFloat = dashing ? -0.55 : (moving ? -0.28 + sin(walkPhase * 0.9) * 0.07 : sin(idleTime * 1.7) * 0.035)
        capeAngle += (capeTarget - capeAngle) * (1 - exp(-dt * 8))
        cape.zRotation = capeAngle - lean * 0.5
        cape.xScale = 1 + (moving ? 0.04 : 0)
        if invuln > 0 && dashTime <= 0 {
            body.alpha = sin(invuln * 40) > 0 ? 0.45 : 1
        } else {
            body.alpha = 1
        }
    }

    func flashHurt() {
        body.removeAction(forKey: "hurt")
        body.run(.sequence([
            .colorize(with: Ink.blood, colorBlendFactor: 0.85, duration: 0),
            .colorize(withColorBlendFactor: 0, duration: 0.3),
        ]), withKey: "hurt")
    }
}

// MARK: - Projectile

final class Projectile: SKNode {
    var vel = CGPoint.zero
    var damage: CGFloat = 10
    var radius: CGFloat = 8
    var hostile = true
    var life: CGFloat = 3
    var pierce = 0
    var slot: Slot?
    var knock: CGFloat = 30
    var dead = false
    var tint: UIColor = .white
    var light: SKSpriteNode?
    var hitSet = Set<ObjectIdentifier>()
    let up = Billboard()
    let art: SKSpriteNode

    init(texture: SKTexture, size: CGSize, height: CGFloat = 26) {
        art = SKSpriteNode(texture: texture, size: size)
        super.init()
        let sh = SKSpriteNode(texture: Tex.softShadow(), size: CGSize(width: 22, height: 22))
        sh.alpha = 0.6
        sh.zPosition = -1
        addChild(sh)
        art.position = CGPoint(x: 0, y: height)
        up.addChild(art)
        addChild(up)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Pickup (room rewards, shop items, coins)

final class Pickup: SKNode {
    let reward: Reward?
    let coinValue: Int
    var price: Int
    var taken = false
    var denyCD: CGFloat = 0
    let radius: CGFloat
    var light: SKSpriteNode?

    var isCoin: Bool { reward == nil }

    init(reward: Reward?, coinValue: Int = 0, price: Int = 0, depth: Int = 0, invisible: Bool = false) {
        self.reward = reward
        self.coinValue = coinValue
        self.price = price
        radius = invisible ? 46 : (reward == nil ? 10 : 28)
        super.init()
        if invisible { return }
        let up = Billboard()
        if let r = reward {
            let sig = SKSpriteNode(texture: Tex.sigil(), size: CGSize(width: 110, height: 110))
            sig.color = r.color
            sig.colorBlendFactor = 1
            sig.blendMode = .add
            sig.alpha = 0.55
            sig.zPosition = -2
            sig.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 14)))
            addChild(sig)
            let g = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: 150, height: 150))
            g.color = r.color
            g.colorBlendFactor = 1
            g.blendMode = .add
            g.alpha = 0.35
            g.zPosition = -1.5
            g.run(.repeatForever(.sequence([.fadeAlpha(to: 0.2, duration: 0.8), .fadeAlpha(to: 0.4, duration: 0.8)])))
            addChild(g)
            addChild(up)
            var iconY: CGFloat = 40
            if price > 0 {
                let ped = SKSpriteNode(texture: Tex.pedestal(depth), size: CGSize(width: 64, height: 56))
                ped.anchorPoint = CGPoint(x: 0.5, y: 0.05)
                up.addChild(ped)
                iconY = 78
            }
            let halo = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: 80, height: 80))
            halo.color = r.color
            halo.colorBlendFactor = 1
            halo.blendMode = .add
            halo.alpha = 0.6
            halo.position = CGPoint(x: 0, y: iconY)
            up.addChild(halo)
            let icon = SKSpriteNode(texture: Tex.icon(r), size: CGSize(width: 50, height: 50))
            icon.position = CGPoint(x: 0, y: iconY)
            icon.zPosition = 1
            icon.run(.repeatForever(.sequence([
                .moveBy(x: 0, y: 7, duration: 0.8),
                .moveBy(x: 0, y: -7, duration: 0.8),
            ])))
            up.addChild(icon)
            let text = price > 0 ? "\(r.title) · \(price) gold" : r.title
            let l = makeLabel(text, size: 14, color: price > 0 ? Ink.gold : Ink.bone, font: Font.bold)
            l.position = CGPoint(x: 0, y: -16)
            l.zPosition = 2
            let back = SKSpriteNode(texture: Tex.panel(max(90, CGFloat(text.count) * 7.2 + 24), 24, fillAlpha: 0.8))
            back.position = l.position
            back.zPosition = 1.5
            up.addChild(back)
            up.addChild(l)
        } else {
            addChild(up)
            let sh = SKSpriteNode(texture: Tex.softShadow(), size: CGSize(width: 16, height: 16))
            sh.zPosition = -1
            addChild(sh)
            let c = SKSpriteNode(texture: Tex.icon(.gold), size: CGSize(width: 20, height: 20))
            c.position = CGPoint(x: 0, y: 12)
            c.run(.repeatForever(.sequence([.moveBy(x: 0, y: 4, duration: 0.4), .moveBy(x: 0, y: -4, duration: 0.4)])))
            up.addChild(c)
        }
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

// MARK: - Door (built into the back-left wall)

final class Door: SKNode {
    let reward: Reward
    var isOpen = false
    let up = Billboard()
    let frameSprite: SKSpriteNode
    let bars: SKSpriteNode
    let glow = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: 120, height: 150))
    let icon: SKSpriteNode
    let label: SKLabelNode
    let plate: SKSpriteNode

    init(reward: Reward, text: String, depth: Int) {
        self.reward = reward
        let tsize = CGSize(width: Tex.segW + 1, height: Tex.wallH + Tex.segRise)
        let anchor = CGPoint(x: 0.5, y: (Tex.segRise / 2) / tsize.height)
        let fs = SKSpriteNode(texture: Tex.doorSeg(depth), size: tsize)
        fs.anchorPoint = anchor
        frameSprite = fs
        let bs = SKSpriteNode(texture: Tex.bars(depth), size: tsize)
        bs.anchorPoint = anchor
        bars = bs
        icon = SKSpriteNode(texture: Tex.icon(reward), size: CGSize(width: 40, height: 40))
        label = makeLabel(text, size: 13, color: reward.color.scaled(1.15), font: Font.bold)
        plate = SKSpriteNode(texture: Tex.panel(max(100, CGFloat(text.count) * 7 + 26), 24, fillAlpha: 0.85))
        super.init()
        addChild(up)
        up.addChild(frameSprite)
        glow.position = CGPoint(x: 0, y: 55)
        glow.color = reward.color
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.alpha = 0
        glow.zPosition = 0.5
        up.addChild(glow)
        bars.zPosition = 1
        up.addChild(bars)
        icon.position = CGPoint(x: 0, y: 62)
        icon.zPosition = 2
        icon.alpha = 0.5
        up.addChild(icon)
        plate.position = CGPoint(x: 0, y: -18)
        plate.zPosition = 2
        up.addChild(plate)
        label.position = CGPoint(x: 0, y: -18)
        label.zPosition = 3
        label.alpha = 0.6
        up.addChild(label)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setOpen() {
        guard !isOpen else { return }
        isOpen = true
        bars.run(.group([.moveBy(x: 0, y: 60, duration: 0.6), .fadeOut(withDuration: 0.6)]))
        icon.run(.fadeIn(withDuration: 0.4))
        label.run(.fadeIn(withDuration: 0.4))
        glow.run(.sequence([
            .fadeAlpha(to: 0.9, duration: 0.4),
            .repeatForever(.sequence([.fadeAlpha(to: 0.5, duration: 0.8), .fadeAlpha(to: 0.9, duration: 0.8)])),
        ]))
        icon.run(.repeatForever(.sequence([.moveBy(x: 0, y: 5, duration: 0.7), .moveBy(x: 0, y: -5, duration: 0.7)])))
    }
}
