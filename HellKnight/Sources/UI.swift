import SpriteKit
import UIKit

// MARK: - Button

final class Button: SKNode {
    let bg: SKShapeNode
    let label: SKLabelNode
    var onTap: () -> Void
    var priority = 0
    var enabled = true {
        didSet { alpha = enabled ? 1 : 0.45 }
    }

    init(_ text: String, size: CGSize, color: UIColor = UIColor(hex: 0x2a1410, alpha: 0.95),
         stroke: UIColor = UIColor(hex: 0xd08a3a), fontSize: CGFloat = 17, onTap: @escaping () -> Void) {
        self.onTap = onTap
        bg = SKShapeNode(rectOf: size, cornerRadius: min(10, size.height * 0.25))
        bg.fillColor = color
        bg.strokeColor = stroke
        bg.lineWidth = 2
        label = makeLabel(text, size: fontSize, font: Font.bold)
        super.init()
        addChild(bg)
        label.zPosition = 1
        addChild(label)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setHighlight(_ on: Bool) {
        removeAction(forKey: "hl")
        run(.scale(to: on ? 0.94 : 1, duration: 0.06), withKey: "hl")
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
    let joyBase = SKSpriteNode(texture: Tex.joyBase(), size: CGSize(width: 130, height: 130))
    let joyKnob = SKSpriteNode(texture: Tex.joyKnob(), size: CGSize(width: 58, height: 58))
    var joyTouch: UITouch?
    var joyOrigin = CGPoint.zero
    var joyRest = CGPoint.zero
    var move = CGPoint.zero
    var pads: [Act: SKSpriteNode] = [:]
    var padRadius: [Act: CGFloat] = [:]
    var held: [UITouch: Act] = [:]
    var buffer: [Act: CGFloat] = [:]
    let castLabel = makeLabel("", size: 13, color: UIColor(hex: 0xffd0a0), font: Font.heavy)

    var attackHeld: Bool { held.values.contains(.attack) }

    override init() {
        super.init()
        joyBase.alpha = 0.45
        joyKnob.alpha = 0.55
        joyKnob.zPosition = 1
        addChild(joyBase)
        addChild(joyKnob)
        let defs: [(Act, String, CGFloat)] = [(.attack, "", 48), (.special, "hurricane", 35), (.cast, "flame.fill", 33), (.dash, "wind", 35)]
        for (a, sym, r) in defs {
            let pad = SKSpriteNode(texture: Tex.padBg(), size: CGSize(width: r * 2, height: r * 2))
            pad.alpha = 0.9
            let tex = a == .attack ? Tex.blade() : Tex.symbol(sym)
            let icon = SKSpriteNode(texture: tex)
            let ts = tex.size()
            if a == .attack {
                icon.size = CGSize(width: r * 1.45, height: r * 1.45 * 16 / 72)
                icon.zRotation = .pi / 4
            } else {
                let k = r * 0.95 / max(1, max(ts.width, ts.height))
                icon.size = CGSize(width: ts.width * k, height: ts.height * k)
            }
            icon.zPosition = 1
            pad.addChild(icon)
            addChild(pad)
            pads[a] = pad
            padRadius[a] = r
        }
        castLabel.position = CGPoint(x: 22, y: -22)
        castLabel.zPosition = 2
        pads[.cast]?.addChild(castLabel)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func layout(_ size: CGSize, _ safe: UIEdgeInsets) {
        screen = size
        let right = size.width / 2 - safe.right - 18
        let bottom = -size.height / 2 + max(safe.bottom, 8) + 10
        let a = CGPoint(x: right - 56, y: bottom + 62)
        pads[.attack]?.position = a
        pads[.dash]?.position = a + CGPoint(x: -112, y: -12)
        pads[.special]?.position = a + CGPoint(x: -88, y: 80)
        pads[.cast]?.position = a + CGPoint(x: 4, y: 112)
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
            joyBase.alpha = 0.8
            joyKnob.alpha = 0.9
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
            joyBase.alpha = 0.45
            joyKnob.alpha = 0.55
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
        pads[a]?.alpha = ready ? 0.92 : 0.35
    }
}

// MARK: - HUD

final class HUD: SKNode {
    var screen = CGSize(width: 800, height: 400)
    var onPause: (() -> Void)?
    let vignette = SKSpriteNode(texture: Tex.vignette())
    let hurt = SKSpriteNode(color: UIColor(hex: 0xff1010), size: CGSize(width: 10, height: 10))
    let fadeNode = SKSpriteNode(color: .black, size: CGSize(width: 10, height: 10))
    let hpBack = SKSpriteNode(color: UIColor(white: 0, alpha: 0.7), size: CGSize(width: 208, height: 20))
    let hpFill = SKSpriteNode(color: UIColor(hex: 0xd42a2a), size: CGSize(width: 202, height: 14))
    let hpText = makeLabel("", size: 12)
    let dashNode = SKNode()
    let castNode = SKNode()
    var dashBuilt = -1
    var castBuilt = -1
    let goldLabel = makeLabel("", size: 15, color: UIColor(hex: 0xf0c040), align: .right)
    let soulLabel = makeLabel("", size: 13, color: UIColor(hex: 0xb79cff), align: .right)
    let roomLabel = makeLabel("", size: 13, color: UIColor(white: 1, alpha: 0.7), font: Font.title)
    let bossNode = SKNode()
    let bossBack = SKSpriteNode(color: UIColor(white: 0, alpha: 0.75), size: CGSize(width: 362, height: 16))
    let bossFill = SKSpriteNode(color: UIColor(hex: 0xc02020), size: CGSize(width: 356, height: 10))
    let bossName = makeLabel("", size: 14, color: UIColor(hex: 0xffd0a0), font: Font.title)
    let bannerTitle = makeLabel("", size: 30, font: Font.title)
    let bannerSub = makeLabel("", size: 15, color: UIColor(white: 1, alpha: 0.8))
    var pauseButton: Button!
    let boonRow = SKNode()
    var boonSig = ""

    func setup() {
        vignette.zPosition = -10
        vignette.alpha = 0.9
        addChild(vignette)
        hurt.alpha = 0
        hurt.zPosition = -9
        addChild(hurt)

        hpBack.anchorPoint = CGPoint(x: 0, y: 0.5)
        addChild(hpBack)
        hpFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        hpFill.zPosition = 1
        addChild(hpFill)
        hpText.zPosition = 2
        addChild(hpText)
        addChild(dashNode)
        addChild(castNode)
        addChild(goldLabel)
        addChild(soulLabel)
        addChild(roomLabel)

        bossNode.isHidden = true
        bossNode.addChild(bossBack)
        bossFill.anchorPoint = CGPoint(x: 0, y: 0.5)
        bossFill.position = CGPoint(x: -178, y: 0)
        bossFill.zPosition = 1
        bossNode.addChild(bossFill)
        bossName.position = CGPoint(x: 0, y: 18)
        bossNode.addChild(bossName)
        addChild(bossNode)

        bannerTitle.alpha = 0
        bannerSub.alpha = 0
        addChild(bannerTitle)
        addChild(bannerSub)

        pauseButton = Button("II", size: CGSize(width: 44, height: 36), fontSize: 16) { [weak self] in
            self?.onPause?()
        }
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
        let T = size.height / 2 - max(safe.top, 0) - 20
        vignette.size = CGSize(width: size.width * 1.2, height: size.height * 1.35)
        hurt.size = CGSize(width: size.width + 20, height: size.height + 20)
        fadeNode.size = CGSize(width: size.width + 40, height: size.height + 40)
        hpBack.position = CGPoint(x: L, y: T)
        hpFill.position = CGPoint(x: L + 3, y: T)
        hpText.position = CGPoint(x: L + 104, y: T)
        dashNode.position = CGPoint(x: L + 8, y: T - 22)
        castNode.position = CGPoint(x: L + 8, y: T - 38)
        boonRow.position = CGPoint(x: L + 12, y: T - 60)
        pauseButton.position = CGPoint(x: R - 22, y: T - 2)
        goldLabel.position = CGPoint(x: R - 54, y: T)
        soulLabel.position = CGPoint(x: R - 54, y: T - 20)
        roomLabel.position = CGPoint(x: 0, y: T)
        bossNode.position = CGPoint(x: 0, y: T - 44)
        bannerTitle.position = CGPoint(x: 0, y: size.height * 0.2)
        bannerSub.position = CGPoint(x: 0, y: size.height * 0.2 - 30)
    }

    private func buildPips(_ node: SKNode, count: Int, color: UIColor) {
        node.removeAllChildren()
        for i in 0..<count {
            let s = SKSpriteNode(texture: Tex.disc(), size: CGSize(width: 11, height: 11))
            s.color = color
            s.colorBlendFactor = 1
            s.position = CGPoint(x: CGFloat(i) * 15, y: 0)
            node.addChild(s)
        }
    }

    func refresh(_ run: RunState, _ player: Player?, _ boss: Boss?) {
        let f = max(0, min(1, run.hp / max(1, run.maxHp)))
        hpFill.xScale = f
        hpText.text = "\(Int(max(0, run.hp).rounded(.up))) / \(Int(run.maxHp))"
        if dashBuilt != run.maxDash {
            dashBuilt = run.maxDash
            buildPips(dashNode, count: run.maxDash, color: UIColor(hex: 0x8fd8ff))
        }
        if castBuilt != run.maxCast {
            castBuilt = run.maxCast
            buildPips(castNode, count: run.maxCast, color: UIColor(hex: 0xff6a3a))
        }
        if let p = player {
            for (i, n) in dashNode.children.enumerated() { n.alpha = i < p.dashCharges ? 1 : 0.2 }
            for (i, n) in castNode.children.enumerated() { n.alpha = i < p.castCharges ? 1 : 0.2 }
        }
        goldLabel.text = "\(run.gold) gold"
        soulLabel.text = "\(run.souls) souls"
        if let b = boss, b.alive {
            bossNode.isHidden = false
            bossName.text = b.bossName
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
                let ic = SKSpriteNode(texture: Tex.icon(.boon(b.patron)), size: CGSize(width: 24, height: 24))
                ic.position = CGPoint(x: x, y: 0)
                let l = makeLabel(String(s.name.prefix(1)), size: 9, color: b.rarity.color, font: Font.heavy)
                l.position = CGPoint(x: 0, y: -15)
                ic.addChild(l)
                boonRow.addChild(ic)
                x += 26
            }
            for p in Passive.allCases where run.passives[p] != nil {
                let ic = SKSpriteNode(texture: Tex.icon(.boon(p.patron)), size: CGSize(width: 18, height: 18))
                ic.position = CGPoint(x: x, y: 0)
                ic.alpha = 0.8
                boonRow.addChild(ic)
                x += 20
            }
        }
    }

    func banner(_ title: String, _ sub: String = "", color: UIColor = UIColor(hex: 0xffe0c0), small: Bool = false) {
        bannerTitle.text = title
        bannerTitle.fontColor = color
        bannerTitle.fontSize = small ? 20 : 30
        bannerSub.text = sub
        for l in [bannerTitle, bannerSub] {
            l.removeAllActions()
            l.alpha = 0
            l.setScale(1.1)
            l.run(.sequence([
                .group([.fadeIn(withDuration: 0.25), .scale(to: 1, duration: 0.25)]),
                .wait(forDuration: small ? 0.9 : 1.9),
                .fadeOut(withDuration: 0.5),
            ]))
        }
    }

    func flashHurt() {
        hurt.removeAllActions()
        hurt.alpha = 0.3
        hurt.run(.fadeOut(withDuration: 0.35))
    }

    func fade(to a: CGFloat, duration: CGFloat, completion: @escaping () -> Void) {
        fadeNode.removeAllActions()
        fadeNode.run(.sequence([.fadeAlpha(to: a, duration: TimeInterval(duration)), .run(completion)]))
    }
}
