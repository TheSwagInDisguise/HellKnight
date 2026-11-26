import SpriteKit
import UIKit

/// Deterministic scenes for automated simulator screenshots.
/// Launch with `-shot <name>` (title, sanctum, game, game1, game2, boon, boss).
enum ShotMode {
    static let name: String? = UserDefaults.standard.string(forKey: "shot")

    static func initialScene(size: CGSize) -> SKScene? {
        guard let shot = name else { return nil }
        switch shot {
        case "title":
            return TitleScene(size: size)
        case "sanctum":
            Meta.shared.data.souls = 240
            Meta.shared.data.ranks = ["vigor": 2, "might": 1, "rebirth": 1]
            Meta.shared.data.runs = 7
            Meta.shared.data.wins = 1
            Meta.shared.data.bestDepth = 3
            return SanctumScene(size: size)
        default:
            let run = RunState(weapon: .blade)
            run.gold = 186
            run.souls = 37
            run.slots[.attack] = Boon(kind: .slot(.attack, .pyre), rarity: .rare)
            run.slots[.dash] = Boon(kind: .slot(.dash, .tempest), rarity: .common)
            run.passives[.bloodPact] = .common
            switch shot {
            case "game1":
                run.depth = 1
                run.room = 2
            case "game2":
                run.depth = 2
                run.room = 4
            case "boss":
                run.depth = 0
                run.room = 6
            case "rest":
                run.room = 2
                run.nextReward = .rest
            case "altar":
                run.depth = 1
                run.room = 2
                run.nextReward = .altar
            default:
                run.depth = 0
                run.room = 1
            }
            run.hp = run.maxHp * 0.72
            let g = GameScene(size: size, runData: run)
            g.shot = shot
            return g
        }
    }
}

extension GameScene {
    func setupShotRoom() {
        let b = room.bounds
        let c = CGPoint(x: b.midX, y: b.midY)
        var kinds: [EnemyKind] = [.imp, .imp, .archer, .brute, .wisp]
        if runData.depth >= 1 { kinds.append(.priest) }
        for (i, k) in kinds.enumerated() {
            let a = CGFloat(i) / CGFloat(kinds.count) * 2 * .pi + 0.4
            finishSpawn(k, at: room.resolve(c + CGPoint(angle: a, length: rnd(170, 280)), 40))
        }
        if shot == "boon" {
            let m = SKNode()
            world.addChild(m)
            m.run(.sequence([.wait(forDuration: 1.2), .run { [weak self] in
                self?.collect(.boon(.pyre)) {}
            }]))
        }
    }

    func updateShot(_ dt: CGFloat) {
        shotTimer += dt
        player.invuln = 1
        if shotTimer < 1.6 {
            controls.move = CGPoint(x: -0.2, y: 0.9)
        } else {
            controls.move = .zero
            if Int(shotTimer * 10) % 5 == 0 { controls.buffer[.attack] = 0.2 }
            if shotTimer > 3 && shotTimer < 3.1 { controls.buffer[.cast] = 0.2 }
            if shotTimer > 4.5 && shotTimer < 4.6 { controls.buffer[.special] = 0.2 }
        }
    }
}
