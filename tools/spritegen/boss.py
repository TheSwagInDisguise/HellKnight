"""The three depth guardians share one huge rig with per-depth details."""
import math
from ink import *

PI = math.pi
ACCENTS = [0xff6a1f, 0x9dff6e, 0x9a7cff]
BODIES = [0x3a140e, 0x2c2a33, 0x141a38]

def base():
    return dict(hx=0.0, hy=0.0, lean=0.1, head=0.0, ua=0.3, fa=0.5, fua=-0.2, ffa=0.2,
                lt=0.15, ls=0.0, ft=-0.15, fs=-0.05, core=0.5, roar=0.0, rot=0.0, kneel=0.0)

def make_draw(depth):
    acc = hexc(ACCENTS[depth])
    body_c = hexc(BODIES[depth])

    def draw(pen, P):
        c = pen.c
        c.save()
        if P["rot"]:
            c.rotate(math.degrees(P["rot"]), 0, 0)
        hip = (P["hx"], -54 + P["hy"] + P["kneel"] * 22)
        lean = P["lean"]
        up = (math.sin(lean), -math.cos(lean))
        fwd = (math.cos(lean), math.sin(lean))
        def T(u, v):
            return (hip[0] + fwd[0] * u + up[0] * v, hip[1] + fwd[1] * u + up[1] * v)

        def leg(off, th, sh, near):
            h = (hip[0] + off, hip[1])
            k = add(h, V(th, 27))
            a = add(k, V(sh, 27))
            b = body_c if near else scale(body_c, 0.7)
            pen.dark(limb(h, k, 20, 17), lw=2.2, base=b, rim_col=acc)
            pen.dark(limb(k, a, 17, 14), lw=2.2, base=b, rim_col=acc)
            pen.armor(smooth_path([add(k, (-6, -7)), add(k, (9, -5)), add(k, (8, 6)), add(k, (-4, 5))]),
                      scale(BONE, 0.9 if near else 0.6), lw=1.6)
            pen.armor(poly([add(a, (-8, -3)), add(a, (12, -3)), add(a, (13, 5)), add(a, (-8, 5))]), scale(STEEL, 1.6), lw=1.6,
                      hatch=False)

        def arm(sh, ua, fa, near):
            el = add(sh, V(ua, 30))
            hd = add(el, V(fa, 28))
            b = body_c if near else scale(body_c, 0.7)
            pen.dark(limb(sh, el, 20, 17), lw=2.2, base=b, rim_col=acc)
            pen.dark(limb(el, hd, 17, 15), lw=2.2, base=b, rim_col=acc)
            for k in (-0.6, -0.2, 0.2, 0.6):
                f = add(hd, V(fa + k, 5))
                cl = poly([add(f, V(fa + k + 1.57, 2.4)), add(f, V(fa + k, 12)), add(f, V(fa + k - 1.57, 2.4))])
                pen.armor(cl, BONE, lw=1.2, hatch=False)
            g = smooth_path([add(el, (-11, -4)), add(el, (-6, -11)), add(el, (8, -9)), add(el, (11, 2)), add(el, (-2, 8))])
            pen.armor(g, scale(BONE, 0.95 if near else 0.65), lw=1.6)
            if P["core"] > 0.9:
                pen.glow(*hd, 14 * (P["core"] - 0.6), acc)

        arm(T(-14, 62), P["fua"], P["ffa"], False)
        leg(-7, P["ft"], P["fs"], False)
        leg(7, P["lt"], P["ls"], True)

        robe = smooth_path([T(-22, 0), T(-30, 30), T(-26, 62), T(-6, 74), T(16, 70), T(28, 52), T(26, 20),
                            T(20, -2), T(0, -8)])
        pen.dark(robe, lw=2.6, base=body_c, rim_col=acc)
        pen.hatch(robe, spacing=3.4, angle=1.3, color=hexc(0xb0a184, 0.12))
        # skirt tatters
        for k in range(6):
            x = -22 + k * 8
            q = T(x, 0)
            pen.dark(poly([add(q, (-4, -2)), add(q, (4, -2)), add(q, (1, 14 + (k % 2) * 6))]), lw=1.4, base=body_c,
                     rim_col=acc)
        # chest core
        core = T(4, 44)
        pen.glow(core[0], core[1], 24 * P["core"] + 8, acc)
        gem = poly([add(core, (0, -10)), add(core, (8, 0)), add(core, (0, 11)), add(core, (-8, 0))])
        pen.gradient_fill(gem, mix(acc, hexc(0xffffff), 0.5), scale(acc, 0.5))
        pen.stroke(gem, INK, 2)
        if depth == 0:
            for pts in ([T(-16, 10), T(-8, 22), T(-12, 34), T(-4, 50)], [T(18, 14), T(12, 28), T(20, 40)]):
                pen.line(pts, mix(acc, hexc(0, 0), 0.3), 5)
                pen.line(pts, hexc(0xffd090), 1.6)
        elif depth == 1:
            for k in range(5):
                pen.armor(poly([T(-14, 14 + k * 6), T(16, 15 + k * 6), T(14, 18 + k * 6), T(-12, 17 + k * 6)]), BONE,
                          lw=1.2, hatch=False)
            pen.line([T(1, 12), T(1, 42)], BONE, 3)
        else:
            for (u, v) in ((-14, 22), (14, 24), (-8, 10), (10, 8)):
                q = T(u, v)
                pen.fill(ellipse(q[0], q[1], 4.5, 3), INK)
                pen.glow(q[0], q[1], 4.5, acc)

        # head
        hc = T(6, 86)
        c.save()
        c.rotate(math.degrees(P["head"] + lean * 0.6 - P["roar"] * 0.35), hc[0], hc[1])
        hx, hy = hc
        crown_col = INK if depth == 2 else BONE
        for k in range(5):
            x = hx - 16 + k * 8
            tall = [12, 18, 24, 18, 12][k]
            sp = poly([(x - 4, hy - 14), (x + 1, hy - 14 - tall), (x + 4, hy - 14)])
            pen.armor(sp, crown_col, lw=1.6, hatch=depth != 2)
            if depth == 2:
                pen.stroke(sp, acc, 0.8)
        if depth == 2:
            for sgn in (-1, 1):
                horn = smooth_path([(hx + 12 * sgn, hy - 8), (hx + 26 * sgn, hy - 18), (hx + 30 * sgn, hy - 32),
                                    (hx + 22 * sgn, hy - 16), (hx + 8 * sgn, hy - 2)])
                pen.armor(horn, BONE, lw=1.6)
        if depth == 1:
            veil = smooth_path([(hx - 18, hy - 10), (hx - 26, hy + 30), (hx - 14, hy + 34), (hx - 10, hy + 6)])
            pen.fill(veil, hexc(0xebe0c8, 0.25))
            pen.stroke(veil, hexc(0xebe0c8, 0.5), 1)
        mask = smooth_path([(hx - 16, hy - 4), (hx - 12, hy - 15), (hx + 2, hy - 18), (hx + 16, hy - 12),
                            (hx + 18, hy + 2), (hx + 12, hy + 16), (hx - 2, hy + 18), (hx - 14, hy + 10)])
        pen.armor(mask, BONE, lw=2.4)
        pen.fill(poly([(hx - 7, hy - 4), (hx + 1, hy - 2), (hx, hy + 2), (hx - 7, hy + 1)]), INK)
        pen.fill(poly([(hx + 13, hy - 4), (hx + 5, hy - 2), (hx + 6, hy + 2), (hx + 13, hy + 1)]), INK)
        pen.glow(hx - 3, hy - 1, 6, acc)
        pen.glow(hx + 9, hy - 1, 5, acc)
        jaw = 2 + 8 * P["roar"]
        mouth = poly([(hx - 6, hy + 7), (hx + 10, hy + 7), (hx + 8, hy + 7 + jaw), (hx - 4, hy + 7 + jaw)])
        pen.fill(mouth, hexc(0x100404))
        pen.glow(hx + 2, hy + 7 + jaw / 2, 3 + 4 * P["roar"], acc)
        for k in range(5):
            x = hx - 5 + k * 3.4
            pen.fill(poly([(x, hy + 6.5), (x + 1.5, hy + 10), (x + 3, hy + 6.5)]), BONE)
        c.restore()
        arm(T(16, 62), P["ua"], P["fa"], True)
        sh = T(16, 62)
        pad = smooth_path([add(sh, (-14, 6)), add(sh, (-11, -9)), add(sh, (3, -14)), add(sh, (16, -6)), add(sh, (14, 8))])
        pen.armor(pad, BONE, lw=2)
        for k in range(3):
            q = add(sh, (-6 + k * 7, -11 - (k == 1) * 2))
            pen.armor(poly([add(q, (-2.5, 2)), add(q, (0, -8)), add(q, (2.5, 2))]), BONE, lw=1, hatch=False)
        c.restore()
    return draw

