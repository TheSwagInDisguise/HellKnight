import SpriteKit
import UIKit

// MARK: - Button (ornate panel)

final class Button: SKNode {
    let bg: SKSpriteNode
    let label: SKLabelNode
    let size: CGSize
    var onTap: () -> Void
    var priority = 0
    var enabled = true {
        didSet { alpha = enabled ? 1 : 0.45 }
    }

    init(_ text: String, size: CGSize, accent: UIColor = Ink.gold, fontSize: CGFloat = 17,
         font: String = Font.title, texture: SKTexture? = nil, onTap: @escaping () -> Void) {
        self.onTap = onTap
        self.size = size
        bg = SKSpriteNode(texture: texture ?? Tex.panel(size.width, size.height, accent: accent), size: size)
        label = makeLabel(text, size: fontSize, color: Ink.bone, font: font)
        super.init()
        addChild(bg)
        label.zPosition = 1
        addChild(label)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setHighlight(_ on: Bool) {
        removeAction(forKey: "hl")
        run(.scale(to: on ? 0.94 : 1, duration: 0.06), withKey: "hl")
        bg.color = Ink.gold
        bg.colorBlendFactor = on ? 0.25 : 0
    }
}

// MARK: - Base scene with button dispatch

class BaseScene: SKScene {
    private var pressed: [UITouch: Button] = [:]

    func touchDown(_ t: UITouch) {}
    func touchMove(_ t: UITouch) {}
    func touchUp(_ t: UITouch) {}
    func relayout() {}

