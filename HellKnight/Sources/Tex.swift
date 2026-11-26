import SpriteKit
import UIKit

/// All art is drawn procedurally in a dark gothic "ink engraving" style and cached as textures.
/// Drawing uses UIKit coordinates (origin top-left, y grows downward).
enum Tex {
    private static var cache: [String: SKTexture] = [:]

    /// Screen width of one 128-unit ground segment of wall, its vertical rise, and wall height.
    static let segW: CGFloat = 128 * isoK
    static let segRise: CGFloat = 128 * isoK * 0.5
    static let wallH: CGFloat = 150

    /// Art is rendered at the device's native pixel density (3× on modern iPhones) for crisp edges.
    static let renderScale: CGFloat = max(2, min(3, UIScreen.main.scale))

    static func make(_ key: String, _ w: CGFloat, _ h: CGFloat, _ draw: (CGContext) -> Void) -> SKTexture {
        if let t = cache[key] { return t }
        let format = UIGraphicsImageRendererFormat.default()
        // Very large textures (full-screen panels, vignettes) stay at 2× to save memory.
        format.scale = w * h > 250_000 ? 2 : renderScale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: max(1, w), height: max(1, h)), format: format)
        let image = renderer.image { ctx in draw(ctx.cgContext) }
        let tex = SKTexture(image: image)
        cache[key] = tex
        return tex
    }

    // MARK: - Primitives

    static func P(_ pts: [(CGFloat, CGFloat)]) -> CGPath {
        let p = CGMutablePath()
        p.addLines(between: pts.map { CGPoint(x: $0.0, y: $0.1) })
        p.closeSubpath()
        return p
    }

    static func E(_ x: CGFloat, _ y: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: x - rx, y: y - ry, width: rx * 2, height: ry * 2), transform: nil)
    }

    static func Rr(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ corner: CGFloat = 0) -> CGPath {
        let r = CGRect(x: x, y: y, width: w, height: h)
        if corner > 0 {
            return CGPath(roundedRect: r, cornerWidth: corner, cornerHeight: corner, transform: nil)
        }
        return CGPath(rect: r, transform: nil)
    }

    static func fill(_ c: CGContext, _ path: CGPath, _ col: UIColor) {
        c.addPath(path)
        c.setFillColor(col.cgColor)
        c.fillPath()
    }

    static func stroke(_ c: CGContext, _ path: CGPath, _ col: UIColor, _ lw: CGFloat) {
        c.addPath(path)
        c.setStrokeColor(col.cgColor)
        c.setLineWidth(lw)
        c.setLineJoin(.round)
        c.setLineCap(.round)
        c.strokePath()
    }

    /// Filled shape with a heavy ink outline.
    static func ink(_ c: CGContext, _ path: CGPath, _ col: UIColor, lw: CGFloat = 2.2) {
        fill(c, path, col)
        sheen(c, path, light: 0.3, dark: 0.4)
        stroke(c, path, Ink.black, lw)
    }

    /// Black silhouette with an engraved bone hairline inside the outline.
    static func shade(_ c: CGContext, _ path: CGPath, _ col: UIColor = UIColor(hex: 0x1d1816), rim: UIColor = UIColor(hex: 0xffb27a)) {
        fill(c, path, col)
        sheen(c, path, light: 0.16, dark: 0.55)
        rimLight(c, path, rim.withAlphaComponent(0.85), width: 2)
        stroke(c, path, Ink.black, 2.2)
    }

    /// Engraving-style parallel hatching clipped to a path (and optional region).
    static func hatch(_ c: CGContext, _ path: CGPath, region: CGRect? = nil, spacing: CGFloat = 3.2,
                      angle: CGFloat = 0.8, color: UIColor = Ink.black.withAlphaComponent(0.65), lw: CGFloat = 0.9) {
        c.saveGState()
        c.addPath(path)
        c.clip()
        if let r = region { c.clip(to: r) }
        let b = path.boundingBox
        let cx = b.midX, cy = b.midY
        let diag = hypot(b.width, b.height) / 2 + 2
        let dx = cos(angle), dy = sin(angle)
        let px = -dy, py = dx
        c.setStrokeColor(color.cgColor)
        c.setLineWidth(lw)
        c.beginPath()
        var t = -diag
        while t <= diag {
            c.move(to: CGPoint(x: cx + px * t - dx * diag, y: cy + py * t - dy * diag))
            c.addLine(to: CGPoint(x: cx + px * t + dx * diag, y: cy + py * t + dy * diag))
            t += spacing
        }
        c.strokePath()
        c.restoreGState()
    }

    /// Hatch only the right-hand (shadow) part of a shape.
    static func shadeRight(_ c: CGContext, _ path: CGPath, _ frac: CGFloat = 0.42, spacing: CGFloat = 2.8) {
        let b = path.boundingBox
        hatch(c, path, region: CGRect(x: b.maxX - b.width * frac, y: b.minY, width: b.width * frac, height: b.height), spacing: spacing)
    }

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

    static func line(_ c: CGContext, _ pts: [CGPoint], _ col: UIColor, _ lw: CGFloat) {
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

    static func glowDot(_ c: CGContext, _ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ col: UIColor) {
        radial(c, x, y, r, [col, col.withAlphaComponent(0)], [0.15, 1])
        circle(c, x, y, max(0.8, r * 0.3), UIColor(white: 1, alpha: 0.95))
    }

    static func arcPoints(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat, _ a0: CGFloat, _ a1: CGFloat, steps: Int = 24) -> [CGPoint] {
        var out: [CGPoint] = []
        for i in 0...steps {
            let a = a0 + (a1 - a0) * CGFloat(i) / CGFloat(steps)
            out.append(CGPoint(x: cx + cos(a) * r, y: cy + sin(a) * r))
        }
        return out
    }

    /// Pointed gothic arch path (base at y=bottom).
    static func gothicArch(_ x: CGFloat, _ bottom: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let spring = bottom - h + w * 0.55
        p.move(to: CGPoint(x: x, y: bottom))
        p.addLine(to: CGPoint(x: x, y: spring))
        p.addQuadCurve(to: CGPoint(x: x + w / 2, y: bottom - h), control: CGPoint(x: x, y: bottom - h + w * 0.1))
        p.addQuadCurve(to: CGPoint(x: x + w, y: spring), control: CGPoint(x: x + w, y: bottom - h + w * 0.1))
        p.addLine(to: CGPoint(x: x + w, y: bottom))
        p.closeSubpath()
        return p
    }

    // MARK: - Generic FX

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

    /// Round soft shadow; becomes an ellipse when laid on the isometric ground.
    static func softShadow() -> SKTexture {
        make("softshadow", 64, 64) { c in
            radial(c, 32, 32, 32, [UIColor(white: 0, alpha: 0.7), UIColor(white: 0, alpha: 0.45), UIColor(white: 0, alpha: 0)], [0, 0.5, 1])
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
            circle(c, 64, 64, 62, UIColor(hex: 0xc4161d, alpha: 0.25))
            ring(c, 64, 64, 61, UIColor(hex: 0xff2a1a, alpha: 0.95), 3)
            ring(c, 64, 64, 54, UIColor(hex: 0xff2a1a, alpha: 0.4), 1.5)
        }
    }

    /// Summoning circle drawn on the ground (white; tint it).
    static func sigil() -> SKTexture {
        make("sigil", 160, 160) { c in
            let w = UIColor.white
            ring(c, 80, 80, 76, w, 3)
            ring(c, 80, 80, 66, w, 1.5)
            var star: [CGPoint] = []
            for i in 0..<5 {
                let a = -CGFloat.pi / 2 + CGFloat(i * 2) * 2 * .pi / 5
                star.append(CGPoint(x: 80 + cos(a) * 64, y: 80 + sin(a) * 64))
            }
            star.append(star[0])
            line(c, star, w, 2)
            for i in 0..<24 {
                let a = CGFloat(i) * 2 * .pi / 24
                line(c, [CGPoint(x: 80 + cos(a) * 67, y: 80 + sin(a) * 67), CGPoint(x: 80 + cos(a) * 75, y: 80 + sin(a) * 75)], w, 1.5)
            }
        }
    }

    /// Ink splatter blobs (white; tint black or red).
    static func splat(_ v: Int) -> SKTexture {
        make("splat\(v)", 96, 96) { c in
            var rng = SeededRNG(seed: UInt64(v * 31 + 7))
            circle(c, 48, 48, CGFloat.random(in: 14...20, using: &rng), .white)
            for _ in 0..<14 {
                let a = CGFloat.random(in: 0...(2 * .pi), using: &rng)
                let d = CGFloat.random(in: 10...40, using: &rng)
                let r = CGFloat.random(in: 1.5...7, using: &rng) * (1 - d / 60)
                circle(c, 48 + cos(a) * d, 48 + sin(a) * d, max(1.2, r), .white)
                line(c, [CGPoint(x: 48, y: 48), CGPoint(x: 48 + cos(a) * d * 0.8, y: 48 + sin(a) * d * 0.8)], .white, max(1, r * 0.7))
            }
        }
    }

    /// Soft cinematic vignette.
    static func inkVignette() -> SKTexture {
        make("vignette2", 384, 256) { c in
            let cols = [UIColor(white: 0, alpha: 0).cgColor, UIColor(white: 0, alpha: 0.25).cgColor, UIColor(white: 0, alpha: 0.85).cgColor] as CFArray
            guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0.45, 0.75, 1]) else { return }
            c.saveGState()
            c.scaleBy(x: 1.5, y: 1)
            let p = CGPoint(x: 128, y: 128)
            c.drawRadialGradient(g, startCenter: p, startRadius: 0, endCenter: p, endRadius: 172, options: [.drawsAfterEndLocation])
            c.restoreGState()
        }
    }

    /// Soft cloud of fog (white; tint it).
    static func fog() -> SKTexture {
        make("fog", 256, 160) { c in
            var rng = SeededRNG(seed: 4242)
            for _ in 0..<26 {
                let x = CGFloat.random(in: 50...206, using: &rng)
                let y = CGFloat.random(in: 45...115, using: &rng)
                let r = CGFloat.random(in: 25...55, using: &rng)
                radial(c, x, y, r, [UIColor(white: 1, alpha: 0.16), UIColor(white: 1, alpha: 0)], [0, 1])
            }
        }
    }

    /// Fills a path with a diagonal light→shadow gradient (form shading).
    static func sheen(_ c: CGContext, _ path: CGPath, light: CGFloat = 0.35, dark: CGFloat = 0.45) {
        let b = path.boundingBox
        linear(c, path, UIColor(white: 1, alpha: light), UIColor(white: 0, alpha: dark),
               from: CGPoint(x: b.minX, y: b.minY), to: CGPoint(x: b.maxX, y: b.maxY))
    }

    /// Colored rim light along the upper-left edge of a shape.
    static func rimLight(_ c: CGContext, _ path: CGPath, _ col: UIColor, width: CGFloat = 2.2) {
        let b = path.boundingBox
        c.saveGState()
        c.addPath(path)
        c.setLineWidth(width * 2)
        c.replacePathWithStrokedPath()
        c.clip()
        c.addPath(path)
        c.clip()
        let cols = [col.cgColor, col.withAlphaComponent(0).cgColor] as CFArray
        if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 0.6]) {
            c.drawLinearGradient(g, start: CGPoint(x: b.minX, y: b.minY), end: CGPoint(x: b.maxX, y: b.maxY), options: [])
        }
        c.restoreGState()
    }

    // MARK: - UI (clean, modern)

    private static func colorKey(_ c: UIColor?) -> String {
        guard let c = c else { return "n" }
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getRed(&r, green: &g, blue: &b, alpha: &a)
        return "\(Int(r * 255))_\(Int(g * 255))_\(Int(b * 255))"
    }

    static func linear(_ c: CGContext, _ path: CGPath, _ top: UIColor, _ bottom: UIColor, from p0: CGPoint, to p1: CGPoint) {
        let cols = [top.cgColor, bottom.cgColor] as CFArray
        guard let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 1]) else { return }
        c.saveGState()
        c.addPath(path)
        c.clip()
        c.drawLinearGradient(g, start: p0, end: p1, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
        c.restoreGState()
    }

    /// Sleek translucent panel. `accent` = nil for neutral, a color for a tinted primary panel.
    static func panel(_ w: CGFloat, _ h: CGFloat, accent: UIColor? = nil, fillAlpha: CGFloat = 0.88) -> SKTexture {
        let W = max(16, w.rounded()), H = max(16, h.rounded())
        let key = "panel2_\(Int(W))x\(Int(H))_\(colorKey(accent))_\(Int(fillAlpha * 100))"
        return make(key, W + 8, H + 8) { c in
            let r = min(12, H / 2.6)
            let shape = Rr(4, 4, W, H, r)
            c.saveGState()
            c.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor(white: 0, alpha: 0.6 * fillAlpha).cgColor)
            fill(c, shape, UIColor(white: 0, alpha: fillAlpha * 0.9))
            c.restoreGState()
            if let a = accent {
                linear(c, shape, a.scaled(0.62).withAlphaComponent(fillAlpha), a.scaled(0.32).withAlphaComponent(fillAlpha),
                       from: CGPoint(x: 0, y: 4), to: CGPoint(x: 0, y: H + 4))
                stroke(c, Rr(4.5, 4.5, W - 1, H - 1, r), a.scaled(1.2).withAlphaComponent(0.55), 1)
            } else {
                linear(c, shape, UIColor(hex: 0x1d1917, alpha: fillAlpha), UIColor(hex: 0x0d0b0a, alpha: fillAlpha),
                       from: CGPoint(x: 0, y: 4), to: CGPoint(x: 0, y: H + 4))
                stroke(c, Rr(4.5, 4.5, W - 1, H - 1, r), UIColor(white: 1, alpha: 0.12), 1)
            }
            line(c, [CGPoint(x: 4 + r, y: 5.5), CGPoint(x: W + 4 - r, y: 5.5)], UIColor(white: 1, alpha: 0.1), 1)
        }
    }

    /// Boon card: dark glass card with a glowing colored header.
    static func card(_ w: CGFloat, _ h: CGFloat, accent: UIColor, glow: UIColor? = nil) -> SKTexture {
        let W = w.rounded(), H = h.rounded()
        let gl = glow ?? accent
        return make("card3_\(Int(W))x\(Int(H))_\(colorKey(accent))_\(colorKey(gl))", W + 10, H + 10) { c in
            let shape = Rr(5, 5, W, H, 14)
            c.saveGState()
            c.setShadow(offset: CGSize(width: 0, height: 4), blur: 6, color: UIColor(white: 0, alpha: 0.7).cgColor)
            fill(c, shape, UIColor(hex: 0x0e0b0a))
            c.restoreGState()
            linear(c, shape, UIColor(hex: 0x1c1715), UIColor(hex: 0x0b0908), from: CGPoint(x: 0, y: 5), to: CGPoint(x: 0, y: H + 5))
            c.saveGState()
            c.addPath(shape)
            c.clip()
            radial(c, W / 2 + 5, 40, W * 0.85, [gl.withAlphaComponent(0.38), gl.withAlphaComponent(0)], [0, 1])
            rect(c, 5, 5, W, 3, accent)
            c.restoreGState()
            stroke(c, Rr(5.5, 5.5, W - 1, H - 1, 14), accent.withAlphaComponent(0.55), 1.2)
            circle(c, W / 2 + 5, 41, 24, UIColor(white: 0, alpha: 0.55))
            ring(c, W / 2 + 5, 41, 24, accent.withAlphaComponent(0.7), 1.2)
            let lx0 = CGFloat(24), lx1 = W - 14
            linear(c, Rr(lx0, 114, lx1 - lx0, 1), accent.withAlphaComponent(0), accent.withAlphaComponent(0),
                   from: CGPoint(x: lx0, y: 0), to: CGPoint(x: lx1, y: 0))
            let lineGrad = [accent.withAlphaComponent(0).cgColor, accent.withAlphaComponent(0.6).cgColor, accent.withAlphaComponent(0).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: lineGrad, locations: [0, 0.5, 1]) {
                c.saveGState()
                c.clip(to: CGRect(x: lx0, y: 114, width: lx1 - lx0, height: 1))
                c.drawLinearGradient(g, start: CGPoint(x: lx0, y: 0), end: CGPoint(x: lx1, y: 0), options: [])
                c.restoreGState()
            }
        }
    }

    static func barFrame(_ w: CGFloat, _ h: CGFloat) -> SKTexture {
        let W = w.rounded(), H = h.rounded()
        return make("bar2_\(Int(W))x\(Int(H))", W + 24, H + 8) { c in
            let p = Rr(9, 1, W + 6, H + 6, (H + 6) / 2)
            c.saveGState()
            c.setShadow(offset: CGSize(width: 0, height: 1), blur: 3, color: UIColor(white: 0, alpha: 0.7).cgColor)
            fill(c, p, UIColor(white: 0, alpha: 0.65))
            c.restoreGState()
            stroke(c, p, UIColor(white: 1, alpha: 0.16), 1)
        }
    }

    /// Vertical darkening behind the top HUD row.
    static func scrim() -> SKTexture {
        make("scrim", 8, 64) { c in
            linear(c, Rr(0, 0, 8, 64), UIColor(white: 0, alpha: 0.7), UIColor(white: 0, alpha: 0),
                   from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: 64))
        }
    }

    /// Round charge pip.
    static func gem(_ hex: UInt32) -> SKTexture {
        let col = UIColor(hex: hex)
        return make("pip\(hex)", 16, 16) { c in
            radial(c, 8, 8, 8, [col.withAlphaComponent(0.6), col.withAlphaComponent(0)], [0.4, 1])
            radial(c, 7, 7, 5.5, [col.scaled(1.4), col.scaled(0.75)], [0, 1])
            ring(c, 8, 8, 5, UIColor(white: 0, alpha: 0.6), 1)
        }
    }

    /// Hairline divider fading out at both ends.
    static func divider(_ w: CGFloat) -> SKTexture {
        let W = w.rounded()
        return make("div2_\(Int(W))", W, 6) { c in
            let cols = [UIColor(white: 1, alpha: 0).cgColor, UIColor(white: 1, alpha: 0.55).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray
            if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: cols, locations: [0, 0.5, 1]) {
                c.saveGState()
                c.clip(to: CGRect(x: 0, y: 2.5, width: W, height: 1))
                c.drawLinearGradient(g, start: .zero, end: CGPoint(x: W, y: 0), options: [])
                c.restoreGState()
            }
            circle(c, W / 2, 3, 2.2, Ink.blood.scaled(1.3))
        }
    }

    /// Round touch button.
    static func medallion(_ r: CGFloat, accent: UIColor = UIColor(white: 1, alpha: 1)) -> SKTexture {
        let R = r.rounded()
        return make("btn2_\(Int(R))_\(colorKey(accent))", R * 2 + 4, R * 2 + 4) { c in
            let m = R + 2
            radial(c, m, m, R, [UIColor(white: 0.12, alpha: 0.55), UIColor(white: 0.02, alpha: 0.7)], [0, 1])
            ring(c, m, m, R - 1, accent.withAlphaComponent(0.5), 1.5)
            ring(c, m, m, R - 4, UIColor(white: 1, alpha: 0.06), 1)
        }
    }

    static func joyBase() -> SKTexture {
        make("joybase2", 136, 136) { c in
            radial(c, 68, 68, 60, [UIColor(white: 0, alpha: 0.05), UIColor(white: 0, alpha: 0.35)], [0, 1])
            ring(c, 68, 68, 59, UIColor(white: 1, alpha: 0.28), 1.5)
        }
    }

    static func joyKnob() -> SKTexture {
        make("joyknob2", 60, 60) { c in
            radial(c, 28, 27, 26, [UIColor(white: 0.95, alpha: 0.55), UIColor(white: 0.7, alpha: 0.3)], [0, 1])
            ring(c, 30, 30, 25, UIColor(white: 1, alpha: 0.6), 1.5)
        }
    }

    static func symbol(_ name: String, _ pt: CGFloat = 34, color: UIColor = Ink.bone) -> SKTexture {
        let key = "sym_\(name)_\(Int(pt))"
        if let t = cache[key] { return t }
        let cfg = UIImage.SymbolConfiguration(pointSize: pt, weight: .bold)
        guard let img = UIImage(systemName: name, withConfiguration: cfg)?
            .withTintColor(color, renderingMode: .alwaysOriginal) else { return disc() }
        let s = img.size
        return make(key, s.width, s.height) { _ in
            img.draw(in: CGRect(origin: .zero, size: s))
        }
    }

    // MARK: - Player & weapons (upright, facing right)

    /// Full knight (with cape) for title art, afterimages and silhouettes.
    static func knight() -> SKTexture {
        make("knight", 64, 84) { c in
            drawCape(c)
            drawKnightBody(c)
        }
    }

    /// The knight without the cape; the cape is a separate sprite so it can sway.
    static func knightBody() -> SKTexture {
        make("knightBody", 64, 84) { c in drawKnightBody(c) }
    }

    static func knightCape() -> SKTexture {
        make("knightCape", 64, 84) { c in drawCape(c) }
    }

    private static func drawCape(_ c: CGContext) {
        let cape = P([(19, 30), (45, 30), (54, 79), (47, 75), (40, 81), (32, 76), (24, 81), (17, 75), (10, 79)])
        shade(c, cape)
        hatch(c, cape, spacing: 4, angle: 1.3, color: Ink.boneDark.withAlphaComponent(0.18))
        line(c, [CGPoint(x: 10, y: 79), CGPoint(x: 17, y: 75), CGPoint(x: 24, y: 81), CGPoint(x: 32, y: 76),
                 CGPoint(x: 40, y: 81), CGPoint(x: 47, y: 75), CGPoint(x: 54, y: 79)], Ink.blood, 1.6)
    }

    private static func drawKnightBody(_ c: CGContext) {
        do {
            // legs
            let l1 = P([(24, 60), (31, 60), (30, 80), (21, 80)])
            let l2 = P([(34, 60), (41, 60), (43, 80), (34, 80)])
            ink(c, l1, Ink.steel)
            ink(c, l2, Ink.steel)
            line(c, [CGPoint(x: 25, y: 64), CGPoint(x: 25, y: 77)], Ink.boneDark.withAlphaComponent(0.6), 1)
            // torso
            let torso = P([(20, 32), (44, 32), (42, 52), (38, 62), (26, 62), (22, 52)])
            ink(c, torso, Ink.bone, lw: 2.4)
            shadeRight(c, torso, 0.4)
            rimLight(c, torso, UIColor(white: 1, alpha: 0.9), width: 1.6)
            line(c, [CGPoint(x: 32, y: 34), CGPoint(x: 32, y: 60)], Ink.black, 1)
            line(c, [CGPoint(x: 23, y: 44), CGPoint(x: 41, y: 44)], Ink.black.withAlphaComponent(0.5), 0.8)
            ink(c, Rr(22, 54, 20, 4), Ink.steel, lw: 1.2)
            circle(c, 32, 56, 1.8, Ink.blood)
            // pauldrons
            let p1 = E(19, 34, 8, 6), p2 = E(45, 34, 8, 6)
            ink(c, p1, Ink.bone)
            ink(c, p2, Ink.bone)
            hatch(c, p2, spacing: 2.5)
            // helmet
            let helm = E(32, 21, 10, 11)
            ink(c, helm, Ink.bone, lw: 2.4)
            shadeRight(c, helm, 0.38, spacing: 2.4)
            rimLight(c, helm, UIColor(white: 1, alpha: 0.95), width: 1.6)
            rect(c, 23.5, 20, 17, 3.5, Ink.black)
            rect(c, 30.5, 20, 3, 9, Ink.black)
            glowDot(c, 27, 21.7, 3.4, Ink.blood)
            glowDot(c, 36.5, 21.7, 3.4, Ink.blood)
            // horns
            let h1 = P([(24, 14), (15, 2), (18.5, 0.5), (27.5, 11)])
            let h2 = P([(40, 14), (49, 2), (45.5, 0.5), (36.5, 11)])
            ink(c, h1, Ink.bone, lw: 1.8)
            ink(c, h2, Ink.bone, lw: 1.8)
            hatch(c, h2, spacing: 2)
        }
    }

    static func blade() -> SKTexture {
        make("blade", 72, 16) { c in
            ink(c, Rr(0, 6, 13, 4), Ink.steel, lw: 1.2)
            ink(c, E(2, 8, 3, 3), Ink.gold, lw: 1)
            ink(c, Rr(12, 1, 4, 14), Ink.gold, lw: 1.2)
            let b = P([(16, 4.5), (62, 5), (71, 8), (62, 11), (16, 11.5)])
            ink(c, b, Ink.bone, lw: 1.4)
            hatch(c, b, region: CGRect(x: 16, y: 8, width: 56, height: 4), spacing: 2)
            line(c, [CGPoint(x: 18, y: 8), CGPoint(x: 64, y: 8)], Ink.blood, 1.2)
        }
    }

    static func pike() -> SKTexture {
        make("pike", 112, 16) { c in
            ink(c, Rr(0, 6.5, 84, 3), UIColor(hex: 0x3a2a1e), lw: 1.2)
            ink(c, Rr(76, 2, 3, 12), Ink.steel, lw: 1)
            let h = P([(80, 2), (111, 8), (80, 14), (86, 8)])
            ink(c, h, Ink.bone, lw: 1.4)
            hatch(c, h, region: CGRect(x: 80, y: 8, width: 32, height: 6), spacing: 2)
            line(c, [CGPoint(x: 86, y: 8), CGPoint(x: 104, y: 8)], Ink.blood, 1.2)
        }
    }

    static func fist() -> SKTexture {
        make("fist", 30, 30) { c in
            for pts in [[(20.0, 6.0), (29.0, 9.0), (22.0, 11.0)], [(20.0, 24.0), (29.0, 21.0), (22.0, 19.0)], [(22.0, 13.0), (30.0, 15.0), (22.0, 17.0)]] {
                ink(c, P(pts.map { (CGFloat($0.0), CGFloat($0.1)) }), Ink.bone, lw: 1)
            }
            let f = E(14, 15, 10, 10)
            ink(c, f, Ink.steel, lw: 2)
            stroke(c, E(14, 15, 7, 7), Ink.boneDark, 1)
            glowDot(c, 18, 15, 4, Ink.blood)
        }
    }

    static func weapon(_ w: WeaponKind) -> SKTexture {
        switch w {
        case .blade: return blade()
        case .pike: return pike()
        case .fists: return fist()
        }
    }

    /// Ground-plane slash arc.
    static func slash(arcDeg: Int) -> SKTexture {
        make("slash\(arcDeg)", 128, 128) { c in
            let a = CGFloat(arcDeg) * .pi / 180
            let outer = arcPoints(64, 64, 56, -a / 2, a / 2, steps: 40)
            let inner = arcPoints(64, 64, 38, a / 2 * 0.85, -a / 2 * 0.85, steps: 40)
            let path = CGMutablePath()
            path.addLines(between: outer + inner)
            path.closeSubpath()
            fill(c, path, UIColor(white: 1, alpha: 0.35))
            line(c, arcPoints(64, 64, 52, -a / 2 * 0.95, a / 2 * 0.95, steps: 40), UIColor(white: 1, alpha: 0.95), 5)
            line(c, arcPoints(64, 64, 56, -a / 2, a / 2, steps: 40), UIColor(white: 1, alpha: 0.9), 1.5)
            var rng = SeededRNG(seed: UInt64(arcDeg))
            for _ in 0..<10 {
                let t = CGFloat.random(in: -a / 2...a / 2, using: &rng)
                let r0 = CGFloat.random(in: 40...50, using: &rng)
                line(c, [CGPoint(x: 64 + cos(t) * r0, y: 64 + sin(t) * r0), CGPoint(x: 64 + cos(t) * (r0 + 8), y: 64 + sin(t) * (r0 + 8))],
                     UIColor(white: 1, alpha: 0.6), 1)
            }
        }
    }

    static func thrust() -> SKTexture {
        make("thrust", 128, 24) { c in
            fill(c, P([(0, 12), (24, 5), (128, 11), (128, 13), (24, 19)]), UIColor(white: 1, alpha: 0.4))
            fill(c, P([(10, 12), (30, 9), (124, 11.5), (124, 12.5), (30, 15)]), UIColor(white: 1, alpha: 0.95))
        }
    }

    // MARK: - Enemies (upright, facing right, feet at bottom)

    static func imp() -> SKTexture {
        make("imp", 52, 58) { c in
            shade(c, P([(18, 28), (2, 10), (6, 23), (0, 31), (10, 31), (17, 38)]))
            shade(c, P([(34, 28), (50, 10), (46, 23), (52, 31), (42, 31), (35, 38)]))
            shade(c, P([(19, 47), (24, 47), (22, 57), (15, 57)]))
            shade(c, P([(29, 47), (34, 47), (38, 57), (31, 57)]))
            let body = E(26, 38, 13, 13)
            shade(c, body)
            hatch(c, body, region: CGRect(x: 13, y: 25, width: 10, height: 26), spacing: 3, color: Ink.boneDark.withAlphaComponent(0.25))
            let head = E(26, 25, 11, 10)
            shade(c, head)
            ink(c, P([(18, 19), (12, 5), (21, 16)]), Ink.bone, lw: 1.5)
            ink(c, P([(34, 19), (40, 5), (31, 16)]), Ink.bone, lw: 1.5)
            glowDot(c, 21.5, 24, 4.5, Ink.blood)
            glowDot(c, 31, 24, 4.5, Ink.blood)
            fill(c, P([(19, 29.5), (33, 29.5), (31, 33), (29, 30.5), (27, 33.5), (25, 30.5), (23, 33), (21, 30.5)]), Ink.bone)
            line(c, [CGPoint(x: 12, y: 42), CGPoint(x: 8, y: 47)], Ink.bone, 1.2)
            line(c, [CGPoint(x: 40, y: 42), CGPoint(x: 44, y: 47)], Ink.bone, 1.2)
        }
    }

    static func archer() -> SKTexture {
        make("archer", 56, 66) { c in
            let cloak = P([(14, 22), (38, 22), (45, 64), (7, 64)])
            shade(c, cloak)
            hatch(c, cloak, spacing: 4, angle: 1.4, color: Ink.boneDark.withAlphaComponent(0.2))
            let ribs = E(26, 38, 8.5, 10)
            ink(c, ribs, Ink.bone, lw: 1.6)
            for y in [CGFloat(33), 37, 41, 45] {
                line(c, [CGPoint(x: 19, y: y), CGPoint(x: 33, y: y)], Ink.black, 1.2)
            }
            line(c, [CGPoint(x: 26, y: 29), CGPoint(x: 26, y: 48)], Ink.black, 1.6)
            let skull = E(26, 17, 9, 9.5)
            ink(c, skull, Ink.bone, lw: 2)
            shadeRight(c, skull, 0.35, spacing: 2.2)
            fill(c, E(22.3, 17, 2.8, 3.3), Ink.black)
            fill(c, E(29.7, 17, 2.8, 3.3), Ink.black)
            glowDot(c, 22.3, 17.5, 2.6, Ink.blood)
            glowDot(c, 29.7, 17.5, 2.6, Ink.blood)
            ink(c, Rr(21, 23.5, 10, 5), Ink.bone, lw: 1.4)
            for i in 0..<4 { line(c, [CGPoint(x: 22.5 + CGFloat(i) * 2.4, y: 24), CGPoint(x: 22.5 + CGFloat(i) * 2.4, y: 28)], Ink.black, 0.8) }
            // bow
            let bow = arcPoints(34, 38, 18, -1.25, 1.25, steps: 16)
            line(c, bow, Ink.black, 3.2)
            line(c, bow, Ink.boneDark, 1)
            line(c, [bow[0], bow[bow.count - 1]], Ink.bone.withAlphaComponent(0.8), 0.7)
            line(c, [CGPoint(x: 31, y: 34), CGPoint(x: 42, y: 38)], Ink.bone, 2)
        }
    }

    static func brute() -> SKTexture {
        make("brute", 86, 94) { c in
            shade(c, P([(24, 80), (36, 80), (36, 93), (19, 93)]))
            shade(c, P([(50, 80), (62, 80), (67, 93), (50, 93)]))
            shade(c, P([(7, 40), (18, 37), (21, 70), (5, 75)]))
            shade(c, P([(68, 37), (79, 40), (81, 75), (65, 70)]))
            let body = P([(14, 42), (26, 23), (60, 23), (72, 42), (70, 70), (60, 85), (26, 85), (16, 70)])
            shade(c, body)
            hatch(c, body, region: CGRect(x: 14, y: 23, width: 22, height: 62), spacing: 3.2, color: Ink.boneDark.withAlphaComponent(0.25))
            let plate = P([(30, 47), (56, 47), (52, 64), (34, 64)])
            ink(c, plate, Ink.bone, lw: 1.8)
            shadeRight(c, plate, 0.4)
            for (x, y) in [(CGFloat(6), CGFloat(75)), (12, 76), (66, 76), (73, 75)] {
                ink(c, P([(x, y), (x + 3, y + 6), (x - 2, y + 5)]), Ink.bone, lw: 1)
            }
            let mask = E(43, 33, 13, 12)
            ink(c, mask, Ink.bone, lw: 2.2)
            shadeRight(c, mask, 0.35, spacing: 2.3)
            fill(c, E(37.5, 31, 3.5, 3.2), Ink.black)
            fill(c, E(48.5, 31, 3.5, 3.2), Ink.black)
            glowDot(c, 37.5, 31, 3.8, Ink.blood)
            glowDot(c, 48.5, 31, 3.8, Ink.blood)
            for i in 0..<5 { line(c, [CGPoint(x: 36 + CGFloat(i) * 3.5, y: 39), CGPoint(x: 36 + CGFloat(i) * 3.5, y: 43)], Ink.black, 1) }
            let h1 = P([(31, 25), (11, 8), (8, 1), (19, 6), (35, 19)])
            let h2 = P([(55, 25), (75, 8), (78, 1), (67, 6), (51, 19)])
            ink(c, h1, Ink.bone, lw: 1.8)
            ink(c, h2, Ink.bone, lw: 1.8)
            hatch(c, h1, spacing: 2.4)
            hatch(c, h2, spacing: 2.4)
            for i in 0..<6 {
                let x = 20 + CGFloat(i) * 9
                ring(c, x, 72 + sin(CGFloat(i)) * 2, 2.6, Ink.boneDark, 1.2)
            }
        }
    }

    static func wisp() -> SKTexture {
        make("wisp", 46, 58) { c in
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 23, y: 3))
            p.addCurve(to: CGPoint(x: 40, y: 34), control1: CGPoint(x: 31, y: 14), control2: CGPoint(x: 42, y: 22))
            p.addCurve(to: CGPoint(x: 23, y: 55), control1: CGPoint(x: 39, y: 49), control2: CGPoint(x: 31, y: 55))
            p.addCurve(to: CGPoint(x: 6, y: 34), control1: CGPoint(x: 15, y: 55), control2: CGPoint(x: 6, y: 49))
            p.addCurve(to: CGPoint(x: 23, y: 3), control1: CGPoint(x: 4, y: 22), control2: CGPoint(x: 15, y: 14))
            p.closeSubpath()
            radial(c, 23, 36, 23, [UIColor(white: 1, alpha: 0.7), UIColor(white: 1, alpha: 0)], [0.3, 1])
            fill(c, p, UIColor(white: 0.95, alpha: 0.9))
            hatch(c, p, region: CGRect(x: 26, y: 0, width: 20, height: 58), spacing: 2.6, color: Ink.black.withAlphaComponent(0.35))
            stroke(c, p, Ink.black, 2)
            line(c, [CGPoint(x: 16, y: 20), CGPoint(x: 20, y: 30), CGPoint(x: 15, y: 40)], Ink.black.withAlphaComponent(0.5), 1)
            fill(c, E(17.5, 35, 3.2, 4.2), Ink.black)
            fill(c, E(28.5, 35, 3.2, 4.2), Ink.black)
            fill(c, E(23, 44, 2.6, 3), Ink.black)
        }
    }

    static func priest() -> SKTexture {
        make("priest", 54, 74) { c in
            let robe = P([(27, 14), (42, 30), (49, 72), (5, 72), (12, 30)])
            shade(c, robe)
            hatch(c, robe, spacing: 3.6, angle: 1.45, color: Ink.boneDark.withAlphaComponent(0.2))
            let trim = P([(25, 34), (29, 34), (31, 72), (23, 72)])
            ink(c, trim, Ink.bone, lw: 1.2)
            for y in [CGFloat(42), 52, 62] { ring(c, 27, y, 2, Ink.black, 1) }
            ink(c, P([(4, 36), (10, 34), (12, 42), (6, 44)]), Ink.bone, lw: 1.2)
            ink(c, P([(50, 36), (44, 34), (42, 42), (48, 44)]), Ink.bone, lw: 1.2)
            let hood = P([(27, 3), (41, 22), (37, 33), (17, 33), (13, 22)])
            shade(c, hood)
            fill(c, E(27, 22, 7, 8), UIColor(hex: 0x000000))
            glowDot(c, 27, 21, 5, UIColor(hex: 0xff3090))
            ring(c, 27, 8, 9, Ink.bone.withAlphaComponent(0.5), 0.9)
        }
    }

    static func boss(_ depth: Int) -> SKTexture {
        let accents: [UInt32] = [0xff6a1f, 0x9dff6e, 0x9a7cff]
        let d = min(max(depth, 0), 2)
        let acc = UIColor(hex: accents[d])
        return make("boss\(d)", 160, 184) { c in
            radial(c, 80, 96, 90, [acc.withAlphaComponent(0.35), acc.withAlphaComponent(0)], [0.3, 1])
            // arms
            shade(c, P([(26, 70), (8, 120), (14, 150), (30, 146), (34, 100)]))
            shade(c, P([(134, 70), (152, 120), (146, 150), (130, 146), (126, 100)]))
            for x in [CGFloat(10), 18, 26] { ink(c, P([(x, 148), (x + 3, 160), (x - 2, 156)]), Ink.bone, lw: 1) }
            for x in [CGFloat(134), 142, 150] { ink(c, P([(x, 148), (x + 2, 160), (x - 3, 156)]), Ink.bone, lw: 1) }
            // body / robe
            let body = P([(32, 74), (56, 46), (104, 46), (128, 74), (140, 182), (20, 182)])
            shade(c, body)
            hatch(c, body, region: CGRect(x: 20, y: 46, width: 40, height: 136), spacing: 3.5, color: Ink.boneDark.withAlphaComponent(0.22))
            // chest core
            radial(c, 80, 100, 26, [acc, acc.withAlphaComponent(0)], [0.1, 1])
            ink(c, P([(80, 84), (92, 100), (80, 116), (68, 100)]), acc.scaled(0.8), lw: 2)
            switch d {
            case 0:
                for pts in [[(48.0, 90.0), (60.0, 110.0), (54.0, 130.0), (64.0, 160.0)], [(110.0, 92.0), (100.0, 118.0), (108.0, 140.0), (96.0, 170.0)]] {
                    let cp = pts.map { CGPoint(x: CGFloat($0.0), y: CGFloat($0.1)) }
                    line(c, cp, acc.withAlphaComponent(0.5), 5)
                    line(c, cp, UIColor(hex: 0xffd090), 1.5)
                }
            case 1:
                for i in 0..<5 {
                    let y = 120 + CGFloat(i) * 10
                    ink(c, P([(56, y), (104, y), (100, y + 4), (60, y + 4)]), Ink.bone, lw: 1.2)
                }
                line(c, [CGPoint(x: 80, y: 118), CGPoint(x: 80, y: 170)], Ink.bone, 3)
            default:
                for (x, y) in [(CGFloat(58), CGFloat(126)), (102, 126), (66, 150), (94, 150)] {
                    fill(c, E(x, y, 4.5, 3), Ink.black)
                    glowDot(c, x, y, 4, acc)
                }
            }
            // head
            let mask = E(80, 40, 21, 23)
            ink(c, mask, Ink.bone, lw: 2.6)
            shadeRight(c, mask, 0.36, spacing: 2.6)
            fill(c, P([(64, 36), (77, 40), (75, 46), (64, 43)]), Ink.black)
            fill(c, P([(96, 36), (83, 40), (85, 46), (96, 43)]), Ink.black)
            glowDot(c, 71, 41, 6, acc)
            glowDot(c, 89, 41, 6, acc)
            fill(c, P([(68, 52), (92, 52), (88, 60), (84, 55), (80, 61), (76, 55), (72, 60)]), Ink.black)
            // crown
            for i in 0..<5 {
                let x = 58 + CGFloat(i) * 11
                let tall: CGFloat = i == 2 ? 30 : (i == 1 || i == 3 ? 22 : 15)
                let sp = P([(x - 5, 22), (x, 22 - tall), (x + 5, 22)])
                ink(c, sp, d == 2 ? Ink.black : Ink.bone, lw: 1.8)
                if d == 2 { stroke(c, sp, acc, 0.8) }
            }
            if d == 2 {
                ink(c, P([(60, 30), (34, 10), (30, 0), (44, 8), (64, 22)]), Ink.bone, lw: 1.8)
                ink(c, P([(100, 30), (126, 10), (130, 0), (116, 8), (96, 22)]), Ink.bone, lw: 1.8)
            }
            if d == 1 {
                stroke(c, P([(58, 30), (40, 100), (46, 140)]), Ink.bone.withAlphaComponent(0.4), 1)
                stroke(c, P([(102, 30), (120, 100), (114, 140)]), Ink.bone.withAlphaComponent(0.4), 1)
            }
        }
    }

    static func orb() -> SKTexture {
        make("orb", 28, 28) { c in
            radial(c, 14, 14, 14, [UIColor(white: 1, alpha: 1), UIColor(white: 1, alpha: 0.85), UIColor(white: 1, alpha: 0)], [0, 0.4, 1])
        }
    }

    static func arrow() -> SKTexture {
        make("arrow", 36, 12) { c in
            ink(c, Rr(1, 5, 24, 2), Ink.boneDark, lw: 0.8)
            ink(c, P([(22, 1), (35, 6), (22, 11)]), Ink.bone, lw: 1.2)
            ink(c, P([(0, 1.5), (7, 6), (0, 10.5)]), Ink.blood, lw: 0.8)
        }
    }

    // MARK: - Environment

    /// Floor tile laid on the ground plane (128×128 ground units).
    static func floor(_ depth: Int, _ v: Int) -> SKTexture {
        let pal = Palette.of(depth)
        return make("floor\(depth)_\(v)", 128, 128) { c in
            var rng = SeededRNG(seed: UInt64(depth * 97 + v * 13 + 5))
            rect(c, 0, 0, 128, 128, Ink.black)
            for i in 0..<2 {
                for j in 0..<2 {
                    let ox = CGFloat(i) * 64, oy = CGFloat(j) * 64
                    let t = CGFloat.random(in: 0...1, using: &rng)
                    let base = (t > 0.5 ? pal.floor : pal.floorAlt).scaled(CGFloat.random(in: 0.9...1.12, using: &rng))
                    let slab = Rr(ox + 2, oy + 2, 60, 60)
                    fill(c, slab, base)
                    stroke(c, Rr(ox + 4, oy + 4, 56, 56), pal.line.withAlphaComponent(0.1), 1)
                    if CGFloat.random(in: 0...1, using: &rng) < 0.55 {
                        let corner = CGRect(x: ox + 2, y: oy + 34, width: 28, height: 28)
                        hatch(c, slab, region: corner, spacing: 3, angle: 0.8, color: Ink.black.withAlphaComponent(0.4), lw: 0.8)
                    }
                    for _ in 0..<5 {
                        let x = ox + CGFloat.random(in: 8...56, using: &rng)
                        let y = oy + CGFloat.random(in: 8...56, using: &rng)
                        circle(c, x, y, CGFloat.random(in: 0.6...1.6, using: &rng), pal.line.withAlphaComponent(0.12))
                    }
                }
            }
            if v == 1 || v == 3 {
                var p = CGPoint(x: CGFloat.random(in: 20...108, using: &rng), y: CGFloat.random(in: 20...108, using: &rng))
                var pts = [p]
                for _ in 0..<6 {
                    p = CGPoint(x: p.x + CGFloat.random(in: -18...18, using: &rng), y: p.y + CGFloat.random(in: -18...18, using: &rng))
                    pts.append(p)
                }
                line(c, pts, pal.accent.withAlphaComponent(0.22), 5)
                line(c, pts, pal.accent.withAlphaComponent(0.9), 1.3)
            }
            if v == 2 {
                ring(c, 64, 64, 20, pal.line.withAlphaComponent(0.16), 1.2)
                ring(c, 64, 64, 14, pal.line.withAlphaComponent(0.1), 0.8)
                for k in 0..<6 {
                    let a = CGFloat(k) * .pi / 3
                    line(c, [CGPoint(x: 64 + cos(a) * 14, y: 64 + sin(a) * 14), CGPoint(x: 64 + cos(a) * 20, y: 64 + sin(a) * 20)],
                         pal.line.withAlphaComponent(0.16), 1)
                }
            }
        }
    }

    /// Draws a straight wall face of size (w × wallH), then the caller shears it.
    private static func wallFace(_ c: CGContext, _ w: CGFloat, _ pal: Palette, _ v: Int, light: CGFloat, seed: UInt64) {
        let H = wallH
        var rng = SeededRNG(seed: seed)
        rect(c, 0, 0, w, H, pal.stoneDark)
        var y: CGFloat = 16
        var row = 0
        while y < H - 10 {
            var x: CGFloat = row % 2 == 0 ? -12 : 2
            while x < w {
                let shade = CGFloat.random(in: 0.78...1.08, using: &rng) * light
                let blk = Rr(x + 1, y + 1, 27, 16)
                fill(c, blk, pal.stone.scaled(shade))
                stroke(c, blk, Ink.black, 1.3)
                line(c, [CGPoint(x: x + 2, y: y + 2.5), CGPoint(x: x + 27, y: y + 2.5)], pal.line.withAlphaComponent(0.18), 0.8)
                if CGFloat.random(in: 0...1, using: &rng) < 0.35 {
                    hatch(c, blk, spacing: 2.4, color: Ink.black.withAlphaComponent(0.5), lw: 0.7)
                }
                x += 28
            }
            y += 18
            row += 1
        }
        // cornice and base
        rect(c, 0, 0, w, 16, pal.stone.scaled(0.7 * light))
        line(c, [CGPoint(x: 0, y: 15.5), CGPoint(x: w, y: 15.5)], Ink.black, 2)
        line(c, [CGPoint(x: 0, y: 3), CGPoint(x: w, y: 3)], pal.line.withAlphaComponent(0.3), 1)
        for i in stride(from: CGFloat(4), to: w, by: 12) {
            fill(c, P([(i, 15), (i + 4, 8), (i + 8, 15)]), Ink.black.withAlphaComponent(0.6))
        }
        rect(c, 0, H - 12, w, 12, pal.stoneDark)
        line(c, [CGPoint(x: 0, y: H - 12), CGPoint(x: w, y: H - 12)], Ink.black, 2)
        if v == 1 {
            let aw = min(30, w * 0.55)
            let arch = gothicArch(w / 2 - aw / 2, H - 30, aw, 78)
            fill(c, arch, Ink.black)
            c.saveGState()
            c.addPath(arch)
            c.clip()
            radial(c, w / 2, H - 50, 46, [pal.accent.withAlphaComponent(0.9), pal.accent.withAlphaComponent(0)], [0, 1])
            for i in 0..<3 { rect(c, w / 2 - aw * 0.3 + CGFloat(i) * aw * 0.27, H - 110, 2.5, 80, Ink.black) }
            c.restoreGState()
            stroke(c, arch, Ink.black, 3)
            stroke(c, arch, pal.line.withAlphaComponent(0.5), 1)
        } else if v == 3 {
            let bw: CGFloat = min(36, w * 0.72)
            let bx = w / 2 - bw / 2
            let cloth = P([(bx, 24), (bx + bw, 24), (bx + bw, H - 46), (bx + bw / 2, H - 60), (bx, H - 46)])
            c.saveGState()
            c.setShadow(offset: CGSize(width: 3, height: 3), blur: 4, color: UIColor(white: 0, alpha: 0.6).cgColor)
            fill(c, cloth, UIColor(hex: 0x6e0f14))
            c.restoreGState()
            linear(c, cloth, UIColor(hex: 0x9c1a20), UIColor(hex: 0x3c070a), from: CGPoint(x: bx, y: 24), to: CGPoint(x: bx + bw, y: H - 50))
            for k in 0..<3 {
                let fx = bx + 8 + CGFloat(k) * 10
                line(c, [CGPoint(x: fx, y: 30), CGPoint(x: fx + 1, y: H - 56)], UIColor(white: 0, alpha: 0.25), 2)
            }
            stroke(c, cloth, Ink.black, 1.6)
            stroke(c, P([(bx + 3, 27), (bx + bw - 3, 27), (bx + bw - 3, H - 48), (bx + bw / 2, H - 61), (bx + 3, H - 48)]), Ink.gold.withAlphaComponent(0.7), 1)
            let es = bw / 36
            let em = E(w / 2, 62, 9 * es, 10 * es)
            ink(c, em, Ink.bone, lw: 1.4)
            fill(c, E(w / 2 - 3.2 * es, 62, 2 * es, 2.4 * es), Ink.black)
            fill(c, E(w / 2 + 3.2 * es, 62, 2 * es, 2.4 * es), Ink.black)
            ink(c, Rr(bx - 4, 20, bw + 8, 4, 2), Ink.gold, lw: 1)
        } else if v == 2 {
            let niche = gothicArch(w / 2 - 12, H - 40, 24, 46)
            fill(c, niche, Ink.black)
            stroke(c, niche, pal.line.withAlphaComponent(0.4), 1)
            let sk = E(w / 2, H - 52, 6, 6.5)
            ink(c, sk, Ink.bone, lw: 1.2)
            fill(c, E(w / 2 - 2.2, H - 52, 1.5, 1.8), Ink.black)
            fill(c, E(w / 2 + 2.2, H - 52, 1.5, 1.8), Ink.black)
            for k in 0..<2 {
                let x = w / 2 - w * 0.24 + CGFloat(k) * w * 0.48
                line(c, [CGPoint(x: x, y: 16), CGPoint(x: x + 3, y: 50), CGPoint(x: x, y: 80)], Ink.boneDark.withAlphaComponent(0.7), 1.5)
            }
        }
    }

    /// Wall segment. side 0 = back-left wall (rises to the right), side 1 = back-right wall (falls to the right).
    static func wallSeg(_ depth: Int, side: Int, _ v: Int, len: CGFloat = 128) -> SKTexture {
        let pal = Palette.of(depth)
        let w = len * isoK + 1
        let rise = len * isoK * 0.5
        return make("wall\(depth)_\(side)_\(v)_\(Int(len))", w, wallH + rise) { c in
            c.saveGState()
            if side == 0 {
                c.concatenate(CGAffineTransform(a: 1, b: -0.5, c: 0, d: 1, tx: 0, ty: rise))
            } else {
                c.concatenate(CGAffineTransform(a: 1, b: 0.5, c: 0, d: 1, tx: 0, ty: 0))
            }
            wallFace(c, w, pal, v, light: side == 0 ? 1.0 : 0.72, seed: UInt64(depth * 11 + side * 5 + v))
            c.restoreGState()
        }
    }

    /// Door built into a back-left wall segment.
    static func doorSeg(_ depth: Int) -> SKTexture {
        let pal = Palette.of(depth)
        let w = segW + 1
        return make("door\(depth)", w, wallH + segRise) { c in
            c.saveGState()
            c.concatenate(CGAffineTransform(a: 1, b: -0.5, c: 0, d: 1, tx: 0, ty: segRise))
            wallFace(c, w, pal, 0, light: 1, seed: UInt64(depth * 7 + 99))
            let arch = gothicArch(w / 2 - 27, wallH - 4, 54, 112)
            let frame = gothicArch(w / 2 - 34, wallH - 2, 68, 122)
            ink(c, frame, pal.stone.scaled(1.25), lw: 2.4)
            hatch(c, frame, spacing: 3, color: Ink.black.withAlphaComponent(0.4))
            fill(c, arch, Ink.black)
            stroke(c, arch, pal.line.withAlphaComponent(0.6), 1.2)
            fill(c, P([(w / 2 - 6, wallH - 120), (w / 2 + 6, wallH - 120), (w / 2 + 4, wallH - 108), (w / 2 - 4, wallH - 108)]), pal.line.withAlphaComponent(0.7))
            c.restoreGState()
        }
    }

    static func bars(_ depth: Int) -> SKTexture {
        let w = segW + 1
        return make("bars\(depth)", w, wallH + segRise) { c in
            c.saveGState()
            c.concatenate(CGAffineTransform(a: 1, b: -0.5, c: 0, d: 1, tx: 0, ty: segRise))
            let arch = gothicArch(w / 2 - 27, wallH - 4, 54, 112)
            c.addPath(arch)
            c.clip()
            for i in 0..<6 {
                let x = w / 2 - 24 + CGFloat(i) * 9.5
                rect(c, x - 1.5, 0, 3.5, wallH, Ink.black)
                rect(c, x - 0.5, 0, 1.2, wallH, Ink.boneDark.withAlphaComponent(0.7))
                fill(c, P([(x - 2, wallH - 4), (x + 0.25, wallH + 2), (x + 2.5, wallH - 4)]), Ink.boneDark)
            }
            for y in [wallH - 80, wallH - 40] {
                rect(c, 0, y, w, 3.5, Ink.black)
                rect(c, 0, y + 1, w, 1.2, Ink.boneDark.withAlphaComponent(0.7))
            }
            c.restoreGState()
        }
    }

    static func pillar(_ depth: Int) -> SKTexture {
        let pal = Palette.of(depth)
        return make("pillar\(depth)", 72, 200) { c in
            let base = P([(6, 198), (66, 198), (62, 182), (10, 182)])
            ink(c, base, pal.stone.scaled(0.9))
            let shaft = Rr(16, 34, 40, 150)
            fill(c, shaft, pal.stone)
            for i in 0..<5 {
                let x = 20 + CGFloat(i) * 8
                line(c, [CGPoint(x: x, y: 36), CGPoint(x: x, y: 180)], Ink.black.withAlphaComponent(0.55), 1.3)
                line(c, [CGPoint(x: x + 1.5, y: 36), CGPoint(x: x + 1.5, y: 180)], pal.line.withAlphaComponent(0.15), 0.8)
            }
            hatch(c, shaft, region: CGRect(x: 40, y: 30, width: 20, height: 160), spacing: 2.6)
            stroke(c, shaft, Ink.black, 2.4)
            // rune glow
            radial(c, 36, 110, 16, [pal.accent.withAlphaComponent(0.7), pal.accent.withAlphaComponent(0)], [0, 1])
            line(c, [CGPoint(x: 36, y: 100), CGPoint(x: 36, y: 120)], pal.accent, 1.6)
            line(c, [CGPoint(x: 30, y: 106), CGPoint(x: 42, y: 114)], pal.accent, 1.2)
            let cap = P([(4, 34), (68, 34), (60, 18), (12, 18)])
            ink(c, cap, pal.stone.scaled(1.15))
            hatch(c, cap, region: CGRect(x: 44, y: 16, width: 26, height: 20), spacing: 2.4)
            let top = Rr(8, 8, 56, 11)
            ink(c, top, pal.stone.scaled(0.85))
            line(c, [CGPoint(x: 10, y: 10.5), CGPoint(x: 62, y: 10.5)], pal.line.withAlphaComponent(0.3), 1)
            line(c, [CGPoint(x: 46, y: 60), CGPoint(x: 52, y: 72), CGPoint(x: 48, y: 84)], Ink.black, 1.2)
        }
    }

    static func sconce() -> SKTexture {
        make("sconce", 24, 30) { c in
            ink(c, P([(6, 10), (18, 10), (14, 18), (10, 18)]), Ink.steel, lw: 1.4)
            ink(c, Rr(10.5, 18, 3, 12), Ink.steel, lw: 1)
            ring(c, 12, 10, 6, Ink.black, 1.5)
        }
    }

    static func pedestal(_ depth: Int) -> SKTexture {
        let pal = Palette.of(depth)
        return make("pedestal\(depth)", 64, 56) { c in
            ink(c, P([(6, 54), (58, 54), (54, 44), (10, 44)]), pal.stone.scaled(0.9))
            let col = Rr(18, 16, 28, 28)
            ink(c, col, pal.stone)
            hatch(c, col, region: CGRect(x: 34, y: 14, width: 14, height: 32), spacing: 2.4)
            ink(c, E(32, 14, 22, 7), pal.stone.scaled(1.2))
            ring(c, 32, 14, 14, pal.accent.withAlphaComponent(0.5), 1)
        }
    }

    // MARK: - Arena features

    static let blockH: CGFloat = 78

    /// Isometric stone block occupying one 64×64 ground cell.
    static func block(_ depth: Int) -> SKTexture {
        let pal = Palette.of(depth)
        let w = 64 * isoK * 2, dh = 64 * isoK
        let H = blockH
        return make("block\(depth)", w + 2, H + dh + 2) { c in
            let top = P([(w / 2 + 1, 1), (w + 1, dh / 2 + 1), (w / 2 + 1, dh + 1), (1, dh / 2 + 1)])
            let left = P([(1, dh / 2 + 1), (w / 2 + 1, dh + 1), (w / 2 + 1, dh + H + 1), (1, dh / 2 + H + 1)])
            let right = P([(w / 2 + 1, dh + 1), (w + 1, dh / 2 + 1), (w + 1, dh / 2 + H + 1), (w / 2 + 1, dh + H + 1)])
            fill(c, left, pal.stone.scaled(0.85))
            fill(c, right, pal.stone.scaled(0.55))
            for k in 1..<4 {
                let y = CGFloat(k) * H / 4
                line(c, [CGPoint(x: 1, y: dh / 2 + 1 + y), CGPoint(x: w / 2 + 1, y: dh + 1 + y)], Ink.black.withAlphaComponent(0.7), 1.2)
                line(c, [CGPoint(x: w / 2 + 1, y: dh + 1 + y), CGPoint(x: w + 1, y: dh / 2 + 1 + y)], Ink.black.withAlphaComponent(0.7), 1.2)
            }
            for k in 0..<4 {
                let y = CGFloat(k) * H / 4 + H / 8
                let off: CGFloat = k % 2 == 0 ? 0.33 : 0.66
                line(c, [CGPoint(x: 1 + w / 2 * off, y: dh / 2 + 1 + y + dh / 2 * off - H / 8),
                         CGPoint(x: 1 + w / 2 * off, y: dh / 2 + 1 + y + dh / 2 * off + H / 8)], Ink.black.withAlphaComponent(0.6), 1)
                line(c, [CGPoint(x: w / 2 + 1 + w / 2 * off, y: dh + 1 + y - dh / 2 * off - H / 8),
                         CGPoint(x: w / 2 + 1 + w / 2 * off, y: dh + 1 + y - dh / 2 * off + H / 8)], Ink.black.withAlphaComponent(0.6), 1)
            }
            hatch(c, right, spacing: 3, color: Ink.black.withAlphaComponent(0.35))
            fill(c, top, pal.stone.scaled(1.2))
            sheen(c, top, light: 0.2, dark: 0.2)
            stroke(c, P([(w / 2 + 1, 9), (w - 13, dh / 2 + 1), (w / 2 + 1, dh - 7), (15, dh / 2 + 1)]), pal.line.withAlphaComponent(0.25), 1)
            for p in [top, left, right] { stroke(c, p, Ink.black, 1.8) }
            line(c, [CGPoint(x: 1, y: dh / 2 + 1), CGPoint(x: w / 2 + 1, y: dh + 1), CGPoint(x: w + 1, y: dh / 2 + 1)], pal.line.withAlphaComponent(0.45), 1)
        }
    }

    /// Burning pool cell (ground plane, 64×64).
    static func lava(_ depth: Int, _ v: Int) -> SKTexture {
        let pal = Palette.of(depth)
        return make("lava\(depth)_\(v)", 64, 64) { c in
            var rng = SeededRNG(seed: UInt64(depth * 13 + v + 900))
            rect(c, 0, 0, 64, 64, pal.accent.scaled(0.45))
            for _ in 0..<5 {
                let x = CGFloat.random(in: 4...60, using: &rng), y = CGFloat.random(in: 4...60, using: &rng)
                radial(c, x, y, CGFloat.random(in: 10...22, using: &rng), [UIColor(hex: 0xfff0c0, alpha: 0.9), pal.accent.withAlphaComponent(0)], [0, 1])
            }
            for _ in 0..<3 {
                var p = CGPoint(x: CGFloat.random(in: 0...64, using: &rng), y: CGFloat.random(in: 0...64, using: &rng))
                var pts = [p]
                for _ in 0..<4 {
                    p = CGPoint(x: p.x + CGFloat.random(in: -14...14, using: &rng), y: p.y + CGFloat.random(in: -14...14, using: &rng))
                    pts.append(p)
                }
                line(c, pts, pal.accent.scaled(0.25), 3)
            }
        }
    }

    /// Chasm cell: deep shaft fading to darkness with a faint glow far below.
    static func pit(_ depth: Int) -> SKTexture {
        let pal = Palette.of(depth)
        return make("pit\(depth)", 64, 64) { c in
            rect(c, 0, 0, 64, 64, UIColor(hex: 0x020102))
            radial(c, 32, 32, 40, [pal.accent.withAlphaComponent(0.16), pal.accent.withAlphaComponent(0)], [0, 1])
        }
    }

    /// The visible far wall inside a chasm (ground strip, 64×22).
    static func pitWall(_ depth: Int) -> SKTexture {
        let pal = Palette.of(depth)
        return make("pitwall\(depth)", 64, 26) { c in
            linear(c, Rr(0, 0, 64, 26), pal.stone.scaled(0.8), UIColor(hex: 0x020102), from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: 26))
            for x in stride(from: CGFloat(0), to: 64, by: 16) {
                line(c, [CGPoint(x: x, y: 0), CGPoint(x: x, y: 10)], Ink.black, 1)
            }
            line(c, [CGPoint(x: 0, y: 0.5), CGPoint(x: 64, y: 0.5)], pal.line.withAlphaComponent(0.4), 1)
        }
    }

    static func spikePlate(_ depth: Int) -> SKTexture {
        let pal = Palette.of(depth)
        return make("spikeplate\(depth)", 64, 64) { c in
            rect(c, 2, 2, 60, 60, pal.stone.scaled(0.6))
            stroke(c, Rr(3, 3, 58, 58), Ink.black, 2)
            stroke(c, Rr(6, 6, 52, 52), pal.line.withAlphaComponent(0.2), 1)
            for i in 0..<4 {
                for j in 0..<4 {
                    circle(c, 12 + CGFloat(i) * 13.3, 12 + CGFloat(j) * 13.3, 3.2, Ink.black)
                }
            }
        }
    }

    /// Upright cluster of spikes (billboard).
    static func spikesUp() -> SKTexture {
        make("spikesup", 84, 50) { c in
            let xs: [CGFloat] = [10, 22, 34, 46, 58, 70, 16, 40, 64]
            for (i, x) in xs.enumerated() {
                let base: CGFloat = i < 6 ? 46 : 38
                let tip: CGFloat = i < 6 ? 6 : 12
                let sp = P([(x - 4, base), (x, tip), (x + 4, base)])
                ink(c, sp, Ink.bone, lw: 1.2)
                line(c, [CGPoint(x: x, y: tip + 2), CGPoint(x: x, y: tip + 9)], Ink.blood, 1.4)
            }
        }
    }

    static func urn() -> SKTexture {
        make("urn", 40, 50) { c in
            let body = CGMutablePath()
            body.move(to: CGPoint(x: 14, y: 6))
            body.addLine(to: CGPoint(x: 26, y: 6))
            body.addCurve(to: CGPoint(x: 28, y: 48), control1: CGPoint(x: 42, y: 18), control2: CGPoint(x: 38, y: 40))
            body.addLine(to: CGPoint(x: 12, y: 48))
            body.addCurve(to: CGPoint(x: 14, y: 6), control1: CGPoint(x: 2, y: 40), control2: CGPoint(x: -2, y: 18))
            body.closeSubpath()
            ink(c, body, UIColor(hex: 0x7a4a2c), lw: 2)
            hatch(c, body, region: CGRect(x: 24, y: 0, width: 20, height: 50), spacing: 2.6)
            line(c, [CGPoint(x: 8, y: 22), CGPoint(x: 32, y: 22)], Ink.gold.withAlphaComponent(0.7), 1.6)
            line(c, [CGPoint(x: 8, y: 30), CGPoint(x: 32, y: 30)], Ink.black.withAlphaComponent(0.5), 1)
            ink(c, Rr(12, 2, 16, 6, 2), UIColor(hex: 0x5a3420), lw: 1.4)
        }
    }

    static func fountain(_ depth: Int) -> SKTexture {
        let pal = Palette.of(depth)
        return make("fountain\(depth)", 140, 130) { c in
            let basin = P([(6, 96), (134, 96), (124, 124), (16, 124)])
            ink(c, basin, pal.stone.scaled(1.05))
            hatch(c, basin, region: CGRect(x: 90, y: 90, width: 50, height: 40), spacing: 2.6)
            fill(c, E(70, 96, 64, 14), UIColor(hex: 0x5a0a10))
            radial(c, 70, 96, 50, [UIColor(hex: 0xff5060, alpha: 0.8), UIColor(hex: 0xff5060, alpha: 0)], [0, 1])
            stroke(c, E(70, 96, 64, 14), Ink.black, 2)
            let col = Rr(60, 40, 20, 56)
            ink(c, col, pal.stone)
            hatch(c, col, region: CGRect(x: 72, y: 40, width: 10, height: 56), spacing: 2.4)
            ink(c, E(70, 40, 26, 7), pal.stone.scaled(1.2))
            let sk = E(70, 24, 11, 12)
            ink(c, sk, Ink.bone, lw: 1.8)
            fill(c, E(66, 24, 2.8, 3.2), Ink.black)
            fill(c, E(74, 24, 2.8, 3.2), Ink.black)
            line(c, [CGPoint(x: 66, y: 30), CGPoint(x: 62, y: 58), CGPoint(x: 58, y: 90)], UIColor(hex: 0xff3048), 2.4)
            line(c, [CGPoint(x: 74, y: 30), CGPoint(x: 78, y: 58), CGPoint(x: 82, y: 90)], UIColor(hex: 0xff3048), 2.4)
        }
    }

    static func altar(_ depth: Int) -> SKTexture {
        let pal = Palette.of(depth)
        return make("altar\(depth)", 130, 110) { c in
            let slab = P([(10, 60), (120, 60), (114, 106), (16, 106)])
            ink(c, slab, pal.stone.scaled(0.95))
            hatch(c, slab, region: CGRect(x: 84, y: 58, width: 40, height: 50), spacing: 2.6)
            ink(c, Rr(4, 50, 122, 12, 3), pal.stone.scaled(1.25))
            for x in [CGFloat(34), 65, 96] {
                ink(c, Rr(x - 4, 30, 8, 22, 2), Ink.bone, lw: 1.2)
                line(c, [CGPoint(x: x, y: 30), CGPoint(x: x, y: 26)], Ink.black, 1)
            }
            radial(c, 65, 84, 22, [UIColor(hex: 0xc070ff), UIColor(hex: 0xc070ff, alpha: 0)], [0, 1])
            stroke(c, P([(65, 70), (76, 84), (65, 98), (54, 84)]), UIColor(hex: 0xe8c0ff), 1.6)
            fill(c, E(65, 84, 3, 3), .white)
            splatDots(c, 30, 104)
        }
    }

    private static func splatDots(_ c: CGContext, _ x: CGFloat, _ y: CGFloat) {
        for (dx, r) in [(CGFloat(0), CGFloat(3)), (8, 2), (16, 1.5), (60, 2.5), (68, 1.6)] {
            circle(c, x + dx, y - 2, r, Ink.blood)
        }
    }

    // MARK: - Props

    static func brazier() -> SKTexture {
        make("brazier", 56, 72) { c in
            for (x0, x1) in [(CGFloat(14), CGFloat(8)), (42, 48), (28, 28)] {
                line(c, [CGPoint(x: x0, y: 40), CGPoint(x: x1, y: 70)], Ink.black, 4)
                line(c, [CGPoint(x: x0, y: 40), CGPoint(x: x1, y: 70)], UIColor(hex: 0x4a423c), 1.6)
            }
            let bowl = P([(4, 26), (52, 26), (44, 42), (12, 42)])
            ink(c, bowl, UIColor(hex: 0x3a332e), lw: 2)
            hatch(c, bowl, region: CGRect(x: 30, y: 24, width: 24, height: 20), spacing: 2.4)
            fill(c, E(28, 26, 22, 5), UIColor(hex: 0x1a0a05))
            for (x, y) in [(CGFloat(18), CGFloat(25)), (26, 23), (34, 25), (40, 24), (22, 27)] {
                radial(c, x, y, 5, [UIColor(hex: 0xffd27a), UIColor(hex: 0xff5a10, alpha: 0)], [0, 1])
            }
            stroke(c, E(28, 26, 22, 5), Ink.black, 1.6)
        }
    }

    static func flame() -> SKTexture {
        make("flame", 32, 48) { c in
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 16, y: 1))
            p.addCurve(to: CGPoint(x: 28, y: 34), control1: CGPoint(x: 20, y: 14), control2: CGPoint(x: 30, y: 22))
            p.addCurve(to: CGPoint(x: 16, y: 47), control1: CGPoint(x: 27, y: 43), control2: CGPoint(x: 22, y: 47))
            p.addCurve(to: CGPoint(x: 4, y: 34), control1: CGPoint(x: 10, y: 47), control2: CGPoint(x: 5, y: 43))
            p.addCurve(to: CGPoint(x: 16, y: 1), control1: CGPoint(x: 2, y: 22), control2: CGPoint(x: 12, y: 14))
            linear(c, p, UIColor(hex: 0xfff2c0), UIColor(hex: 0xff4a10, alpha: 0.6), from: CGPoint(x: 16, y: 47), to: CGPoint(x: 16, y: 2))
            radial(c, 16, 36, 9, [UIColor(white: 1, alpha: 0.95), UIColor(white: 1, alpha: 0)], [0, 1])
        }
    }

    static func candles() -> SKTexture {
        make("candles", 60, 52) { c in
            fill(c, E(30, 46, 26, 6), UIColor(hex: 0xd8ceb4, alpha: 0.5))
            let specs: [(CGFloat, CGFloat, CGFloat)] = [(12, 22, 6), (24, 10, 7), (36, 18, 6.5), (47, 28, 5.5), (30, 30, 5)]
            for (x, top, w) in specs {
                let body = Rr(x - w / 2, top, w, 48 - top, 2)
                ink(c, body, UIColor(hex: 0xe9dfc6), lw: 1.4)
                fill(c, E(x, top + 1, w / 2 + 0.5, 1.6), UIColor(hex: 0xfff8e4))
                fill(c, P([(x - w / 2, top + 2), (x - w / 2 + 1.5, top + 9), (x - w / 2 + 2.5, top + 2)]), UIColor(hex: 0xfff8e4))
                line(c, [CGPoint(x: x, y: top), CGPoint(x: x, y: top - 3)], Ink.black, 1)
            }
        }
    }

    static func bones() -> SKTexture {
        make("bones", 76, 44) { c in
            var rng = SeededRNG(seed: 17)
            for _ in 0..<7 {
                let x = CGFloat.random(in: 10...60, using: &rng), y = CGFloat.random(in: 22...38, using: &rng)
                let a = CGFloat.random(in: -0.6...0.6, using: &rng)
                let dx = cos(a) * 11, dy = sin(a) * 11
                line(c, [CGPoint(x: x - dx, y: y - dy), CGPoint(x: x + dx, y: y + dy)], Ink.black, 5)
                line(c, [CGPoint(x: x - dx, y: y - dy), CGPoint(x: x + dx, y: y + dy)], Ink.bone, 2.8)
                circle(c, x - dx, y - dy, 2.6, Ink.bone)
                circle(c, x + dx, y + dy, 2.6, Ink.bone)
            }
            let sk = E(38, 18, 10, 9.5)
            ink(c, sk, Ink.bone, lw: 1.8)
            hatch(c, sk, region: CGRect(x: 40, y: 8, width: 10, height: 20), spacing: 2.2)
            fill(c, E(34.5, 18, 2.6, 3), Ink.black)
            fill(c, E(41.5, 18, 2.6, 3), Ink.black)
            ink(c, Rr(33, 24, 10, 5), Ink.bone, lw: 1.2)
        }
    }

    static func rubble(_ depth: Int) -> SKTexture {
        let pal = Palette.of(depth)
        return make("rubble\(depth)", 70, 40) { c in
            var rng = SeededRNG(seed: UInt64(depth + 300))
            for _ in 0..<6 {
                let x = CGFloat.random(in: 12...58, using: &rng), y = CGFloat.random(in: 16...32, using: &rng)
                let r = CGFloat.random(in: 5...11, using: &rng)
                let rock = P([(x - r, y + r * 0.4), (x - r * 0.5, y - r * 0.7), (x + r * 0.6, y - r * 0.6), (x + r, y + r * 0.3), (x + r * 0.2, y + r * 0.7)])
                ink(c, rock, pal.stone.scaled(CGFloat.random(in: 0.8...1.2, using: &rng)), lw: 1.4)
            }
        }
    }

    /// Ground-plane lava grate.
    static func grate(_ depth: Int) -> SKTexture {
        let pal = Palette.of(depth)
        return make("grate\(depth)", 96, 96) { c in
            rect(c, 4, 4, 88, 88, Ink.black)
            radial(c, 48, 48, 46, [pal.accent, pal.accent.withAlphaComponent(0.2)], [0, 1])
            for i in 0..<7 {
                let x = 8 + CGFloat(i) * 13
                rect(c, x, 4, 5, 88, UIColor(hex: 0x2a2420))
                rect(c, x, 4, 1.5, 88, UIColor(white: 1, alpha: 0.12))
            }
            stroke(c, Rr(3, 3, 90, 90), UIColor(hex: 0x3a322c), 5)
            stroke(c, Rr(1, 1, 94, 94), Ink.black, 2)
        }
    }

    /// Ground-plane carpet runner (tiles along its length).
    static func carpet() -> SKTexture {
        make("carpet", 96, 128) { c in
            linear(c, Rr(0, 0, 96, 128), UIColor(hex: 0x5a0d12), UIColor(hex: 0x3a070b), from: CGPoint(x: 0, y: 0), to: CGPoint(x: 96, y: 0))
            rect(c, 6, 0, 5, 128, Ink.gold.withAlphaComponent(0.55))
            rect(c, 85, 0, 5, 128, Ink.gold.withAlphaComponent(0.55))
            rect(c, 14, 0, 1.5, 128, Ink.gold.withAlphaComponent(0.35))
            rect(c, 80.5, 0, 1.5, 128, Ink.gold.withAlphaComponent(0.35))
            let d = P([(48, 34), (64, 64), (48, 94), (32, 64)])
            stroke(c, d, Ink.gold.withAlphaComponent(0.45), 2)
            fill(c, E(48, 64, 5, 5), Ink.gold.withAlphaComponent(0.4))
            hatch(c, Rr(0, 0, 96, 128), spacing: 3, angle: 1.57, color: UIColor(white: 0, alpha: 0.15), lw: 0.7)
        }
    }

    // MARK: - Reward icons

    static func icon(_ r: Reward) -> SKTexture {
        switch r {
        case .boon(let p):
            let col = p.color
            return make("icon_boon_\(p.rawValue)", 52, 52) { c in
                radial(c, 26, 26, 26, [col.withAlphaComponent(0.7), col.withAlphaComponent(0)], [0.2, 1])
                let disc = E(26, 26, 15, 15)
                ink(c, disc, Ink.black, lw: 2)
                stroke(c, E(26, 26, 15, 15), Ink.gold, 1.4)
                stroke(c, E(26, 26, 12, 12), col.withAlphaComponent(0.8), 0.8)
                let w = col.scaled(1.25)
                switch p {
                case .pyre:
                    let f = CGMutablePath()
                    f.move(to: CGPoint(x: 26, y: 14))
                    f.addQuadCurve(to: CGPoint(x: 32, y: 32), control: CGPoint(x: 35, y: 24))
                    f.addQuadCurve(to: CGPoint(x: 20, y: 32), control: CGPoint(x: 26, y: 38))
                    f.addQuadCurve(to: CGPoint(x: 26, y: 14), control: CGPoint(x: 17, y: 22))
                    f.closeSubpath()
                    fill(c, f, w)
                case .rime:
                    for k in 0..<3 {
                        let a = CGFloat(k) * .pi / 3 + .pi / 6
                        line(c, [CGPoint(x: 26 - cos(a) * 10, y: 26 - sin(a) * 10), CGPoint(x: 26 + cos(a) * 10, y: 26 + sin(a) * 10)], w, 2.2)
                    }
                    circle(c, 26, 26, 2.5, w)
                case .tempest:
                    fill(c, P([(29, 13), (19, 28), (25, 28), (22, 39), (33, 23), (27, 23)]), w)
                case .sanguine:
                    let dpath = CGMutablePath()
                    dpath.move(to: CGPoint(x: 26, y: 14))
                    dpath.addQuadCurve(to: CGPoint(x: 26, y: 37), control: CGPoint(x: 40, y: 34))
                    dpath.addQuadCurve(to: CGPoint(x: 26, y: 14), control: CGPoint(x: 12, y: 34))
                    fill(c, dpath, w)
                case .umbral:
                    circle(c, 26, 26, 9.5, w)
                    circle(c, 30, 23, 8, Ink.black)
                    circle(c, 20, 30, 1.2, w)
                }
            }
        case .heart:
            return make("icon_heart", 52, 52) { c in
                let h = CGMutablePath()
                h.move(to: CGPoint(x: 26, y: 44))
                h.addCurve(to: CGPoint(x: 26, y: 16), control1: CGPoint(x: 0, y: 28), control2: CGPoint(x: 14, y: 4))
                h.addCurve(to: CGPoint(x: 26, y: 44), control1: CGPoint(x: 38, y: 4), control2: CGPoint(x: 52, y: 28))
                ink(c, h, Ink.blood, lw: 2.4)
                hatch(c, h, region: CGRect(x: 28, y: 0, width: 24, height: 52), spacing: 2.6)
                line(c, [CGPoint(x: 26, y: 20), CGPoint(x: 22, y: 28), CGPoint(x: 28, y: 32), CGPoint(x: 25, y: 40)], Ink.black, 1.4)
                circle(c, 17, 20, 2.5, UIColor(white: 1, alpha: 0.6))
            }
        case .gold:
            return make("icon_gold", 52, 52) { c in
                for (x, y) in [(CGFloat(18), CGFloat(32)), (34, 32), (26, 22)] {
                    let coin = E(x, y, 11, 11)
                    ink(c, coin, Ink.gold, lw: 1.8)
                    stroke(c, E(x, y, 7.5, 7.5), Ink.goldDark, 1.2)
                    hatch(c, coin, region: CGRect(x: x + 2, y: y - 11, width: 10, height: 22), spacing: 2.2, color: Ink.goldDark.withAlphaComponent(0.8))
                }
            }
        case .souls:
            return make("icon_souls", 52, 52) { c in
                radial(c, 26, 26, 24, [UIColor(hex: 0x9a7cff, alpha: 0.6), UIColor(hex: 0x9a7cff, alpha: 0)], [0.2, 1])
                let g = P([(26, 4), (41, 22), (26, 47), (11, 22)])
                ink(c, g, UIColor(hex: 0x7a5cff), lw: 2)
                fill(c, P([(26, 4), (32, 22), (26, 47), (20, 22)]), UIColor(hex: 0xb8a6ff))
                stroke(c, P([(11, 22), (41, 22)]), Ink.black, 1)
                stroke(c, g, Ink.black, 2)
            }
        case .anvil:
            return make("icon_anvil", 52, 52) { c in
                let a = P([(9, 16), (44, 16), (44, 22), (34, 27), (34, 34), (41, 43), (12, 43), (19, 34), (19, 27), (9, 21)])
                ink(c, a, UIColor(hex: 0x6a6460), lw: 2)
                hatch(c, a, region: CGRect(x: 30, y: 14, width: 16, height: 32), spacing: 2.4)
                ink(c, P([(9, 16), (1, 17), (9, 21)]), UIColor(hex: 0x6a6460), lw: 1.5)
                line(c, [CGPoint(x: 11, y: 17.5), CGPoint(x: 43, y: 17.5)], Ink.bone, 1.4)
                glowDot(c, 33, 10, 5, UIColor(hex: 0xff8a30))
            }
        case .heal:
            return make("icon_heal", 52, 52) { c in
                ink(c, Rr(21, 6, 10, 10), Ink.boneDark, lw: 1.5)
                let flask = E(26, 31, 14, 14)
                ink(c, flask, Ink.blood, lw: 2.2)
                hatch(c, flask, region: CGRect(x: 28, y: 17, width: 14, height: 30), spacing: 2.4)
                circle(c, 20, 26, 3, UIColor(white: 1, alpha: 0.6))
            }
        case .shop:
            return make("icon_shop", 52, 52) { c in
                let bag = E(26, 32, 15, 14)
                ink(c, bag, UIColor(hex: 0x6a4524), lw: 2)
                hatch(c, bag, region: CGRect(x: 28, y: 18, width: 16, height: 30), spacing: 2.4)
                ink(c, P([(18, 10), (34, 10), (30, 18), (22, 18)]), UIColor(hex: 0x6a4524), lw: 1.5)
                line(c, [CGPoint(x: 19, y: 18), CGPoint(x: 33, y: 18)], Ink.gold, 2)
                ink(c, E(26, 33, 6, 6), Ink.gold, lw: 1.2)
            }
        case .elite:
            return make("icon_elite", 52, 52) { c in
                radial(c, 26, 26, 26, [UIColor(hex: 0xffc040, alpha: 0.5), UIColor(hex: 0xffc040, alpha: 0)], [0.2, 1])
                let sk = E(26, 28, 13, 13)
                ink(c, sk, Ink.bone, lw: 2)
                fill(c, E(21, 28, 4, 4.5), Ink.black)
                fill(c, E(31, 28, 4, 4.5), Ink.black)
                glowDot(c, 21, 28, 3.5, Ink.blood)
                glowDot(c, 31, 28, 3.5, Ink.blood)
                ink(c, P([(13, 18), (16, 6), (21, 14), (26, 3), (31, 14), (36, 6), (39, 18)]), Ink.gold, lw: 1.6)
                ink(c, Rr(20, 38, 12, 7), Ink.bone, lw: 1.4)
            }
        case .rest:
            return make("icon_rest", 52, 52) { c in
                radial(c, 26, 26, 26, [UIColor(hex: 0x7ad8ff, alpha: 0.4), UIColor(hex: 0x7ad8ff, alpha: 0)], [0.2, 1])
                let cup = P([(10, 22), (42, 22), (36, 38), (16, 38)])
                ink(c, cup, UIColor(hex: 0x8a8278), lw: 2)
                fill(c, E(26, 22, 16, 4), Ink.blood)
                ink(c, Rr(22, 38, 8, 6), UIColor(hex: 0x8a8278), lw: 1.4)
                ink(c, Rr(15, 44, 22, 4, 2), UIColor(hex: 0x8a8278), lw: 1.4)
                line(c, [CGPoint(x: 26, y: 18), CGPoint(x: 26, y: 6)], UIColor(hex: 0xff5060), 2.4)
                circle(c, 26, 5, 2.4, UIColor(hex: 0xff5060))
            }
        case .altar:
            return make("icon_altar", 52, 52) { c in
                radial(c, 26, 26, 26, [UIColor(hex: 0xc070ff, alpha: 0.5), UIColor(hex: 0xc070ff, alpha: 0)], [0.2, 1])
                ink(c, P([(8, 30), (44, 30), (40, 46), (12, 46)]), UIColor(hex: 0x5a5260), lw: 2)
                ink(c, Rr(6, 26, 40, 6, 2), UIColor(hex: 0x7a7280), lw: 1.4)
                for x in [CGFloat(16), 26, 36] {
                    ink(c, Rr(x - 3, 14, 6, 12, 1.5), Ink.bone, lw: 1)
                    glowDot(c, x, 11, 3.5, UIColor(hex: 0xffb060))
                }
                stroke(c, P([(26, 33), (31, 38), (26, 43), (21, 38)]), UIColor(hex: 0xe8c0ff), 1.4)
            }
        case .relic:
            return make("icon_relic", 52, 52) { c in
                radial(c, 26, 26, 26, [UIColor(hex: 0xffd070, alpha: 0.5), UIColor(hex: 0xffd070, alpha: 0)], [0.2, 1])
                line(c, [CGPoint(x: 14, y: 4), CGPoint(x: 26, y: 18), CGPoint(x: 38, y: 4)], Ink.gold, 2)
                let gem = P([(26, 16), (38, 28), (26, 46), (14, 28)])
                ink(c, gem, Ink.gold, lw: 2)
                let inner = P([(26, 22), (32, 29), (26, 39), (20, 29)])
                fill(c, inner, Ink.blood)
                fill(c, P([(26, 22), (29, 29), (26, 39), (23, 29)]), Ink.blood.scaled(1.5))
                stroke(c, inner, Ink.black, 1.2)
            }
        case .boss:
            return make("icon_boss", 52, 52) { c in
                let sk = E(26, 22, 15, 15)
                ink(c, sk, Ink.bone, lw: 2.2)
                hatch(c, sk, region: CGRect(x: 30, y: 6, width: 12, height: 30), spacing: 2.4)
                ink(c, Rr(17, 32, 18, 10), Ink.bone, lw: 1.8)
                fill(c, E(20, 23, 4.5, 5), Ink.black)
                fill(c, E(32, 23, 4.5, 5), Ink.black)
                glowDot(c, 20, 23, 4, Ink.blood)
                glowDot(c, 32, 23, 4, Ink.blood)
                for i in 0..<4 { line(c, [CGPoint(x: 20 + CGFloat(i) * 4, y: 33), CGPoint(x: 20 + CGFloat(i) * 4, y: 41)], Ink.black, 1) }
            }
        }
    }
}
