import SpriteKit
import UIKit

extension GameScene {

    // MARK: - Player update

    func updatePlayer(_ dt: CGFloat) {
        guard let p = player else { return }
        p.invuln = max(0, p.invuln - dt)
        p.specialCD = max(0, p.specialCD - dt)
        p.attackTimer = max(0, p.attackTimer - dt)
        p.comboReset -= dt
        if p.comboReset <= 0 { p.comboIndex = 0 }
        if p.dashCharges < runData.maxDash {
            p.dashRecharge -= dt
            if p.dashRecharge <= 0 {
                p.dashCharges += 1
                p.dashRecharge = 0.55
            }
        }
        if p.castCharges < runData.maxCast {
            p.castRecharge -= dt
            if p.castRecharge <= 0 {
                p.castCharges += 1
                p.castRecharge = 2.5
            }
        }

        if p.dashTime <= 0 && p.dashCharges > 0 && controls.consume(.dash) {
            startDash()
        }

        if p.dashTime > 0 {
            p.dashTime -= dt
            p.position = room.resolve(p.position + p.dashDir * (1100 * dt), p.radius)
            p.afterimageTimer -= dt
            if p.afterimageTimer <= 0 {
                p.afterimageTimer = 0.025
                afterimage()
            }
            if p.dashTime <= 0 { endDash() }
        } else {
            let mv = moveInput
            var speed: CGFloat = 255 * runData.moveMult
            if p.attackTimer > 0 { speed *= 0.3 }
            var delta = mv * (speed * dt)
            if p.lungeTime > 0 {
                p.lungeTime -= dt
                delta = delta + p.lungeVel * dt
            }
            p.position = room.resolve(p.position + delta, p.radius)
            p.moving = mv.length > 0.15
            if p.moving && p.attackTimer <= 0 && !p.isSwinging { p.setFacing(mv.angle) }
            p.animate(dt)
            if p.attackTimer <= 0 {
                if controls.attackHeld || controls.consume(.attack) {
                    _ = controls.consume(.attack)
                    doAttack()
                } else if p.specialCD <= 0 && controls.consume(.special) {
                    doSpecial()
                } else if p.castCharges > 0 && controls.consume(.cast) {
                    doCast()
                }
            }
        }
        p.zPosition = depthZ(p.position)
    }

    func aimAngle(range: CGFloat) -> CGFloat {
        let mv = moveInput
        let steering = mv.length > 0.2
        let base = steering ? mv.angle : player.facing
        var best: Enemy?
        var bestScore = CGFloat.greatestFiniteMagnitude
        for e in enemies where e.alive {
            let d = e.position - player.position
            let dist = d.length
            if dist > range { continue }
            let ad = abs(angleDiff(d.angle, base))
            if steering && ad > 0.9 && dist > 70 { continue }
            let score = dist + ad * (steering ? 150 : 60)
            if score < bestScore {
                bestScore = score
                best = e
            }
        }
        if let b = best { return (b.position - player.position).angle }
        return base
    }

    func slotColor(_ s: Slot) -> UIColor {
        if let b = runData.slots[s] { return b.patron.color }
        return UIColor(hex: 0xffd0a0)
    }

    // MARK: - Actions

    func doAttack() {
        guard let p = player else { return }
        let combo = runData.weapon.combo
        let i = p.comboIndex % combo.count
        let sw = combo[i]
        let finisher = i == combo.count - 1
        let range = sw.range * runData.rangeMult
        let a = aimAngle(range: range + 140)
        p.attackTimer = sw.time / runData.attackSpeed
        p.comboIndex = (i + 1) % combo.count
        p.comboReset = p.attackTimer + 0.4
        if sw.lunge > 0 {
            p.lungeVel = CGPoint(angle: a, length: sw.lunge / 0.1)
            p.lungeTime = 0.1
        }
        p.playSwing(angle: a, arcDeg: sw.arc)
        attackVisual(at: p.position, angle: a, range: range, arcDeg: sw.arc, color: slotColor(.attack), finisher: finisher)
        sfx(.swing, finisher ? 1 : 0.7)
        let hits = arcHit(origin: p.position, angle: a, range: range, arc: sw.arc * .pi / 180,
                          damage: sw.damage, knock: sw.knock, slot: .attack)
        if hits > 0 {
            hitstop = finisher ? 0.07 : 0.03
            addShake(finisher ? 6 : 2.5)
            if finisher { punch(0.035) }
            sfx(.hit, 0.8)
            if finisher { Haptics.light() }
        }
    }

