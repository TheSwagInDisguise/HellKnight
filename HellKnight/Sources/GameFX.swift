import SpriteKit
import UIKit

extension GameScene {

    func attackVisual(at p: CGPoint, angle: CGFloat, range: CGFloat, arcDeg: CGFloat, color: UIColor, finisher: Bool) {
        let s: SKSpriteNode
        if arcDeg <= 50 {
            s = SKSpriteNode(texture: Tex.thrust(), size: CGSize(width: range * 1.05, height: finisher ? 34 : 22))
            s.anchorPoint = CGPoint(x: 0, y: 0.5)
            s.position = p + CGPoint(angle: angle, length: 8)
        } else {
            let key = Int((arcDeg / 10).rounded()) * 10
            s = SKSpriteNode(texture: Tex.slash(arcDeg: key), size: CGSize(width: range * 2.3, height: range * 2.3))
            s.position = p
        }
        s.zRotation = angle
        s.color = color
        s.colorBlendFactor = 0.65
        s.blendMode = .add
        s.alpha = finisher ? 1 : 0.85
        s.zPosition = 40
        world.addChild(s)
        s.run(.sequence([
            .group([.fadeOut(withDuration: 0.18), .scale(by: finisher ? 1.15 : 1.06, duration: 0.18)]),
            .removeFromParent(),
        ]))
    }

    func burst(at p: CGPoint, color: UIColor, count: Int, speed: CGFloat, size: CGFloat = 7, life: CGFloat = 0.4) {
        let tex = Tex.spark()
        for _ in 0..<count {
            let s = SKSpriteNode(texture: tex, size: CGSize(width: size, height: size))
            s.color = color
            s.colorBlendFactor = 1
            s.blendMode = .add
            s.position = p
            s.zPosition = 50
            world.addChild(s)
            let v = speed * rnd(0.35, 1)
            let l = life * rnd(0.6, 1.2)
            let d = CGPoint(angle: rnd(0, 2 * .pi), length: v * l)
            s.run(.sequence([
                .group([
                    .moveBy(x: d.x, y: d.y, duration: TimeInterval(l)),
                    .fadeOut(withDuration: TimeInterval(l)),
                    .scale(to: 0.2, duration: TimeInterval(l)),
                ]),
                .removeFromParent(),
            ]))
        }
    }

    func shockwave(at p: CGPoint, radius: CGFloat, color: UIColor) {
        let r = SKSpriteNode(texture: Tex.ringTex(), size: CGSize(width: radius * 2, height: radius * 2))
        r.position = p
        r.color = color
        r.colorBlendFactor = 1
        r.blendMode = .add
        r.zPosition = 43
        r.setScale(0.2)
        world.addChild(r)
        r.run(.sequence([.group([.scale(to: 1.05, duration: 0.22), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
    }

    func damageNumber(_ v: CGFloat, at p: CGPoint, color: UIColor, crit: Bool) {
        let text = crit ? "\(Int(v.rounded()))!" : "\(Int(v.rounded()))"
        let l = makeLabel(text, size: crit ? 22 : 15, color: color, font: Font.heavy)
        l.position = p + CGPoint(x: rnd(-12, 12), y: 8)
        l.zPosition = 60
        world.addChild(l)
        if crit {
            l.setScale(1.5)
            l.run(.scale(to: 1, duration: 0.15))
        }
        l.run(.sequence([
            .group([.moveBy(x: 0, y: 36, duration: 0.6), .sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.3)])]),
            .removeFromParent(),
        ]))
    }

    func floatText(_ text: String, at p: CGPoint, color: UIColor, size: CGFloat = 16) {
        let l = makeLabel(text, size: size, color: color, font: Font.heavy)
        l.position = p
        l.zPosition = 61
        world.addChild(l)
        l.run(.sequence([
            .group([.moveBy(x: 0, y: 40, duration: 1.0), .sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 0.4)])]),
            .removeFromParent(),
        ]))
    }

    @discardableResult
    func telegraphLine(from p: CGPoint, angle: CGFloat, length: CGFloat, width: CGFloat, duration: CGFloat) -> SKSpriteNode {
        let n = SKSpriteNode(color: UIColor(hex: 0xff2a1a, alpha: 0.2), size: CGSize(width: length, height: width))
        n.anchorPoint = CGPoint(x: 0, y: 0.5)
        n.position = p
        n.zRotation = angle
        n.zPosition = 3
        let fill = SKSpriteNode(color: UIColor(hex: 0xff3a1a, alpha: 0.35), size: CGSize(width: length, height: width))
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.xScale = 0.02
        fill.zPosition = 0.1
        n.addChild(fill)
        world.addChild(n)
        fill.run(.scaleX(to: 1, duration: TimeInterval(duration)))
        n.run(.sequence([.wait(forDuration: TimeInterval(duration)), .fadeOut(withDuration: 0.1), .removeFromParent()]))
        return n
    }

    func telegraphCircle(at p: CGPoint, radius: CGFloat, duration: CGFloat) {
        let o = SKSpriteNode(texture: Tex.teleCircle(), size: CGSize(width: radius * 2, height: radius * 2))
        o.position = p
        o.zPosition = 3
        o.alpha = 0
        world.addChild(o)
        let inner = SKSpriteNode(texture: Tex.teleCircle(), size: o.size)
        inner.setScale(0.05)
        inner.zPosition = 0.1
        o.addChild(inner)
        o.run(.sequence([
            .fadeIn(withDuration: 0.1),
            .wait(forDuration: TimeInterval(max(0, duration - 0.1))),
            .removeFromParent(),
        ]))
        inner.run(.scale(to: 1, duration: TimeInterval(duration)))
    }

    func lightningBolt(from a: CGPoint, to b: CGPoint, color: UIColor = UIColor(hex: 0xffe14a)) {
        let path = CGMutablePath()
        path.move(to: a)
        let segs = 6
        let d = b - a
        let perpUnit = CGPoint(x: -d.y, y: d.x).normalized
        for i in 1..<segs {
            let t = CGFloat(i) / CGFloat(segs)
            let p = a + d * t + perpUnit * rnd(-14, 14)
            path.addLine(to: p)
        }
        path.addLine(to: b)
        let s = SKShapeNode(path: path)
        s.strokeColor = color
        s.lineWidth = 3
        s.glowWidth = 3
        s.blendMode = .add
        s.zPosition = 45
        world.addChild(s)
        s.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
    }

    func afterimage() {
        guard let p = player else { return }
        let s = SKSpriteNode(texture: Tex.knight(), size: p.body.size)
        s.position = p.position + p.body.position
        s.zPosition = p.zPosition - 0.01
        s.color = runData.slots[.dash]?.patron.color ?? UIColor(hex: 0x8fd8ff)
        s.colorBlendFactor = 0.8
        s.alpha = 0.5
        s.blendMode = .add
        world.addChild(s)
        s.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
    }
}
