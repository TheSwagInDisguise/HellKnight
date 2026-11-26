import UIKit

// MARK: - Patrons (the infernal powers that grant boons)

enum Patron: Int, CaseIterable {
    case pyre, rime, tempest, sanguine, umbral

    var name: String {
        switch self {
        case .pyre: return "Ignar, Lord of Pyres"
        case .rime: return "Sereth, the Frozen Widow"
        case .tempest: return "Kharos, the Storm Herald"
        case .sanguine: return "Mother Vey, the Blood Saint"
        case .umbral: return "Ombrae, the Veiled One"
        }
    }

    var short: String { ["Ignar", "Sereth", "Kharos", "Vey", "Ombrae"][rawValue] }

    var color: UIColor {
        switch self {
        case .pyre: return UIColor(hex: 0xff7a1a)
        case .rime: return UIColor(hex: 0x6fd6ff)
        case .tempest: return UIColor(hex: 0xffe14a)
        case .sanguine: return UIColor(hex: 0xff2a4a)
        case .umbral: return UIColor(hex: 0xb070ff)
        }
    }
}

enum Slot: Int, CaseIterable {
    case attack, special, cast, dash
    var name: String { ["Attack", "Special", "Cast", "Dash"][rawValue] }
}

enum Rarity: Int {
    case common, rare, epic, legendary

    var mult: CGFloat {
        let m: [CGFloat] = [1.0, 1.5, 2.0, 2.6]
        return m[rawValue]
    }
    var name: String { ["Common", "Rare", "Epic", "Legendary"][rawValue] }
    var color: UIColor {
        switch self {
        case .common: return UIColor(hex: 0xe8e0d0)
        case .rare: return UIColor(hex: 0x4aa3ff)
        case .epic: return UIColor(hex: 0xc060ff)
        case .legendary: return UIColor(hex: 0xffb020)
        }
    }

    static func roll(luck: CGFloat) -> Rarity {
        let r = CGFloat.random(in: 0..<1)
        if r < 0.03 + luck * 0.5 { return .legendary }
        if r < 0.12 + luck * 1.5 { return .epic }
        if r < 0.36 + luck * 2 { return .rare }
        return .common
    }
}

enum Passive: Int, CaseIterable {
    case kindling, immolation, permafrost, glacialArmor, overcharge, stormStep, vitality, bloodPact, assassin, evasion

    var patron: Patron { Patron(rawValue: rawValue / 2) ?? .pyre }

    var name: String {
        ["Kindling", "Immolation", "Permafrost", "Glacial Armor", "Overcharge",
         "Storm Step", "Vitality", "Blood Pact", "Assassin's Mark", "Evasion"][rawValue]
    }

    func desc(_ m: CGFloat) -> String {
        switch self {
        case .kindling: return "Burn deals +\(pct(0.5 * m)) damage."
        case .immolation: return "Foes slain while Burning explode for \(num(20 * m)) damage."
        case .permafrost: return "Chill slows \(pct(0.1 * m)) more and lasts \(num(m))s longer."
        case .glacialArmor: return "Take \(pct(min(0.5, 0.1 * m))) less damage from all sources."
        case .overcharge: return "Shock arcs to 1 more foe and deals +\(pct(0.5 * m)) damage."
        case .stormStep: return "Dashing calls lightning on up to 3 nearby foes for \(num(14 * m)) damage."
        case .vitality: return "+\(num(20 * m)) max health (also heals that much)."
        case .bloodPact: return "Slaying a foe restores \(num(2 * m)) health."
        case .assassin: return "Critical hits deal an extra +\(String(format: "%.1f", m))x damage."
        case .evasion: return "\(pct(0.1 * m)) chance to dodge any damage."
        }
    }
}

struct Boon {
    enum Kind {
        case slot(Slot, Patron)
        case passive(Passive)
    }

    let kind: Kind
    var rarity: Rarity

