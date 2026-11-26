import SpriteKit
import UIKit

extension GameScene {

    // MARK: - Reward collection

    func collect(_ r: Reward, completion: @escaping () -> Void) {
        let at = player.position
        switch r {
        case .boon(let pat):
            sfx(.boon)
            showBoonChoice(pat, completion: completion)
        case .anvil:
            sfx(.boon)
            showAnvilChoice(completion: completion)
        case .heart:
            runData.maxHp += 25
            runData.hp += 25
            floatText("+25 Max Health", at: at, color: UIColor(hex: 0xff5060), size: 18)
            completion()
        case .gold:
            let g = Int(rnd(55, 85)) + 25 * runData.depth
            runData.gold += g
            floatText("+\(g) Gold", at: at, color: Ink.gold, size: 18)
            completion()
        case .souls:
            let s = 12 + 8 * runData.depth
            runData.souls += s
            floatText("+\(s) Soul Shards", at: at, color: UIColor(hex: 0xb79cff), size: 18)
            completion()
        case .heal:
            healPlayer(runData.maxHp * 0.35)
            completion()
        case .shop, .boss:
            completion()
        }
    }

    func showBoonChoice(_ pat: Patron, completion: @escaping () -> Void) {
        var kinds: [Boon.Kind] = Slot.allCases.map { Boon.Kind.slot($0, pat) }
        for pa in Passive.allCases where pa.patron == pat {
            kinds.append(.passive(pa))
        }
        kinds.shuffle()
        var cards: [ChoiceCard] = []
        for k in kinds.prefix(3) {
            var boon = Boon(kind: k, rarity: Rarity.roll(luck: runData.luck))
            var sub = boon.slotName
            switch k {
            case .slot(let s, _):
                if let cur = runData.slots[s] {
                    if cur.patron == pat {
                        boon.rarity = Rarity(rawValue: min(3, max(boon.rarity.rawValue, cur.rarity.rawValue + 1))) ?? .legendary
                        sub += " · Upgrade"
                    } else {
                        sub += " · Replaces \(cur.title)"
                    }
                }
            case .passive(let pa):
                if let cur = runData.passives[pa] {
                    boon.rarity = Rarity(rawValue: min(3, max(boon.rarity.rawValue, cur.rawValue + 1))) ?? .legendary
                    sub += " · Upgrade"
                }
            }
            let b = boon
            cards.append(ChoiceCard(tag: b.rarity.name.uppercased(), title: b.title, sub: sub, desc: b.desc,
                                    color: b.rarity.color, accent: pat.color, icon: .boon(pat)) { [weak self] in
                self?.applyBoon(b)
                completion()
            })
        }
        showChoices(title: pat.name, subtitle: "offers you a boon. Choose one.", accent: pat.color, cards: cards)
    }

    func applyBoon(_ b: Boon) {
        switch b.kind {
        case .slot(let s, _):
            runData.slots[s] = b
        case .passive(let pa):
            runData.passives[pa] = b.rarity
            if pa == .vitality {
                let add = 20 * b.rarity.mult
                runData.maxHp += add
                runData.hp += add
            }
        }
        if let p = player {
            burst(at: p.position, color: b.patron.color, count: 24, speed: 220)
            shockwave(at: p.position, radius: 90, color: b.patron.color)
        }
    }

    func showAnvilChoice(completion: @escaping () -> Void) {
        let opts = AnvilOption.all.filter { !($0.once && runData.anvilTaken.contains($0.id)) }.shuffled().prefix(3)
        var cards: [ChoiceCard] = []
        for o in opts {
            cards.append(ChoiceCard(tag: "HELLFORGE", title: o.title, sub: "Weapon Tempering", desc: o.desc,
                                    color: UIColor(hex: 0xffb060), accent: UIColor(hex: 0xff8a40), icon: .anvil) { [weak self] in
                guard let self = self else { return }
                o.apply(self.runData)
                self.runData.anvilTaken.insert(o.id)
                if let p = self.player {
                    self.burst(at: p.position, color: UIColor(hex: 0xffa040), count: 24, speed: 220)
                }
                completion()
            })
        }
        showChoices(title: "Hellforge Anvil", subtitle: "Temper your \(runData.weapon.name)", accent: UIColor(hex: 0xffa040), cards: cards)
    }

    // MARK: - Generic overlays

    private func makeOverlay() -> SKNode {
        let o = SKNode()
        o.zPosition = 500
        let dim = SKSpriteNode(color: UIColor(white: 0, alpha: 0.9), size: CGSize(width: size.width + 60, height: size.height + 60))
        o.addChild(dim)
        let v = SKSpriteNode(texture: Tex.inkVignette(), size: CGSize(width: size.width * 1.05, height: size.height * 1.1))
        v.zPosition = 0.1
        o.addChild(v)
        return o
    }

