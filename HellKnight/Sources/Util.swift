import SpriteKit
import UIKit

// MARK: - Vector math

extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: CGPoint, s: CGFloat) -> CGPoint { CGPoint(x: a.x * s, y: a.y * s) }
    static func += (a: inout CGPoint, b: CGPoint) { a = a + b }
    static func -= (a: inout CGPoint, b: CGPoint) { a = a - b }

    var length: CGFloat { sqrt(x * x + y * y) }
    var normalized: CGPoint {
        let l = length
        return l > 0.0001 ? CGPoint(x: x / l, y: y / l) : .zero
    }
    var angle: CGFloat { atan2(y, x) }

    init(angle: CGFloat, length: CGFloat = 1) {
        self.init(x: cos(angle) * length, y: sin(angle) * length)
    }

    func distance(to p: CGPoint) -> CGFloat { (p - self).length }
}

func clamp(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(v, lo), hi) }

func angleDiff(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
    var d = a - b
    while d > .pi { d -= 2 * .pi }
    while d < -.pi { d += 2 * .pi }
    return d
}

func rnd(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
    a < b ? CGFloat.random(in: a...b) : a
}

func chance(_ p: CGFloat) -> Bool { CGFloat.random(in: 0..<1) < p }

func pct(_ v: CGFloat) -> String { "\(Int((v * 100).rounded()))%" }
func num(_ v: CGFloat) -> String { "\(Int(v.rounded()))" }

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

// MARK: - Colors & fonts

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xff) / 255,
                  green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255,
                  alpha: alpha)
    }

    func scaled(_ f: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return UIColor(red: min(1, r * f), green: min(1, g * f), blue: min(1, b * f), alpha: a)
    }
}

enum Font {
    static let title = "Copperplate-Bold"
    static let heavy = "AvenirNext-Heavy"
    static let bold = "AvenirNext-Bold"
    static let medium = "AvenirNext-DemiBold"
}

func makeLabel(_ text: String, size: CGFloat, color: UIColor = .white, font: String = Font.bold,
               align: SKLabelHorizontalAlignmentMode = .center) -> SKLabelNode {
    let l = SKLabelNode(fontNamed: font)
    l.text = text
    l.fontSize = size
    l.fontColor = color
    l.horizontalAlignmentMode = align
    l.verticalAlignmentMode = .center
    return l
}

func visibleInTree(_ node: SKNode) -> Bool {
    var c: SKNode? = node
    while let n = c {
        if n.isHidden || n.alpha < 0.05 { return false }
        c = n.parent
    }
    return true
}

func makeEmbers(area: CGSize, color: UIColor, rate: CGFloat) -> SKEmitterNode {
    let e = SKEmitterNode()
    e.particleTexture = Tex.spark()
    e.particleBirthRate = rate
    e.particleLifetime = 5
    e.particleLifetimeRange = 2
    e.particlePositionRange = CGVector(dx: area.width, dy: area.height)
    e.particleSpeed = 28
    e.particleSpeedRange = 18
    e.emissionAngle = .pi / 2
    e.emissionAngleRange = 0.7
    e.particleAlpha = 0.85
    e.particleAlphaRange = 0.2
    e.particleAlphaSpeed = -0.16
    e.particleScale = 0.4
    e.particleScaleRange = 0.2
    e.particleScaleSpeed = -0.04
    e.particleColor = color
    e.particleColorBlendFactor = 1
    e.particleBlendMode = .add
    return e
}

enum Haptics {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
}

// MARK: - Palettes per depth

struct Palette {
    let name: String
    let floor: UIColor
    let floorAlt: UIColor
    let grout: UIColor
    let crack: UIColor
    let wall: UIColor
    let wallDark: UIColor
    let accent: UIColor
    let ember: UIColor
    let bg: UIColor

    static func of(_ depth: Int) -> Palette {
        switch depth {
        case 0:
            return Palette(name: "Cinder Halls",
                           floor: UIColor(hex: 0x2b1814), floorAlt: UIColor(hex: 0x341d17), grout: UIColor(hex: 0x160a07),
                           crack: UIColor(hex: 0xff6a1a), wall: UIColor(hex: 0x4e2c22), wallDark: UIColor(hex: 0x22110c),
                           accent: UIColor(hex: 0xff7a2a), ember: UIColor(hex: 0xff8a30), bg: UIColor(hex: 0x080302))
        case 1:
            return Palette(name: "Ossuary Wastes",
                           floor: UIColor(hex: 0x27242d), floorAlt: UIColor(hex: 0x2e2a35), grout: UIColor(hex: 0x111016),
                           crack: UIColor(hex: 0x9cff7a), wall: UIColor(hex: 0x48424f), wallDark: UIColor(hex: 0x1c1a22),
                           accent: UIColor(hex: 0xa8ff8a), ember: UIColor(hex: 0x9aff7a), bg: UIColor(hex: 0x050407))
        default:
            return Palette(name: "Abyssal Throne",
                           floor: UIColor(hex: 0x131b2f), floorAlt: UIColor(hex: 0x182139), grout: UIColor(hex: 0x070b16),
                           crack: UIColor(hex: 0x7a5cff), wall: UIColor(hex: 0x2c3155), wallDark: UIColor(hex: 0x0e1126),
                           accent: UIColor(hex: 0x8f72ff), ember: UIColor(hex: 0xb08aff), bg: UIColor(hex: 0x020308))
        }
    }
}