    static let slotNames: [[String]] = [
        ["Searing Strike", "Blazing Flourish", "Ember Bolt", "Cinder Step"],
        ["Frostbite Strike", "Glacial Flourish", "Rime Shard", "Frozen Step"],
        ["Thunder Strike", "Storm Flourish", "Arc Bolt", "Lightning Step"],
        ["Crimson Strike", "Hemorrhage Flourish", "Blood Bolt", "Vital Step"],
        ["Shadow Strike", "Veiled Flourish", "Night Bolt", "Phantom Step"],
    ]

    var patron: Patron {
        switch kind {
        case .slot(_, let p): return p
        case .passive(let pa): return pa.patron
        }
    }

    var title: String {
        switch kind {
        case .slot(let s, let p): return Boon.slotNames[p.rawValue][s.rawValue]
        case .passive(let pa): return pa.name
        }
    }

    var slotName: String {
        switch kind {
        case .slot(let s, _): return s.name
        case .passive: return "Blessing"
        }
    }

    var desc: String {
        let m = rarity.mult
        switch kind {
        case .passive(let pa):
            return pa.desc(m)
        case .slot(let s, let p):
            let who = s == .dash ? "Your Dash ends in a burst (\(num(15 * m)) dmg) that" : "Your \(s.name)"
            switch p {
            case .pyre:
                return "\(who) inflicts Burn: \(num(5 * m)) damage per second for 3s. +\(pct(0.1 * m)) damage."
            case .rime:
                return "\(who) inflicts Chill, slowing foes \(pct(0.3 + 0.05 * m)) for 3s. +\(pct(0.1 * m)) damage."
            case .tempest:
                return "\(who) unleashes Shock: lightning arcs to 2 nearby foes for \(num(8 * m)) damage."
            case .sanguine:
                return "\(who) deals +\(pct(0.2 * m)) damage and heals you \(num(1.5 * m)) health when it hits."
            case .umbral:
                return "\(who) has a \(pct(0.12 * m)) chance to Critically hit for 3x damage."
            }
        }
    }
}

// MARK: - Rewards

enum Reward: Equatable {
    case boon(Patron), heart, gold, souls, anvil, heal, shop, boss

    var title: String {
        switch self {
        case .boon(let p): return "Boon of \(p.short)"
        case .heart: return "Infernal Heart"
        case .gold: return "Hellgold"
        case .souls: return "Soul Shards"
        case .anvil: return "Hellforge Anvil"
        case .heal: return "Blood Draught"
        case .shop: return "Ash Merchant"
        case .boss: return "Guardian's Lair"
        }
    }

    var color: UIColor {
        switch self {
        case .boon(let p): return p.color
        case .heart: return UIColor(hex: 0xff3050)
        case .gold: return UIColor(hex: 0xf0c040)
        case .souls: return UIColor(hex: 0x9a7cff)
        case .anvil: return UIColor(hex: 0xffa040)
        case .heal: return UIColor(hex: 0xff4060)
        case .shop: return UIColor(hex: 0xf0c040)
        case .boss: return UIColor(hex: 0xff2020)
        }
    }
}

// MARK: - Weapons

struct Swing {
    let damage: CGFloat
    let range: CGFloat
    let arc: CGFloat   // degrees
    let time: CGFloat
    let lunge: CGFloat
    let knock: CGFloat
}

enum SpecialKind { case spin, hurl, slam }

enum WeaponKind: Int, CaseIterable {
    case blade, pike, fists

    var name: String { ["Cinderblade", "Hellpike", "Doomfists"][rawValue] }

    var blurb: String {
        switch self {
        case .blade: return "Balanced sweeping slashes with a heavy third strike. Special: Whirling Inferno, a spinning strike around you."
        case .pike: return "Long piercing thrusts that keep foes at bay. Special: Hurl, throw a pike that pierces every foe in its path."
        case .fists: return "A blinding flurry of blows. Special: Cataclysm, a ground slam that hurls foes away."
        }
    }

