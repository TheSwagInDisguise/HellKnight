import SpriteKit
import UIKit

/// Dynamic 2D lighting: a screen-sized light map (dark ambient + additive lights) is
/// multiplied over the world, so rooms are dark except where torches, fire and magic glow.
extension GameScene {

    func setupLighting() {
        lightLayer.zPosition = 700
        lightLayer.blendMode = .multiply
        lightLayer.shouldEnableEffects = true
        lightBase.zPosition = -10
        lightLayer.addChild(lightBase)
        addChild(lightLayer)
        fogLayer.zPosition = 650
        addChild(fogLayer)
    }

    func ambientColor() -> UIColor {
        switch runData.depth {
        case 0: return UIColor(red: 0.36, green: 0.29, blue: 0.27, alpha: 1)
        case 1: return UIColor(red: 0.29, green: 0.32, blue: 0.27, alpha: 1)
        default: return UIColor(red: 0.27, green: 0.26, blue: 0.38, alpha: 1)
        }
    }

    /// Clears lights and fog for a new room.
    func resetLights() {
        lightLayer.removeAllChildren()
        lightLayer.addChild(lightBase)
        lightBase.color = ambientColor()
        fogLayer.removeAllChildren()
        playerLight = makeLight(radius: 560, color: UIColor(hex: 0xffe2bc), alpha: 0.7)
    }

    @discardableResult
    func makeLight(radius: CGFloat, color: UIColor, alpha: CGFloat) -> SKSpriteNode {
        let l = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: radius * 2, height: radius * 1.4))
        l.color = color
        l.colorBlendFactor = 1
        l.blendMode = .add
        l.alpha = alpha
        lightLayer.addChild(l)
        return l
    }

    /// A light fixed at a ground position, raised by `height`.
    @discardableResult
    func addLight(at p: CGPoint, height: CGFloat, radius: CGFloat, color: UIColor, alpha: CGFloat, flicker: Bool = false) -> SKSpriteNode {
        let l = makeLight(radius: radius, color: color, alpha: alpha)
        l.position = screenPoint(p, height: height)
        if flicker {
            let lo = alpha * 0.75
            l.run(.repeatForever(.sequence([
                .fadeAlpha(to: lo, duration: TimeInterval(rnd(0.08, 0.2))),
                .fadeAlpha(to: alpha, duration: TimeInterval(rnd(0.08, 0.2))),
            ])))
        }
        return l
    }

    /// A short burst of light (hits, explosions, casts).
    func flashLight(at p: CGPoint, radius: CGFloat, color: UIColor, alpha: CGFloat = 0.9, duration: CGFloat = 0.25) {
        let l = makeLight(radius: radius, color: color, alpha: alpha)
        l.position = screenPoint(p, height: 30)
        l.run(.sequence([.fadeOut(withDuration: TimeInterval(duration)), .removeFromParent()]))
    }

    /// True when a tall block or pillar stands between the camera and the player.
    func playerOccluded() -> Bool {
        guard let p = player?.position, let room = room else { return false }
        let sp = isoProject(p)
        var tall = room.blockCenters
        for pl in room.pillars where pl.blocksShots { tall.append(pl.pos) }
        for q in tall {
            if q.x + q.y >= p.x + p.y { continue }
            let sq = isoProject(q)
            if abs(sq.x - sp.x) > 56 { continue }
            let dy = sp.y - sq.y
            if dy > 0 && dy < 120 { return true }
        }
        return false
    }

    func addFog() {
        guard let room = room else { return }
        let pal = Palette.of(runData.depth)
        let b = room.bounds
        let tint = pal.ember.scaled(0.5)
        for _ in 0..<7 {
            let f = SKSpriteNode(texture: Tex.fog(), size: CGSize(width: rnd(500, 800), height: rnd(260, 380)))
            let g = CGPoint(x: rnd(b.minX, b.maxX), y: rnd(b.minY, b.maxY))
            f.position = screenPoint(g, height: rnd(0, 60))
            f.color = tint
            f.colorBlendFactor = 0.6
            f.alpha = rnd(0.45, 0.8)
            f.blendMode = .add
            fogLayer.addChild(f)
            let dx = rnd(60, 140) * (chance(0.5) ? 1 : -1)
            let t = TimeInterval(rnd(9, 16))
            f.run(.repeatForever(.sequence([
                .moveBy(x: dx, y: rnd(-15, 15), duration: t),
                .moveBy(x: -dx, y: rnd(-15, 15), duration: t),
            ])))
        }
    }

    func updateLighting(_ dt: CGFloat) {
        lightBase.position = cam.position
        lightBase.size = CGSize(width: size.width * cam.xScale * 1.5, height: size.height * cam.yScale * 1.5)
        if let p = player, let l = playerLight {
            l.position = screenPoint(p.position, height: 50)
        }
        if let p = player, let g = playerGhost {
            g.isHidden = !playerOccluded()
            if !g.isHidden {
                g.position = screenPoint(p.position) + p.body.position
                g.xScale = p.body.xScale
            }
        }
        for pr in projectiles {
            pr.light?.position = screenPoint(pr.position, height: 26)
        }
        for e in enemies {
            e.light?.position = screenPoint(e.position, height: 40)
        }
    }
}
