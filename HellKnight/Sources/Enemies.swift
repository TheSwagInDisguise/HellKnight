import SpriteKit
import UIKit

enum EnemyKind: Int {
    case imp, archer, brute, wisp, priest, boss

    var cost: Int {
        let c = [1, 2, 3, 1, 3, 10]
        return c[rawValue]
    }
}

class Enemy: SKNode {
    let kind: EnemyKind
    let depth: Int
    var hp: CGFloat
    var maxHp: CGFloat
    var radius: CGFloat
    var baseSpeed: CGFloat
    var dmgMult: CGFloat
    var alive = true
    var elite = false
    var knockVel = CGPoint.zero
    var knockResist: CGFloat = 1
    var burnTime: CGFloat = 0
    var burnDps: CGFloat = 0
    var burnTick: CGFloat = 0
    var chillTime: CGFloat = 0
    var chillAmount: CGFloat = 0
    var stun: CGFloat = 0
    var timer: CGFloat = 0
    var showsBar = true
    var deathColor = UIColor(hex: 0xff5030)

    let sprite: SKSpriteNode
    let shadowNode: SKSpriteNode
    let statusGlow: SKSpriteNode
    let hpBack: SKSpriteNode
    let hpFill: SKSpriteNode

    init(kind: EnemyKind, depth: Int, texture: SKTexture, spriteSize: CGFloat, radius: CGFloat, hp: CGFloat, speed: CGFloat) {
        self.kind = kind
        self.depth = depth
        let scale = 1 + 0.5 * CGFloat(depth)
        self.hp = hp * scale
        self.maxHp = hp * scale
        self.radius = radius
        self.baseSpeed = speed
        self.dmgMult = 1 + 0.3 * CGFloat(depth)
        sprite = SKSpriteNode(texture: texture, size: CGSize(width: spriteSize, height: spriteSize))
        shadowNode = SKSpriteNode(texture: Tex.shadow(), size: CGSize(width: radius * 2.4, height: radius * 1.1))
        statusGlow = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: radius * 3.6, height: radius * 3.6))
        let bw = max(36, radius * 2)
        hpBack = SKSpriteNode(color: UIColor(white: 0, alpha: 0.7), size: CGSize(width: bw + 2, height: 6))
        hpFill = SKSpriteNode(color: UIColor(hex: 0xe0303a), size: CGSize(width: bw, height: 4))
        super.init()
        shadowNode.position = CGPoint(x: 0, y: -radius * 0.85)
        shadowNode.zPosition = -1
        addChild(shadowNode)
        statusGlow.blendMode = .add
        statusGlow.colorBlendFactor = 1
        statusGlow.alpha = 0
        statusGlow.zPosition = -0.5
        addChild(statusGlow)
        addChild(sprite)
        hpBack.position = CGPoint(x: 0, y: spriteSize * 0.5 + 8)
        hpBack.zPosition = 5
        hpBack.isHidden = true
        hpFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        hpFill.position = CGPoint(x: -bw / 2, y: 0)
        hpFill.zPosition = 0.1
        hpBack.addChild(hpFill)
        addChild(hpBack)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var moveSpeed: CGFloat { baseSpeed * (chillTime > 0 ? (1 - chillAmount) : 1) }

    func makeElite() {
        elite = true
        maxHp *= 1.8
        hp = maxHp
        dmgMult *= 1.25
        radius *= 1.15
        sprite.setScale(1.15)
        let ring = SKSpriteNode(texture: Tex.ringTex(), size: CGSize(width: radius * 2.7, height: radius * 2.7))
        ring.color = UIColor(hex: 0xffc040)
        ring.colorBlendFactor = 1
        ring.alpha = 0.75
        ring.zPosition = -0.4
        ring.run(.repeatForever(.sequence([.fadeAlpha(to: 0.35, duration: 0.6), .fadeAlpha(to: 0.8, duration: 0.6)])))
        addChild(ring)
    }

    func update(_ dt: CGFloat, game: GameScene) {
        guard alive else { return }
        if burnTime > 0 {
            burnTime -= dt
            burnTick -= dt
            if burnTick <= 0 {
                burnTick = 0.5
                game.applyDot(self, burnDps * 0.5)
                if !alive { return }
            }
        }
        if chillTime > 0 { chillTime -= dt }
        if burnTime > 0 {
            statusGlow.color = UIColor(hex: 0xff6a1a)
            statusGlow.alpha = 0.6
        } else if chillTime > 0 {
            statusGlow.color = UIColor(hex: 0x6fd6ff)
            statusGlow.alpha = 0.6
        } else {
            statusGlow.alpha = 0
        }
        if knockVel.length > 1 {
            position = position + knockVel * dt
            knockVel = knockVel * max(0, 1 - 9 * dt)
        }
        if stun > 0 {
            stun -= dt
        } else {
            think(dt, game: game)
        }
        position = game.room.resolve(position, radius)
        zPosition = game.depthZ(position.y)
    }

    func think(_ dt: CGFloat, game: GameScene) {}

    func moveToward(_ target: CGPoint, _ dt: CGFloat, speedMult: CGFloat = 1) {
        let d = (target - position).normalized
        position = position + d * (moveSpeed * speedMult * dt)
        face(d.x)
    }

    func face(_ dx: CGFloat) {
        if abs(dx) > 0.05 {
            let s = abs(sprite.xScale)
            sprite.xScale = dx < 0 ? -s : s
        }
    }

    func takeDamage(_ amount: CGFloat) {
        hp -= amount
        if showsBar {
            hpBack.isHidden = false
            hpFill.xScale = max(0, hp / maxHp)
        }
    }

    func flashHit() {
        sprite.removeAction(forKey: "flash")
        sprite.run(.sequence([
            .colorize(with: .white, colorBlendFactor: 1, duration: 0),
            .wait(forDuration: 0.06),
            .colorize(withColorBlendFactor: 0, duration: 0.08),
        ]), withKey: "flash")
    }

    func applyBurn(dps: CGFloat, time: CGFloat) {
        burnDps = burnTime > 0 ? max(burnDps, dps) : dps
        burnTime = max(burnTime, time)
        if burnTick <= 0 { burnTick = 0.5 }
    }

    func applyChill(amount: CGFloat, time: CGFloat) {
        chillAmount = max(chillTime > 0 ? chillAmount : 0, amount)
        chillTime = max(chillTime, time)
    }

    func windupFlash(_ duration: CGFloat) {
        sprite.removeAction(forKey: "flash")
        sprite.run(.sequence([
            .colorize(with: UIColor(hex: 0xff2010), colorBlendFactor: 0.7, duration: TimeInterval(duration * 0.8)),
            .colorize(withColorBlendFactor: 0, duration: TimeInterval(duration * 0.2)),
        ]), withKey: "flash")
    }
}

