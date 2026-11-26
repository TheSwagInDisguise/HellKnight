import SpriteKit
import UIKit

extension GameScene {

    /// Weapon trail laid flat on the isometric ground.
    func attackVisual(at p: CGPoint, angle: CGFloat, range: CGFloat, arcDeg: CGFloat, color: UIColor, finisher: Bool) {
        let s: SKSpriteNode
        if arcDeg <= 50 {
            s = SKSpriteNode(texture: Tex.thrust(), size: CGSize(width: range * 1.05, height: finisher ? 40 : 26))
            s.anchorPoint = CGPoint(x: 0, y: 0.5)
            s.position = p + CGPoint(angle: angle, length: 8)
        } else {
            let key = Int((arcDeg / 10).rounded()) * 10
            s = SKSpriteNode(texture: Tex.slash(arcDeg: key), size: CGSize(width: range * 2.3, height: range * 2.3))
            s.position = p
        }
        s.zRotation = angle
        s.color = color
        s.colorBlendFactor = 0.55
        s.blendMode = .add
        s.alpha = finisher ? 1 : 0.85
        s.zPosition = 9
        world.addChild(s)
        s.run(.sequence([
            .group([.fadeOut(withDuration: 0.2), .scale(by: finisher ? 1.15 : 1.06, duration: 0.2)]),
            .removeFromParent(),
        ]))
    }

    func burst(at p: CGPoint, color: UIColor, count: Int, speed: CGFloat, size: CGFloat = 7, life: CGFloat = 0.4) {
        let tex = Tex.spark()
        let base = isoProject(p)
        for _ in 0..<count {
            let s = SKSpriteNode(texture: tex, size: CGSize(width: size, height: size))
            s.color = color
            s.colorBlendFactor = 1
            s.blendMode = .add
            let h = rnd(6, 40)
            s.position = base + CGPoint(x: 0, y: h)
            s.zPosition = 5
            topLayer.addChild(s)
            let v = speed * rnd(0.35, 1)
            let l = life * rnd(0.6, 1.2)
            let d = isoProject(CGPoint(angle: rnd(0, 2 * .pi), length: v * l))
            let rise = rnd(10, 40) * l * 2
            s.run(.sequence([
                .group([
                    .moveBy(x: d.x, y: d.y + rise, duration: TimeInterval(l)),
                    .fadeOut(withDuration: TimeInterval(l)),
                    .scale(to: 0.2, duration: TimeInterval(l)),
                ]),
                .removeFromParent(),
            ]))
        }
    }

    /// Ink or blood splatter left on the floor.
    func splat(at p: CGPoint, size: CGFloat, color: UIColor, alpha: CGFloat, fade: CGFloat) {
        let s = SKSpriteNode(texture: Tex.splat(Int.random(in: 0..<4)), size: CGSize(width: size, height: size))
        s.position = p + CGPoint(x: rnd(-6, 6), y: rnd(-6, 6))
        s.zRotation = rnd(0, 2 * .pi)
        s.color = color
        s.colorBlendFactor = 1
        s.alpha = alpha
        s.zPosition = 1.3
        s.setScale(0.6)
        world.addChild(s)
        s.run(.sequence([
            .scale(to: 1, duration: 0.08),
            .wait(forDuration: TimeInterval(fade * 0.6)),
            .fadeOut(withDuration: TimeInterval(fade * 0.4)),
            .removeFromParent(),
        ]))
    }