def idle(t):
    P = base()
    s = math.sin(2 * PI * t)
    P["hy"] = 2 * s
    P["lean"] = 0.1 + 0.03 * s
    P["ua"] = 0.3 + 0.06 * s
    P["core"] = 0.6 + 0.2 * s
    return P

def walk(t):
    P = base()
    p = 2 * PI * t
    s = math.sin(p)
    P["lean"] = 0.18
    P["hy"] = -3 * abs(math.cos(p)) + 2
    P["lt"], P["ft"] = 0.35 * s, -0.35 * s
    P["ls"] = P["lt"] - 0.05 - 0.5 * max(0, -math.sin(p + 0.9))
    P["fs"] = P["ft"] - 0.05 - 0.5 * max(0, math.sin(p + 0.9))
    P["ua"] = -0.25 * s + 0.2
    P["fua"] = 0.25 * s
    return P

def slam(t):
    P = base()
    if t < 0.5:
        k = smooth(t / 0.5)
        P["ua"], P["fa"] = lerp(0.3, 3.0, k), lerp(0.5, 3.3, k)
        P["fua"], P["ffa"] = lerp(-0.2, 2.6, k), lerp(0.2, 3.0, k)
        P["lean"] = lerp(0.1, -0.15, k)
        P["core"] = lerp(0.6, 1.3, k)
    else:
        k = smooth((t - 0.5) / 0.25) if t < 0.75 else 1
        r = smooth((t - 0.75) / 0.25) if t >= 0.75 else 0
        P["ua"], P["fa"] = lerp(3.0, 0.9, k), lerp(3.3, 0.9, k)
        P["fua"], P["ffa"] = lerp(2.6, 0.7, k), lerp(3.0, 0.8, k)
        P["lean"] = lerp(-0.15, 0.45, k) - 0.3 * r
        P["hy"] = 8 * k * (1 - r)
        P["core"] = 1.3 - 0.6 * r
    return P