// MARK: - Imp: fast melee lunger

final class Imp: Enemy {
    enum S { case chase, windup, lunge, recover }
    var s = S.chase
    var dir = CGPoint.zero
    var hitDone = false

    init(depth: Int) {
        super.init(kind: .imp, depth: depth, texture: Tex.imp(), spriteSize: 42, radius: 16, hp: 42, speed: 140)
        timer = rnd(0.3, 1.0)
        deathColor = UIColor(hex: 0xff5030)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func think(_ dt: CGFloat, game: GameScene) {
        let p = game.player.position
        timer -= dt
        switch s {
        case .chase:
            moveToward(p, dt)
            if position.distance(to: p) < 120 && timer <= 0 {
                s = .windup
                timer = 0.42
                dir = (p - position).normalized
                windupFlash(0.42)
                game.telegraphLine(from: position, angle: dir.angle, length: 140, width: radius * 1.6, duration: 0.42)
            }
        case .windup:
            if timer <= 0 {
                s = .lunge
                timer = 0.22
                hitDone = false
            }
        case .lunge:
            position = position + dir * (580 * dt)
            face(dir.x)
            if !hitDone && position.distance(to: p) < radius + game.player.radius + 4 {
                hitDone = true
                game.hurtPlayer(10 * dmgMult, from: position)
            }
            if timer <= 0 {
                s = .recover
                timer = 0.6
            }
        case .recover:
            moveToward(p, dt, speedMult: 0.25)
            if timer <= 0 {
                s = .chase
                timer = rnd(0.4, 0.9)
            }
        }
    }
}

// MARK: - Bone Archer: keeps distance, telegraphed shots

final class Archer: Enemy {
    var aiming = false
    var aimAngle: CGFloat = 0
    var aimLine: SKSpriteNode?
    var strafe: CGFloat = 1