    func shockwave(at p: CGPoint, radius: CGFloat, color: UIColor) {
        let r = SKSpriteNode(texture: Tex.ringTex(), size: CGSize(width: radius * 2, height: radius * 2))
        r.position = p
        r.color = color
        r.colorBlendFactor = 1
        r.blendMode = .add
        r.zPosition = 8
        r.setScale(0.2)
        world.addChild(r)
        r.run(.sequence([.group([.scale(to: 1.05, duration: 0.22), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
    }

    func damageNumber(_ v: CGFloat, at p: CGPoint, height: CGFloat, color: UIColor, crit: Bool) {
        let text = crit ? "\(Int(v.rounded()))!" : "\(Int(v.rounded()))"
        let l = makeLabel(text, size: crit ? 24 : 17, color: color, font: Font.heavy)
        l.position = screenPoint(p, height: height) + CGPoint(x: rnd(-12, 12), y: 0)
        l.zPosition = 20
        let sh = makeLabel(text, size: l.fontSize, color: Ink.black, font: Font.heavy)
        sh.position = CGPoint(x: 1.5, y: -1.5)
        sh.zPosition = -0.1
        l.addChild(sh)
        topLayer.addChild(l)
        if crit {
            l.setScale(1.6)
            l.run(.scale(to: 1, duration: 0.15))
        }
        l.run(.sequence([
            .group([.moveBy(x: 0, y: 36, duration: 0.6), .sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.3)])]),
            .removeFromParent(),
        ]))
    }

    func floatText(_ text: String, at p: CGPoint, height: CGFloat = 60, color: UIColor, size: CGFloat = 16) {
        let l = makeLabel(text, size: size, color: color, font: Font.heavy)
        l.position = screenPoint(p, height: height)
        l.zPosition = 21
        let sh = makeLabel(text, size: size, color: Ink.black, font: Font.heavy)
        sh.position = CGPoint(x: 1.5, y: -1.5)
        sh.zPosition = -0.1
        l.addChild(sh)
        topLayer.addChild(l)
        l.run(.sequence([
            .group([.moveBy(x: 0, y: 40, duration: 1.0), .sequence([.wait(forDuration: 0.6), .fadeOut(withDuration: 0.4)])]),
            .removeFromParent(),
        ]))
    }

    @discardableResult
    func telegraphLine(from p: CGPoint, angle: CGFloat, length: CGFloat, width: CGFloat, duration: CGFloat) -> SKSpriteNode {
        let n = SKSpriteNode(color: UIColor(hex: 0xc4161d, alpha: 0.22), size: CGSize(width: length, height: width))
        n.anchorPoint = CGPoint(x: 0, y: 0.5)
        n.position = p
        n.zRotation = angle
        n.zPosition = 3
        let fill = SKSpriteNode(color: UIColor(hex: 0xff2a1a, alpha: 0.4), size: CGSize(width: length, height: width))
        fill.anchorPoint = CGPoint(x: 0, y: 0.5)
        fill.xScale = 0.02
        fill.zPosition = 0.1
        n.addChild(fill)
        for side in [CGFloat(-1), CGFloat(1)] {
            let edge = SKSpriteNode(color: UIColor(hex: 0xff3a1a, alpha: 0.9), size: CGSize(width: length, height: 2))
            edge.anchorPoint = CGPoint(x: 0, y: 0.5)
            edge.position = CGPoint(x: 0, y: side * width / 2)
            edge.zPosition = 0.2
            n.addChild(edge)
        }
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

    /// Jagged lightning drawn in screen space between two raised ground points.
    func lightningBolt(from a: CGPoint, to b: CGPoint, fromHeight: CGFloat, toHeight: CGFloat,
                       color: UIColor = Patron.tempest.color) {
        let sa = screenPoint(a, height: fromHeight)
        let sb = screenPoint(b, height: toHeight)
        let path = CGMutablePath()
        path.move(to: sa)
        let segs = 7
        let d = sb - sa
        let perpUnit = CGPoint(x: -d.y, y: d.x).normalized
        for i in 1..<segs {
            let t = CGFloat(i) / CGFloat(segs)
            path.addLine(to: sa + d * t + perpUnit * rnd(-14, 14))
        }
        path.addLine(to: sb)
        let s = SKShapeNode(path: path)
        s.strokeColor = color
        s.lineWidth = 3
        s.glowWidth = 4
        s.blendMode = .add
        s.zPosition = 10
        topLayer.addChild(s)
        let core = SKShapeNode(path: path)
        core.strokeColor = .white
        core.lineWidth = 1.2
        core.zPosition = 0.1
        s.addChild(core)
        s.run(.sequence([.fadeOut(withDuration: 0.22), .removeFromParent()]))
    }

    func afterimage() {
        guard let p = player else { return }
        let n = SKNode()
        n.position = p.position
        n.zPosition = p.zPosition - 0.01
        let b = Billboard()
        n.addChild(b)
        let s = SKSpriteNode(texture: Tex.knight(), size: Player.bodySize)
        s.anchorPoint = Player.bodyAnchor
        s.xScale = p.body.xScale
        s.position = p.body.position
        s.color = runData.slots[.dash]?.patron.color ?? Ink.bone
        s.colorBlendFactor = 0.9
        s.alpha = 0.5
        b.addChild(s)
        world.addChild(n)
        n.run(.sequence([.fadeOut(withDuration: 0.22), .removeFromParent()]))
    }
}