    private func addHeading(_ o: SKNode, _ title: String, _ subtitle: String, color: UIColor, y: CGFloat) {
        let fs = min(28, size.width * 0.036)
        let sh = makeLabel(title.uppercased(), size: fs, color: Ink.black, font: Font.title, kern: 4)
        sh.position = CGPoint(x: 2, y: y - 2)
        sh.zPosition = 1
        o.addChild(sh)
        let t = makeLabel(title.uppercased(), size: fs, color: color, font: Font.title, kern: 4)
        t.position = CGPoint(x: 0, y: y)
        t.zPosition = 1.1
        o.addChild(t)
        let d = SKSpriteNode(texture: Tex.divider(320), size: CGSize(width: 320, height: 6))
        d.position = CGPoint(x: 0, y: y - 20)
        d.zPosition = 1
        o.addChild(d)
        if !subtitle.isEmpty {
            let st = makeLabel(subtitle, size: 14, color: Ink.bone.withAlphaComponent(0.85), font: Font.medium)
            st.position = CGPoint(x: 0, y: y - 38)
            st.zPosition = 1
            o.addChild(st)
        }
    }

    func showChoices(title: String, subtitle: String, accent: UIColor, cards: [ChoiceCard]) {
        state = .choosing
        controls.reset()
        let W = size.width
        let H = size.height
        let o = makeOverlay()
        addHeading(o, title, subtitle, color: accent, y: H / 2 - 28)

        let n = CGFloat(max(cards.count, 1))
        let gap: CGFloat = 16
        let cw = min(220, (W - 60 - (n - 1) * gap) / n)
        let ch = min(250, H - 110)
        let small = cw < 190
        for (i, c) in cards.enumerated() {
            let x = (CGFloat(i) - (n - 1) / 2) * (cw + gap)
            let b = Button("", size: CGSize(width: cw, height: ch), texture: Tex.card(cw, ch, accent: c.color, glow: c.accent)) { [weak self] in
                self?.closeOverlay()
                c.action()
            }
            b.priority = 10
            b.position = CGPoint(x: x, y: -40)
            b.zPosition = 2
            let top = ch / 2
            if let r = c.icon {
                let s = SKSpriteNode(texture: Tex.icon(r), size: CGSize(width: 40, height: 40))
                s.position = CGPoint(x: 0, y: top - 34)
                s.zPosition = 2
                b.addChild(s)
            }
            let tag = makeLabel(c.tag, size: 9, color: c.color, font: Font.bold, kern: 2.5)
            tag.position = CGPoint(x: 0, y: top - 68)
            tag.zPosition = 2
            b.addChild(tag)
            let tl = makeLabel(c.title, size: small ? 15 : 17, color: .white, font: Font.title)
            tl.numberOfLines = 2
            tl.preferredMaxLayoutWidth = cw - 20
            tl.position = CGPoint(x: 0, y: top - 88)
            tl.zPosition = 2
            b.addChild(tl)
            let sl = makeLabel(c.sub, size: 11, color: c.accent, font: Font.bold)
            sl.numberOfLines = 2
            sl.preferredMaxLayoutWidth = cw - 22
            sl.verticalAlignmentMode = .top
            sl.position = CGPoint(x: 0, y: top - 120)
            sl.zPosition = 2
            b.addChild(sl)
            let dl = makeLabel(c.desc, size: small ? 12 : 13.5, color: Ink.bone.withAlphaComponent(0.92), font: Font.medium)
            dl.numberOfLines = 0
            dl.lineBreakMode = .byWordWrapping
            dl.preferredMaxLayoutWidth = cw - 26
            dl.verticalAlignmentMode = .top
            dl.position = CGPoint(x: 0, y: top - 146)
            dl.zPosition = 2
            b.addChild(dl)
            o.addChild(b)
            b.alpha = 0
            b.setScale(0.85)
            b.run(.sequence([
                .wait(forDuration: 0.1 * Double(i)),
                .group([.fadeIn(withDuration: 0.2), .scale(to: 1, duration: 0.2)]),
            ]))
        }
        hud.addChild(o)
        overlay = o
        hud.pauseButton.isHidden = true
    }

    func closeOverlay() {
        overlay?.removeFromParent()
        overlay = nil
        hud.pauseButton.isHidden = false
        if state == .choosing || state == .paused { state = .playing }
    }