    init(depth: Int) {
        super.init(kind: .archer, depth: depth, texture: Tex.archer(), spriteSize: 44, radius: 16, hp: 34, speed: 115)
        timer = rnd(1.0, 2.0)
        strafe = chance(0.5) ? 1 : -1
        deathColor = UIColor(hex: 0xe0d6bf)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func think(_ dt: CGFloat, game: GameScene) {
        let p = game.player.position
        let d = p - position
        let dist = d.length
        face(d.x)
        timer -= dt
        if aiming {
            if timer > 0.3 {
                aimAngle = d.angle
                aimLine?.zRotation = aimAngle
            }
            if timer <= 0 {
                aiming = false
                aimLine = nil
                let v = CGPoint(angle: aimAngle, length: 560 + 30 * CGFloat(depth))
                game.spawnProjectile(at: position + CGPoint(angle: aimAngle, length: radius), vel: v,
                                     damage: 10 * dmgMult, hostile: true, texture: Tex.arrow(),
                                     size: CGSize(width: 34, height: 10), radius: 7)
                sfx(.shoot, 0.6)
                timer = rnd(1.8, 2.6)
            }
            return
        }
        var mv = CGPoint.zero
        if dist < 230 {
            mv = d.normalized * -1
        } else if dist > 420 {
            mv = d.normalized
        } else {
            mv = CGPoint(x: -d.y, y: d.x).normalized * (strafe * 0.6)
            if chance(dt * 0.4) { strafe *= -1 }
        }
        position = position + mv * (moveSpeed * dt)
        if timer <= 0 && dist < 700 {
            aiming = true
            timer = 0.75
            aimAngle = d.angle
            windupFlash(0.75)
            aimLine = game.telegraphLine(from: position, angle: aimAngle, length: 720, width: 5, duration: 0.75)
        }
    }
}

// MARK: - Brute: slow, armored charger

final class Brute: Enemy {
    enum S { case chase, windup, charge }
    var s = S.chase
    var dir = CGPoint.zero
    var hitDone = false

    init(depth: Int) {
        super.init(kind: .brute, depth: depth, texture: Tex.brute(), spriteSize: 70, radius: 28, hp: 150, speed: 75)
        knockResist = 0.25
        timer = rnd(1.0, 2.0)
        deathColor = UIColor(hex: 0xb070d0)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func think(_ dt: CGFloat, game: GameScene) {
        let p = game.player.position
        timer -= dt
        switch s {
        case .chase:
            moveToward(p, dt)
            if position.distance(to: p) < 400 && timer <= 0 {
                s = .windup
                timer = 0.8
                dir = (p - position).normalized
                face(dir.x)
                windupFlash(0.8)
                game.telegraphLine(from: position, angle: dir.angle, length: 440, width: radius * 2, duration: 0.8)
            }
        case .windup:
            if timer <= 0 {
                s = .charge
                timer = 0.65
                hitDone = false
            }
        case .charge:
            let next = position + dir * (660 * dt)
            let res = game.room.resolve(next, radius)
            position = res
            if !hitDone && position.distance(to: p) < radius + game.player.radius + 4 {
                hitDone = true
                game.hurtPlayer(20 * dmgMult, from: position)
            }
            if res.distance(to: next) > 0.5 {
                game.addShake(6)
                game.burst(at: position, color: UIColor(hex: 0xb0a090), count: 12, speed: 220)
                stun = 1.2
                s = .chase
                timer = 1.8
            } else if timer <= 0 {
                s = .chase
                timer = 1.6
            }
        }
    }
}

// MARK: - Wisp: kamikaze that explodes

final class Wisp: Enemy {
    var fuse = false
    var phase: CGFloat = 0

    init(depth: Int) {
        super.init(kind: .wisp, depth: depth, texture: Tex.wisp(), spriteSize: 40, radius: 14, hp: 22, speed: 160)
        phase = rnd(0, 6)
        sprite.blendMode = .add
        deathColor = UIColor(hex: 0x6cf0c2)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func think(_ dt: CGFloat, game: GameScene) {
        phase += dt * 4
        if fuse {
            timer -= dt
            sprite.alpha = sin(timer * 40) > 0 ? 1 : 0.4
            if timer <= 0 {
                game.explosion(at: position, radius: 95, damage: 18 * dmgMult, hostile: true, color: UIColor(hex: 0x6cf0c2))
                game.killEnemy(self, rewards: false)
            }
            return
        }
        let d = game.player.position - position
        let perp = CGPoint(x: -d.y, y: d.x).normalized * (sin(phase) * 0.7)
        position = position + (d.normalized + perp).normalized * (moveSpeed * dt)
        sprite.position = CGPoint(x: 0, y: sin(phase * 1.5) * 4)
        if d.length < 90 {
            fuse = true
            timer = 0.75
            game.telegraphCircle(at: position, radius: 95, duration: 0.75)
        }
    }
}

// MARK: - Hex Priest: ranged caster, bullet rings, teleports

final class Priest: Enemy {
    var casting = false
    var casts = 0

