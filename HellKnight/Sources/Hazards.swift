import SpriteKit
import UIKit

struct SpikeTrap {
    let pos: CGPoint
    let plate: SKSpriteNode
    let spikes: SKNode
}

extension GameScene {

    /// Enemy pathing target: straight at the goal if clear, otherwise along the flow field.
    func steer(_ e: Enemy, _ target: CGPoint) -> CGPoint {
        room.steer(from: e.position, to: target, radius: e.radius)
    }

    func updateHazards(_ dt: CGFloat) {
        guard let p = player else { return }

        // Refresh enemy pathing a few times per second.
        flowTimer -= dt
        if flowTimer <= 0 {
            flowTimer = 0.25
            room.computeFlow(to: p.position)
        }

        // Spike traps: idle → warning glow → spikes up.
        if !spikes.isEmpty {
            let period: CGFloat = 3.2
            let before = spikeClock.truncatingRemainder(dividingBy: period)
            spikeClock += dt
            let t = spikeClock.truncatingRemainder(dividingBy: period)
            let warn = t > 2.1 && t < 2.7
            let active = t >= 2.7
            let justFired = active && before < 2.7
            for s in spikes {
                s.plate.color = Ink.blood
                s.plate.colorBlendFactor = warn ? 0.35 + 0.25 * sin(t * 30) : 0
                s.spikes.isHidden = !active
            }
            if justFired {
                sfx(.hit, 0.4)
                for s in spikes {
                    let rect = CGRect(x: s.pos.x - 32, y: s.pos.y - 32, width: 64, height: 64)
                    if rect.insetBy(dx: -8, dy: -8).contains(p.position) && p.dashTime <= 0 {
                        hurtPlayer(12, from: s.pos)
                    }
                    for e in enemies where e.alive && !(e is Boss) && !(e is Wisp) && rect.contains(e.position) {
                        dealDamage(e, 18, color: Ink.blood.scaled(1.4))
                    }
                }
            }
        }

        // Burning pools hurt anyone standing in them.
        hazardTick -= dt
        if hazardTick <= 0 {
            hazardTick = 0.5
            if room.cellAt(p.position) == .lava && p.dashTime <= 0 {
                hurtPlayer(7, from: nil)
            }
            for e in enemies where e.alive && !(e is Boss) && !(e is Wisp) && room.cellAt(e.position) == .lava {
                e.applyBurn(dps: 10, time: 2)
            }
        }
    }

    /// An enemy knocked into a chasm plunges to its death.
    func enemyFell(_ e: Enemy) {
        guard e.alive else { return }
        floatText("FELL", at: e.position, height: 60, color: Ink.bone)
        e.up.run(.group([.moveBy(x: 0, y: -60, duration: 0.4), .scale(to: 0.3, duration: 0.4)]))
        killEnemy(e)
    }

    func breakUrn(_ u: Breakable) {
        guard !u.broken else { return }
        u.broken = true
        sfx(.hit, 0.7)
        burst(at: u.position, color: UIColor(hex: 0xc08050), count: 12, speed: 180)
        splat(at: u.position, size: 50, color: UIColor(hex: 0x3a2212), alpha: 0.7, fade: 10)
        room.pillars.removeAll { $0.pos.distance(to: u.position) < 1 }
        if chance(0.7) {
            for _ in 0..<Int.random(in: 1...3) {
                let c = Pickup(reward: nil, coinValue: Int.random(in: 2...6) + runData.depth * 2)
                c.position = u.position + CGPoint(x: rnd(-20, 20), y: rnd(-20, 20))
                c.zPosition = 4
                world.addChild(c)
                pickups.append(c)
            }
        }
        u.run(.sequence([.group([.fadeOut(withDuration: 0.2), .scale(to: 1.2, duration: 0.2)]), .removeFromParent()]))
        breakables.removeAll { $0 === u }
    }

    func hitBreakables(origin: CGPoint, range: CGFloat, angle: CGFloat, arc: CGFloat) {
        let full = arc >= .pi * 1.99
        for u in breakables where !u.broken {
            let d = u.position - origin
            if d.length - u.radius > range { continue }
            if !full && d.length > 24 && abs(angleDiff(d.angle, angle)) > arc / 2 + 0.3 { continue }
            breakUrn(u)
        }
    }
}
