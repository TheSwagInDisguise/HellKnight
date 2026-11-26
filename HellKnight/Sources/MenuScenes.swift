import SpriteKit
import UIKit

/// Shared gothic backdrop: dark gradient glow, embers, and an engraved vignette.
private func addBackdrop(to scene: SKScene, glowColor: UIColor) {
    let W = scene.size.width
    let H = scene.size.height
    let glow = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: W * 1.4, height: H * 1.2))
    glow.color = glowColor
    glow.colorBlendFactor = 1
    glow.blendMode = .add
    glow.alpha = 0.35
    glow.position = CGPoint(x: 0, y: -H * 0.55)
    scene.addChild(glow)
    glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.22, duration: 1.8), .fadeAlpha(to: 0.4, duration: 1.8)])))

    let em = makeEmbers(area: CGSize(width: W, height: 30), color: UIColor(hex: 0xff8a3a), rate: 24)
    em.position = CGPoint(x: 0, y: -H / 2)
    em.particleSpeed = 60
    em.particleLifetime = 7
    em.advanceSimulationTime(6)
    scene.addChild(em)

    let v = SKSpriteNode(texture: Tex.inkVignette(), size: CGSize(width: W * 1.05, height: H * 1.1))
    v.zPosition = 50
    scene.addChild(v)
}

// MARK: - Title

final class TitleScene: BaseScene {
    private var leaving = false