    init(depth: Int) {
        super.init(kind: .priest, depth: depth, texture: Tex.priest(), spriteSize: 48, radius: 18, hp: 70, speed: 85)
        timer = rnd(1.5, 2.5)
        deathColor = UIColor(hex: 0xc060ff)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func think(_ dt: CGFloat, game: GameScene) {
        let p = game.player.position
        let d = p - position
        face(d.x)
        timer -= dt
        if casting {
            if timer <= 0 {
                casting = false
                casts += 1
                let n = 10 + 2 * depth
                let off = rnd(0, 2 * .pi)
                for i in 0..<n {
                    let a = off + CGFloat(i) * 2 * .pi / CGFloat(n)
                    game.enemyOrb(from: position, angle: a, speed: 185 + 20 * CGFloat(depth), damage: 9 * dmgMult, color: UIColor(hex: 0xff40c0))
                }
                sfx(.cast, 0.5)
                timer = rnd(2.6, 3.4)
                if casts % 2 == 0 { teleport(game) }
            }
            return
        }
        let dist = d.length
        if dist < 260 {
            position = position - d.normalized * (moveSpeed * dt)
        } else if dist > 420 {
            moveToward(p, dt)
        }
        if timer <= 0 {
            casting = true
            timer = 0.65
            windupFlash(0.65)
            statusGlow.color = UIColor(hex: 0xff40c0)
            game.burst(at: position, color: UIColor(hex: 0xff40c0), count: 8, speed: 80)
        }
    }

    func teleport(_ game: GameScene) {
        let target = game.room.randomOpenPoint(margin: 40, avoid: game.player.position, minDist: 300)
        stun = 0.5
        run(.sequence([
            .fadeOut(withDuration: 0.2),
            .run { [weak self] in self?.position = target },
            .fadeIn(withDuration: 0.2),
        ]))
    }
}

// MARK: - Boss

final class Boss: Enemy {
    enum Pattern { case spiral, charge, rings, slam, summon }
    enum ChargeStep { case wind, go, rest }

    static let names = ["Gorrath, the Cinder Warden", "Vexis, Matron of Bones", "Malphor, the Abyssal King"]

    let bossName: String
    let color: UIColor
    var pattern: Pattern?
    var last: Pattern?
    var idle: CGFloat = 1.6
    var sub: CGFloat = 0
    var count = 0
    var spin: CGFloat = 0
    var dir = CGPoint.zero
    var cstep = ChargeStep.wind
    var hitDone = false
    var phase2 = false
    var contactCD: CGFloat = 0
    let rage = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: 220, height: 220))