    func button(at p: CGPoint) -> Button? {
        var best: Button?
        for n in nodes(at: p) {
            var c: SKNode? = n
            while let x = c {
                if let b = x as? Button {
                    if b.enabled && visibleInTree(b) {
                        if let cur = best {
                            if b.priority > cur.priority { best = b }
                        } else {
                            best = b
                        }
                    }
                    break
                }
                c = x.parent
            }
        }
        return best
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            if let b = button(at: t.location(in: self)) {
                pressed[t] = b
                b.setHighlight(true)
            } else {
                touchDown(t)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches where pressed[t] == nil {
            touchMove(t)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            if let b = pressed.removeValue(forKey: t) {
                b.setHighlight(false)
                if let parent = b.parent, b.contains(t.location(in: parent)), b.enabled {
                    sfx(.pickup, 0.35)
                    b.onTap()
                }
            } else {
                touchUp(t)
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            if let b = pressed.removeValue(forKey: t) {
                b.setHighlight(false)
            } else {
                touchUp(t)
            }
        }
    }
}

// MARK: - Touch controls

enum Act: Int { case attack, special, cast, dash }

final class Controls: SKNode {
    var screen = CGSize(width: 800, height: 400)
    let joyBase = SKSpriteNode(texture: Tex.joyBase(), size: CGSize(width: 136, height: 136))
    let joyKnob = SKSpriteNode(texture: Tex.joyKnob(), size: CGSize(width: 58, height: 58))
    var joyTouch: UITouch?
    var joyOrigin = CGPoint.zero
    var joyRest = CGPoint.zero
    var move = CGPoint.zero
    var pads: [Act: SKSpriteNode] = [:]
    var padRadius: [Act: CGFloat] = [:]
    var held: [UITouch: Act] = [:]
    var buffer: [Act: CGFloat] = [:]
    let castLabel = makeLabel("", size: 14, color: Ink.bone, font: Font.heavy)

    var attackHeld: Bool { held.values.contains(.attack) }

    override init() {
        super.init()
        joyBase.alpha = 0.55
        joyKnob.alpha = 0.7
        joyKnob.zPosition = 1
        addChild(joyBase)
        addChild(joyKnob)
        let defs: [(Act, String, CGFloat, UIColor)] = [
            (.attack, "", 50, Ink.blood),
            (.special, "hurricane", 36, Ink.gold),
            (.cast, "flame.fill", 34, UIColor(hex: 0xff6a3a)),
            (.dash, "wind", 36, Ink.bone),
        ]
        for (a, sym, r, accent) in defs {
            let pad = SKSpriteNode(texture: Tex.medallion(r, accent: accent), size: CGSize(width: r * 2 + 4, height: r * 2 + 4))
            pad.alpha = 0.92
            let tex = a == .attack ? Tex.blade() : Tex.symbol(sym)
            let icon = SKSpriteNode(texture: tex)
            if a == .attack {
                icon.size = CGSize(width: r * 1.5, height: r * 1.5 * 16 / 72)
                icon.zRotation = .pi / 4
            } else {
                let ts = tex.size()
                let k = r * 0.9 / max(1, max(ts.width, ts.height))
                icon.size = CGSize(width: ts.width * k, height: ts.height * k)
            }
            icon.zPosition = 1
            pad.addChild(icon)
            addChild(pad)
            pads[a] = pad
            padRadius[a] = r
        }
        let gem = SKSpriteNode(texture: Tex.gem(0xff4a2a), size: CGSize(width: 20, height: 22))
        gem.position = CGPoint(x: 24, y: -22)
        gem.zPosition = 2
        pads[.cast]?.addChild(gem)
        castLabel.position = CGPoint(x: 24, y: -36)
        castLabel.zPosition = 3
        pads[.cast]?.addChild(castLabel)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func layout(_ size: CGSize, _ safe: UIEdgeInsets) {
        screen = size
        let right = size.width / 2 - safe.right - 18
        let bottom = -size.height / 2 + max(safe.bottom, 8) + 10
        let a = CGPoint(x: right - 56, y: bottom + 62)
        pads[.attack]?.position = a
        pads[.dash]?.position = a + CGPoint(x: -114, y: -12)
        pads[.special]?.position = a + CGPoint(x: -90, y: 80)
        pads[.cast]?.position = a + CGPoint(x: 4, y: 114)
        joyRest = CGPoint(x: -size.width / 2 + safe.left + 105, y: bottom + 90)
        if joyTouch == nil {
            joyBase.position = joyRest
            joyKnob.position = joyRest
        }
    }

    private func padAt(_ p: CGPoint) -> Act? {
        var best: Act?
        var bestD = CGFloat.greatestFiniteMagnitude
        for (a, pad) in pads {
            let r = (padRadius[a] ?? 30) * 1.35
            let d = pad.position.distance(to: p)
            if d < r && d < bestD {
                best = a
                bestD = d
            }
        }
        return best
    }

    func began(_ t: UITouch, _ loc: CGPoint) {
        if let a = padAt(loc) {
            held[t] = a
            buffer[a] = 0.3
            pads[a]?.setScale(0.9)
            return
        }
        if loc.x < screen.width * 0.1 && joyTouch == nil {
            joyTouch = t
            joyOrigin = loc
            joyBase.position = loc
            joyKnob.position = loc
            joyBase.alpha = 0.9
            joyKnob.alpha = 1
            move = .zero
        }
    }

    func moved(_ t: UITouch, _ loc: CGPoint) {
        guard t == joyTouch else { return }
        let maxR: CGFloat = 55
        var d = loc - joyOrigin
        var l = d.length
        if l > maxR * 1.5 {
            joyOrigin = loc - d.normalized * (maxR * 1.5)
            joyBase.position = joyOrigin
            d = loc - joyOrigin
            l = d.length
        }
        let c = l > maxR ? d * (maxR / l) : d
        joyKnob.position = joyOrigin + c
        let raw = c * (1 / maxR)
        move = raw.length < 0.12 ? .zero : raw
    }

    func ended(_ t: UITouch) {
        if t == joyTouch {
            joyTouch = nil
            move = .zero
            joyBase.position = joyRest
            joyKnob.position = joyRest
            joyBase.alpha = 0.55
            joyKnob.alpha = 0.7
        }
        if let a = held.removeValue(forKey: t) {
            pads[a]?.setScale(1)
        }
    }

    func tick(_ dt: CGFloat) {
        if buffer.isEmpty { return }
        buffer = buffer.mapValues { $0 - dt }.filter { $0.value > 0 }
    }

    func consume(_ a: Act) -> Bool {
        if let v = buffer[a], v > 0 {
            buffer[a] = nil
            return true
        }
        return false
    }

    func reset() {
        if let t = joyTouch { ended(t) }
        for (_, a) in held { pads[a]?.setScale(1) }
        held.removeAll()
        buffer.removeAll()
        move = .zero
    }

    func setReady(_ a: Act, _ ready: Bool) {
        pads[a]?.alpha = ready ? 0.95 : 0.38
    }
}

// MARK: - HUD (ornate gothic)

final class HUD: SKNode {
    var screen = CGSize(width: 800, height: 400)
    var onPause: (() -> Void)?
    let vignette = SKSpriteNode(texture: Tex.inkVignette())
    let hurt = SKSpriteNode(color: Ink.blood, size: CGSize(width: 10, height: 10))
    let fadeNode = SKSpriteNode(color: .black, size: CGSize(width: 10, height: 10))
    static let hpW: CGFloat = 196
    var hpWidth: CGFloat { HUD.hpW }
    let hpFrame: SKSpriteNode
    let hpFill: SKSpriteNode
    let hpShine: SKSpriteNode
    let hpText = makeLabel("", size: 12, color: Ink.bone, font: Font.heavy)
    let heartMedal = SKSpriteNode(texture: Tex.medallion(22, accent: Ink.blood), size: CGSize(width: 48, height: 48))
    let dashNode = SKNode()
    let castNode = SKNode()
    var dashBuilt = -1
    var castBuilt = -1
    let goldLabel = makeLabel("", size: 15, color: Ink.gold, font: Font.heavy, align: .right)
    let soulLabel = makeLabel("", size: 13, color: UIColor(hex: 0xb79cff), font: Font.heavy, align: .right)
    let goldIcon = SKSpriteNode(texture: Tex.icon(.gold), size: CGSize(width: 20, height: 20))
    let soulIcon = SKSpriteNode(texture: Tex.icon(.souls), size: CGSize(width: 18, height: 18))
    let roomLabel = makeLabel("", size: 14, color: Ink.bone, font: Font.title)
    let roomDivider = SKSpriteNode(texture: Tex.divider(220), size: CGSize(width: 220, height: 14))
    let bossNode = SKNode()
    static let bossW: CGFloat = 360
    var bossWidth: CGFloat { HUD.bossW }
    let bossFill: SKSpriteNode
    let bossName = makeLabel("", size: 15, color: Ink.bone, font: Font.title)
    let bannerTitle = makeLabel("", size: 30, font: Font.title)
    let bannerShadow = makeLabel("", size: 30, color: Ink.black, font: Font.title)
    let bannerSub = makeLabel("", size: 15, color: Ink.bone, font: Font.medium)
    let bannerDivider = SKSpriteNode(texture: Tex.divider(300), size: CGSize(width: 300, height: 14))
    var pauseButton: Button!
    let boonRow = SKNode()
    var boonSig = ""

    override init() {
        hpFrame = SKSpriteNode(texture: Tex.barFrame(HUD.hpW, 14), size: CGSize(width: HUD.hpW + 24, height: 22))
        hpFill = SKSpriteNode(color: Ink.blood, size: CGSize(width: HUD.hpW, height: 12))
        hpShine = SKSpriteNode(color: UIColor(white: 1, alpha: 0.18), size: CGSize(width: HUD.hpW, height: 3))
        bossFill = SKSpriteNode(color: Ink.blood, size: CGSize(width: HUD.bossW, height: 10))
        super.init()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setup() {
        vignette.zPosition = -10
        addChild(vignette)
        hurt.alpha = 0
        hurt.zPosition = -9
        hurt.blendMode = .add
        addChild(hurt)

        hpFrame.anchorPoint = CGPoint(x: 0, y: 0.5)
        addChild(hpFrame)
        hpFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        hpFill.zPosition = 1
        addChild(hpFill)
        hpShine.anchorPoint = CGPoint(x: 0, y: 0.5)
        hpShine.zPosition = 1.1
        addChild(hpShine)
        hpText.zPosition = 2
        addChild(hpText)
        heartMedal.zPosition = 3
        let heart = SKSpriteNode(texture: Tex.icon(.heart), size: CGSize(width: 30, height: 30))
        heart.zPosition = 1
        heartMedal.addChild(heart)
        heart.run(.repeatForever(.sequence([.scale(to: 1.12, duration: 0.15), .scale(to: 1, duration: 0.15), .wait(forDuration: 0.7)])))
        addChild(heartMedal)
        addChild(dashNode)
        addChild(castNode)
        addChild(goldLabel)
        addChild(soulLabel)
        addChild(goldIcon)
        addChild(soulIcon)
        roomDivider.alpha = 0.8
        addChild(roomDivider)
        addChild(roomLabel)

        bossNode.isHidden = true
        let bf = SKSpriteNode(texture: Tex.barFrame(bossWidth, 12), size: CGSize(width: bossWidth + 24, height: 20))
        bossNode.addChild(bf)
        bossFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        bossFill.position = CGPoint(x: -bossWidth / 2, y: 0)
        bossFill.zPosition = 1
        bossNode.addChild(bossFill)
        let bd = SKSpriteNode(texture: Tex.divider(300), size: CGSize(width: 300, height: 14))
        bd.position = CGPoint(x: 0, y: 30)
        bossNode.addChild(bd)
        bossName.position = CGPoint(x: 0, y: 18)
        bossName.zPosition = 1
        bossNode.addChild(bossName)
        addChild(bossNode)

        for l in [bannerShadow, bannerTitle, bannerSub] {
            l.alpha = 0
            addChild(l)
        }
        bannerShadow.zPosition = -0.1
        bannerDivider.alpha = 0
        addChild(bannerDivider)

        pauseButton = Button("", size: CGSize(width: 44, height: 44), texture: Tex.medallion(20)) { [weak self] in
            self?.onPause?()
        }
        let pi = SKSpriteNode(texture: Tex.symbol("pause.fill", 18), size: CGSize(width: 14, height: 16))
        pi.zPosition = 2
        pauseButton.addChild(pi)
        pauseButton.priority = 1
        addChild(pauseButton)
        addChild(boonRow)

        fadeNode.zPosition = 900
        fadeNode.alpha = 1
        addChild(fadeNode)
    }

    func layout(_ size: CGSize, _ safe: UIEdgeInsets) {
        screen = size
        let L = -size.width / 2 + safe.left + 16
        let R = size.width / 2 - safe.right - 14
        let T = size.height / 2 - max(safe.top, 0) - 24
        vignette.size = CGSize(width: size.width * 1.08, height: size.height * 1.12)
        hurt.size = CGSize(width: size.width + 20, height: size.height + 20)
        fadeNode.size = CGSize(width: size.width + 40, height: size.height + 40)
        heartMedal.position = CGPoint(x: L + 22, y: T)
        hpFrame.position = CGPoint(x: L + 30, y: T)
        hpFill.position = CGPoint(x: L + 42, y: T)
        hpShine.position = CGPoint(x: L + 42, y: T + 3)
        hpText.position = CGPoint(x: L + 42 + hpWidth / 2, y: T)
        dashNode.position = CGPoint(x: L + 56, y: T - 24)
        castNode.position = CGPoint(x: L + 56 + 100, y: T - 24)
        boonRow.position = CGPoint(x: L + 18, y: T - 52)
        pauseButton.position = CGPoint(x: R - 22, y: T)
        goldIcon.position = CGPoint(x: R - 60, y: T + 1)
        goldLabel.position = CGPoint(x: R - 74, y: T)
        soulIcon.position = CGPoint(x: R - 60, y: T - 22)
        soulLabel.position = CGPoint(x: R - 74, y: T - 22)
        roomLabel.position = CGPoint(x: 0, y: T + 2)
        roomDivider.position = CGPoint(x: 0, y: T - 12)
        bossNode.position = CGPoint(x: 0, y: T - 52)
        bannerTitle.position = CGPoint(x: 0, y: size.height * 0.2)
        bannerShadow.position = CGPoint(x: 2, y: size.height * 0.2 - 2)
        bannerDivider.position = CGPoint(x: 0, y: size.height * 0.2 - 22)
        bannerSub.position = CGPoint(x: 0, y: size.height * 0.2 - 42)
    }

    private func buildPips(_ node: SKNode, count: Int, hex: UInt32) {
        node.removeAllChildren()
        for i in 0..<count {
            let s = SKSpriteNode(texture: Tex.gem(hex), size: CGSize(width: 13, height: 15))
            s.position = CGPoint(x: CGFloat(i) * 16, y: 0)
            node.addChild(s)
        }
    }

    func refresh(_ run: RunState, _ player: Player?, _ boss: Boss?) {
        let f = max(0, min(1, run.hp / max(1, run.maxHp)))
        hpFill.xScale = f
        hpShine.xScale = f
        hpText.text = "\(Int(max(0, run.hp).rounded(.up))) / \(Int(run.maxHp))"
        if dashBuilt != run.maxDash {
            dashBuilt = run.maxDash
            buildPips(dashNode, count: run.maxDash, hex: 0xd8d0c0)
        }
        if castBuilt != run.maxCast {
            castBuilt = run.maxCast
            buildPips(castNode, count: run.maxCast, hex: 0xff4a2a)
        }
        if let p = player {
            for (i, n) in dashNode.children.enumerated() { n.alpha = i < p.dashCharges ? 1 : 0.2 }
            for (i, n) in castNode.children.enumerated() { n.alpha = i < p.castCharges ? 1 : 0.2 }
        }
        goldLabel.text = "\(run.gold)"
        soulLabel.text = "\(run.souls)"
        if let b = boss, b.alive {
            bossNode.isHidden = false
            bossName.text = b.bossName.uppercased()
            bossFill.xScale = max(0, b.hp / b.maxHp)
        } else {
            bossNode.isHidden = true
        }
        var sig = ""
        for s in Slot.allCases { if let b = run.slots[s] { sig += "\(s.rawValue)\(b.patron.rawValue)\(b.rarity.rawValue)," } }
        for p in Passive.allCases { if let r = run.passives[p] { sig += "p\(p.rawValue)\(r.rawValue)," } }
        if sig != boonSig {
            boonSig = sig
            boonRow.removeAllChildren()
            var x: CGFloat = 0
            for s in Slot.allCases {
                guard let b = run.slots[s] else { continue }
                let ic = SKSpriteNode(texture: Tex.icon(.boon(b.patron)), size: CGSize(width: 28, height: 28))
                ic.position = CGPoint(x: x, y: 0)
                let l = makeLabel(String(s.name.prefix(1)), size: 10, color: b.rarity.color, font: Font.heavy)
                l.position = CGPoint(x: 0, y: -17)
                ic.addChild(l)
                boonRow.addChild(ic)
                x += 30
            }
            for p in Passive.allCases where run.passives[p] != nil {
                let ic = SKSpriteNode(texture: Tex.icon(.boon(p.patron)), size: CGSize(width: 20, height: 20))
                ic.position = CGPoint(x: x, y: 0)
                ic.alpha = 0.85
                boonRow.addChild(ic)
                x += 22
            }
        }
    }

    func banner(_ title: String, _ sub: String = "", color: UIColor = Ink.bone, small: Bool = false) {
        bannerTitle.text = title
        bannerShadow.text = title
        bannerTitle.fontColor = color
        bannerTitle.fontSize = small ? 22 : 32
        bannerShadow.fontSize = bannerTitle.fontSize
        bannerSub.text = sub
        for l in [bannerTitle, bannerShadow, bannerSub, bannerDivider] as [SKNode] {
            l.removeAllActions()
            l.alpha = 0
            l.setScale(1.1)
            l.run(.sequence([
                .group([.fadeIn(withDuration: 0.25), .scale(to: 1, duration: 0.25)]),
                .wait(forDuration: small ? 0.9 : 1.9),
                .fadeOut(withDuration: 0.5),
            ]))
        }
        bannerDivider.isHidden = small
    }

    func flashHurt() {
        hurt.removeAllActions()
        hurt.alpha = 0.35
        hurt.run(.fadeOut(withDuration: 0.35))
    }

    func fade(to a: CGFloat, duration: CGFloat, completion: @escaping () -> Void) {
        fadeNode.removeAllActions()
        fadeNode.run(.sequence([.fadeAlpha(to: a, duration: TimeInterval(duration)), .run(completion)]))
    }
}