    func doSpecial() {
        guard let p = player else { return }
        let w = runData.weapon
        p.specialCD = w.specialCooldown * (runData.hasRelic(.hourglass) ? 0.7 : 1)
        p.attackTimer = 0.32 / runData.attackSpeed
        let col = slotColor(.special)
        sfx(.special)
        switch w.special {
        case .spin:
            let range = 140 * runData.rangeMult
            p.spin()
            let s = SKSpriteNode(texture: Tex.slash(arcDeg: 340), size: CGSize(width: range * 2.3, height: range * 2.3))
            s.zRotation = rnd(0, 2 * .pi)
            s.position = p.position
            s.color = col
            s.colorBlendFactor = 0.7
            s.blendMode = .add
            s.zPosition = 40
            world.addChild(s)
            s.run(.sequence([.group([.rotate(byAngle: .pi * 2, duration: 0.28), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
            let hits = arcHit(origin: p.position, angle: 0, range: range, arc: .pi * 2, damage: w.specialDamage, knock: 130, slot: .special)
            flashLight(at: p.position, radius: 320, color: col, alpha: 0.7, duration: 0.3)
            if hits > 0 {
                hitstop = 0.06
                addShake(5)
                punch(0.04)
            }
        case .hurl:
            let a = aimAngle(range: 700)
            p.setFacing(a)
            p.playSwing(angle: a, arcDeg: 0)
            let pr = spawnProjectile(at: p.position + CGPoint(angle: a, length: 20), vel: CGPoint(angle: a, length: 980),
                                     damage: w.specialDamage, hostile: false, texture: Tex.pike(),
                                     size: CGSize(width: 90, height: 14), radius: 16, life: 0.6, pierce: 99, slot: .special, knock: 90)
            let g = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: 70, height: 40))
            g.color = col
            g.colorBlendFactor = 1
            g.blendMode = .add
            g.zPosition = -1
            pr.art.addChild(g)
        case .slam:
            let range = 160 * runData.rangeMult
            p.playSwing(angle: p.facing, arcDeg: 0)
            shockwave(at: p.position, radius: range, color: col)
            burst(at: p.position, color: col, count: 22, speed: 380)
            addShake(9)
            punch(0.05)
            flashLight(at: p.position, radius: 380, color: col, alpha: 0.8, duration: 0.35)
            Haptics.heavy()
            let hits = arcHit(origin: p.position, angle: 0, range: range, arc: .pi * 2, damage: w.specialDamage, knock: 230, slot: .special)
            if hits > 0 { hitstop = 0.08 }
        }
    }

    func doCast() {
        guard let p = player else { return }
        p.castCharges -= 1
        if p.castRecharge <= 0 { p.castRecharge = 2.5 }
        let a = aimAngle(range: 750)
        p.setFacing(a)
        p.attackTimer = 0.2
        let col = runData.slots[.cast]?.patron.color ?? UIColor(hex: 0xff3a2a)
        spawnProjectile(at: p.position + CGPoint(angle: a, length: 22), vel: CGPoint(angle: a, length: 820),
                        damage: 32, hostile: false, texture: Tex.orb(), size: CGSize(width: 30, height: 30),
                        radius: 14, color: col, life: 1.1, pierce: runData.hasRelic(.lantern) ? 1 : 0, slot: .cast, knock: 80)
        sfx(.cast)
    }

    func startDash() {
        guard let p = player else { return }
        p.dashCharges -= 1
        if p.dashRecharge <= 0 { p.dashRecharge = 0.55 }
        let mv = moveInput
        let dir = mv.length > 0.2 ? mv.normalized : CGPoint(angle: p.facing)
        p.dashDir = dir
        p.dashTime = 0.16
        p.attackTimer = 0
        p.lungeTime = 0
        p.invuln = max(p.invuln, 0.22)
        p.setFacing(dir.angle)
        sfx(.dash, 0.8)
        burst(at: p.position, color: UIColor(white: 0.8, alpha: 1), count: 6, speed: 120)
        if runData.has(.stormStep) {
            let m = runData.pm(.stormStep)
            let targets = enemies.filter { $0.alive && $0.position.distance(to: p.position) < 260 }
                .sorted { $0.position.distance(to: p.position) < $1.position.distance(to: p.position) }
                .prefix(3)
            for e in targets {
                lightningBolt(from: e.position, to: e.position, fromHeight: 260, toHeight: 10)
                dealDamage(e, 14 * m * runData.damageMult, color: Patron.tempest.color)
            }
        }
    }

    func endDash() {
        guard let p = player, let b = runData.slots[.dash] else { return }
        let m = b.rarity.mult
        shockwave(at: p.position, radius: 95, color: b.patron.color)
        _ = arcHit(origin: p.position, angle: 0, range: 95, arc: .pi * 2, damage: 15 * m, knock: 60, slot: .dash)
    }

    // MARK: - Damage

    @discardableResult
    func arcHit(origin: CGPoint, angle: CGFloat, range: CGFloat, arc: CGFloat, damage: CGFloat, knock: CGFloat, slot: Slot?) -> Int {
        var hits = 0
        var leeched = false
        let full = arc >= .pi * 1.99
        for e in enemies where e.alive {
            let d = e.position - origin
            let dist = d.length
            if dist - e.radius > range { continue }
            if !full && dist > e.radius + 12 {
                let tol = atan2(e.radius, max(dist, 1))
                if abs(angleDiff(d.angle, angle)) > arc / 2 + tol { continue }
            }
            hits += 1
            hitEnemy(e, base: damage, slot: slot, dir: d.normalized, knock: knock, leech: &leeched)
        }
        hitBreakables(origin: origin, range: range, angle: angle, arc: arc)
        for pr in projectiles where pr.hostile && !pr.dead {
            let d = pr.position - origin
            if d.length < range + 8 && (full || abs(angleDiff(d.angle, angle)) < arc / 2 + 0.25) {
                pr.dead = true
                burst(at: pr.position, color: Ink.bone, count: 5, speed: 120, size: 5, life: 0.25)
            }
        }
        return hits
    }

    func hitEnemy(_ e: Enemy, base: CGFloat, slot: Slot?, dir: CGPoint, knock: CGFloat, leech: inout Bool) {
        guard e.alive else { return }
        var dmg = base * runData.damageMult
        var crit = false
        if let s = slot, let b = runData.slots[s] {
            let m = b.rarity.mult
            switch b.patron {
            case .pyre:
                dmg *= 1 + 0.1 * m
                e.applyBurn(dps: 5 * m * (1 + 0.5 * runData.pm(.kindling)), time: 3)
            case .rime:
                dmg *= 1 + 0.1 * m
                let amt = min(0.75, 0.3 + 0.05 * m + 0.1 * runData.pm(.permafrost))
                e.applyChill(amount: amt, time: 3 + runData.pm(.permafrost))
            case .tempest:
                let jumps = 2 + (runData.has(.overcharge) ? 1 : 0)
                chainLightning(from: e, damage: 8 * m * (1 + 0.5 * runData.pm(.overcharge)), jumps: jumps)
            case .sanguine:
                dmg *= 1 + 0.2 * m
                if !leech {
                    leech = true
                    healPlayer(1.5 * m, quiet: true)
                }
            case .umbral:
                if chance(0.12 * m) { crit = true }
            }
        }
        if crit { dmg *= 3 + runData.pm(.assassin) }
        if runData.hasRelic(.crown) && runData.hp >= runData.maxHp * 0.8 { dmg *= 1.25 }
        e.knockVel = e.knockVel + dir * (knock * 6 * e.knockResist)
        dealDamage(e, dmg, crit: crit, color: crit ? Patron.umbral.color : .white)
    }

    func dealDamage(_ e: Enemy, _ amount: CGFloat, crit: Bool = false, color: UIColor = .white) {
        guard e.alive else { return }
        e.takeDamage(amount)
        e.flashHit()
        flashLight(at: e.position, radius: crit ? 260 : 170, color: crit ? Patron.umbral.color : UIColor(hex: 0xffd8b0), alpha: 0.5, duration: 0.15)
        damageNumber(amount, at: e.position, height: e.bodyHeight * 0.8, color: color, crit: crit)
        splat(at: e.position, size: crit ? 40 : 26, color: Ink.black, alpha: 0.55, fade: 1.2)
        if e.hp <= 0 {
            killEnemy(e)
        } else {
            sfx(.enemyHurt, 0.4)
        }
    }

    func applyDot(_ e: Enemy, _ amount: CGFloat) {
        guard e.alive else { return }
        e.takeDamage(amount)
        damageNumber(amount, at: e.position, height: e.bodyHeight * 0.8, color: Patron.pyre.color, crit: false)
        if e.hp <= 0 { killEnemy(e) }
    }

    func killEnemy(_ e: Enemy, rewards: Bool = true) {
        guard e.alive else { return }
        e.alive = false
        e.hpBack.isHidden = true
        if let l = e.light {
            e.light = nil
            l.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
        }
        burst(at: e.position, color: e.deathColor, count: e is Boss ? 50 : 16, speed: e is Boss ? 420 : 240)
        splat(at: e.position, size: e is Boss ? 260 : 80 + e.radius * 2, color: Ink.black, alpha: 0.85, fade: 14)
        splat(at: e.position, size: e is Boss ? 160 : 40 + e.radius, color: Ink.blood, alpha: 0.6, fade: 14)
        sfx(.death, 0.5)
        if rewards {
            runData.kills += 1
            runData.souls += e.elite ? 3 : 1
            if !(e is Boss) && chance(0.28) {
                let c = Pickup(reward: nil, coinValue: Int.random(in: 3...8) + 2 * runData.depth)
                c.position = e.position
                c.zPosition = 4
                world.addChild(c)
                pickups.append(c)
            }
            if runData.has(.bloodPact) { healPlayer(2 * runData.pm(.bloodPact), quiet: true) }
            if runData.hasRelic(.bloodstone) { healPlayer(2, quiet: true) }
            if runData.has(.immolation) && e.burnTime > 0 {
                explosion(at: e.position, radius: 90, damage: 20 * runData.pm(.immolation), hostile: false, color: Patron.pyre.color)
            }
        }
        if let b = e as? Boss, b === boss { bossDefeated() }
        e.run(.sequence([.group([.fadeOut(withDuration: 0.25), .scale(to: 1.3, duration: 0.25)]), .removeFromParent()]))
    }

    func chainLightning(from start: Enemy, damage: CGFloat, jumps: Int) {
        var current = start
        var hitSet: Set<ObjectIdentifier> = [ObjectIdentifier(start)]
        for _ in 0..<jumps {
            let from = current.position
            let candidates = enemies.filter { $0.alive && !hitSet.contains(ObjectIdentifier($0)) && $0.position.distance(to: from) < 220 }
            guard let next = candidates.min(by: { $0.position.distance(to: from) < $1.position.distance(to: from) }) else { break }
            hitSet.insert(ObjectIdentifier(next))
            lightningBolt(from: from, to: next.position, fromHeight: 30, toHeight: 30)
            dealDamage(next, damage * runData.damageMult, color: Patron.tempest.color)
            current = next
        }
    }

    func explosion(at p: CGPoint, radius: CGFloat, damage: CGFloat, hostile: Bool, color: UIColor) {
        let g = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: radius * 2.6, height: radius * 2.6))
        g.color = color
        g.colorBlendFactor = 1
        g.blendMode = .add
        g.position = p
        g.zPosition = 44
        g.setScale(0.4)
        world.addChild(g)
        g.run(.sequence([.group([.scale(to: 1, duration: 0.12), .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
        shockwave(at: p, radius: radius, color: color)
        burst(at: p, color: color, count: 16, speed: radius * 3)
        sfx(.explode, 0.7)
        addShake(hostile ? 6 : 4)
        flashLight(at: p, radius: radius * 3.2, color: color, alpha: 1, duration: 0.45)
        if hostile {
            if let pl = player, pl.position.distance(to: p) < radius + pl.radius * 0.5 {
                hurtPlayer(damage, from: p)
            }
        } else {
            for e in enemies where e.alive && e.position.distance(to: p) < radius + e.radius {
                dealDamage(e, damage * runData.damageMult, color: color)
            }
            hitBreakables(origin: p, range: radius, angle: 0, arc: .pi * 2)
        }
    }

    func delayedExplosion(at p: CGPoint, radius: CGFloat, delay: CGFloat, damage: CGFloat, color: UIColor) {
        telegraphCircle(at: p, radius: radius, duration: delay)
        let m = SKNode()
        m.position = p
        world.addChild(m)
        m.run(.sequence([
            .wait(forDuration: TimeInterval(delay)),
            .run { [weak self] in self?.explosion(at: p, radius: radius, damage: damage, hostile: true, color: color) },
            .removeFromParent(),
        ]))
    }

    func hurtPlayer(_ amount: CGFloat, from src: CGPoint?) {
        guard state == .playing, let p = player else { return }
        if p.invuln > 0 || p.dashTime > 0 { return }
        if runData.has(.evasion) && chance(min(0.6, 0.1 * runData.pm(.evasion))) {
            floatText("DODGE", at: p.position, height: 80, color: Patron.umbral.color)
            p.invuln = 0.3
            return
        }
        var dmg = amount * runData.damageTakenMult
        if runData.has(.glacialArmor) { dmg *= max(0.5, 1 - 0.1 * runData.pm(.glacialArmor)) }
        runData.hp -= dmg
        p.invuln = 0.75
        p.flashHurt()
        damageNumber(dmg, at: p.position, height: 70, color: Ink.blood.scaled(1.4), crit: false)
        splat(at: p.position, size: 46, color: Ink.blood, alpha: 0.8, fade: 4)
        addShake(7)
        hitstop = 0.06
        hud.flashHurt()
        punch(0.03)
        flashLight(at: p.position, radius: 240, color: Ink.blood, alpha: 0.8, duration: 0.3)
        Haptics.heavy()
        sfx(.playerHurt)
        if let s = src {
            p.lungeVel = (p.position - s).normalized * 320
            p.lungeTime = 0.1
        }
        if runData.hp <= 0 {
            if runData.hasRelic(.phoenix) && !runData.phoenixUsed {
                runData.phoenixUsed = true
                runData.hp = runData.maxHp * 0.4
                p.invuln = 2.0
                hud.banner("Phoenix Feather", "Rise from the ashes", color: Relic.phoenix.color)
                explosion(at: p.position, radius: 180, damage: 60, hostile: false, color: Relic.phoenix.color)
                for pr in projectiles where pr.hostile { pr.dead = true }
            } else if runData.revives > 0 {
                runData.revives -= 1
                runData.hp = runData.maxHp * 0.5
                p.invuln = 2.0
                hud.banner("Defiance of Death", "You refuse to fall", color: UIColor(hex: 0xff6a3a))
                explosion(at: p.position, radius: 160, damage: 60, hostile: false, color: UIColor(hex: 0xff6a3a))
                for pr in projectiles where pr.hostile { pr.dead = true }
            } else {
                runData.hp = 0
                playerDied()
            }
        }
    }

    func healPlayer(_ amt: CGFloat, quiet: Bool = false) {
        let before = runData.hp
        runData.hp = min(runData.maxHp, runData.hp + amt)
        let gained = runData.hp - before
        if gained >= 1, let p = player {
            floatText("+\(Int(gained.rounded()))", at: p.position, height: 90, color: UIColor(hex: 0x7dff8a), size: quiet ? 13 : 18)
        }
    }

    // MARK: - Projectiles

    @discardableResult
    func spawnProjectile(at p: CGPoint, vel: CGPoint, damage: CGFloat, hostile: Bool, texture: SKTexture, size: CGSize,
                         radius: CGFloat, color: UIColor? = nil, life: CGFloat = 4, pierce: Int = 0, slot: Slot? = nil,
                         knock: CGFloat = 30) -> Projectile {
        let pr = Projectile(texture: texture, size: size)
        pr.position = p
        pr.vel = vel
        pr.damage = damage
        pr.hostile = hostile
        pr.radius = radius
        pr.life = life
        pr.pierce = pierce
        pr.slot = slot
        pr.knock = knock
        if let c = color {
            pr.tint = c
            pr.art.color = c
            pr.art.colorBlendFactor = 1
            pr.art.blendMode = .add
            let core = SKSpriteNode(texture: Tex.spark(), size: CGSize(width: size.width * 0.55, height: size.height * 0.55))
            core.zPosition = 1
            pr.art.addChild(core)
            let halo = SKSpriteNode(texture: Tex.glow(), size: CGSize(width: size.width * 2.2, height: size.height * 2.2))
            halo.color = c
            halo.colorBlendFactor = 1
            halo.blendMode = .add
            halo.alpha = 0.45
            halo.zPosition = -1
            pr.art.addChild(halo)
        } else {
            pr.tint = Ink.bone
        }
        pr.art.zRotation = screenAngle(vel.angle)
        pr.zPosition = depthZ(p) + 0.5
        pr.light = makeLight(radius: color == nil ? 90 : 170, color: color ?? Ink.bone, alpha: color == nil ? 0.35 : 0.85)
        pr.light?.position = screenPoint(p, height: 26)
        world.addChild(pr)
        projectiles.append(pr)
        return pr
    }

    func enemyOrb(from p: CGPoint, angle: CGFloat, speed: CGFloat, damage: CGFloat, color: UIColor) {
        spawnProjectile(at: p + CGPoint(angle: angle, length: 20), vel: CGPoint(angle: angle, length: speed),
                        damage: damage, hostile: true, texture: Tex.orb(), size: CGSize(width: 24, height: 24),
                        radius: 9, color: color, life: 5)
    }

    func updateProjectiles(_ dt: CGFloat) {
        for pr in projectiles where !pr.dead {
            pr.life -= dt
            pr.position = pr.position + pr.vel * dt
            pr.zPosition = depthZ(pr.position) + 0.5
            if pr.life <= 0 {
                pr.dead = true
                continue
            }
            if room.shotBlocked(pr.position) {
                pr.dead = true
                burst(at: pr.position, color: pr.tint, count: 4, speed: 90, size: 5, life: 0.25)
                continue
            }
            if pr.hostile {
                if let p = player, p.dashTime <= 0, pr.position.distance(to: p.position) < pr.radius + p.radius - 4 {
                    pr.dead = true
                    hurtPlayer(pr.damage, from: pr.position)
                }
            } else {
                for u in breakables where !u.broken && pr.position.distance(to: u.position) < pr.radius + u.radius {
                    breakUrn(u)
                }
                for e in enemies where e.alive && !pr.hitSet.contains(ObjectIdentifier(e)) {
                    if pr.position.distance(to: e.position) < pr.radius + e.radius {
                        pr.hitSet.insert(ObjectIdentifier(e))
                        var l = false
                        hitEnemy(e, base: pr.damage, slot: pr.slot, dir: pr.vel.normalized, knock: pr.knock, leech: &l)
                        sfx(.hit, 0.6)
                        pr.pierce -= 1
                        if pr.pierce < 0 {
                            pr.dead = true
                            burst(at: pr.position, color: pr.tint, count: 8, speed: 160)
                            break
                        }
                    }
                }
            }
        }
        for pr in projectiles where pr.dead {
            pr.light?.removeFromParent()
            pr.light = nil
            pr.run(.sequence([.fadeOut(withDuration: 0.08), .removeFromParent()]))
        }
        projectiles.removeAll { $0.dead }
    }

    // MARK: - Pickups

    func updatePickups(_ dt: CGFloat) {
        guard let p = player else { return }
        for pk in pickups where !pk.taken {
            pk.denyCD -= dt
            let d = pk.position.distance(to: p.position)
            if pk.isCoin {
                if d < 170 { pk.position = pk.position + (p.position - pk.position).normalized * (520 * dt) }
                if d < 24 {
                    pk.taken = true
                    runData.gold += runData.goldGain(pk.coinValue)
                    sfx(.pickup, 0.35)
                    pk.removeFromParent()
                }
                continue
            }
            guard d < pk.radius + p.radius, let r = pk.reward else { continue }
            if pk.price > 0 {
                if runData.gold >= pk.price {
                    runData.gold -= pk.price
                    pk.taken = true
                    takeAnim(pk)
                    collect(r) {}
                } else if pk.denyCD <= 0 {
                    pk.denyCD = 1.5
                    floatText("Need \(pk.price) gold", at: pk.position, height: 130, color: Ink.gold)
                }
            } else {
                pk.taken = true
                takeAnim(pk)
                collect(r) { [weak self] in self?.openDoors() }
            }
        }
        pickups.removeAll { $0.taken }
    }

    func takeAnim(_ pk: Pickup) {
        sfx(.pickup)
        burst(at: pk.position, color: pk.reward?.color ?? .yellow, count: 14, speed: 200)
        if let l = pk.light {
            pk.light = nil
            l.run(.sequence([.fadeOut(withDuration: 0.4), .removeFromParent()]))
        }
        pk.run(.sequence([.group([.scale(to: 1.5, duration: 0.2), .fadeOut(withDuration: 0.2)]), .removeFromParent()]))
    }

    // MARK: - Separation

    func separateEnemies() {
        let n = enemies.count
        if n >= 2 {
            for i in 0..<(n - 1) {
                let a = enemies[i]
                if !a.alive { continue }
                for j in (i + 1)..<n {
                    let b = enemies[j]
                    if !b.alive { continue }
                    let d = b.position - a.position
                    let md = a.radius + b.radius
                    let l = d.length
                    if l < md && l > 0.01 {
                        let push = d * ((md - l) / l * 0.5)
                        if !(a is Boss) { a.position = a.position - push }
                        if !(b is Boss) { b.position = b.position + push }
                    }
                }
            }
        }
        guard let p = player, p.dashTime <= 0 else { return }
        for e in enemies where e.alive {
            let d = p.position - e.position
            let md = e.radius + p.radius - 4
            let l = d.length
            if l < md && l > 0.01 {
                p.position = room.resolve(e.position + d * (md / l), p.radius)
            }
        }
    }
}
