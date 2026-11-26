import SpriteKit
import UIKit

extension GameScene {

    // MARK: - Room construction

    func buildRoom() {
        world.removeAllChildren()
        world.removeAllActions()
        enemies.removeAll()
        projectiles.removeAll()
        pickups.removeAll()
        doors.removeAll()
        boss = nil
        waves = []
        pendingSpawns = 0
        combatStarted = false
        roomCleared = false
        doorsOpen = false

        let pal = Palette.of(runData.depth)
        backgroundColor = pal.bg
        let type = runData.roomType
        var w: CGFloat = 1200
        var h: CGFloat = 900
        switch type {
        case .combat:
            w = (rnd(1050, 1450) / 50).rounded() * 50
            h = (rnd(800, 1050) / 50).rounded() * 50
        case .shop:
            w = 1000
            h = 760
        case .boss:
            w = 1500
            h = 1150
        }
        room = Room(bounds: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), type: type)
        addPillars()
        drawRoom(pal)

        let p = Player(weapon: runData.weapon)
        p.dashCharges = runData.maxDash
        p.castCharges = runData.maxCast
        p.position = CGPoint(x: 0, y: room.bounds.minY + 70)
        p.zPosition = depthZ(p.position.y)
        world.addChild(p)
        player = p
        camBase = clampCam(p.position)
        cam.position = camBase

        makeDoors(pal)