def cast(t):
    P = base()
    k = smooth(min(1, t / 0.4))
    pulse = 0.5 + 0.5 * math.sin(t * 4 * PI)
    P["ua"], P["fa"] = lerp(0.3, 1.9, k), lerp(0.5, 2.2, k)
    P["fua"], P["ffa"] = lerp(-0.2, 1.4, k), lerp(0.2, 1.7, k)
    P["core"] = 0.8 + 0.6 * pulse * k
    P["lean"] = -0.05
    return P

def roar(t):
    P = base()
    k = math.sin(PI * min(1, t * 1.1))
    P["roar"] = k
    P["ua"], P["fa"] = lerp(0.3, 2.2, k), lerp(0.5, 2.6, k)
    P["fua"], P["ffa"] = lerp(-0.2, -1.8, k), lerp(0.2, -2.2, k)
    P["lean"] = lerp(0.1, -0.25, k)
    P["core"] = 0.6 + 0.8 * k
    P["hy"] = -2 * k
    return P

def hurt(t):
    P = idle(0)
    k = math.sin(PI * min(1, t * 1.2))
    P["lean"] = 0.1 - 0.2 * k
    P["head"] = -0.2 * k
    return P

def death(t):
    P = base()
    k1 = smooth(min(1, t / 0.5))
    k2 = smooth(max(0, (t - 0.45) / 0.55))
    P["kneel"] = k1
    P["lt"], P["ls"] = lerp(0.15, 1.5, k1), lerp(0, -0.2, k1)
    P["ft"], P["fs"] = lerp(-0.15, 1.3, k1), lerp(-0.05, -0.4, k1)
    P["roar"] = k1 * (1 - k2)
    P["lean"] = lerp(0.1, 0.5, k1)
    P["ua"], P["fua"] = lerp(0.3, 1.4, k1), lerp(-0.2, 1.2, k1)
    P["rot"] = 1.2 * k2
    P["core"] = 0.6 * (1 - k2)
    return P

ANIMS = [("idle", 8, idle, True), ("run", 8, walk, True), ("attack", 8, slam, False), ("cast", 8, cast, True),
         ("roar", 8, roar, False), ("hurt", 3, hurt, False), ("death", 10, death, False)]
