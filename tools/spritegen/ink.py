"""Shared drawing helpers for the HellKnight sprite generator (dark gothic ink style)."""
import math
import skia

def hexc(h, a=1.0):
    return skia.Color4f(((h >> 16) & 255) / 255, ((h >> 8) & 255) / 255, (h & 255) / 255, a)

def mix(c1, c2, t):
    return skia.Color4f(c1.fR + (c2.fR - c1.fR) * t, c1.fG + (c2.fG - c1.fG) * t,
                        c1.fB + (c2.fB - c1.fB) * t, c1.fA + (c2.fA - c1.fA) * t)

def scale(c, f):
    return skia.Color4f(min(1, c.fR * f), min(1, c.fG * f), min(1, c.fB * f), c.fA)

INK = hexc(0x0b0908)
BONE = hexc(0xebe0c8)
BONE_DARK = hexc(0xb0a184)
STEEL = hexc(0x2e2a27)
BLOOD = hexc(0xc4161d)
GOLD = hexc(0xcda552)
CHAR = hexc(0x1d1816)
EMBER_RIM = hexc(0xffb27a)

def V(a, l):
    """Vector for an angle measured from straight down, positive = forward (+x)."""
    return (math.sin(a) * l, math.cos(a) * l)

def add(p, q):
    return (p[0] + q[0], p[1] + q[1])

def lerp(a, b, t):
    return a + (b - a) * t

def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)

def poly(pts):
    p = skia.Path()
    p.moveTo(*pts[0])
    for q in pts[1:]:
        p.lineTo(*q)
    p.close()
    return p

def ellipse(cx, cy, rx, ry):
    p = skia.Path()
    p.addOval(skia.Rect.MakeLTRB(cx - rx, cy - ry, cx + rx, cy + ry))
    return p

def smooth_path(pts, closed=True):
    """Catmull-Rom style smooth path through points."""
    p = skia.Path()
    n = len(pts)
    p.moveTo(*pts[0])
    rng = range(n) if closed else range(n - 1)
    for i in rng:
        p0 = pts[(i - 1) % n] if closed or i > 0 else pts[i]
        p1 = pts[i]
        p2 = pts[(i + 1) % n]
        p3 = pts[(i + 2) % n] if closed or i + 2 < n else p2
        c1 = (p1[0] + (p2[0] - p0[0]) / 6, p1[1] + (p2[1] - p0[1]) / 6)
        c2 = (p2[0] - (p3[0] - p1[0]) / 6, p2[1] - (p3[1] - p1[1]) / 6)
        p.cubicTo(c1[0], c1[1], c2[0], c2[1], p2[0], p2[1])
    if closed:
        p.close()
    return p

def limb(a, b, wa, wb):
    """Tapered capsule from point a (width wa) to point b (width wb)."""
    dx, dy = b[0] - a[0], b[1] - a[1]
    l = math.hypot(dx, dy) or 1
    nx, ny = -dy / l, dx / l
    p = skia.Path()
    p.moveTo(a[0] + nx * wa / 2, a[1] + ny * wa / 2)
    p.lineTo(b[0] + nx * wb / 2, b[1] + ny * wb / 2)
    p.arcTo(skia.Rect.MakeLTRB(b[0] - wb / 2, b[1] - wb / 2, b[0] + wb / 2, b[1] + wb / 2),
            math.degrees(math.atan2(ny, nx)), -180, False)
    p.lineTo(a[0] - nx * wa / 2, a[1] - ny * wa / 2)
    p.arcTo(skia.Rect.MakeLTRB(a[0] - wa / 2, a[1] - wa / 2, a[0] + wa / 2, a[1] + wa / 2),
            math.degrees(math.atan2(-ny, -nx)), -180, False)
    p.close()
    return p

