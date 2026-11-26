import SpriteKit
import UIKit

extension GameScene {

    // MARK: - Room construction

    func buildRoom() {
        world.removeAllChildren()
        world.removeAllActions()
        topLayer.removeAllChildren()
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
            w = 128 * CGFloat(Int.random(in: 8...11))
            h = 128 * CGFloat(Int.random(in: 7...9))
        case .shop:
            w = 128 * 8
            h = 128 * 6
        case .boss:
            w = 128 * 11
            h = 128 * 10
        }
        room = Room(bounds: CGRect(x: -w / 2, y: -h / 2, width: w, height: h), type: type)
        addPillars()
        resetLights()
        drawRoom(pal)

        let p = Player(weapon: runData.weapon)
        p.dashCharges = runData.maxDash
        p.castCharges = runData.maxCast
        p.position = CGPoint(x: 0, y: room.bounds.minY + 70)
        p.zPosition = depthZ(p.position)
        world.addChild(p)
        player = p
        camBase = clampCam(isoProject(p.position))
        cam.position = camBase

        makeDoors(pal)
        addProps(pal)
        addFog()

        switch type {
        case .combat:
            if shot != nil {
                setupShotRoom()
                break
            }
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
            if shot != nil {
                combatStarted = true
                finishSpawn(.boss, at: CGPoint(x: 0, y: room.bounds.midY + 150))
                break
            }
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
        setKerned(hud.roomLabel, "\(pal.name) · \(where_)".uppercased(), kern: 2.5)
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
            let n = Int.random(in: 1...3)
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
        let sp = SKSpriteNode(color: col, size: r.size)
        sp.anchorPoint = .zero
        sp.position = r.origin
        sp.zPosition = z
        world.addChild(sp)
    }

