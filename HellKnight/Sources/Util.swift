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
    static let title = "Baskerville-Bold"
    static let heavy = "AvenirNext-Heavy"
    static let bold = "AvenirNext-DemiBold"
    static let medium = "AvenirNext-Medium"
}

/// The ink palette shared by every area.
enum Ink {
    static let black = UIColor(hex: 0x0b0908)
    static let bone = UIColor(hex: 0xebe0c8)
    static let boneDark = UIColor(hex: 0xb0a184)
    static let steel = UIColor(hex: 0x2b2724)
    static let blood = UIColor(hex: 0xc4161d)
    static let gold = UIColor(hex: 0xcda552)
    static let goldDark = UIColor(hex: 0x6b5222)
    static let panel = UIColor(hex: 0x130d0b)
}

// MARK: - Isometric projection
// Game logic runs on a flat ground plane. The world node is rotated 45° and squashed
// vertically by half, which turns the ground plane into a true isometric diamond.

let isoK: CGFloat = 0.70710678

func isoProject(_ p: CGPoint) -> CGPoint {
    CGPoint(x: (p.x - p.y) * isoK, y: (p.x + p.y) * isoK * 0.5)
}

/// Screen-space angle of a ground-plane direction.
func screenAngle(_ groundAngle: CGFloat) -> CGFloat {
    isoProject(CGPoint(angle: groundAngle)).angle
}

/// Converts a screen-space stick vector into a ground-plane vector of the same magnitude.
func groundFromScreen(_ v: CGPoint) -> CGPoint {
    let m = v.length
    if m < 0.0001 { return .zero }
    return CGPoint(x: v.x + 2 * v.y, y: 2 * v.y - v.x).normalized * m
}

/// A node whose children render upright (unrotated, unsquashed) inside the isometric world.
final class Billboard: SKNode {
    override init() {
        super.init()
        zRotation = -.pi / 4
        yScale = 2
    }
    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}

func makeLabel(_ text: String, size: CGFloat, color: UIColor = .white, font: String = Font.bold,
               align: SKLabelHorizontalAlignmentMode = .center, kern: CGFloat = 0) -> SKLabelNode {
    let l = SKLabelNode(fontNamed: font)
    l.fontSize = size
    l.fontColor = color
    l.horizontalAlignmentMode = align
    l.verticalAlignmentMode = .center
    if kern > 0 {
        setKerned(l, text, kern: kern)
    } else {
        l.text = text
    }
    return l
}

/// Letter-spaced text (used for cinematic titles).
func setKerned(_ l: SKLabelNode, _ text: String, kern: CGFloat) {
    let font = UIFont(name: l.fontName ?? Font.title, size: l.fontSize) ?? UIFont.boldSystemFont(ofSize: l.fontSize)
    l.attributedText = NSAttributedString(string: text, attributes: [
        .font: font,
        .foregroundColor: l.fontColor ?? UIColor.white,
        .kern: kern,
    ])
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
    let line: UIColor
    let stone: UIColor
    let stoneDark: UIColor
    let accent: UIColor
    let ember: UIColor
    let bg: UIColor

    static func of(_ depth: Int) -> Palette {
        switch depth {
        case 0:
            return Palette(name: "Cinder Halls",
                           floor: UIColor(hex: 0x2c231e), floorAlt: UIColor(hex: 0x32271f), line: UIColor(hex: 0xdccaa6),
                           stone: UIColor(hex: 0x54473c), stoneDark: UIColor(hex: 0x1e1814),
                           accent: UIColor(hex: 0xff6a1f), ember: UIColor(hex: 0xff8a3a), bg: UIColor(hex: 0x070504))
        case 1:
            return Palette(name: "Ossuary Wastes",
                           floor: UIColor(hex: 0x26271f), floorAlt: UIColor(hex: 0x2b2c23), line: UIColor(hex: 0xdcd8bd),
                           stone: UIColor(hex: 0x4c4d40), stoneDark: UIColor(hex: 0x1a1b15),
                           accent: UIColor(hex: 0x9dff6e), ember: UIColor(hex: 0xb8ff8a), bg: UIColor(hex: 0x050604))
        default:
            return Palette(name: "Abyssal Throne",
                           floor: UIColor(hex: 0x1f1f2b), floorAlt: UIColor(hex: 0x242331), line: UIColor(hex: 0xd2cbe6),
                           stone: UIColor(hex: 0x403e58), stoneDark: UIColor(hex: 0x14131d),
                           accent: UIColor(hex: 0x9a7cff), ember: UIColor(hex: 0xb59cff), bg: UIColor(hex: 0x040309))
        }
    }
}