        switch type {
        case .combat:
            waves = generateWaves()
            let m = SKNode()
            world.addChild(m)
            m.run(.sequence([.wait(forDuration: 0.8), .run { [weak self] in
                guard let self = self else { return }
                self.combatStarted = true
                self.startNextWave()
            }]))
            if runData.room == 0 {
                hud.banner(pal.name, "Depth \(runData.depth + 1) of \(RunState.finalDepth + 1)", color: pal.accent.scaled(1.2))
            }
        case .shop:
            makeShop()
            roomCleared = true
            openDoors()
            healPlayer(runData.maxHp * 0.2)
            hud.banner("The Ash Merchant", "Walk over an item to buy it", color: UIColor(hex: 0xf0c040))
        case .boss:
            let name = Boss.names[min(runData.depth, 2)]
            hud.banner(name, "Guardian of the \(pal.name)", color: UIColor(hex: 0xff5030))
            let m = SKNode()
            world.addChild(m)
            m.run(.sequence([.wait(forDuration: 1.8), .run { [weak self] in
                guard let self = self else { return }
                self.combatStarted = true
                self.spawnEnemy(.boss, at: CGPoint(x: 0, y: self.room.bounds.midY + 150))
            }]))
        }
        let where_ = type == .boss ? "Guardian" : (type == .shop ? "Merchant" : "Chamber \(runData.room + 1)")
        hud.roomLabel.text = "\(pal.name) · \(where_)"
    }

    func addPillars() {
        let b = room.bounds
        switch room.type {
        case .boss:
            let sx: [CGFloat] = [-1, 1]
            for x in sx {
                for y in sx {
                    room.pillars.append(Pillar(pos: CGPoint(x: x * b.width * 0.3, y: y * b.height * 0.24), r: 38))
                }
            }
        case .shop:
            break
        case .combat:
            let n = Int.random(in: 2...5)
            var tries = 0
            while room.pillars.count < n && tries < 80 {
                tries += 1
                let r = rnd(30, 46)
                let p = CGPoint(x: rnd(b.minX + 140, b.maxX - 140), y: rnd(b.minY + 200, b.maxY - 170))
                if abs(p.x) < 100 { continue }
                if room.pillars.contains(where: { $0.pos.distance(to: p) < $0.r + r + 130 }) { continue }
                room.pillars.append(Pillar(pos: p, r: r))
            }
        }
    }

    private func block(_ r: CGRect, _ col: UIColor, _ z: CGFloat) {
        let s = SKSpriteNode(color: col, size: r.size)
        s.anchorPoint = .zero
        s.position = r.origin
        s.zPosition = z
        world.addChild(s)
    }

    func drawRoom(_ pal: Palette) {
        let b = room.bounds
        let tile: CGFloat = 128
        var y = b.minY
        while y < b.maxY {
            var x = b.minX
            while x < b.maxX {
                let t = SKSpriteNode(texture: Tex.floor(runData.depth, Int.random(in: 0..<4)), size: CGSize(width: tile, height: tile))
                t.anchorPoint = .zero
                t.position = CGPoint(x: x, y: y)
                t.zPosition = 0
                world.addChild(t)
                x += tile
            }
            y += tile
        }

        // Glowing floor cracks / ambience
        for _ in 0..<Int.random(in: 5...9) {
            let g = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: rnd(140, 260), height: rnd(90, 160)))
            g.color = pal.crack
            g.colorBlendFactor = 1
            g.blendMode = .add
            g.alpha = 0.1
            g.position = CGPoint(x: rnd(b.minX + 60, b.maxX - 60), y: rnd(b.minY + 60, b.maxY - 60))
            g.zPosition = 1
            world.addChild(g)
        }

        // Back wall (tall), side and bottom walls
        let wallH: CGFloat = 128
        let side: CGFloat = 48
        var x = b.minX - side
        while x < b.maxX + side {
            let t = SKSpriteNode(texture: Tex.wall(runData.depth), size: CGSize(width: 128, height: wallH))
            t.anchorPoint = .zero
            t.position = CGPoint(x: x, y: b.maxY)
            t.zPosition = 2
            world.addChild(t)
            x += 128
        }
        block(CGRect(x: b.minX - side, y: b.minY - side, width: side, height: b.height + side + wallH), pal.wallDark, 2.2)
        block(CGRect(x: b.maxX, y: b.minY - side, width: side, height: b.height + side + wallH), pal.wallDark, 2.2)
        block(CGRect(x: b.minX - side, y: b.minY - side, width: b.width + side * 2, height: side), pal.wallDark, 2.2)
        let edge = pal.accent.withAlphaComponent(0.35)
        block(CGRect(x: b.minX - 3, y: b.minY - 3, width: 3, height: b.height + 3), edge, 2.3)
        block(CGRect(x: b.maxX, y: b.minY - 3, width: 3, height: b.height + 3), edge, 2.3)
        block(CGRect(x: b.minX - 3, y: b.minY - 3, width: b.width + 6, height: 3), edge, 2.3)
        block(CGRect(x: b.minX, y: b.maxY - 2, width: b.width, height: 4), pal.accent.withAlphaComponent(0.5), 2.3)
        block(CGRect(x: b.minX - side, y: b.maxY + wallH - 6, width: b.width + side * 2, height: 6), pal.wallDark, 2.3)
        // Masks outside the room
        let big: CGFloat = 4000
        block(CGRect(x: b.maxX + side, y: -big, width: big, height: big * 2), pal.bg, 2.5)
        block(CGRect(x: b.minX - side - big, y: -big, width: big, height: big * 2), pal.bg, 2.5)
        block(CGRect(x: -big, y: b.maxY + wallH, width: big * 2, height: big), pal.bg, 2.5)
        block(CGRect(x: -big, y: b.minY - side - big, width: big * 2, height: big), pal.bg, 2.5)

        // Pillars
        for pl in room.pillars {
            let s = SKSpriteNode(texture: Tex.pillar(runData.depth), size: CGSize(width: pl.r * 2.2, height: pl.r * 2.2))
            s.position = pl.pos
            s.zPosition = depthZ(pl.pos.y - pl.r * 0.4)
            world.addChild(s)
            let sh = SKSpriteNode(texture: Tex.shadow(), size: CGSize(width: pl.r * 2.6, height: pl.r * 1.2))
            sh.position = pl.pos + CGPoint(x: 0, y: -pl.r * 0.9)
            sh.zPosition = 1.5
            world.addChild(sh)
        }

        // Drifting embers
        let em = makeEmbers(area: CGSize(width: b.width, height: b.height), color: pal.ember, rate: 7)
        em.position = CGPoint(x: b.midX, y: b.midY)
        em.zPosition = 45
        em.advanceSimulationTime(5)
        world.addChild(em)
    }

    func addTorch(at p: CGPoint, color: UIColor) {
        let g = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: 150, height: 150))
        g.color = color
        g.colorBlendFactor = 1
        g.blendMode = .add
        g.alpha = 0.5
        g.position = p
        g.zPosition = 2.6
        world.addChild(g)
        g.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.3, duration: TimeInterval(rnd(0.1, 0.25))),
            .fadeAlpha(to: 0.6, duration: TimeInterval(rnd(0.1, 0.25))),
        ])))
        let bracket = SKSpriteNode(color: UIColor(hex: 0x1a1210), size: CGSize(width: 10, height: 18))
        bracket.position = p + CGPoint(x: 0, y: -14)
        bracket.zPosition = 2.65
        world.addChild(bracket)
        let f = SKSpriteNode(texture: Tex.spark(), size: CGSize(width: 18, height: 28))
        f.color = color.scaled(1.3)
        f.colorBlendFactor = 0.6
        f.blendMode = .add
        f.position = p
        f.zPosition = 2.7
        world.addChild(f)
        f.run(.repeatForever(.sequence([.scaleY(to: 1.25, duration: 0.12), .scaleY(to: 0.9, duration: 0.15)])))
    }

    // MARK: - Doors

    func makeDoors(_ pal: Palette) {
        let b = room.bounds
        var rewards: [Reward] = []
        var labels: [String] = []
        let type = runData.roomType
        if type == .boss {
            if runData.depth < RunState.finalDepth {
                rewards = [.boon(Patron.allCases.randomElement() ?? .pyre)]
                labels = ["Descend"]
            }
        } else if runData.room + 1 == 3 {
            rewards = [.shop]
            labels = [Reward.shop.title]
        } else if runData.room + 1 >= 6 {
            rewards = [.boss]
            labels = [Reward.boss.title]
        } else {
            rewards = rollDoorRewards(2)
            labels = rewards.map { $0.title }
        }
        var xs: [CGFloat] = []
        for (i, r) in rewards.enumerated() {
            let x: CGFloat = rewards.count == 1 ? 0 : (i == 0 ? -b.width * 0.24 : b.width * 0.24)
            xs.append(x)
            let d = Door(reward: r, text: labels[i])
            d.position = CGPoint(x: x, y: b.maxY - 6)
            d.zPosition = 3
            world.addChild(d)
            doors.append(d)
        }
        var tx = b.minX + 130
        while tx < b.maxX - 90 {
            if !xs.contains(where: { abs($0 - tx) < 110 }) {
                addTorch(at: CGPoint(x: tx, y: b.maxY + 72), color: pal.accent)
            }
            tx += 260
        }
    }

    func rollDoorRewards(_ n: Int) -> [Reward] {
        let pats = Patron.allCases.shuffled()
        var pool: [(Reward, CGFloat)] = [(.boon(pats[0]), 4), (.boon(pats[1]), 2.5), (.gold, 2), (.heart, 1.2), (.souls, 1.8), (.anvil, 1.3)]
        var out: [Reward] = []
        while out.count < n && !pool.isEmpty {
            let total = pool.reduce(CGFloat(0)) { $0 + $1.1 }
            var r = rnd(0, total)
            var idx = pool.count - 1
            for (i, e) in pool.enumerated() {
                r -= e.1
                if r <= 0 {
                    idx = i
                    break
                }
            }
            out.append(pool[idx].0)
            pool.remove(at: idx)
        }
        return out
    }

    func openDoors() {
        guard !doorsOpen else { return }
        doorsOpen = true
        for d in doors { d.setOpen() }
        if !doors.isEmpty { sfx(.door, 0.6) }
    }

    func checkDoors() {
        guard doorsOpen, let p = player else { return }
        let b = room.bounds
        for d in doors where d.isOpen {
            if abs(p.position.x - d.position.x) < 50 && p.position.y > b.maxY - p.radius - 12 {
                enterDoor(d)
                return
            }
        }
    }

    func enterDoor(_ d: Door) {
        guard state == .playing else { return }
        state = .transition
        controls.reset()
        sfx(.door)
        runData.nextReward = d.reward
        if runData.roomType == .boss {
            runData.depth += 1
            runData.room = 0
        } else {
            runData.room += 1
        }
        hud.fade(to: 1, duration: 0.3) { [weak self] in
            guard let self = self else { return }
            self.buildRoom()
            self.hud.fade(to: 0, duration: 0.35) { [weak self] in
                self?.state = .playing
            }
        }
    }

    // MARK: - Shop

    func makeShop() {
        let b = room.bounds
        let d = runData.depth
        var items: [(Reward, Int)] = [(.heal, 40 + 10 * d)]
        var extra: [(Reward, Int)] = [
            (.boon(Patron.allCases.randomElement() ?? .pyre), 110 + 25 * d),
            (.heart, 90 + 20 * d),
            (.anvil, 120 + 20 * d),
        ]
        extra.shuffle()
        items.append(contentsOf: extra.prefix(2))
        for (i, it) in items.enumerated() {
            let pk = Pickup(reward: it.0, price: it.1)
            pk.position = CGPoint(x: (CGFloat(i) - 1) * 230, y: b.midY + 40)
            pk.zPosition = 5
            world.addChild(pk)
            pickups.append(pk)
        }
    }

    // MARK: - Waves & spawning

    func generateWaves() -> [[EnemyKind]] {
        let d = runData.depth
        let r = runData.room
        let count = r <= 1 ? 2 : 3
        let roster: [EnemyKind]
        switch d {
        case 0: roster = r < 2 ? [.imp, .imp, .archer, .wisp] : [.imp, .imp, .archer, .wisp, .brute]
        case 1: roster = [.imp, .archer, .wisp, .brute, .priest]
        default: roster = [.imp, .archer, .wisp, .brute, .priest, .priest, .brute]
        }
        var result: [[EnemyKind]] = []
        for wi in 0..<count {
            var budget = 3 + d * 2 + r / 2 + wi
            var wave: [EnemyKind] = []
            var guardCount = 0
            while budget > 0 && guardCount < 50 {
                guardCount += 1
                let k = roster.randomElement() ?? .imp
                if k.cost <= budget || wave.isEmpty {
                    wave.append(k)
                    budget -= k.cost
                }
            }
            result.append(wave)
        }
        return result
    }

    func startNextWave() {
        guard !waves.isEmpty, let p = player else { return }
        let wave = waves.removeFirst()
        for k in wave {
            let pos = room.randomOpenPoint(margin: 40, avoid: p.position, minDist: 280)
            spawnEnemy(k, at: pos)
        }
    }

    func spawnEnemy(_ k: EnemyKind, at pos: CGPoint) {
        pendingSpawns += 1
        let portal = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: k == .boss ? 260 : 110, height: k == .boss ? 260 : 110))
        portal.color = UIColor(hex: 0xff2a10)
        portal.colorBlendFactor = 1
        portal.blendMode = .add
        portal.position = pos
        portal.zPosition = 3
        portal.setScale(0.2)
        portal.alpha = 0.9
        world.addChild(portal)
        let ring = SKSpriteNode(texture: Tex.ringTex(), size: portal.size)
        ring.color = UIColor(hex: 0xff6a30)
        ring.colorBlendFactor = 1
        ring.zPosition = 0.1
        portal.addChild(ring)
        ring.run(.repeatForever(.rotate(byAngle: .pi, duration: 0.5)))
        let delay: TimeInterval = k == .boss ? 1.0 : 0.75
        portal.run(.sequence([
            .scale(to: 1, duration: delay),
            .run { [weak self] in self?.finishSpawn(k, at: pos) },
            .fadeOut(withDuration: 0.2),
            .removeFromParent(),
        ]))
    }

    func finishSpawn(_ k: EnemyKind, at pos: CGPoint) {
        pendingSpawns = max(0, pendingSpawns - 1)
        guard state != .dead else { return }
        let d = runData.depth
        let e: Enemy
        switch k {
        case .imp: e = Imp(depth: d)
        case .archer: e = Archer(depth: d)
        case .brute: e = Brute(depth: d)
        case .wisp: e = Wisp(depth: d)
        case .priest: e = Priest(depth: d)
        case .boss: e = Boss(depth: d)
        }
        if k != .boss && chance(0.04 + 0.08 * CGFloat(d) + 0.02 * CGFloat(runData.room)) {
            e.makeElite()
        }
        e.position = room.resolve(pos, e.radius)
        e.zPosition = depthZ(e.position.y)
        e.alpha = 0
        e.run(.fadeIn(withDuration: 0.15))
        world.addChild(e)
        enemies.append(e)
        burst(at: pos, color: UIColor(hex: 0xff4020), count: 8, speed: 140)
        if let b = e as? Boss {
            boss = b
            sfx(.roar)
            addShake(10)
            Haptics.heavy()
        }
    }

    func checkRoomProgress() {
        guard combatStarted, !roomCleared, pendingSpawns == 0, enemies.isEmpty else { return }
        if !waves.isEmpty {
            startNextWave()
        } else {
            roomClearedNow()
        }
    }

    func roomClearedNow() {
        roomCleared = true
        for pr in projectiles where pr.hostile { pr.dead = true }
        runData.souls += 1
        if runData.roomType == .boss {
            if runData.depth >= RunState.finalDepth {
                let m = SKNode()
                world.addChild(m)
                m.run(.sequence([.wait(forDuration: 2.2), .run { [weak self] in self?.victory() }]))
                return
            }
            spawnRoomReward(.heart)
        } else {
            hud.banner("Chamber Cleared", "", color: UIColor(hex: 0xffd090), small: true)
            spawnRoomReward(runData.nextReward)
        }
    }

    func spawnRoomReward(_ r: Reward) {
        let pk = Pickup(reward: r)
        pk.position = room.resolve(CGPoint(x: 0, y: room.bounds.midY), 40)
        pk.zPosition = 5
        world.addChild(pk)
        pickups.append(pk)
        pk.setScale(0)
        pk.run(.scale(to: 1, duration: 0.3))
        sfx(.pickup)
    }

    func bossDefeated() {
        guard let b = boss else { return }
        for e in enemies where e.alive && e !== b { killEnemy(e, rewards: false) }
        for pr in projectiles where pr.hostile { pr.dead = true }
        runData.souls += 25 + 15 * runData.depth
        hud.banner("\(b.shortName) Vanquished", "+\(25 + 15 * runData.depth) souls", color: UIColor(hex: 0xffd090))
        sfx(.explode)
        sfx(.roar, 0.7)
        addShake(14)
        hitstop = 0.35
        Haptics.heavy()
        for i in 0..<4 {
            let m = SKNode()
            world.addChild(m)
            let at = b.position + CGPoint(angle: rnd(0, 2 * .pi), length: rnd(0, 60))
            m.run(.sequence([.wait(forDuration: 0.15 * Double(i)), .run { [weak self] in
                self?.burst(at: at, color: b.color, count: 20, speed: 300)
            }, .removeFromParent()]))
        }
        Meta.shared.data.bestDepth = max(Meta.shared.data.bestDepth, runData.depth + 1)
    }
}
