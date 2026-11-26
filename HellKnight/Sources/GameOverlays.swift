import SpriteKit
import UIKit

extension GameScene {

    // MARK: - Reward collection

    func collect(_ r: Reward, completion: @escaping () -> Void) {
        let at = player.position + CGPoint(x: 0, y: 44)
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
            floatText("+\(g) Gold", at: at, color: UIColor(hex: 0xf0c040), size: 18)
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
        let dim = SKSpriteNode(color: UIColor(white: 0, alpha: 0.8), size: CGSize(width: size.width + 60, height: size.height + 60))
        o.addChild(dim)
        return o
    }

    func showChoices(title: String, subtitle: String, accent: UIColor, cards: [ChoiceCard]) {
        state = .choosing
        controls.reset()
        let W = size.width
        let H = size.height
        let o = makeOverlay()
        let t = makeLabel(title, size: min(26, W * 0.034), color: accent, font: Font.title)
        t.position = CGPoint(x: 0, y: H / 2 - 30)
        o.addChild(t)
        let st = makeLabel(subtitle, size: 13, color: UIColor(white: 1, alpha: 0.75), font: Font.medium)
        st.position = CGPoint(x: 0, y: H / 2 - 52)
        o.addChild(st)

        let n = CGFloat(max(cards.count, 1))
        let gap: CGFloat = 14
        let cw = min(240, (W - 60 - (n - 1) * gap) / n)
        let ch = min(270, H - 100)
        let small = cw < 200
        for (i, c) in cards.enumerated() {
            let x = (CGFloat(i) - (n - 1) / 2) * (cw + gap)
            let b = Button("", size: CGSize(width: cw, height: ch), color: UIColor(hex: 0x170c0a, alpha: 0.96), stroke: c.color) { [weak self] in
                self?.closeOverlay()
                c.action()
            }
            b.priority = 10
            b.bg.lineWidth = 2.5
            b.position = CGPoint(x: x, y: -32)
            let top = ch / 2
            if let r = c.icon {
                let s = SKSpriteNode(texture: Tex.icon(r), size: CGSize(width: 36, height: 36))
                s.position = CGPoint(x: 0, y: top - 26)
                s.zPosition = 2
                b.addChild(s)
            }
            let tag = makeLabel(c.tag, size: 10, color: c.color, font: Font.heavy)
            tag.position = CGPoint(x: 0, y: top - 53)
            tag.zPosition = 2
            b.addChild(tag)
            let tl = makeLabel(c.title, size: small ? 14 : 17, color: .white, font: Font.heavy)
            tl.position = CGPoint(x: 0, y: top - 72)
            tl.zPosition = 2
            b.addChild(tl)
            let sl = makeLabel(c.sub, size: 10, color: c.accent, font: Font.bold)
            sl.numberOfLines = 2
            sl.preferredMaxLayoutWidth = cw - 14
            sl.position = CGPoint(x: 0, y: top - 92)
            sl.zPosition = 2
            b.addChild(sl)
            let dl = makeLabel(c.desc, size: small ? 11.5 : 13, color: UIColor(white: 0.92, alpha: 1), font: Font.medium)
            dl.numberOfLines = 0
            dl.lineBreakMode = .byWordWrapping
            dl.preferredMaxLayoutWidth = cw - 20
            dl.verticalAlignmentMode = .top
            dl.position = CGPoint(x: 0, y: top - 108)
            dl.zPosition = 2
            b.addChild(dl)
            o.addChild(b)
            b.alpha = 0
            b.setScale(0.85)
            b.run(.sequence([
                .wait(forDuration: 0.08 * Double(i)),
                .group([.fadeIn(withDuration: 0.18), .scale(to: 1, duration: 0.18)]),
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
        let t = makeLabel("PAUSED", size: 28, color: UIColor(hex: 0xffd0a0), font: Font.title)
        t.position = CGPoint(x: 0, y: H / 2 - 34)
        o.addChild(t)

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
        let list = makeLabel(lines.joined(separator: "\n"), size: 13, color: UIColor(white: 0.9, alpha: 1), font: Font.medium)
        list.numberOfLines = 0
        list.preferredMaxLayoutWidth = W - 80
        list.verticalAlignmentMode = .top
        list.position = CGPoint(x: 0, y: H / 2 - 62)
        o.addChild(list)

        let resume = Button("Resume", size: CGSize(width: 170, height: 44), fontSize: 18) { [weak self] in
            self?.closeOverlay()
        }
        resume.priority = 10
        resume.position = CGPoint(x: -100, y: -H / 2 + 46)
        o.addChild(resume)
        let quit = Button("Abandon Run", size: CGSize(width: 170, height: 44), color: UIColor(hex: 0x3a0808), stroke: UIColor(hex: 0xff4030), fontSize: 16) { [weak self] in
            guard let self = self else { return }
            self.recordRunEnd(won: false)
            self.goToSanctum()
        }
        quit.priority = 10
        quit.position = CGPoint(x: 100, y: -H / 2 + 46)
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
            burst(at: p.position, color: UIColor(hex: 0xff3020), count: 40, speed: 300)
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
        let H = size.height
        let o = makeOverlay()
        let title = won ? "YOU ESCAPED THE ABYSS" : "SLAIN"
        let t = makeLabel(title, size: won ? 30 : 40, color: won ? UIColor(hex: 0xffd070) : UIColor(hex: 0xff3a2a), font: Font.title)
        t.position = CGPoint(x: 0, y: H * 0.26)
        o.addChild(t)
        let pal = Palette.of(runData.depth)
        let sub = won ? "The thrones of the deep lie broken behind you... for now."
                      : "You fell in the \(pal.name), chamber \(runData.room + 1)."
        let s = makeLabel(sub, size: 15, color: UIColor(white: 0.85, alpha: 1), font: Font.medium)
        s.position = CGPoint(x: 0, y: H * 0.26 - 40)
        o.addChild(s)
        let stats = makeLabel("Foes slain: \(runData.kills)    Soul Shards earned: \(runData.souls)    Total: \(Meta.shared.data.souls)",
                              size: 14, color: UIColor(hex: 0xb79cff), font: Font.bold)
        stats.position = CGPoint(x: 0, y: 0)
        o.addChild(stats)
        let tip = makeLabel("Spend Soul Shards at the Altar of Embers to grow stronger.", size: 12,
                            color: UIColor(white: 0.6, alpha: 1), font: Font.medium)
        tip.position = CGPoint(x: 0, y: -28)
        o.addChild(tip)
        let b = Button("Return to the Sanctum", size: CGSize(width: 260, height: 48), fontSize: 18) { [weak self] in
            self?.goToSanctum()
        }
        b.priority = 10
        b.position = CGPoint(x: 0, y: -H * 0.28)
        o.addChild(b)
        o.alpha = 0
        o.run(.fadeIn(withDuration: 0.5))
        hud.addChild(o)
        overlay = o
        hud.pauseButton.isHidden = true
    }
}