    var combo: [Swing] {
        switch self {
        case .blade:
            return [Swing(damage: 20, range: 105, arc: 130, time: 0.28, lunge: 14, knock: 40),
                    Swing(damage: 22, range: 105, arc: 130, time: 0.28, lunge: 14, knock: 40),
                    Swing(damage: 42, range: 122, arc: 170, time: 0.46, lunge: 34, knock: 150)]
        case .pike:
            return [Swing(damage: 19, range: 165, arc: 30, time: 0.3, lunge: 10, knock: 35),
                    Swing(damage: 19, range: 165, arc: 30, time: 0.3, lunge: 10, knock: 35),
                    Swing(damage: 38, range: 200, arc: 40, time: 0.5, lunge: 80, knock: 130)]
        case .fists:
            return [Swing(damage: 11, range: 72, arc: 80, time: 0.15, lunge: 10, knock: 15),
                    Swing(damage: 11, range: 72, arc: 80, time: 0.15, lunge: 10, knock: 15),
                    Swing(damage: 12, range: 72, arc: 80, time: 0.15, lunge: 10, knock: 15),
                    Swing(damage: 13, range: 72, arc: 80, time: 0.15, lunge: 10, knock: 15),
                    Swing(damage: 30, range: 90, arc: 110, time: 0.36, lunge: 28, knock: 170)]
        }
    }

    var special: SpecialKind {
        switch self {
        case .blade: return .spin
        case .pike: return .hurl
        case .fists: return .slam
        }
    }

    var specialDamage: CGFloat {
        let d: [CGFloat] = [38, 45, 50]
        return d[rawValue]
    }

    var specialCooldown: CGFloat {
        let d: [CGFloat] = [1.1, 1.0, 1.6]
        return d[rawValue]
    }
}

// MARK: - Meta progression (persists between runs)

enum MetaUpgrade: String, CaseIterable {
    case vigor, might, haste, fleet, ember, fortune, greed, rebirth

    var title: String {
        switch self {
        case .vigor: return "Infernal Vigor"
        case .might: return "Wrathful Might"
        case .haste: return "Ashen Haste"
        case .fleet: return "Wings of Cinder"
        case .ember: return "Ember Reservoir"
        case .fortune: return "Patron's Favor"
        case .greed: return "Tithe of Greed"
        case .rebirth: return "Defiance of Death"
        }
    }

    var maxRank: Int {
        switch self {
        case .vigor, .might: return 5
        case .haste, .fortune, .greed: return 3
        case .fleet, .ember: return 1
        case .rebirth: return 2
        }
    }

    func cost(_ rank: Int) -> Int {
        let base: [Int]
        switch self {
        case .vigor: base = [20, 35, 50, 70, 95]
        case .might: base = [25, 45, 65, 90, 120]
        case .haste: base = [20, 40, 65]
        case .fleet: base = [120]
        case .ember: base = [70]
        case .fortune: base = [30, 60, 100]
        case .greed: base = [15, 30, 50]
        case .rebirth: base = [90, 220]
        }
        return base[min(max(rank, 0), base.count - 1)]
    }

    var effect: String {
        switch self {
        case .vigor: return "+10 max health per rank"
        case .might: return "+5% damage per rank"
        case .haste: return "+5% move speed per rank"
        case .fleet: return "+1 dash charge"
        case .ember: return "+1 cast charge"
        case .fortune: return "Rarer boons per rank"
        case .greed: return "+30 starting gold per rank"
        case .rebirth: return "Revive once per run, per rank"
        }
    }
}

struct MetaData: Codable {
    var souls: Int = 0
    var ranks: [String: Int] = [:]
    var runs: Int = 0
    var wins: Int = 0
    var bestDepth: Int = 0
    var weapon: Int = 0
}

final class Meta {
    static let shared = Meta()
    private let key = "hellknight.meta.v1"
    var data: MetaData

    private init() {
        if let d = UserDefaults.standard.data(forKey: key),
           let m = try? JSONDecoder().decode(MetaData.self, from: d) {
            data = m
        } else {
            data = MetaData()
        }
    }

