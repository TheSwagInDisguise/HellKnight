import SpriteKit
import UIKit

/// A breakable urn: smash it for gold.
final class Breakable: SKNode {
    let radius: CGFloat = 16
    var broken = false
}

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
        breakables.removeAll()
        spikes.removeAll()
        boss = nil
        waves = []
        pendingSpawns = 0
        combatStarted = false
        roomCleared = false
        doorsOpen = false
        spikeClock = 0

        let pal = Palette.of(runData.depth)
        backgroundColor = pal.bg
        let type = runData.roomType
        let template: [String]
        switch type {
        case .combat: template = Layouts.combat.randomElement() ?? Layouts.combat[0]
        case .boss: template = Layouts.boss.randomElement() ?? Layouts.boss[0]
        case .shop: template = Layouts.shop
        case .rest: template = Layouts.rest
        case .altar: template = Layouts.altar
        }
        room = Room(template: template, type: type, mirror: chance(0.5))
        resetLights()
        drawRoom(pal)

        let p = Player(weapon: runData.weapon)
        p.dashCharges = runData.maxDash
        p.castCharges = runData.maxCast
        p.position = room.startPoint
        p.zPosition = depthZ(p.position)
        world.addChild(p)
        player = p
        camBase = clampCam(isoProject(p.position))
        cam.position = camBase
        let ghost = SKSpriteNode(texture: Tex.knight(), size: Player.bodySize)
        ghost.anchorPoint = Player.bodyAnchor
        ghost.color = Ink.bone
        ghost.colorBlendFactor = 1
        ghost.alpha = 0.45
        ghost.isHidden = true
        topLayer.addChild(ghost)
        playerGhost = ghost
        room.computeFlow(to: p.position)

        makeDoors(pal)
        addProps(pal)
        addFog()

        if runData.hasRelic(.moss) && !(runData.room == 0 && runData.depth == 0) {
            healPlayer(runData.maxHp * 0.12)
        }

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
            if runData.isEliteRoom {
                hud.banner("Elite Chamber", "Survive to claim a Relic", color: Reward.elite.color)
            } else if runData.room == 0 {
                hud.banner(pal.name, "Depth \(runData.depth + 1) of \(RunState.finalDepth + 1)", color: pal.accent.scaled(1.2))
            }
        case .shop:
            makeShop()
            roomCleared = true
            openDoors()
            if !runData.scarcity { healPlayer(runData.maxHp * 0.2) }
            hud.banner("The Ash Merchant", "Walk over an item to buy it", color: Ink.gold)
        case .rest:
            roomCleared = true
            openDoors()
            spawnFeaturePickup(.rest, mark: "F")
            hud.banner("Rest Shrine", "Drink from the fountain to heal", color: Reward.rest.color)
        case .altar:
            roomCleared = true
            spawnFeaturePickup(.altar, mark: "A")
            hud.banner("Cursed Altar", "Every gift has a price", color: Reward.altar.color)
        case .boss:
            if shot != nil {
                combatStarted = true
                finishSpawn(.boss, at: CGPoint(x: room.bounds.midX, y: room.bounds.midY + 150))
                break
            }
            let name = Boss.names[min(runData.depth, 2)]
            hud.banner(name, "Guardian of the \(pal.name)", color: UIColor(hex: 0xff5030))
            let m = SKNode()
            world.addChild(m)
            m.run(.sequence([.wait(forDuration: 1.8), .run { [weak self] in
                guard let self = self else { return }
                self.combatStarted = true
                self.spawnEnemy(.boss, at: CGPoint(x: self.room.bounds.midX, y: self.room.bounds.midY + 150))
            }]))
        }
        let label: String
        switch type {
        case .boss: label = "Guardian"
        case .shop: label = "Merchant"
        case .rest: label = "Rest Shrine"
        case .altar: label = "Cursed Altar"
        case .combat: label = runData.isEliteRoom ? "Elite Chamber" : "Chamber \(runData.room + 1)"
        }
        setKerned(hud.roomLabel, "\(pal.name) · \(label)".uppercased(), kern: 2.5)
    }

    private func block(_ r: CGRect, _ col: UIColor, _ z: CGFloat) {
        let sp = SKSpriteNode(color: col, size: r.size)
        sp.anchorPoint = .zero
        sp.position = r.origin
        sp.zPosition = z
        world.addChild(sp)
    }

    private func cellHash(_ c: Int, _ r: Int) -> Int {
        abs((c * 73856093) ^ (r * 19349663) ^ (runData.room * 83492791)) % 1000
    }

    func drawRoom(_ pal: Palette) {
        let cs = Room.cs
        let d = runData.depth

        for r in 0..<room.rows {
            for c in 0..<room.cols {
                let cell = room.cell(c, r)
                if cell == .void { continue }
                let rect = room.cellRect(c, r)

                // Floor (quarter of a 128 tile so slabs stay large and consistent)
                if cell != .pit {
                    let h = cellHash(c / 2, r / 2)
                    let v = h < 500 ? 0 : (h < 700 ? 1 : (h < 900 ? 3 : 2))
                    let full = Tex.floor(d, v)
                    let q = SKTexture(rect: CGRect(x: CGFloat(c % 2) * 0.5, y: CGFloat(r % 2) * 0.5, width: 0.5, height: 0.5), in: full)
                    let t = SKSpriteNode(texture: q, size: CGSize(width: cs, height: cs))
                    t.anchorPoint = .zero
                    t.position = rect.origin
                    t.zPosition = 0
                    world.addChild(t)
                }

                switch cell {
                case .pit:
                    let t = SKSpriteNode(texture: Tex.pit(d), size: CGSize(width: cs, height: cs))
                    t.anchorPoint = .zero
                    t.position = rect.origin
                    t.zPosition = 0
                    world.addChild(t)
                    // Far inner walls of the shaft
                    if room.cell(c, r + 1) != .pit {
                        let wsp = SKSpriteNode(texture: Tex.pitWall(d), size: CGSize(width: cs, height: 26))
                        wsp.anchorPoint = CGPoint(x: 0, y: 1)
                        wsp.position = CGPoint(x: rect.minX, y: rect.maxY)
                        wsp.zPosition = 0.2
                        world.addChild(wsp)
                    }
                    if room.cell(c + 1, r) != .pit {
                        let wsp = SKSpriteNode(texture: Tex.pitWall(d), size: CGSize(width: cs, height: 26))
                        wsp.anchorPoint = CGPoint(x: 0, y: 1)
                        wsp.zRotation = -.pi / 2
                        wsp.position = CGPoint(x: rect.maxX, y: rect.minY)
                        wsp.zPosition = 0.2
                        world.addChild(wsp)
                    }
                    // Lip on the near edges
                    if room.cell(c, r - 1) != .pit { block(CGRect(x: rect.minX, y: rect.minY - 1, width: cs, height: 3), pal.line.withAlphaComponent(0.35), 0.25) }
                    if room.cell(c - 1, r) != .pit { block(CGRect(x: rect.minX - 1, y: rect.minY, width: 3, height: cs), pal.line.withAlphaComponent(0.35), 0.25) }
                case .lava:
                    let t = SKSpriteNode(texture: Tex.lava(d, cellHash(c, r) % 3), size: CGSize(width: cs, height: cs))
                    t.anchorPoint = .zero
                    t.position = rect.origin
                    t.zPosition = 0.3
                    t.run(.repeatForever(.sequence([
                        .fadeAlpha(to: 0.8, duration: TimeInterval(rnd(0.6, 1.0))),
                        .fadeAlpha(to: 1, duration: TimeInterval(rnd(0.6, 1.0))),
                    ])))
                    world.addChild(t)
                    if cellHash(c, r) % 2 == 0 {
                        addLight(at: CGPoint(x: rect.midX, y: rect.midY), height: 0, radius: 150, color: pal.accent, alpha: 0.6, flicker: true)
                    }
                    if cellHash(c, r) % 4 == 0 {
                        let em = makeEmbers(area: CGSize(width: 50, height: 50), color: pal.ember, rate: 3)
                        em.position = CGPoint(x: rect.midX, y: rect.midY)
                        em.zPosition = 46
                        world.addChild(em)
                    }
                case .spikes:
                    let t = SKSpriteNode(texture: Tex.spikePlate(d), size: CGSize(width: cs, height: cs))
                    t.anchorPoint = .zero
                    t.position = rect.origin
                    t.zPosition = 0.3
                    world.addChild(t)
                    let n = SKNode()
                    n.position = CGPoint(x: rect.midX, y: rect.midY)
                    n.zPosition = depthZ(n.position)
                    let up = Billboard()
                    let sp = SKSpriteNode(texture: Tex.spikesUp(), size: CGSize(width: 70, height: 42))
                    sp.anchorPoint = CGPoint(x: 0.5, y: 0.15)
                    up.addChild(sp)
                    n.addChild(up)
                    n.isHidden = true
                    world.addChild(n)
                    spikes.append(SpikeTrap(pos: n.position, plate: t, spikes: n))
                case .block:
                    let n = SKNode()
                    n.position = CGPoint(x: rect.midX, y: rect.midY)
                    n.zPosition = depthZ(n.position)
                    let up = Billboard()
                    let w = 64 * isoK * 2, dh = 64 * isoK
                    let size = CGSize(width: w + 2, height: Tex.blockH + dh + 2)
                    let sp = SKSpriteNode(texture: Tex.block(d), size: size)
                    sp.anchorPoint = CGPoint(x: 0.5, y: (dh / 2 + 1) / size.height)
                    up.addChild(sp)
                    n.addChild(up)
                    world.addChild(n)
                default:
                    break
                }

                // Front ledges where the floor ends in the void
                let ledge: CGFloat = 34
                if room.cell(c, r - 1) == .void {
                    block(CGRect(x: rect.minX, y: rect.minY - ledge, width: cs, height: ledge), pal.stoneDark, 0.5)
                    block(CGRect(x: rect.minX, y: rect.minY - 3, width: cs, height: 3), Ink.black, 0.6)
                    block(CGRect(x: rect.minX, y: rect.minY - ledge - 2, width: cs, height: 2), pal.line.withAlphaComponent(0.25), 0.6)
                    block(CGRect(x: rect.minX, y: rect.minY - ledge, width: 2, height: ledge), Ink.black.withAlphaComponent(0.6), 0.55)
                }
                if room.cell(c - 1, r) == .void {
                    block(CGRect(x: rect.minX - ledge, y: rect.minY, width: ledge, height: cs), pal.stoneDark, 0.5)
                    block(CGRect(x: rect.minX - 3, y: rect.minY, width: 3, height: cs), Ink.black, 0.6)
                    block(CGRect(x: rect.minX - ledge - 2, y: rect.minY, width: 2, height: cs), pal.line.withAlphaComponent(0.25), 0.6)
                    block(CGRect(x: rect.minX - ledge, y: rect.minY, width: ledge, height: 2), Ink.black.withAlphaComponent(0.6), 0.55)
                }
                // Back wall shadows
                if room.cell(c, r + 1) == .void {
                    block(CGRect(x: rect.minX, y: rect.maxY - 40, width: cs, height: 40), Ink.black.withAlphaComponent(0.3), 1.1)
                }
                if room.cell(c + 1, r) == .void {
                    block(CGRect(x: rect.maxX - 40, y: rect.minY, width: 40, height: cs), Ink.black.withAlphaComponent(0.4), 1.1)
                }
            }
        }

        // Drifting embers / spores / motes
        let b = room.bounds
        let em = makeEmbers(area: CGSize(width: b.width, height: b.height), color: pal.ember, rate: 8)
        em.position = CGPoint(x: b.midX, y: b.midY)
        em.zPosition = 45
        em.advanceSimulationTime(5)
        world.addChild(em)
    }

    /// Places an upright wall segment whose base runs along a ground edge of length `len`.
    private func addWallSegment(at mid: CGPoint, texture: SKTexture, len: CGFloat) {
        let n = SKNode()
        n.position = mid
        n.zPosition = 2.8
        let up = Billboard()
        let rise = len * isoK * 0.5
        let tsize = CGSize(width: len * isoK + 1, height: Tex.wallH + rise)
        let sp = SKSpriteNode(texture: texture, size: tsize)
        sp.anchorPoint = CGPoint(x: 0.5, y: (rise / 2) / tsize.height)
        up.addChild(sp)
        n.addChild(up)
        world.addChild(n)
    }

    func addTorch(at p: CGPoint, color: UIColor) {
        let n = SKNode()
        n.position = p
        n.zPosition = 2.95
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
        let f = SKSpriteNode(texture: Tex.flame(), size: CGSize(width: 14, height: 22))
        f.blendMode = .add
        f.position = CGPoint(x: 0, y: 100)
        f.zPosition = 1
        up.addChild(f)
        f.run(.repeatForever(.sequence([.scaleY(to: 1.3, duration: 0.12), .scaleY(to: 0.85, duration: 0.15)])))
        world.addChild(n)
        addLight(at: p, height: 100, radius: 340, color: color.scaled(1.1), alpha: 0.85, flicker: true)
    }

    // MARK: - Doors & walls

    func makeDoors(_ pal: Palette) {
        let d = runData.depth
        var rewards: [Reward] = []
        var labels: [String] = []
        let type = runData.roomType
        let slots = room.doorSlots
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
            let k = slots.count >= 3 && chance(0.5) ? 3 : 2
            rewards = rollDoorRewards(min(k, max(1, slots.count)))
            labels = rewards.map { $0.title }
        }

        var chosen: [Int] = []
        if rewards.count == 1 {
            chosen = [slots[slots.count / 2]]
        } else if rewards.count == 2 {
            chosen = [slots.first ?? 0, slots.last ?? 0]
        } else if rewards.count >= 3 {
            chosen = Array(slots.prefix(3))
        }
        let topRow = room.rows - 1
        var doorCells = Set<Int>()
        for (i, r) in rewards.enumerated() where i < chosen.count {
            let c = chosen[i]
            doorCells.insert(c)
            doorCells.insert(c + 1)
            let door = Door(reward: r, text: labels[i], depth: d)
            door.position = CGPoint(x: room.cellRect(c, topRow).maxX, y: room.bounds.maxY)
            door.zPosition = 2.9
            world.addChild(door)
            doors.append(door)
        }

        // Walls follow the room's outline: a back-left face wherever a cell has void above it,
        // and a back-right face wherever it has void to its right.
        var torchCount = 0
        for r in 0..<room.rows {
            for c in 0..<room.cols where room.cell(c, r) != .void {
                let rect = room.cellRect(c, r)
                if room.cell(c, r + 1) == .void && !(r == topRow && doorCells.contains(c)) {
                    let h = cellHash(c, r) % 6
                    let v = h == 0 ? 1 : (h == 1 ? 3 : (h == 2 ? 2 : 0))
                    addWallSegment(at: CGPoint(x: rect.midX, y: rect.maxY), texture: Tex.wallSeg(d, side: 0, v, len: Room.cs), len: Room.cs)
                    if c % 3 == 1 && v == 0 {
                        addTorch(at: CGPoint(x: rect.midX, y: rect.maxY), color: pal.accent)
                        torchCount += 1
                    }
                }
                if room.cell(c + 1, r) == .void {
                    let h = cellHash(c + 7, r) % 6
                    let v = h == 0 ? 1 : (h == 1 ? 3 : (h == 2 ? 2 : 0))
                    addWallSegment(at: CGPoint(x: rect.maxX, y: rect.midY), texture: Tex.wallSeg(d, side: 1, v, len: Room.cs), len: Room.cs)
                    if r % 3 == 1 && v == 0 {
                        addTorch(at: CGPoint(x: rect.maxX, y: rect.midY), color: pal.accent)
                        torchCount += 1
                    }
                }
            }
        }
    }

    // MARK: - Props & dressing

    /// Adds an upright prop (billboard) with a ground shadow.
    @discardableResult
    private func addProp(_ tex: SKTexture, size: CGSize, at p: CGPoint, anchorY: CGFloat = 0.06) -> SKNode {
        let n = SKNode()
        n.position = p
        n.zPosition = depthZ(p)
        let sh = SKSpriteNode(texture: Tex.softShadow(), size: CGSize(width: size.width * 1.1, height: size.width * 1.1))
        sh.zPosition = -1
        sh.alpha = 0.8
        n.addChild(sh)
        let up = Billboard()
        let sp = SKSpriteNode(texture: tex, size: size)
        sp.anchorPoint = CGPoint(x: 0.5, y: anchorY)
        up.addChild(sp)
        n.addChild(up)
        world.addChild(n)
        return n
    }

    private func addFlames(at p: CGPoint, height: CGFloat, size: CGSize) {
        let fl = SKSpriteNode(texture: Tex.flame(), size: size)
        fl.blendMode = .add
        fl.position = screenPoint(p, height: height)
        fl.run(.repeatForever(.sequence([.scaleY(to: 1.2, duration: 0.11), .scaleY(to: 0.9, duration: 0.13)])))
        topLayer.addChild(fl)
    }

    func addProps(_ pal: Palette) {
        let d = runData.depth
        let warm = UIColor(hex: 0xffa050)

        // Carpet from the entrance up the middle, ending at a rune circle.
        let startC = room.cols / 2
        var r = 0
        while r < room.rows / 2 && room.cell(startC, r) == .floor && room.cell(startC - 1, r) == .floor {
            let c = SKSpriteNode(texture: Tex.carpet(), size: CGSize(width: 96, height: Room.cs))
            c.anchorPoint = CGPoint(x: 0.5, y: 0)
            c.position = CGPoint(x: room.cellRect(startC, r).minX, y: room.cellRect(startC, r).minY)
            c.zPosition = 0.8
            world.addChild(c)
            r += 1
        }
        let mid = CGPoint(x: room.bounds.midX, y: room.bounds.midY)
        if room.cellAt(mid) == .floor && room.type != .shop {
            let rune = SKSpriteNode(texture: Tex.sigil(), size: CGSize(width: 300, height: 300))
            rune.position = mid
            rune.color = pal.accent
            rune.colorBlendFactor = 1
            rune.alpha = 0.2
            rune.zPosition = 0.9
            rune.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 60)))
            world.addChild(rune)
        }

        for m in room.marks {
            let p = room.center(m.c, m.r)
            switch m.ch {
            case "P":
                let pl = Pillar(pos: p, r: 26, blocksShots: true)
                room.pillars.append(pl)
                addProp(Tex.pillar(d), size: CGSize(width: 50, height: 50 * 2.15))
            case "B":
                room.pillars.append(Pillar(pos: p, r: 20, blocksShots: false))
                addProp(Tex.brazier(), size: CGSize(width: 56, height: 72), at: p)
                addFlames(at: p, height: 78, size: CGSize(width: 36, height: 54))
                addLight(at: p, height: 80, radius: 420, color: warm, alpha: 0.9, flicker: true)
            case "u":
                let u = Breakable()
                u.position = p
                u.zPosition = depthZ(p)
                let sh = SKSpriteNode(texture: Tex.softShadow(), size: CGSize(width: 40, height: 40))
                sh.zPosition = -1
                u.addChild(sh)
                let up = Billboard()
                let sp = SKSpriteNode(texture: Tex.urn(), size: CGSize(width: 34, height: 42))
                sp.anchorPoint = CGPoint(x: 0.5, y: 0.06)
                up.addChild(sp)
                u.addChild(up)
                world.addChild(u)
                breakables.append(u)
                room.pillars.append(Pillar(pos: p, r: 14, blocksShots: false))
            case "F":
                room.pillars.append(Pillar(pos: p, r: 44, blocksShots: false))
                addProp(Tex.fountain(d), size: CGSize(width: 140, height: 130), at: p, anchorY: 0.08)
                addLight(at: p, height: 40, radius: 380, color: UIColor(hex: 0xff5060), alpha: 0.7, flicker: true)
            case "A":
                room.pillars.append(Pillar(pos: p, r: 40, blocksShots: false))
                addProp(Tex.altar(d), size: CGSize(width: 130, height: 110), at: p, anchorY: 0.06)
                addLight(at: p, height: 40, radius: 380, color: Reward.altar.color, alpha: 0.8, flicker: true)
                for k in 0..<3 {
                    addFlames(at: p, height: 0, size: CGSize(width: 8, height: 13))
                    if let fl = topLayer.children.last {
                        fl.position = screenPoint(p, height: 0) + CGPoint(x: -31 + CGFloat(k) * 31, y: 86)
                    }
                }
            case "c":
                addProp(Tex.candles(), size: CGSize(width: 50, height: 44), at: p)
                for k in 0..<3 {
                    addFlames(at: p, height: 0, size: CGSize(width: 8, height: 13))
                    if let fl = topLayer.children.last {
                        fl.position = screenPoint(p, height: 0) + CGPoint(x: -12 + CGFloat(k) * 11, y: 38 - CGFloat(k % 2) * 8)
                    }
                }
                addLight(at: p, height: 30, radius: 230, color: warm, alpha: 0.75, flicker: true)
            case "x":
                if chance(0.5) {
                    addProp(Tex.bones(), size: CGSize(width: 64, height: 37), at: p, anchorY: 0.2)
                } else {
                    addProp(Tex.rubble(d), size: CGSize(width: 60, height: 34), at: p, anchorY: 0.2)
                }
            default:
                break
            }
        }
    }

    /// Pillars are drawn as props; this overload keeps their position.
    private func addProp(_ tex: SKTexture, size: CGSize) {
        guard let last = room.pillars.last else { return }
        addProp(tex, size: size, at: last.pos)
    }

    func rollDoorRewards(_ n: Int) -> [Reward] {
        let pats = Patron.allCases.shuffled()
        var pool: [(Reward, CGFloat)] = [(.boon(pats[0]), 4), (.boon(pats[1]), 2.5), (.gold, 1.6), (.heart, 1.1),
                                          (.souls, 1.4), (.anvil, 1.1)]
        let wasSpecial = runData.roomType == .rest || runData.roomType == .altar
        if runData.room >= 1 { pool.append((.elite, 1.3)) }
        if runData.room >= 1 && !wasSpecial { pool.append((.altar, 1.0)) }
        if runData.room >= 2 && !wasSpecial { pool.append((.rest, runData.hp < runData.maxHp * 0.6 ? 1.6 : 0.8)) }
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
            if abs(p.position.x - d.position.x) < 56 && p.position.y > b.maxY - p.radius - 12 {
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

    // MARK: - Shop, shrine, altar

    func makeShop() {
        let d = runData.depth
        var items: [(Reward, Int)] = [(.heal, 40 + 10 * d)]
        var extra: [(Reward, Int)] = [
            (.boon(Patron.allCases.randomElement() ?? .pyre), 110 + 25 * d),
            (.heart, 90 + 20 * d),
            (.anvil, 120 + 20 * d),
            (.relic, 170 + 30 * d),
        ]
        extra.shuffle()
        items.append(contentsOf: extra.prefix(2))
        let c = CGPoint(x: room.bounds.midX, y: room.bounds.midY + 20)
        for (i, it) in items.enumerated() {
            let pk = Pickup(reward: it.0, price: Int((CGFloat(it.1) * runData.priceMult).rounded()), depth: d)
            pk.position = c + CGPoint(x: (CGFloat(i) - 1) * 170, y: -(CGFloat(i) - 1) * 170)
            pk.zPosition = depthZ(pk.position)
            world.addChild(pk)
            pickups.append(pk)
            pk.light = addLight(at: pk.position, height: 60, radius: 240, color: it.0.color, alpha: 0.6)
        }
    }

    /// The fountain / altar is used by walking up to it.
    func spawnFeaturePickup(_ r: Reward, mark: Character) {
        guard let m = room.marks.first(where: { $0.ch == mark }) else { return }
        let pk = Pickup(reward: r, invisible: true)
        pk.position = room.center(m.c, m.r) + CGPoint(x: -30, y: -30)
        world.addChild(pk)
        pickups.append(pk)
    }

    // MARK: - Waves & spawning

    func generateWaves() -> [[EnemyKind]] {
        let d = runData.depth
        let r = runData.room
        let elite = runData.isEliteRoom
        let count = elite ? 2 : (r <= 1 ? 2 : 3)
        let roster: [EnemyKind]
        switch d {
        case 0: roster = r < 2 ? [.imp, .imp, .archer, .wisp] : [.imp, .imp, .archer, .wisp, .brute]
        case 1: roster = [.imp, .archer, .wisp, .brute, .priest]
        default: roster = [.imp, .archer, .wisp, .brute, .priest, .priest, .brute]
        }
        var result: [[EnemyKind]] = []
        for wi in 0..<count {
            var budget = 3 + d * 2 + r / 2 + wi + (elite ? 1 : 0) + runData.hordeBonus
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
        e.maxHp *= runData.enemyHpMult
        e.dmgMult *= runData.enemyDmgMult
        e.baseSpeed *= runData.enemySpeedMult
        if let b = e as? Boss, runData.bossFury {
            e.maxHp *= 1.25
            b.enrageAt = 0.75
        }
        e.hp = e.maxHp
        if k != .boss && (runData.isEliteRoom || chance(0.04 + 0.08 * CGFloat(d) + 0.02 * CGFloat(runData.room) + runData.eliteBonus)) {
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
            spawnRoomReward(runData.isEliteRoom ? .relic : runData.nextReward)
        }
    }

    func spawnRoomReward(_ r: Reward) {
        let pk = Pickup(reward: r)
        var p = CGPoint(x: room.bounds.midX, y: room.bounds.midY)
        if room.blocked(p, 30) { p = room.randomOpenPoint(margin: 40, avoid: p, minDist: 0) }
        pk.position = p
        pk.zPosition = depthZ(p)
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