class Pen:
    """Wraps a skia canvas with ink-style shape rendering."""
    def __init__(self, canvas, light_dir=(-0.6, -0.8)):
        self.c = canvas
        self.light = light_dir

    def fill(self, path, color):
        self.c.drawPath(path, skia.Paint(Color4f=color, AntiAlias=True))

    def stroke(self, path, color, w):
        self.c.drawPath(path, skia.Paint(Color4f=color, AntiAlias=True, Style=skia.Paint.kStroke_Style,
                                         StrokeWidth=w, StrokeJoin=skia.Paint.kRound_Join,
                                         StrokeCap=skia.Paint.kRound_Cap))

    def line(self, pts, color, w):
        p = skia.Path()
        p.moveTo(*pts[0])
        for q in pts[1:]:
            p.lineTo(*q)
        self.stroke(p, color, w)

    def gradient_fill(self, path, c_light, c_dark):
        b = path.getBounds()
        lx, ly = self.light
        cx, cy = b.centerX(), b.centerY()
        r = max(b.width(), b.height()) / 2 + 1
        p0 = skia.Point(cx + lx * r, cy + ly * r)
        p1 = skia.Point(cx - lx * r, cy - ly * r)
        shader = skia.GradientShader.MakeLinear([p0, p1], [c_light.toColor(), c_dark.toColor()])
        self.c.drawPath(path, skia.Paint(Shader=shader, AntiAlias=True))

    def hatch(self, path, spacing=2.2, angle=0.8, color=None, w=0.7, region=None):
        color = color or hexc(0x000000, 0.5)
        self.c.save()
        self.c.clipPath(path, skia.ClipOp.kIntersect, True)
        if region is not None:
            self.c.clipPath(region, skia.ClipOp.kIntersect, True)
        b = path.getBounds()
        cx, cy = b.centerX(), b.centerY()
        d = math.hypot(b.width(), b.height()) / 2 + 2
        dx, dy = math.cos(angle), math.sin(angle)
        px, py = -dy, dx
        t = -d
        lines = skia.Path()
        while t <= d:
            lines.moveTo(cx + px * t - dx * d, cy + py * t - dy * d)
            lines.lineTo(cx + px * t + dx * d, cy + py * t + dy * d)
            t += spacing
        self.stroke(lines, color, w)
        self.c.restore()

    def shadow_side(self, path, frac=0.42, spacing=2.0):
        """Hatch the side facing away from the light."""
        b = path.getBounds()
        lx, _ = self.light
        if lx < 0:
            reg = poly([(b.right() - b.width() * frac, b.top() - 2), (b.right() + 2, b.top() - 2),
                        (b.right() + 2, b.bottom() + 2), (b.right() - b.width() * frac, b.bottom() + 2)])
        else:
            reg = poly([(b.left() - 2, b.top() - 2), (b.left() + b.width() * frac, b.top() - 2),
                        (b.left() + b.width() * frac, b.bottom() + 2), (b.left() - 2, b.bottom() + 2)])
        self.hatch(path, spacing=spacing, region=reg, color=hexc(0x000000, 0.45))

    def rim(self, path, color, w=1.6):
        """Light catching the upper-left edge of a shape."""
        b = path.getBounds()
        self.c.save()
        self.c.clipPath(path, skia.ClipOp.kIntersect, True)
        lx, ly = self.light
        r = max(b.width(), b.height()) / 2 + 1
        cx, cy = b.centerX(), b.centerY()
        shader = skia.GradientShader.MakeLinear(
            [skia.Point(cx + lx * r, cy + ly * r), skia.Point(cx, cy)],
            [color.toColor(), skia.Color4f(color.fR, color.fG, color.fB, 0).toColor()])
        self.c.drawPath(path, skia.Paint(Shader=shader, AntiAlias=True, Style=skia.Paint.kStroke_Style,
                                         StrokeWidth=w * 2))
        self.c.restore()

    def armor(self, path, base, lw=1.9, hatch=True, rim_col=None):
        """Bone/steel plate: gradient form shading, shadow hatching, rim light, ink outline."""
        self.gradient_fill(path, scale(base, 1.12), scale(base, 0.62))
        if hatch:
            self.shadow_side(path)
        self.rim(path, rim_col or hexc(0xffffff, 0.75))
        self.stroke(path, INK, lw)

    def dark(self, path, lw=2.0, rim_col=EMBER_RIM, base=CHAR):
        """Dark cloth / flesh silhouette with a warm rim light."""
        self.gradient_fill(path, scale(base, 1.6), scale(base, 0.6))
        self.rim(path, mix(rim_col, hexc(0, 0), 0.15), 1.4)
        self.stroke(path, INK, lw)

    def glow(self, x, y, r, color):
        shader = skia.GradientShader.MakeRadial(skia.Point(x, y), r,
                                                [color.toColor(), skia.Color4f(color.fR, color.fG, color.fB, 0).toColor()])
        self.c.drawCircle(x, y, r, skia.Paint(Shader=shader, AntiAlias=True))
        self.c.drawCircle(x, y, r * 0.3, skia.Paint(Color4f=hexc(0xffffff, 0.95), AntiAlias=True))