    func save() {
        if let d = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(d, forKey: key)
        }
    }

    func rank(_ u: MetaUpgrade) -> Int { data.ranks[u.rawValue] ?? 0 }

    @discardableResult
    func buy(_ u: MetaUpgrade) -> Bool {
        let r = rank(u)
        guard r < u.maxRank else { return false }
        let c = u.cost(r)
        guard data.souls >= c else { return false }
        data.souls -= c
        data.ranks[u.rawValue] = r + 1
        save()
        return true
    }
}

// MARK: - Run state

enum RoomType { case combat, shop, boss }

final class RunState {
    static let finalDepth = 2

    let weapon: WeaponKind
    var depth = 0
    var room = 0
    var maxHp: CGFloat
    var hp: CGFloat
    var gold: Int
    var souls = 0
    var revives: Int
    var slots: [Slot: Boon] = [:]
    var passives: [Passive: Rarity] = [:]
    var damageMult: CGFloat
    var attackSpeed: CGFloat = 1
    var rangeMult: CGFloat = 1
    var moveMult: CGFloat
    var maxDash: Int
    var maxCast: Int
    var luck: CGFloat
    var nextReward: Reward
    var kills = 0
    var anvilTaken: Set<String> = []

    init(weapon: WeaponKind) {
        let meta = Meta.shared
        self.weapon = weapon
        maxHp = 80 + 10 * CGFloat(meta.rank(.vigor))
        hp = maxHp
        damageMult = 1 + 0.05 * CGFloat(meta.rank(.might))
        moveMult = 1 + 0.05 * CGFloat(meta.rank(.haste))
        maxDash = 1 + meta.rank(.fleet)
        maxCast = 2 + meta.rank(.ember)
        luck = 0.02 * CGFloat(meta.rank(.fortune))
        gold = 30 * meta.rank(.greed)
        revives = meta.rank(.rebirth)
        nextReward = .boon(Patron.allCases.randomElement() ?? .pyre)
    }

    var roomType: RoomType {
        if room >= 6 { return .boss }
        if room == 3 { return .shop }
        return .combat
    }

    func pm(_ p: Passive) -> CGFloat { passives[p]?.mult ?? 0 }
    func has(_ p: Passive) -> Bool { passives[p] != nil }
}

// MARK: - Hellforge anvil upgrades

struct AnvilOption {
    let id: String
    let title: String
    let desc: String
    let once: Bool
    let apply: (RunState) -> Void

    static let all: [AnvilOption] = [
        AnvilOption(id: "edge", title: "Honed Edge", desc: "+15% damage with everything.", once: false) { $0.damageMult *= 1.15 },
        AnvilOption(id: "grip", title: "Quickened Grip", desc: "+12% attack speed.", once: false) { $0.attackSpeed += 0.12 },
        AnvilOption(id: "reach", title: "Long Reach", desc: "+15% attack range.", once: false) { $0.rangeMult += 0.15 },
        AnvilOption(id: "heart", title: "Forged Heart", desc: "+20 max health.", once: false) { r in
            r.maxHp += 20
            r.hp += 20
        },
        AnvilOption(id: "greaves", title: "Swift Greaves", desc: "+10% move speed.", once: false) { $0.moveMult += 0.1 },
        AnvilOption(id: "flask", title: "Ember Flask", desc: "+1 cast charge.", once: true) { $0.maxCast += 1 },
        AnvilOption(id: "wing", title: "Wingstep", desc: "+1 dash charge.", once: true) { $0.maxDash += 1 },
        AnvilOption(id: "mend", title: "Searing Mend", desc: "Fully restore your health.", once: false) { $0.hp = $0.maxHp },
    ]
}

struct ChoiceCard {
    let tag: String
    let title: String
    let sub: String
    let desc: String
    let color: UIColor
    let accent: UIColor
    let icon: Reward?
    let action: () -> Void
}
