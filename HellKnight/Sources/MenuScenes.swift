import SpriteKit
import UIKit

// MARK: - Title

final class TitleScene: BaseScene {
    private var leaving = false

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = UIColor(hex: 0x0a0403)
        build()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if view != nil { build() }
    }

    override func relayout() { build() }

    func build() {
        removeAllChildren()
        let W = size.width
        let H = size.height
        let glow = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: W * 1.4, height: H * 1.1))
        glow.color = UIColor(hex: 0xff3a10)
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.alpha = 0.4
        glow.position = CGPoint(x: 0, y: -H * 0.55)
        addChild(glow)
        glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.28, duration: 1.6), .fadeAlpha(to: 0.45, duration: 1.6)])))

        let em = makeEmbers(area: CGSize(width: W, height: 30), color: UIColor(hex: 0xff8a30), rate: 30)
        em.position = CGPoint(x: 0, y: -H / 2)
        em.particleSpeed = 70
        em.particleLifetime = 7
        em.advanceSimulationTime(6)
        addChild(em)

        let knight = SKSpriteNode(texture: Tex.knight(), size: CGSize(width: 120, height: 120))
        knight.position = CGPoint(x: 0, y: H * 0.22)
        addChild(knight)
        knight.run(.repeatForever(.sequence([.moveBy(x: 0, y: 6, duration: 1.2), .moveBy(x: 0, y: -6, duration: 1.2)])))

        let fs = min(74, W * 0.1)
        let shadow = makeLabel("HELLKNIGHT", size: fs, color: UIColor(hex: 0xff2a10), font: Font.title)
        shadow.position = CGPoint(x: 2, y: -H * 0.04 - 3)
        shadow.alpha = 0.7
        addChild(shadow)
        let title = makeLabel("HELLKNIGHT", size: fs, color: UIColor(hex: 0xffe2c4), font: Font.title)
        title.position = CGPoint(x: 0, y: -H * 0.04)
        addChild(title)
        let sub = makeLabel("A descent through the burning abyss", size: 15, color: UIColor(hex: 0xffb080), font: Font.medium)
        sub.position = CGPoint(x: 0, y: -H * 0.04 - fs * 0.75)
        addChild(sub)
        let tap = makeLabel("Tap to begin", size: 18, color: .white, font: Font.bold)
        tap.position = CGPoint(x: 0, y: -H * 0.34)
        addChild(tap)
        tap.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.8), .fadeAlpha(to: 1, duration: 0.8)])))
    }

    override func touchDown(_ t: UITouch) {
        guard !leaving, let v = view else { return }
        leaving = true
        sfx(.door)
        let s = SanctumScene(size: size)
        s.scaleMode = .resizeFill
        v.presentScene(s, transition: .fade(with: .black, duration: 0.8))
    }
}

// MARK: - Sanctum hub (meta progression + weapon select)

