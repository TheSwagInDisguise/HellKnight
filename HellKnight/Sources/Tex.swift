import SpriteKit
import UIKit

/// All art in the game is drawn procedurally with Core Graphics and cached as textures.
/// Note: drawing uses UIKit coordinates (origin top-left, y grows downward).
enum Tex {
    private static var cache: [String: SKTexture] = [:]

    static func make(_ key: String, _ w: CGFloat, _ h: CGFloat, _ draw: (CGContext) -> Void) -> SKTexture {
        if let t = cache[key] { return t }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: format)
        let image = renderer.image { ctx in draw(ctx.cgContext) }
        let tex = SKTexture(image: image)
        cache[key] = tex
        return tex
    }

    // MARK: - Primitives

    static func circle(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ col: UIColor) {
        c.setFillColor(col.cgColor)
        c.fillEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    static func ring(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ col: UIColor, _ lw: CGFloat) {
        c.setStrokeColor(col.cgColor)
        c.setLineWidth(lw)
        c.strokeEllipse(in: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2))
    }

    static func rect(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ col: UIColor) {
        c.setFillColor(col.cgColor)
        c.fill(CGRect(x: x, y: y, width: w, height: h))
    }

    static func poly(_ c: CGContext, _ pts: [(CGFloat, CGFloat)], _ col: UIColor) {
        fillPts(c, pts.map { CGPoint(x: $0.0, y: $0.1) }, col)
    }

    static func fillPts(_ c: CGContext, _ pts: [CGPoint], _ col: UIColor) {
        guard let f = pts.first else { return }
        c.setFillColor(col.cgColor)
        c.beginPath()
        c.move(to: f)
        for p in pts.dropFirst() { c.addLine(to: p) }
        c.closePath()
        c.fillPath()
    }

    static func strokePts(_ c: CGContext, _ pts: [CGPoint], _ col: UIColor, _ lw: CGFloat) {
        guard let f = pts.first else { return }
        c.setStrokeColor(col.cgColor)
        c.setLineWidth(lw)
        c.setLineCap(.round)
        c.setLineJoin(.round)
        c.beginPath()
        c.move(to: f)
        for p in pts.dropFirst() { c.addLine(to: p) }
        c.strokePath()
    }

    static func radial(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ cols: [UIColor], _ locs: [CGFloat]) {
        let cgCols = cols.map { $0.cgColor } as CFArray
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cgCols, locations: locs) else { return }
        let p = CGPoint(x: x, y: y)
        c.drawRadialGradient(g, startCenter: p, startRadius: 0, endCenter: p, endRadius: r, options: [])
    }

    static func arcPoints(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ a0: CGFloat, _ a1: CGFloat, steps: Int = 24) -> [CGPoint] {
        var out: [CGPoint] = []
        for i in 0...steps {
            let a = a0 + (a1 - a0) * CGFloat(i) / CGFloat(steps)
            out.append(CGPoint(x: cx + cos(a) * r, y: cy + sin(a) * r))
        }
        return out
    }

    // MARK: - Generic

    static func glow() -> SKTexture {
        make("glow", 64, 64) { c in
            radial(c, 32, 32, 32, [UIColor(white: 1, alpha: 1), UIColor(white: 1, alpha: 0.35), UIColor(white: 1, alpha: 0)], [0, 0.3, 1])
        }
    }

    static func spark() -> SKTexture {
        make("spark", 16, 16) { c in
            radial(c, 8, 8, 8, [UIColor(white: 1, alpha: 1), UIColor(white: 1, alpha: 0.7), UIColor(white: 1, alpha: 0)], [0, 0.35, 1])
        }
    }

    static func shadow() -> SKTexture {
        make("shadow", 64, 32) { c in
            c.saveGState()
            c.scaleBy(x: 1, y: 0.5)
            radial(c, 32, 32, 32, [UIColor(white: 0, alpha: 0.6), UIColor(white: 0, alpha: 0)], [0.2, 1])
            c.restoreGState()
        }
    }

    static func ringTex() -> SKTexture {
        make("ring", 128, 128) { c in ring(c, 64, 64, 60, .white, 5) }
    }

    static func disc() -> SKTexture {
        make("disc", 64, 64) { c in circle(c, 32, 32, 31, .white) }
    }

    static func teleCircle() -> SKTexture {
        make("tele", 128, 128) { c in
            circle(c, 64, 64, 62, UIColor(hex: 0xff2a1a, alpha: 0.22))
            ring(c, 64, 64, 61, UIColor(hex: 0xff3a1a, alpha: 0.9), 3)
        }
    }

    static func vignette() -> SKTexture {
        make("vignette", 256, 256) { c in
            let cols = [UIColor(white: 0, alpha: 0).cgColor, UIColor(white: 0, alpha: 0.82).cgColor] as CFArray
            guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0.45, 1]) else { return }
            let p = CGPoint(x: 128, y: 128)
            c.drawRadialGradient(g, startCenter: p, startRadius: 0, endCenter: p, endRadius: 181, options: [.drawsAfterEndLocation])
        }
    }

    static func joyBase() -> SKTexture {
        make("joybase", 130, 130) { c in
            circle(c, 65, 65, 60, UIColor(white: 1, alpha: 0.07))
            ring(c, 65, 65, 60, UIColor(white: 1, alpha: 0.45), 3)
        }
    }

    static func joyKnob() -> SKTexture {
        make("joyknob", 60, 60) { c in
            circle(c, 30, 30, 27, UIColor(white: 1, alpha: 0.4))
            ring(c, 30, 30, 27, UIColor(white: 1, alpha: 0.8), 2)
        }
    }

    static func padBg() -> SKTexture {
        make("pad", 100, 100) { c in
            circle(c, 50, 50, 47, UIColor(white: 0, alpha: 0.45))
            ring(c, 50, 50, 46, UIColor(hex: 0xffc080, alpha: 0.7), 3)
        }
    }

    static func symbol(_ name: String, _ pt: CGFloat = 34) -> SKTexture {
        let key = "sym_\(name)_\(Int(pt))"
        if let t = cache[key] { return t }
        let cfg = UIImage.SymbolConfiguration(pointSize: pt, weight: .bold)
        guard let img = UIImage(systemName: name, withConfiguration: cfg)?
            .withTintColor(.white, renderingMode: .alwaysOriginal) else { return disc() }
        let s = img.size
        return make(key, max(1, s.width), max(1, s.height)) { _ in
            img.draw(in: CGRect(origin: .zero, size: s))
        }
    }

    // MARK: - Player & weapons

    static func knight() -> SKTexture {
        make("knight", 56, 56) { c in
            circle(c, 28, 33, 21, UIColor(hex: 0x6b0f14))
            circle(c, 28, 30, 17, UIColor(hex: 0x2b2f38))
            ring(c, 28, 30, 17, UIColor(hex: 0x6a7282), 2)
            circle(c, 12, 31, 7, UIColor(hex: 0x5a6170))
            circle(c, 44, 31, 7, UIColor(hex: 0x5a6170))
            ring(c, 12, 31, 7, UIColor(hex: 0x8a92a3), 1.5)
            ring(c, 44, 31, 7, UIColor(hex: 0x8a92a3), 1.5)
            poly(c, [(20, 21), (14, 7), (23, 17)], UIColor(hex: 0xe8dcc0))
            poly(c, [(36, 21), (42, 7), (33, 17)], UIColor(hex: 0xe8dcc0))
            circle(c, 28, 26, 11, UIColor(hex: 0x9aa3b5))
            ring(c, 28, 26, 11, UIColor(hex: 0x3b404a), 1.5)
            poly(c, [(26.5, 15.5), (29.5, 15.5), (29, 8), (27, 8)], UIColor(hex: 0xd0201a))
            rect(c, 20.5, 24.5, 15, 4, UIColor(hex: 0x111111))
            rect(c, 26.5, 24.5, 3, 9, UIColor(hex: 0x111111))
            circle(c, 24.2, 26.5, 1.8, UIColor(hex: 0xff4a1a))
            circle(c, 31.8, 26.5, 1.8, UIColor(hex: 0xff4a1a))
        }
    }

    static func blade() -> SKTexture {
        make("blade", 72, 16) { c in
            rect(c, 0, 6, 13, 4, UIColor(hex: 0x4a2a1a))
            circle(c, 2, 8, 3, UIColor(hex: 0xc8a040))
            rect(c, 12, 1, 4, 14, UIColor(hex: 0xc8a040))
            poly(c, [(16, 4.5), (62, 5), (72, 8), (62, 11), (16, 11.5)], UIColor(hex: 0xd8dde6))
            rect(c, 18, 7.3, 46, 1.4, UIColor(hex: 0xff6a2a))
        }
    }

    static func pike() -> SKTexture {
        make("pike", 112, 16) { c in
            rect(c, 0, 6.5, 84, 3, UIColor(hex: 0x5a3a22))
            rect(c, 76, 2, 3, 12, UIColor(hex: 0x8a8f9a))
            poly(c, [(80, 2), (112, 8), (80, 14), (86, 8)], UIColor(hex: 0xcfd5de))
            rect(c, 86, 7.3, 18, 1.4, UIColor(hex: 0xff6a2a))
        }
    }

    static func fist() -> SKTexture {
        make("fist", 30, 30) { c in
            poly(c, [(20, 6), (29, 9), (22, 11)], UIColor(hex: 0xb8bcc8))
            poly(c, [(20, 24), (29, 21), (22, 19)], UIColor(hex: 0xb8bcc8))
            poly(c, [(22, 13), (30, 15), (22, 17)], UIColor(hex: 0xb8bcc8))
            circle(c, 14, 15, 10, UIColor(hex: 0x3e434e))
            ring(c, 14, 15, 10, UIColor(hex: 0x8a92a3), 2)
            circle(c, 18, 15, 3, UIColor(hex: 0xff6a2a))
        }
    }

    static func weapon(_ w: WeaponKind) -> SKTexture {
        switch w {
        case .blade: return blade()
        case .pike: return pike()
        case .fists: return fist()
        }
    }

    static func slash(arcDeg: Int) -> SKTexture {
        make("slash\(arcDeg)", 128, 128) { c in
            let a = CGFloat(arcDeg) * .pi / 180
            let pts = arcPoints(64, 64, 50, -a / 2, a / 2, steps: 40)
            strokePts(c, pts, UIColor(white: 1, alpha: 0.3), 18)
            strokePts(c, pts, UIColor(white: 1, alpha: 0.75), 9)
            strokePts(c, arcPoints(64, 64, 54, -a / 2 * 0.92, a / 2 * 0.92, steps: 40), .white, 3)
        }
    }

    static func thrust() -> SKTexture {
        make("thrust", 128, 24) { c in
            poly(c, [(0, 12), (24, 5), (128, 11), (128, 13), (24, 19)], UIColor(white: 1, alpha: 0.45))
            poly(c, [(10, 12), (30, 9), (124, 11.5), (124, 12.5), (30, 15)], UIColor(white: 1, alpha: 0.95))
        }
    }

    // MARK: - Enemies

    static func imp() -> SKTexture {
        make("imp", 44, 44) { c in
            poly(c, [(10, 22), (1, 11), (4, 28)], UIColor(hex: 0x6a1810))
            poly(c, [(34, 22), (43, 11), (40, 28)], UIColor(hex: 0x6a1810))
            circle(c, 22, 25, 14, UIColor(hex: 0xc0391f))
            circle(c, 22, 29, 7, UIColor(hex: 0xe0663a))
            poly(c, [(13, 15), (10, 3), (18, 12)], UIColor(hex: 0x2a1410))
            poly(c, [(31, 15), (34, 3), (26, 12)], UIColor(hex: 0x2a1410))
            circle(c, 17, 22, 3.2, UIColor(hex: 0xffe14a))
            circle(c, 27, 22, 3.2, UIColor(hex: 0xffe14a))
            circle(c, 17, 22, 1.3, .black)
            circle(c, 27, 22, 1.3, .black)
            rect(c, 17, 30, 10, 2, UIColor(hex: 0x3a0a05))
        }
    }

    static func archer() -> SKTexture {
        make("archer", 44, 44) { c in
            circle(c, 22, 26, 17, UIColor(hex: 0x24301f))
            ring(c, 22, 26, 17, UIColor(hex: 0x3e5234), 2)
            circle(c, 22, 20, 12.5, UIColor(hex: 0xe0d6bf))
            rect(c, 15, 26, 14, 7, UIColor(hex: 0xd2c7ac))
            circle(c, 17, 20, 3.6, UIColor(hex: 0x1a1414))
            circle(c, 27, 20, 3.6, UIColor(hex: 0x1a1414))
            circle(c, 17, 20, 1.6, UIColor(hex: 0x7dff6a))
            circle(c, 27, 20, 1.6, UIColor(hex: 0x7dff6a))
            poly(c, [(22, 23), (20.5, 26), (23.5, 26)], UIColor(hex: 0x1a1414))
            for i in 0..<4 { rect(c, 16.5 + CGFloat(i) * 3, 28, 1, 4, UIColor(hex: 0x6a5f4c)) }
            strokePts(c, arcPoints(22, 26, 19, 2.2, 4.1, steps: 12), UIColor(hex: 0x8a5a2a), 2.5)
        }
    }

    static func brute() -> SKTexture {
        make("brute", 72, 72) { c in
            circle(c, 36, 39, 28, UIColor(hex: 0x4b2b58))
            ring(c, 36, 39, 28, UIColor(hex: 0x2a1430), 3)
            circle(c, 36, 45, 15, UIColor(hex: 0x6b4a78))
            ring(c, 36, 45, 15, UIColor(hex: 0x8d6a9a), 2)
            poly(c, [(19, 24), (5, 4), (12, 5), (25, 19)], UIColor(hex: 0xd8c8a8))
            poly(c, [(53, 24), (67, 4), (60, 5), (47, 19)], UIColor(hex: 0xd8c8a8))
            circle(c, 28, 32, 3.8, UIColor(hex: 0xff3020))
            circle(c, 44, 32, 3.8, UIColor(hex: 0xff3020))
            poly(c, [(29, 40), (31, 48), (33, 40)], UIColor(hex: 0xf0e8d8))
            poly(c, [(39, 40), (41, 48), (43, 40)], UIColor(hex: 0xf0e8d8))
        }
    }

    static func wisp() -> SKTexture {
        make("wisp", 40, 40) { c in
            radial(c, 20, 20, 20, [UIColor(hex: 0xd0fff4), UIColor(hex: 0x40e0b0, alpha: 0.85), UIColor(hex: 0x10806a, alpha: 0)], [0, 0.45, 1])
            circle(c, 16, 19, 2.2, UIColor(hex: 0x05201a))
            circle(c, 24, 19, 2.2, UIColor(hex: 0x05201a))
        }
    }

    static func priest() -> SKTexture {
        make("priest", 48, 48) { c in
            circle(c, 24, 27, 18, UIColor(hex: 0x3b1f5c))
            ring(c, 24, 27, 18, UIColor(hex: 0xc060ff, alpha: 0.7), 1.5)
            poly(c, [(24, 3), (39, 26), (9, 26)], UIColor(hex: 0x2a1244))
            circle(c, 24, 23, 7.5, UIColor(hex: 0x0a0510))
            radial(c, 24, 23, 7, [UIColor(hex: 0xff80e0), UIColor(hex: 0xff40c0, alpha: 0)], [0, 1])
            circle(c, 24, 23, 2.4, .white)
        }
    }

    static func boss(_ depth: Int) -> SKTexture {
        let bodies: [UInt32] = [0x5a1a12, 0x3a3346, 0x141c3e]
        let accents: [UInt32] = [0xff7a1a, 0xe8e0c8, 0x8a6cff]
        let d = min(max(depth, 0), 2)
        let body = UIColor(hex: bodies[d])
        let acc = UIColor(hex: accents[d])
        return make("boss\(d)", 130, 130) { c in
            radial(c, 65, 65, 65, [acc.withAlphaComponent(0.45), acc.withAlphaComponent(0)], [0.4, 1])
            for i in 0..<5 {
                let t = (CGFloat(30) + CGFloat(i) * 30) * .pi / 180
                let tip = CGPoint(x: 65 + cos(t) * 62, y: 65 - sin(t) * 62)
                let b1 = CGPoint(x: 65 + cos(t - 0.2) * 40, y: 65 - sin(t - 0.2) * 40)
                let b2 = CGPoint(x: 65 + cos(t + 0.2) * 40, y: 65 - sin(t + 0.2) * 40)
                fillPts(c, [b1, tip, b2], acc)
            }
            circle(c, 65, 67, 44, body)
            ring(c, 65, 67, 44, acc.withAlphaComponent(0.85), 4)
            circle(c, 65, 72, 26, body.scaled(1.4))
            poly(c, [(40, 54), (58, 60), (56, 66), (42, 62)], acc)
            poly(c, [(90, 54), (72, 60), (74, 66), (88, 62)], acc)
            circle(c, 51, 61, 2.6, .white)
            circle(c, 79, 61, 2.6, .white)
            poly(c, [(48, 82), (54, 90), (60, 84), (65, 92), (70, 84), (76, 90), (82, 82), (65, 86)], acc)
        }
    }

    static func orb() -> SKTexture {
        make("orb", 28, 28) { c in
            radial(c, 14, 14, 14, [UIColor(white: 1, alpha: 1), UIColor(white: 1, alpha: 0.85), UIColor(white: 1, alpha: 0)], [0, 0.4, 1])
        }
    }

    static func arrow() -> SKTexture {
        make("arrow", 34, 10) { c in
            rect(c, 0, 4, 24, 2, UIColor(hex: 0xcbb89a))
            poly(c, [(22, 0), (34, 5), (22, 10)], UIColor(hex: 0xb8ff9a))
            poly(c, [(0, 1), (6, 5), (0, 9)], UIColor(hex: 0xd02020))
        }
    }

    // MARK: - Environment

    static func floor(_ depth: Int, _ v: Int) -> SKTexture {
        let pal = Palette.of(depth)
        return make("floor\(depth)_\(v)", 128, 128) { c in
            var rng = SeededRNG(seed: UInt64(depth * 97 + v * 13 + 5))
            rect(c, 0, 0, 128, 128, pal.grout)
            for i in 0..<2 {
                for j in 0..<2 {
                    let t = CGFloat.random(in: 0...1, using: &rng)
                    let base = t > 0.5 ? pal.floor : pal.floorAlt
                    let ox = CGFloat(i) * 64, oy = CGFloat(j) * 64
                    rect(c, ox + 1.5, oy + 1.5, 61, 61, base)
                    rect(c, ox + 1.5, oy + 1.5, 61, 3, base.scaled(1.18))
                    for _ in 0..<6 {
                        let x = ox + CGFloat.random(in: 6...58, using: &rng)
                        let y = oy + CGFloat.random(in: 6...58, using: &rng)
                        circle(c, x, y, CGFloat.random(in: 0.8...2.2, using: &rng), pal.grout.withAlphaComponent(0.55))
                    }
                }
            }
            if v % 2 == 1 {
                var p = CGPoint(x: CGFloat.random(in: 16...112, using: &rng), y: CGFloat.random(in: 16...112, using: &rng))
                var pts = [p]
                for _ in 0..<6 {
                    p = CGPoint(x: p.x + CGFloat.random(in: -18...18, using: &rng), y: p.y + CGFloat.random(in: -18...18, using: &rng))
                    pts.append(p)
                }
                strokePts(c, pts, pal.crack.withAlphaComponent(0.25), 4)
                strokePts(c, pts, pal.crack.withAlphaComponent(0.85), 1.4)
            }
        }
    }

    static func wall(_ depth: Int) -> SKTexture {
        let pal = Palette.of(depth)
        return make("wall\(depth)", 128, 128) { c in
            rect(c, 0, 0, 128, 128, pal.wallDark)
            var rng = SeededRNG(seed: UInt64(depth + 77))
            var row = 0
            var y: CGFloat = 0
            while y < 128 {
                var x: CGFloat = row % 2 == 0 ? 0 : -16
                while x < 128 {
                    let shade = CGFloat.random(in: 0.8...1.1, using: &rng)
                    rect(c, x + 1.5, y + 1.5, 29, 13, pal.wall.scaled(shade * (0.75 + y / 512)))
                    x += 32
                }
                y += 16
                row += 1
            }
        }
    }

    static func pillar(_ depth: Int) -> SKTexture {
        let pal = Palette.of(depth)
        return make("pillar\(depth)", 96, 96) { c in
            circle(c, 48, 50, 46, pal.wallDark)
            circle(c, 48, 47, 42, pal.wall)
            circle(c, 48, 44, 32, pal.wall.scaled(1.25))
            ring(c, 48, 44, 32, pal.wallDark, 3)
            ring(c, 48, 44, 20, pal.accent.withAlphaComponent(0.6), 2)
            circle(c, 48, 44, 6, pal.accent.withAlphaComponent(0.85))
        }
    }

    static func door() -> SKTexture {
        make("door", 110, 130) { c in
            var outer = [CGPoint(x: 4, y: 130)]
            outer += arcPoints(55, 52, 51, .pi, 2 * .pi, steps: 24)
            outer.append(CGPoint(x: 106, y: 130))
            fillPts(c, outer, UIColor(hex: 0x3a302c))
            var inner = [CGPoint(x: 16, y: 130)]
            inner += arcPoints(55, 54, 39, .pi, 2 * .pi, steps: 24)
            inner.append(CGPoint(x: 94, y: 130))
            fillPts(c, inner, UIColor(hex: 0x070303))
            strokePts(c, arcPoints(55, 52, 51, .pi, 2 * .pi, steps: 24), UIColor(hex: 0x6a5a52), 2)
        }
    }

    static func bars() -> SKTexture {
        make("bars", 110, 130) { c in
            let col = UIColor(hex: 0x6a625e)
            for i in 0..<5 {
                let x = 22 + CGFloat(i) * 15
                let dx = x + 2 - 55
                let top = 54 - sqrt(max(0, 39 * 39 - dx * dx)) + 3
                rect(c, x, top, 4, 130 - top, col)
            }
            rect(c, 17, 70, 76, 4, col)
            rect(c, 17, 105, 76, 4, col)
        }
    }

    // MARK: - Reward icons

    static func icon(_ r: Reward) -> SKTexture {
        switch r {
        case .boon(let p):
            let col = p.color
            return make("icon_boon_\(p.rawValue)", 48, 48) { c in
                radial(c, 24, 24, 24, [col.withAlphaComponent(0.8), col.withAlphaComponent(0)], [0.25, 1])
                circle(c, 24, 24, 14, col.scaled(0.7))
                ring(c, 24, 24, 14, UIColor(white: 1, alpha: 0.9), 2)
                let w = UIColor(hex: 0xfff4e0)
                switch p {
                case .pyre:
                    poly(c, [(24, 13), (30, 25), (27, 33), (21, 33), (18, 25)], w)
                case .rime:
                    for k in 0..<3 {
                        let a = CGFloat(k) * .pi / 3
                        strokePts(c, [CGPoint(x: 24 - cos(a) * 10, y: 24 - sin(a) * 10), CGPoint(x: 24 + cos(a) * 10, y: 24 + sin(a) * 10)], w, 2.4)
                    }
                case .tempest:
                    poly(c, [(27, 12), (18, 26), (24, 26), (21, 36), (31, 21), (25, 21)], w)
                case .sanguine:
                    circle(c, 24, 28, 6, w)
                    poly(c, [(24, 14), (29.5, 26), (18.5, 26)], w)
                case .umbral:
                    circle(c, 24, 24, 9, w)
                    circle(c, 28, 21, 8, col.scaled(0.7))
                }
            }
        case .heart:
            return make("icon_heart", 48, 48) { c in
                let col = UIColor(hex: 0xe0203a)
                circle(c, 17, 19, 9.5, col)
                circle(c, 31, 19, 9.5, col)
                poly(c, [(8, 22), (40, 22), (24, 41)], col)
                circle(c, 15, 16, 3, UIColor(white: 1, alpha: 0.6))
            }
        case .gold:
            return make("icon_gold", 48, 48) { c in
                circle(c, 24, 24, 17, UIColor(hex: 0xf0c040))
                ring(c, 24, 24, 12, UIColor(hex: 0xb08020), 2.5)
                rect(c, 21, 17, 6, 14, UIColor(hex: 0xb08020))
                circle(c, 18, 17, 3, UIColor(white: 1, alpha: 0.6))
            }
        case .souls:
            return make("icon_souls", 48, 48) { c in
                poly(c, [(24, 3), (40, 21), (24, 45), (8, 21)], UIColor(hex: 0x7a5cff))
                poly(c, [(24, 3), (32, 21), (24, 45), (16, 21)], UIColor(hex: 0xa68cff))
                poly(c, [(24, 3), (28, 21), (20, 21)], UIColor(hex: 0xe0d8ff))
            }
        case .anvil:
            return make("icon_anvil", 48, 48) { c in
                let col = UIColor(hex: 0x8890a0)
                poly(c, [(8, 14), (42, 14), (42, 20), (32, 25), (32, 32), (38, 40), (10, 40), (16, 32), (16, 25), (8, 19)], col)
                poly(c, [(8, 14), (1, 15), (8, 19)], col)
                rect(c, 10, 14, 32, 2.5, UIColor(hex: 0xc8d0e0))
                circle(c, 30, 9, 3, UIColor(hex: 0xff8a30))
            }
        case .heal:
            return make("icon_heal", 48, 48) { c in
                rect(c, 20, 6, 8, 10, UIColor(hex: 0xb8a890))
                circle(c, 24, 29, 14, UIColor(hex: 0xe0303a))
                ring(c, 24, 29, 14, UIColor(white: 1, alpha: 0.6), 2)
                circle(c, 19, 25, 3.5, UIColor(white: 1, alpha: 0.6))
            }
        case .shop:
            return make("icon_shop", 48, 48) { c in
                circle(c, 24, 29, 15, UIColor(hex: 0x8a5a2a))
                poly(c, [(16, 10), (32, 10), (28, 17), (20, 17)], UIColor(hex: 0x8a5a2a))
                rect(c, 18, 15, 12, 3, UIColor(hex: 0xd0a040))
                circle(c, 24, 30, 6, UIColor(hex: 0xf0c040))
            }
        case .boss:
            return make("icon_boss", 48, 48) { c in
                let col = UIColor(hex: 0xd02020)
                circle(c, 24, 20, 15, col)
                rect(c, 15, 28, 18, 10, col)
                circle(c, 18, 20, 4.5, .black)
                circle(c, 30, 20, 4.5, .black)
                for i in 0..<4 { rect(c, 16.5 + CGFloat(i) * 4.5, 33, 2, 5, .black) }
            }
        }
    }
}