    init(depth: Int) {
        let d = min(max(depth, 0), 2)
        bossName = Boss.names[d]
        let cols: [UInt32] = [0xff6a1a, 0xb8ff9a, 0x9a7cff]
        color = UIColor(hex: cols[d])
        super.init(kind: .boss, depth: depth, texture: Tex.boss(d), spriteSize: 130, radius: 50, hp: 1300, speed: 105)
        knockResist = 0
        showsBar = false
        deathColor = color
        rage.color = UIColor(hex: 0xff1a10)
        rage.colorBlendFactor = 1
        rage.blendMode = .add
        rage.alpha = 0
        rage.zPosition = -0.6
        addChild(rage)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var shortName: String { bossName.components(separatedBy: ",").first ?? bossName }

    override func think(_ dt: CGFloat, game: GameScene) {
        let p = game.player.position
        let d = p - position
        face(d.x)
        contactCD -= dt
        if contactCD <= 0 && d.length < radius + game.player.radius - 6 {
            contactCD = 0.8
            game.hurtPlayer(12 * dmgMult, from: position)
        }
        if !phase2 && hp < maxHp * 0.5 {
            phase2 = true
            game.hud.banner(shortName, "is enraged!", color: color)
            sfx(.roar)
            game.addShake(10)
            rage.run(.repeatForever(.sequence([.fadeAlpha(to: 0.5, duration: 0.5), .fadeAlpha(to: 0.25, duration: 0.5)])))
        }
        guard let pat = pattern else {
            idle -= dt
            if d.length > 150 { moveToward(p, dt, speedMult: phase2 ? 1.25 : 0.9) }
            if idle <= 0 { begin(game) }
            return
        }
        switch pat {
        case .spiral:
            timer -= dt
            sub -= dt
            if sub <= 0 {
                sub = phase2 ? 0.075 : 0.1
                let arms = phase2 ? 4 : 3
                for i in 0..<arms {
                    let a = spin + CGFloat(i) * 2 * .pi / CGFloat(arms)
                    game.enemyOrb(from: position, angle: a, speed: 205 + 20 * CGFloat(depth), damage: 9 * dmgMult, color: color)
                }
                spin += 0.21
            }
            if timer <= 0 { end() }
        case .charge:
            sub -= dt
            switch cstep {
            case .wind:
                if sub <= 0 {
                    cstep = .go
                    sub = 0.6
                    hitDone = false
                }
            case .go:
                let next = position + dir * (800 * dt)
                let res = game.room.resolve(next, radius)
                position = res
                if !hitDone && p.distance(to: position) < radius + game.player.radius {
                    hitDone = true
                    game.hurtPlayer(22 * dmgMult, from: position)
                }
                let hitWall = res.distance(to: next) > 0.5
                if hitWall || sub <= 0 {
                    if hitWall {
                        game.addShake(8)
                        game.burst(at: position, color: color, count: 14, speed: 260)
                    }
                    cstep = .rest
                    sub = 0.3
                    count -= 1
                }
            case .rest:
                if sub <= 0 {
                    if count > 0 { startWind(game) } else { end() }
                }
            }
        case .rings:
            sub -= dt
            if sub <= 0 {
                sub = 0.55
                let n = phase2 ? 22 : 16
                let off: CGFloat = count % 2 == 0 ? 0 : .pi / CGFloat(n)
                for i in 0..<n {
                    let a = off + CGFloat(i) * 2 * .pi / CGFloat(n)
                    game.enemyOrb(from: position, angle: a, speed: 185 + 20 * CGFloat(depth), damage: 9 * dmgMult, color: color)
                }
                sfx(.shoot, 0.8)
                count -= 1
                if count <= 0 { end() }
            }
        case .slam, .summon:
            timer -= dt
            if timer <= 0 { end() }
        }
    }

    func begin(_ game: GameScene) {
        var options: [Pattern] = [.spiral, .charge, .rings, .slam]
        if (phase2 || depth > 0) && game.enemies.count < 5 { options.append(.summon) }
        options.removeAll { $0 == last }
        let pat = options.randomElement() ?? .spiral
        pattern = pat
        last = pat
        switch pat {
        case .spiral:
            sub = 0.3
            spin = rnd(0, 2 * .pi)
            timer = phase2 ? 3.2 : 2.6
            windupFlash(0.3)
        case .charge:
            count = phase2 ? 4 : 3
            startWind(game)
        case .rings:
            count = phase2 ? 5 : 3
            sub = 0.4
            windupFlash(0.4)
        case .slam:
            let n = phase2 ? 7 : 5
            for i in 0..<n {
                let off = i == 0 ? CGPoint.zero : CGPoint(angle: rnd(0, 2 * .pi), length: rnd(80, 230))
                let at = game.room.resolve(game.player.position + off, 40)
                game.delayedExplosion(at: at, radius: 85, delay: 1.0 + 0.12 * CGFloat(i), damage: 18 * dmgMult, color: color)
            }
            timer = 1.9
        case .summon:
            let n = 2 + depth
            for _ in 0..<n {
                let at = game.room.resolve(position + CGPoint(angle: rnd(0, 2 * .pi), length: rnd(120, 190)), 30)
                let k: EnemyKind = chance(0.5) ? .imp : .wisp
                game.spawnEnemy(k, at: at)
            }
            sfx(.roar, 0.6)
            timer = 1.2
        }
    }

    func end() {
        pattern = nil
        idle = phase2 ? 0.7 : 1.2
    }

    func startWind(_ game: GameScene) {
        cstep = .wind
        sub = phase2 ? 0.5 : 0.65
        dir = (game.player.position - position).normalized
        windupFlash(sub)
        game.telegraphLine(from: position, angle: dir.angle, length: 650, width: radius * 2, duration: sub)
    }
}