final class SanctumScene: BaseScene {

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = UIColor(hex: 0x0b0605)
        build()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if view != nil { build() }
    }

    override func relayout() { build() }

    func build() {
        removeAllChildren()
        let meta = Meta.shared
        let W = size.width
        let H = size.height
        let safe = view?.safeAreaInsets ?? .zero
        let L = -W / 2 + safe.left + 18
        let R = W / 2 - safe.right - 18
        let T = H / 2 - 18
        let B = -H / 2 + max(safe.bottom, 6) + 8

        let glow = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: W * 1.3, height: H))
        glow.color = UIColor(hex: 0xff3a10)
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        glow.alpha = 0.22
        glow.position = CGPoint(x: 0, y: -H * 0.5)
        addChild(glow)
        let em = makeEmbers(area: CGSize(width: W, height: 30), color: UIColor(hex: 0xff8a30), rate: 14)
        em.position = CGPoint(x: 0, y: -H / 2)
        em.particleSpeed = 50
        em.particleLifetime = 7
        em.advanceSimulationTime(6)
        addChild(em)

        let title = makeLabel("SANCTUM OF ASH", size: 22, color: UIColor(hex: 0xffb070), font: Font.title)
        title.position = CGPoint(x: 0, y: T - 4)
        addChild(title)
        let souls = makeLabel("\(meta.data.souls) Soul Shards", size: 15, color: UIColor(hex: 0xb79cff), font: Font.heavy, align: .right)
        souls.position = CGPoint(x: R, y: T - 4)
        addChild(souls)
        let stats = makeLabel("Descents \(meta.data.runs)  ·  Escapes \(meta.data.wins)  ·  Deepest \(meta.data.bestDepth)",
                              size: 11, color: UIColor(white: 0.6, alpha: 1), font: Font.medium, align: .left)
        stats.position = CGPoint(x: L, y: T - 4)
        addChild(stats)

        let colW = (R - L - 28) / 2
        let leftX = L + colW / 2
        let rightX = R - colW / 2

        // Left: armament
        let h1 = makeLabel("ARMAMENT", size: 14, color: UIColor(hex: 0xffd0a0), font: Font.title)
        h1.position = CGPoint(x: leftX, y: T - 36)
        addChild(h1)
        let selected = WeaponKind(rawValue: meta.data.weapon) ?? .blade
        let bh: CGFloat = min(36, (H - 200) / 5)
        for (i, w) in WeaponKind.allCases.enumerated() {
            let sel = w == selected
            let b = Button(w.name, size: CGSize(width: colW, height: bh),
                           color: sel ? UIColor(hex: 0x6a2410) : UIColor(hex: 0x241210, alpha: 0.9),
                           stroke: sel ? UIColor(hex: 0xffc070) : UIColor(hex: 0x6a4030), fontSize: 15) { [weak self] in
                meta.data.weapon = w.rawValue
                meta.save()
                self?.build()
            }
            b.position = CGPoint(x: leftX, y: T - 62 - CGFloat(i) * (bh + 6))
            addChild(b)
        }
        let blurbTop = T - 62 - 3 * (bh + 6) + bh / 2 - 4
        let blurb = makeLabel(selected.blurb, size: 12, color: UIColor(white: 0.8, alpha: 1), font: Font.medium)
        blurb.numberOfLines = 0
        blurb.preferredMaxLayoutWidth = colW
        blurb.verticalAlignmentMode = .top
        blurb.position = CGPoint(x: leftX, y: blurbTop)
        addChild(blurb)

        let start = Button("BEGIN DESCENT", size: CGSize(width: colW, height: 46), color: UIColor(hex: 0x7a1a0a),
                           stroke: UIColor(hex: 0xffc070), fontSize: 20) { [weak self] in
            self?.startRun()
        }
        start.label.fontName = Font.title
        start.position = CGPoint(x: leftX, y: B + 23)
        addChild(start)
        start.run(.repeatForever(.sequence([.scale(to: 1.03, duration: 0.7), .scale(to: 1, duration: 0.7)])))

        // Right: Altar of Embers
        let h2 = makeLabel("ALTAR OF EMBERS", size: 14, color: UIColor(hex: 0xffd0a0), font: Font.title)
        h2.position = CGPoint(x: rightX, y: T - 36)
        addChild(h2)
        let ups = MetaUpgrade.allCases
        let top = T - 52
        let avail = top - B
        let rowH = min(44, avail / CGFloat(ups.count))
        let btnW: CGFloat = 64
        for (i, u) in ups.enumerated() {
            let y = top - rowH * (CGFloat(i) + 0.5)
            let rank = meta.rank(u)
            let maxed = rank >= u.maxRank
            let cost = u.cost(rank)
            let row = SKSpriteNode(color: UIColor(white: 1, alpha: i % 2 == 0 ? 0.04 : 0.0), size: CGSize(width: colW, height: rowH - 2))
            row.position = CGPoint(x: rightX, y: y)
            addChild(row)
            let name = makeLabel("\(u.title)  \(rank)/\(u.maxRank)", size: min(14, rowH * 0.36),
                                 color: maxed ? UIColor(hex: 0xffc060) : .white, font: Font.bold, align: .left)
            name.position = CGPoint(x: rightX - colW / 2 + 6, y: y + rowH * 0.17)
            addChild(name)
            let eff = makeLabel(u.effect, size: min(11, rowH * 0.28), color: UIColor(white: 0.65, alpha: 1), font: Font.medium, align: .left)
            eff.position = CGPoint(x: rightX - colW / 2 + 6, y: y - rowH * 0.2)
            addChild(eff)
            let b = Button(maxed ? "MAX" : "\(cost)", size: CGSize(width: btnW, height: rowH - 8),
                           color: UIColor(hex: 0x2a1840), stroke: UIColor(hex: 0xb79cff), fontSize: min(14, rowH * 0.4)) { [weak self] in
                if meta.buy(u) {
                    sfx(.boon)
                    self?.build()
                }
            }
            b.enabled = !maxed && meta.data.souls >= cost
            b.position = CGPoint(x: rightX + colW / 2 - btnW / 2 - 2, y: y)
            addChild(b)
        }
    }

    func startRun() {
        guard let v = view else { return }
        let weapon = WeaponKind(rawValue: Meta.shared.data.weapon) ?? .blade
        let run = RunState(weapon: weapon)
        let g = GameScene(size: size, runData: run)
        sfx(.door)
        v.presentScene(g, transition: .fade(with: .black, duration: 0.8))
    }
}