    func showPause() {
        guard state == .playing else { return }
        state = .paused
        controls.reset()
        let W = size.width
        let H = size.height
        let o = makeOverlay()
        addHeading(o, "PAUSED", "", color: Ink.bone, y: H / 2 - 30)

        let pw = min(560, W - 60)
        let ph = H - 150
        let panel = SKSpriteNode(texture: Tex.panel(pw, ph), size: CGSize(width: pw + 8, height: ph + 8))
        panel.position = CGPoint(x: 0, y: -8)
        panel.zPosition = 1
        o.addChild(panel)

        var lines: [String] = []
        lines.append("\(runData.weapon.name)  ·  Damage x\(String(format: "%.2f", runData.damageMult))  ·  Souls \(runData.souls)  ·  Revives \(runData.revives)")
        lines.append("")
        for s in Slot.allCases {
            if let b = runData.slots[s] { lines.append("\(s.name): \(b.title) (\(b.rarity.name), \(b.patron.short))") }
        }
        for pa in Passive.allCases {
            if let r = runData.passives[pa] { lines.append("\(pa.name) (\(r.name), \(pa.patron.short))") }
        }
        if runData.slots.isEmpty && runData.passives.isEmpty { lines.append("No boons yet. Clear chambers to earn them.") }
        let list = makeLabel(lines.joined(separator: "\n"), size: 14, color: Ink.bone, font: Font.medium)
        list.numberOfLines = 0
        list.preferredMaxLayoutWidth = pw - 40
        list.verticalAlignmentMode = .top
        list.position = CGPoint(x: 0, y: ph / 2 - 26)
        list.zPosition = 2
        panel.addChild(list)

        let resume = Button("Resume", size: CGSize(width: 170, height: 44), fontSize: 18) { [weak self] in
            self?.closeOverlay()
        }
        resume.priority = 10
        resume.zPosition = 3
        resume.position = CGPoint(x: -100, y: -H / 2 + 40)
        o.addChild(resume)
        let quit = Button("Abandon Run", size: CGSize(width: 170, height: 44), accent: Ink.blood, fontSize: 15) { [weak self] in
            guard let self = self else { return }
            self.recordRunEnd(won: false)
            self.goToSanctum()
        }
        quit.priority = 10
        quit.zPosition = 3
        quit.position = CGPoint(x: 100, y: -H / 2 + 40)
        o.addChild(quit)
        hud.addChild(o)
        overlay = o
        hud.pauseButton.isHidden = true
    }

    // MARK: - Death & victory

    func playerDied() {
        state = .dead
        controls.reset()
        sfx(.death)
        sfx(.playerHurt)
        if let p = player {
            burst(at: p.position, color: Ink.blood, count: 40, speed: 300)
            splat(at: p.position, size: 140, color: Ink.blood, alpha: 0.9, fade: 30)
            p.run(.group([.fadeOut(withDuration: 0.9), .scale(to: 0.5, duration: 0.9)]))
        }
        recordRunEnd(won: false)
        hud.run(.sequence([.wait(forDuration: 1.4), .run { [weak self] in self?.showEndScreen(won: false) }]))
    }

    func victory() {
        guard state == .playing || state == .choosing else { return }
        state = .victory
        controls.reset()
        runData.souls += 100
        recordRunEnd(won: true)
        showEndScreen(won: true)
    }

    func showEndScreen(won: Bool) {
        overlay?.removeFromParent()
        let W = size.width
        let H = size.height
        let o = makeOverlay()
        let pw = min(560, W - 60)
        let ph = min(300, H - 60)
        let panel = SKSpriteNode(texture: Tex.panel(pw, ph), size: CGSize(width: pw + 8, height: ph + 8))
        panel.zPosition = 1
        o.addChild(panel)
        let title = won ? "YOU ESCAPED THE ABYSS" : "SLAIN"
        let tcol = won ? Ink.gold : Ink.blood.scaled(1.3)
        let t = makeLabel(title, size: won ? 26 : 42, color: tcol, font: Font.title, kern: won ? 4 : 10)
        t.position = CGPoint(x: 0, y: ph / 2 - 46)
        t.zPosition = 2
        o.addChild(t)
        let d = SKSpriteNode(texture: Tex.divider(300), size: CGSize(width: 300, height: 6))
        d.position = CGPoint(x: 0, y: ph / 2 - 76)
        d.zPosition = 2
        o.addChild(d)
        let pal = Palette.of(runData.depth)
        let sub = won ? "The thrones of the deep lie broken behind you... for now."
                      : "You fell in the \(pal.name), chamber \(runData.room + 1)."
        let s = makeLabel(sub, size: 16, color: Ink.bone, font: Font.medium)
        s.numberOfLines = 2
        s.preferredMaxLayoutWidth = pw - 40
        s.position = CGPoint(x: 0, y: ph / 2 - 102)
        s.zPosition = 2
        o.addChild(s)
        let stats = makeLabel("Foes slain \(runData.kills)   ·   Soul Shards earned \(runData.souls)   ·   Total \(Meta.shared.data.souls)",
                              size: 14, color: UIColor(hex: 0xb79cff), font: Font.bold)
        stats.position = CGPoint(x: 0, y: ph / 2 - 136)
        stats.zPosition = 2
        o.addChild(stats)
        let tip = makeLabel("Spend Soul Shards at the Altar of Embers to grow stronger.", size: 13,
                            color: Ink.boneDark, font: Font.medium)
        tip.position = CGPoint(x: 0, y: ph / 2 - 160)
        tip.zPosition = 2
        o.addChild(tip)
        let b = Button("Return to the Sanctum", size: CGSize(width: 270, height: 48), fontSize: 17) { [weak self] in
            self?.goToSanctum()
        }
        b.priority = 10
        b.zPosition = 3
        b.position = CGPoint(x: 0, y: -ph / 2 + 44)
        o.addChild(b)
        o.alpha = 0
        o.run(.fadeIn(withDuration: 0.5))
        hud.addChild(o)
        overlay = o
        hud.pauseButton.isHidden = true
    }
}