    func drawRoom(_ pal: Palette) {
        let b = room.bounds
        let tile: CGFloat = 128

        // Floor
        var y = b.minY
        while y < b.maxY - 1 {
            var x = b.minX
            while x < b.maxX - 1 {
                let v = Int.random(in: 0..<10)
                let t = SKSpriteNode(texture: Tex.floor(runData.depth, v < 5 ? 0 : (v < 7 ? 1 : (v < 9 ? 3 : 2))),
                                     size: CGSize(width: tile, height: tile))
                t.anchorPoint = .zero
                t.position = CGPoint(x: x, y: y)
                t.zPosition = 0
                world.addChild(t)
                x += tile
            }
            y += tile
        }

        // Glowing cracks & pools of light
        for _ in 0..<Int.random(in: 4...7) {
            let g = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: rnd(160, 300), height: rnd(160, 300)))
            g.color = pal.accent
            g.colorBlendFactor = 1
            g.blendMode = .add
            g.alpha = 0.08
            g.position = CGPoint(x: rnd(b.minX + 80, b.maxX - 80), y: rnd(b.minY + 80, b.maxY - 80))
            g.zPosition = 1
            world.addChild(g)
        }

        // Front ledges (low, so they never hide the action) and outer ink rim
        let ledge: CGFloat = 40
        block(CGRect(x: b.minX - ledge, y: b.minY - ledge, width: ledge, height: b.height + ledge), pal.stoneDark, 0.5)
        block(CGRect(x: b.minX - ledge, y: b.minY - ledge, width: b.width + ledge, height: ledge), pal.stoneDark, 0.5)
        block(CGRect(x: b.minX - 4, y: b.minY - 4, width: 4, height: b.height + 4), Ink.black, 0.6)
        block(CGRect(x: b.minX - 4, y: b.minY - 4, width: b.width + 4, height: 4), Ink.black, 0.6)
        block(CGRect(x: b.minX - ledge - 3, y: b.minY - ledge - 3, width: 3, height: b.height + ledge + 3), pal.line.withAlphaComponent(0.25), 0.6)
        block(CGRect(x: b.minX - ledge - 3, y: b.minY - ledge - 3, width: b.width + ledge + 3, height: 3), pal.line.withAlphaComponent(0.25), 0.6)
        for i in stride(from: b.minX, to: b.maxX, by: 64) {
            block(CGRect(x: i, y: b.minY - ledge, width: 2, height: ledge), Ink.black.withAlphaComponent(0.6), 0.55)
        }
        for j in stride(from: b.minY, to: b.maxY, by: 64) {
            block(CGRect(x: b.minX - ledge, y: j, width: ledge, height: 2), Ink.black.withAlphaComponent(0.6), 0.55)
        }
        // Shadow cast by the back walls onto the floor
        block(CGRect(x: b.minX, y: b.maxY - 70, width: b.width, height: 70), Ink.black.withAlphaComponent(0.28), 1.1)
        block(CGRect(x: b.maxX - 70, y: b.minY, width: 70, height: b.height - 70), Ink.black.withAlphaComponent(0.4), 1.1)

        // Pillars: upright gothic columns with ground shadows
        for pl in room.pillars {
            let n = SKNode()
            n.position = pl.pos
            n.zPosition = depthZ(pl.pos)
            let sh = SKSpriteNode(texture: Tex.softShadow(), size: CGSize(width: pl.r * 3.2, height: pl.r * 3.2))
            sh.zPosition = -1
            n.addChild(sh)
            let up = Billboard()
            let col = SKSpriteNode(texture: Tex.pillar(runData.depth), size: CGSize(width: pl.r * 1.8, height: pl.r * 1.8 * 2.15))
            col.anchorPoint = CGPoint(x: 0.5, y: 0.06)
            up.addChild(col)
            n.addChild(up)
            world.addChild(n)
        }

        // Drifting embers / spores / motes
        let em = makeEmbers(area: CGSize(width: b.width, height: b.height), color: pal.ember, rate: 8)
        em.position = CGPoint(x: b.midX, y: b.midY)
        em.zPosition = 45
        em.advanceSimulationTime(5)
        world.addChild(em)
    }

    /// Places an upright wall segment whose base runs along a 128-unit ground edge.
    private func addWallSegment(at mid: CGPoint, texture: SKTexture) {
        let n = SKNode()
        n.position = mid
        n.zPosition = 2.8
        let up = Billboard()
        let tsize = CGSize(width: Tex.segW + 1, height: Tex.wallH + Tex.segRise)
        let sp = SKSpriteNode(texture: texture, size: tsize)
        sp.anchorPoint = CGPoint(x: 0.5, y: (Tex.segRise / 2) / tsize.height)
        up.addChild(sp)
        n.addChild(up)
        world.addChild(n)
    }

    func addTorch(at p: CGPoint, color: UIColor) {
        let n = SKNode()
        n.position = p
        n.zPosition = 2.95
        let pool = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: 240, height: 240))
        pool.color = color
        pool.colorBlendFactor = 1
        pool.blendMode = .add
        pool.alpha = 0.16
        pool.position = CGPoint(x: -40, y: -40)
        pool.zPosition = -1.8
        n.addChild(pool)
        let up = Billboard()
        n.addChild(up)
        let sc = SKSpriteNode(texture: Tex.sconce(), size: CGSize(width: 24, height: 30))
        sc.position = CGPoint(x: 0, y: 84)
        up.addChild(sc)
        let g = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: 120, height: 140))
        g.color = color
        g.colorBlendFactor = 1
        g.blendMode = .add
        g.alpha = 0.5
        g.position = CGPoint(x: 0, y: 100)
        up.addChild(g)
        g.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.3, duration: TimeInterval(rnd(0.1, 0.25))),
            .fadeAlpha(to: 0.6, duration: TimeInterval(rnd(0.1, 0.25))),
        ])))
        let f = SKSpriteNode(texture: Tex.spark(), size: CGSize(width: 14, height: 26))
        f.color = color.scaled(1.3)
        f.colorBlendFactor = 0.6
        f.blendMode = .add
        f.position = CGPoint(x: 0, y: 100)
        f.zPosition = 1
        up.addChild(f)
        f.run(.repeatForever(.sequence([.scaleY(to: 1.3, duration: 0.12), .scaleY(to: 0.85, duration: 0.15)])))
        world.addChild(n)
        addLight(at: p, height: 100, radius: 360, color: color.scaled(1.1), alpha: 0.85, flicker: true)
    }

    // MARK: - Doors & walls

    func makeDoors(_ pal: Palette) {
        let b = room.bounds
        let d = runData.depth
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

        // Back-left wall runs along maxY; segments are 128 ground units long.
        let segCount = Int((b.width / 128).rounded())
        var doorSegs: [Int] = []
        if rewards.count == 1 {
            doorSegs = [segCount / 2]
        } else if rewards.count >= 2 {
            doorSegs = [max(1, segCount / 4), min(segCount - 2, segCount - 1 - segCount / 4)]
        }
        for (i, r) in rewards.enumerated() {
            let si = doorSegs[i]
            let door = Door(reward: r, text: labels[i], depth: d)
            door.position = CGPoint(x: b.minX + 64 + CGFloat(si) * 128, y: b.maxY)
            door.zPosition = 2.9
            world.addChild(door)
            doors.append(door)
        }
        for si in 0..<segCount where !doorSegs.contains(si) {
            let v = si % 3 == 1 ? 1 : (si % 3 == 2 ? 3 : (si % 4 == 0 ? 2 : 0))
            addWallSegment(at: CGPoint(x: b.minX + 64 + CGFloat(si) * 128, y: b.maxY), texture: Tex.wallSeg(d, side: 0, v))
            if si % 2 == 0 && si > 0 {
                addTorch(at: CGPoint(x: b.minX + CGFloat(si) * 128, y: b.maxY), color: pal.accent)
            }
        }
        // Back-right wall runs along maxX.
        let segCountR = Int((b.height / 128).rounded())
        for sj in 0..<segCountR {
            let v = sj % 3 == 1 ? 1 : (sj % 3 == 0 ? 3 : (sj % 4 == 2 ? 2 : 0))
            addWallSegment(at: CGPoint(x: b.maxX, y: b.minY + 64 + CGFloat(sj) * 128), texture: Tex.wallSeg(d, side: 1, v))
            if sj % 2 == 1 {
                addTorch(at: CGPoint(x: b.maxX, y: b.minY + CGFloat(sj) * 128), color: pal.accent)
            }
        }
    }

    // MARK: - Props & dressing

    /// Adds an upright prop (billboard) with a ground shadow. `collide` > 0 blocks movement.
    private func addProp(_ tex: SKTexture, size: CGSize, at p: CGPoint, anchorY: CGFloat = 0.06, collide: CGFloat = 0) {
        let n = SKNode()
        n.position = p
        n.zPosition = depthZ(p)
        let sh = SKSpriteNode(texture: Tex.softShadow(), size: CGSize(width: size.width * 1.2, height: size.width * 1.2))
        sh.zPosition = -1
        sh.alpha = 0.8
        n.addChild(sh)
        let up = Billboard()
        let sp = SKSpriteNode(texture: tex, size: size)
        sp.anchorPoint = CGPoint(x: 0.5, y: anchorY)
        up.addChild(sp)
        n.addChild(up)
        world.addChild(n)
        if collide > 0 { room.pillars.append(Pillar(pos: p, r: collide)) }
    }

    private func freeSpot(margin: CGFloat, avoidCenter: Bool = true) -> CGPoint? {
        let b = room.bounds
        for _ in 0..<30 {
            let p = CGPoint(x: rnd(b.minX + margin, b.maxX - margin), y: rnd(b.minY + margin, b.maxY - margin))
            if room.blocked(p, 40) { continue }
            if avoidCenter && abs(p.x) < 120 { continue }
            if p.distance(to: CGPoint(x: 0, y: b.minY + 70)) < 200 { continue }
            return p
        }
        return nil
    }

    func addProps(_ pal: Palette) {
        let b = room.bounds
        let d = runData.depth
        let warm = UIColor(hex: 0xffa050)

        // Carpet runner from the entrance to the centre, ending in a rune circle.
        var y = b.minY
        while y < b.midY - 40 {
            let c = SKSpriteNode(texture: Tex.carpet(), size: CGSize(width: 96, height: 128))
            c.anchorPoint = CGPoint(x: 0.5, y: 0)
            c.position = CGPoint(x: 0, y: y)
            c.zPosition = 0.8
            world.addChild(c)
            y += 128
        }
        let rune = SKSpriteNode(texture: Tex.sigil(), size: CGSize(width: 330, height: 330))
        rune.position = CGPoint(x: 0, y: b.midY)
        rune.color = pal.accent
        rune.colorBlendFactor = 1
        rune.alpha = 0.22
        rune.zPosition = 0.9
        rune.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 60)))
        world.addChild(rune)
        addLight(at: CGPoint(x: 0, y: b.midY), height: 0, radius: 240, color: pal.accent, alpha: 0.25)

        // Braziers flanking the room near the back walls.
        let brazierSpots = [CGPoint(x: b.maxX - 110, y: b.maxY - 110), CGPoint(x: b.minX + 120, y: b.maxY - 110),
                            CGPoint(x: b.maxX - 110, y: b.minY + 140)]
        for p in brazierSpots.prefix(room.type == .boss ? 3 : 2) {
            if room.blocked(p, 30) { continue }
            addProp(Tex.brazier(), size: CGSize(width: 56, height: 72), at: p, collide: 22)
            let fl = SKSpriteNode(texture: Tex.flame(), size: CGSize(width: 36, height: 54))
            fl.blendMode = .add
            fl.position = screenPoint(p, height: 78)
            fl.zPosition = depthZ(p) + 0.01
            fl.run(.repeatForever(.sequence([.scaleY(to: 1.2, duration: 0.11), .scaleY(to: 0.9, duration: 0.13)])))
            // Flames live in screen space so they stay upright.
            topLayer.addChild(fl)
            fl.zPosition = 0
            addLight(at: p, height: 80, radius: 420, color: warm, alpha: 0.9, flicker: true)
        }

        // Candle clusters along the back walls.
        for _ in 0..<Int.random(in: 2...4) {
            let alongTop = chance(0.5)
            let p = alongTop ? CGPoint(x: rnd(b.minX + 80, b.maxX - 80), y: b.maxY - 34)
                             : CGPoint(x: b.maxX - 34, y: rnd(b.minY + 80, b.maxY - 80))
            if doors.contains(where: { abs($0.position.x - p.x) < 90 && alongTop }) { continue }
            addProp(Tex.candles(), size: CGSize(width: 50, height: 44), at: p)
            for k in 0..<3 {
                let fl = SKSpriteNode(texture: Tex.flame(), size: CGSize(width: 8, height: 13))
                fl.blendMode = .add
                fl.position = screenPoint(p, height: 0) + CGPoint(x: -12 + CGFloat(k) * 11, y: 38 - CGFloat(k % 2) * 8)
                fl.run(.repeatForever(.sequence([.scaleY(to: 1.25, duration: 0.09), .scaleY(to: 0.85, duration: 0.12)])))
                topLayer.addChild(fl)
            }
            addLight(at: p, height: 30, radius: 230, color: warm, alpha: 0.75, flicker: true)
        }

        guard room.type != .shop else { return }

        // Lava grates set into the floor.
        for _ in 0..<(room.type == .boss ? 2 : Int.random(in: 0...2)) {
            guard let p = freeSpot(margin: 160) else { break }
            let g = SKSpriteNode(texture: Tex.grate(d), size: CGSize(width: 96, height: 96))
            g.position = p
            g.zPosition = 0.85
            world.addChild(g)
            addLight(at: p, height: 0, radius: 260, color: pal.accent, alpha: 0.65, flicker: true)
            let em = makeEmbers(area: CGSize(width: 70, height: 70), color: pal.ember, rate: 6)
            em.position = p
            em.zPosition = 46
            world.addChild(em)
        }

        // Scattered bones and rubble.
        for i in 0..<Int.random(in: 3...6) {
            guard let p = freeSpot(margin: 60, avoidCenter: false) else { break }
            if i % 2 == 0 {
                addProp(Tex.bones(), size: CGSize(width: 64, height: 37), at: p, anchorY: 0.2)
            } else {
                addProp(Tex.rubble(d), size: CGSize(width: 60, height: 34), at: p, anchorY: 0.2)
            }
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
        for d in doors {
            d.setOpen()
            addLight(at: d.position, height: 60, radius: 260, color: d.reward.color, alpha: 0.75, flicker: true)
        }
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
            let pk = Pickup(reward: it.0, price: it.1, depth: d)
            pk.position = CGPoint(x: (CGFloat(i) - 1) * 200 + 40, y: b.midY - (CGFloat(i) - 1) * 200 + 40)
            pk.zPosition = 5
            world.addChild(pk)
            pickups.append(pk)
            pk.light = addLight(at: pk.position, height: 60, radius: 240, color: it.0.color, alpha: 0.6)
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
        let big = k == .boss
        let portal = SKSpriteNode(texture: Tex.sigil(), size: CGSize(width: big ? 280 : 120, height: big ? 280 : 120))
        portal.color = Ink.blood
        portal.colorBlendFactor = 1
        portal.blendMode = .add
        portal.position = pos
        portal.zPosition = 3
        portal.setScale(0.2)
        portal.alpha = 0.95
        world.addChild(portal)
        portal.run(.rotate(byAngle: .pi, duration: 1.2))
        let ring = SKSpriteNode(texture: Tex.glow(), size: portal.size)
        ring.color = Ink.blood
        ring.colorBlendFactor = 1
        ring.blendMode = .add
        ring.alpha = 0.5
        ring.zPosition = -0.1
        portal.addChild(ring)
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
        e.zPosition = depthZ(e.position)
        e.alpha = 0
        e.run(.fadeIn(withDuration: 0.15))
        world.addChild(e)
        enemies.append(e)
        if k == .wisp {
            e.light = makeLight(radius: 200, color: e.deathColor, alpha: 0.75)
        } else if let bs = e as? Boss {
            e.light = makeLight(radius: 420, color: bs.color, alpha: 0.8)
        }
        flashLight(at: pos, radius: 260, color: Ink.blood, alpha: 0.8, duration: 0.5)
        burst(at: pos, color: Ink.blood, count: 10, speed: 140)
        splat(at: pos, size: k == .boss ? 200 : 70, color: Ink.black, alpha: 0.7, fade: 6)
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
        pk.light = addLight(at: pk.position, height: 50, radius: 300, color: r.color, alpha: 0.8, flicker: true)
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