    override func didMove(to view: SKView) {
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        backgroundColor = UIColor(hex: 0x070504)
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
        addBackdrop(to: self, glowColor: Ink.blood)


        let halo = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: 260, height: 260))
        halo.color = Ink.blood
        halo.colorBlendFactor = 1
        halo.blendMode = .add
        halo.alpha = 0.45
        halo.position = CGPoint(x: 0, y: H * 0.17)
        addChild(halo)
        // Summoning circle on the "floor" under the knight (flattened, spinning inside).
        let floorNode = SKNode()
        floorNode.position = CGPoint(x: 0, y: H * 0.17 - 62)
        floorNode.yScale = 0.42
        addChild(floorNode)
        let sig = SKSpriteNode(texture: Tex.sigil(), size: CGSize(width: 300, height: 300))
        sig.color = Ink.blood
        sig.colorBlendFactor = 1
        sig.alpha = 0.35
        floorNode.addChild(sig)
        sig.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 40)))
        let knight = SKSpriteNode(texture: Tex.knight(), size: CGSize(width: 110, height: 144))
        knight.position = CGPoint(x: 0, y: H * 0.17)
        knight.zPosition = 1
        addChild(knight)
        knight.run(.repeatForever(.sequence([.moveBy(x: 0, y: 6, duration: 1.4), .moveBy(x: 0, y: -6, duration: 1.4)])))

        let fs = min(76, W * 0.1)
        let ty = -H * 0.12
        let shadow = makeLabel("HELLKNIGHT", size: fs, color: Ink.blood, font: Font.title, kern: fs * 0.18)
        shadow.position = CGPoint(x: 3, y: ty - 3)
        shadow.zPosition = 2
        addChild(shadow)
        let title = makeLabel("HELLKNIGHT", size: fs, color: Ink.bone, font: Font.title, kern: fs * 0.18)
        title.position = CGPoint(x: 0, y: ty)
        title.zPosition = 3
        addChild(title)
        let div = SKSpriteNode(texture: Tex.divider(min(420, W * 0.6)), size: CGSize(width: min(420, W * 0.6), height: 6))
        div.position = CGPoint(x: 0, y: ty - fs * 0.5)
        div.zPosition = 3
        addChild(div)
        let sub = makeLabel("A DESCENT THROUGH THE BURNING ABYSS", size: 12, color: Ink.boneDark, font: Font.bold, kern: 3)
        sub.position = CGPoint(x: 0, y: ty - fs * 0.5 - 22)
        sub.zPosition = 3
        addChild(sub)
        let tap = makeLabel("TOUCH TO BEGIN", size: 14, color: Ink.bone, font: Font.bold, kern: 4)
        tap.position = CGPoint(x: 0, y: -H * 0.38)
        tap.zPosition = 3
        addChild(tap)
        tap.run(.repeatForever(.sequence([.fadeAlpha(to: 0.3, duration: 0.9), .fadeAlpha(to: 1, duration: 0.9)])))
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
        backgroundColor = UIColor(hex: 0x080504)
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
        let T = H / 2 - 16
        let B = -H / 2 + max(safe.bottom, 6) + 8
        addBackdrop(to: self, glowColor: UIColor(hex: 0xff4a10))

        let title = makeLabel("SANCTUM OF ASH", size: 22, color: Ink.bone, font: Font.title, kern: 5)
        title.position = CGPoint(x: 0, y: T - 6)
        title.zPosition = 10
        addChild(title)
        let div = SKSpriteNode(texture: Tex.divider(260), size: CGSize(width: 260, height: 6))
        div.position = CGPoint(x: 0, y: T - 24)
        div.zPosition = 10
        addChild(div)
        let soulIcon = SKSpriteNode(texture: Tex.icon(.souls), size: CGSize(width: 22, height: 22))
        soulIcon.position = CGPoint(x: R - 8, y: T - 6)
        soulIcon.zPosition = 10
        addChild(soulIcon)
        let souls = makeLabel("\(meta.data.souls) Soul Shards", size: 15, color: UIColor(hex: 0xc2aaff), font: Font.heavy, align: .right)
        souls.position = CGPoint(x: R - 24, y: T - 6)
        souls.zPosition = 10
        addChild(souls)
        let stats = makeLabel("Descents \(meta.data.runs)  ·  Escapes \(meta.data.wins)  ·  Deepest \(meta.data.bestDepth)",
                              size: 12, color: Ink.boneDark, font: Font.medium, align: .left)
        stats.position = CGPoint(x: L, y: T - 6)
        stats.zPosition = 10
        addChild(stats)

        let colW = (R - L - 24) / 2
        let leftX = L + colW / 2
        let rightX = R - colW / 2
        let panelTop = T - 36
        let panelH = panelTop - B
        for x in [leftX, rightX] {
            let p = SKSpriteNode(texture: Tex.panel(colW + 10, panelH, fillAlpha: 0.75), size: CGSize(width: colW + 10, height: panelH))
            p.position = CGPoint(x: x, y: B + panelH / 2)
            p.zPosition = 5
            addChild(p)
        }

        // Left: armament
        let h1 = makeLabel("ARMAMENT", size: 12, color: Ink.boneDark, font: Font.bold, kern: 3)
        h1.position = CGPoint(x: leftX, y: panelTop - 20)
        h1.zPosition = 10
        addChild(h1)
        let selected = WeaponKind(rawValue: meta.data.weapon) ?? .blade
        let bh: CGFloat = min(36, (panelH - 150) / 4)
        for (i, w) in WeaponKind.allCases.enumerated() {
            let sel = w == selected
            let b = Button(w.name, size: CGSize(width: colW - 30, height: bh), accent: sel ? Ink.blood : nil,
                           fontSize: 15) { [weak self] in
                meta.data.weapon = w.rawValue
                meta.save()
                self?.build()
            }
            if !sel {
                b.label.fontColor = Ink.boneDark
                setKerned(b.label, w.name.uppercased(), kern: 1.2)
            }
            if sel {
                let ic = SKSpriteNode(texture: Tex.weapon(w))
                ic.size = w == .fists ? CGSize(width: 20, height: 20) : CGSize(width: 40, height: 9)
                ic.position = CGPoint(x: -(colW - 30) / 2 + 30, y: 0)
                ic.zPosition = 2
                b.addChild(ic)
            }
            b.position = CGPoint(x: leftX, y: panelTop - 46 - CGFloat(i) * (bh + 6))
            b.zPosition = 10
            addChild(b)
        }
        let blurbTop = panelTop - 46 - 3 * (bh + 6) + bh / 2 - 6
        let blurb = makeLabel(selected.blurb, size: 13, color: Ink.bone.withAlphaComponent(0.85), font: Font.medium)
        blurb.numberOfLines = 0
        blurb.preferredMaxLayoutWidth = colW - 30
        blurb.verticalAlignmentMode = .top
        blurb.position = CGPoint(x: leftX, y: blurbTop)
        blurb.zPosition = 10
        addChild(blurb)

        let start = Button("BEGIN DESCENT", size: CGSize(width: colW - 30, height: 46), accent: Ink.blood, fontSize: 19) { [weak self] in
            self?.startRun()
        }
        start.position = CGPoint(x: leftX, y: B + 34)
        start.zPosition = 10
        addChild(start)
        start.run(.repeatForever(.sequence([.scale(to: 1.03, duration: 0.8), .scale(to: 1, duration: 0.8)])))

        // Right: Altar of Embers
        let h2 = makeLabel("ALTAR OF EMBERS", size: 12, color: Ink.boneDark, font: Font.bold, kern: 3)
        h2.position = CGPoint(x: rightX, y: panelTop - 20)
        h2.zPosition = 10
        addChild(h2)
        let ups = MetaUpgrade.allCases
        let top = panelTop - 36
        let avail = top - (B + 8)
        let rowH = min(44, avail / CGFloat(ups.count))
        let btnW: CGFloat = 62
        let inner = colW - 24
        for (i, u) in ups.enumerated() {
            let y = top - rowH * (CGFloat(i) + 0.5)
            let rank = meta.rank(u)
            let maxed = rank >= u.maxRank
            let cost = u.cost(rank)
            if i > 0 {
                let sep = SKSpriteNode(color: UIColor(white: 1, alpha: 0.07), size: CGSize(width: inner, height: 1))
                sep.position = CGPoint(x: rightX, y: y + rowH / 2)
                sep.zPosition = 9
                addChild(sep)
            }
            let name = makeLabel(u.title, size: min(14, rowH * 0.37),
                                 color: maxed ? Ink.gold : Ink.bone, font: Font.bold, align: .left)
            for r in 0..<u.maxRank {
                let pip = SKSpriteNode(texture: Tex.gem(r < rank ? 0xb79cff : 0x3a3448), size: CGSize(width: 9, height: 9))
                pip.position = CGPoint(x: rightX + inner / 2 - btnW - 14 - CGFloat(u.maxRank - 1 - r) * 10, y: y + rowH * 0.17)
                pip.zPosition = 10
                addChild(pip)
            }
            name.position = CGPoint(x: rightX - inner / 2, y: y + rowH * 0.17)
            name.zPosition = 10
            addChild(name)
            let eff = makeLabel(u.effect, size: min(12, rowH * 0.3), color: Ink.boneDark, font: Font.medium, align: .left)
            eff.position = CGPoint(x: rightX - inner / 2, y: y - rowH * 0.2)
            eff.zPosition = 10
            addChild(eff)
            let b = Button(maxed ? "MAX" : "\(cost)", size: CGSize(width: btnW, height: max(22, rowH - 8)),
                           accent: UIColor(hex: 0xb79cff), fontSize: min(14, rowH * 0.38)) { [weak self] in
                if meta.buy(u) {
                    sfx(.boon)
                    self?.build()
                }
            }
            b.enabled = !maxed && meta.data.souls >= cost
            b.position = CGPoint(x: rightX + inner / 2 - btnW / 2, y: y)
            b.zPosition = 10
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
