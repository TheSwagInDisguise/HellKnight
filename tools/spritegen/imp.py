"""Rig + animations for the Imp: hunched demon with flapping bat wings and a whip tail."""
import math
from ink import *

PI = math.pi
SKIN = hexc(0x2a1512)

def base():
    return dict(hx=0.0, hy=0.0, lean=0.35, head=0.0, wing=0.0, tail=0.0,
                lt=0.2, ls=-0.3, ft=-0.25, fs=-0.6, ua=0.5, fa=1.3, fua=0.2, ffa=1.0,
                jaw=0.0, rot=0.0, claw=0.0)

def draw(pen, P):
    c = pen.c
    c.save()
    if P["rot"]:
        c.rotate(math.degrees(P["rot"]), 0, 0)
    hip = (P["hx"], -17 + P["hy"])
    lean = P["lean"]
    up = (math.sin(lean), -math.cos(lean))
    fwd = (math.cos(lean), math.sin(lean))
    def T(u, v):
        return (hip[0] + fwd[0] * u + up[0] * v, hip[1] + fwd[1] * u + up[1] * v)
    chest = T(2, 16)

    # tail
    pts = [T(-6, 2)]
    a = -1.9 + P["tail"]
    for i in range(6):
        a += 0.32 * math.sin(P["tail"] * 2 + i * 0.9) + 0.15
        pts.append(add(pts[-1], V(a, 5)))
    pen.line(pts, INK, 4.2)
    pen.line(pts, scale(SKIN, 1.8), 2.0)
    tip = pts[-1]
    d = (pts[-1][0] - pts[-2][0], pts[-1][1] - pts[-2][1])
    l = math.hypot(*d) or 1
    d = (d[0] / l, d[1] / l)
    n = (-d[1], d[0])
    pen.armor(poly([add(tip, (n[0] * 3, n[1] * 3)), add(tip, (d[0] * 6, d[1] * 6)), add(tip, (-n[0] * 3, -n[1] * 3))]),
              BLOOD, lw=1.1, hatch=False)

    # wings (far behind, near in front of body edge)
    def wing(root, spread, near):
        w = P["wing"]
        tipA = add(root, (-14 - 6 * spread, -16 + 14 * w))
        tipB = add(root, (-24 - 4 * spread, -4 + 10 * w))
        tipC = add(root, (-20, 8 + 4 * w))
        mem = smooth_path([root, add(root, (-6, -10 + 8 * w)), tipA, add(tipA, (-3, 6)), tipB, add(tipB, (2, 5)), tipC,
                           add(root, (-6, 6))])
        pen.dark(mem, lw=1.6, base=hexc(0x3a0d0c) if near else hexc(0x260807))
        for t_ in (tipA, tipB, tipC):
            pen.line([root, t_], INK, 1.6)
            pen.line([root, t_], hexc(0xffb27a, 0.35), 0.6)
    wing(T(-3, 15), 1.0, False)

    def leg(off, th, sh, near):
        h = (hip[0] + off, hip[1])
        knee = add(h, V(th, 9))
        ank = add(knee, V(sh, 9))
        base_c = SKIN if near else scale(SKIN, 0.7)
        pen.dark(limb(h, knee, 6.5, 5), lw=1.5, base=base_c)
        pen.dark(limb(knee, ank, 5, 3.6), lw=1.5, base=base_c)
        for k in (-0.5, 0, 0.5):
            pen.armor(poly([add(ank, V(1.3 + k, 1.5)), add(ank, V(1.57 + k * 0.6, 5.5)), add(ank, V(1.8 + k, 1.5))]),
                      BONE, lw=0.8, hatch=False)
    def arm(sh, ua, fa, near):
        el = add(sh, V(ua, 8))
        hd = add(el, V(fa, 8))
        base_c = SKIN if near else scale(SKIN, 0.7)
        pen.dark(limb(sh, el, 5, 4), lw=1.4, base=base_c)
        pen.dark(limb(el, hd, 4, 3.4), lw=1.4, base=base_c)
        for k in (-0.4, 0, 0.4):
            pen.armor(poly([add(hd, V(fa + k + 1.57, 1.3)), add(hd, V(fa + k * 0.7, 5.5 + P["claw"] * 2)),
                            add(hd, V(fa + k - 1.57, 1.3))]), BONE, lw=0.8, hatch=False)
    arm(T(-2, 14), P["fua"], P["ffa"], False)
    leg(-2, P["ft"], P["fs"], False)
    leg(2, P["lt"], P["ls"], True)

    body = smooth_path([T(-7, 1), T(-9, 9), T(-6, 17), T(3, 20), T(9, 15), T(8, 5), T(3, -1)])
    pen.dark(body, lw=2.0, base=SKIN)
    belly = smooth_path([T(1, 2), T(6, 5), T(7, 12), T(3, 15), T(0, 9)])
    pen.gradient_fill(belly, hexc(0x8a2a18), hexc(0x3a0f0a))
    pen.stroke(belly, hexc(0, 0.6), 0.8)
    for k in range(3):
        pen.line([T(1.5, 5 + k * 3), T(6, 6 + k * 3)], hexc(0, 0.4), 0.7)

    # head
    hc = add(chest, (up[0] * 7 + fwd[0] * 4, up[1] * 7 + fwd[1] * 4))
    c.save()
    c.rotate(math.degrees(lean * 0.4 + P["head"]), hc[0], hc[1])
    hx, hy = hc
    for sgn, dx in ((-1, -4), (1, 3)):
        horn = smooth_path([(hx + dx - 2, hy - 5), (hx + dx - 1 + sgn * 1, hy - 11), (hx + dx + sgn * 2 - 3, hy - 16),
                            (hx + dx + 1, hy - 10), (hx + dx + 2, hy - 5)])
        pen.armor(horn, BONE if sgn > 0 else scale(BONE, 0.75), lw=1.2)
    skull = smooth_path([(hx - 7, hy), (hx - 5, hy - 6), (hx + 2, hy - 7), (hx + 8, hy - 3), (hx + 9, hy + 2),
                         (hx + 4, hy + 6), (hx - 4, hy + 6)])
    pen.dark(skull, lw=1.9, base=SKIN)
    jaw = P["jaw"]
    mouth = poly([(hx + 1, hy + 2.5), (hx + 9, hy + 1.5), (hx + 8, hy + 3.5 + jaw * 3), (hx + 1, hy + 4 + jaw * 2)])
    pen.fill(mouth, hexc(0x1a0302))
    for k in range(4):
        x = hx + 2 + k * 1.8
        pen.fill(poly([(x, hy + 2.3), (x + 0.9, hy + 4), (x + 1.8, hy + 2.3)]), BONE)
    pen.glow(hx + 3, hy - 2, 3.2, hexc(0xffd040))
    pen.glow(hx + 7, hy - 2.2, 2.6, hexc(0xffd040))
    c.restore()

    wing(T(1, 15), 0.6, True)
    arm(T(3, 14), P["ua"], P["fa"], True)
    c.restore()

def idle(t):
    P = base()
    p = 2 * PI * t
    P["hy"] = 1.2 * math.sin(p * 2)
    P["wing"] = 0.5 + 0.5 * math.sin(p * 2)
    P["tail"] = 0.4 * math.sin(p)
    P["ua"] = 0.6 + 0.1 * math.sin(p)
    P["head"] = 0.05 * math.sin(p)
    return P

def run(t):
    P = base()
    p = 2 * PI * t
    s = math.sin(p)
    P["lean"] = 0.6
    P["hy"] = -2.5 * abs(math.cos(p)) + 1.5
    P["lt"] = 0.7 * s
    P["ft"] = -0.7 * s
    P["ls"] = P["lt"] - 0.6 - 0.5 * max(0, -s)
    P["fs"] = P["ft"] - 0.6 - 0.5 * max(0, s)
    P["ua"] = -0.6 * s + 0.6
    P["fua"] = 0.6 * s + 0.6
    P["fa"], P["ffa"] = P["ua"] + 0.8, P["fua"] + 0.8
    P["wing"] = 0.5 + 0.5 * math.sin(p * 2 + 1)
    P["tail"] = 0.6 * math.sin(p + 1)
    return P

def attack(t):
    """Windup crouch, then a clawing lunge."""
    P = base()
    if t < 0.45:
        k = smooth(t / 0.45)
        P["hy"] = 3 * k
        P["lean"] = lerp(0.35, 0.1, k)
        P["ua"] = lerp(0.5, -0.6, k)
        P["wing"] = lerp(0.5, -0.3, k)
        P["jaw"] = k
        P["hx"] = -2 * k
    elif t < 0.7:
        k = smooth((t - 0.45) / 0.25)
        P["hy"] = lerp(3, -4, k)
        P["lean"] = lerp(0.1, 0.9, k)
        P["ua"] = lerp(-0.6, 2.0, k)
        P["fa"] = lerp(1.3, 1.9, k)
        P["fua"] = lerp(0.2, 1.6, k)
        P["ffa"] = 1.8
        P["wing"] = 1
        P["jaw"] = 1
        P["claw"] = k
        P["hx"] = lerp(-2, 8, k)
        P["lt"], P["ls"] = 0.9, 0.4
        P["ft"], P["fs"] = -0.9, -1.4
    else:
        k = smooth((t - 0.7) / 0.3)
        P["lean"] = lerp(0.9, 0.35, k)
        P["ua"] = lerp(2.0, 0.5, k)
        P["fua"] = lerp(1.6, 0.2, k)
        P["hx"] = lerp(8, 0, k)
        P["jaw"] = 1 - k
        P["wing"] = lerp(1, 0.5, k)
    P["tail"] = 0.8 * math.sin(t * 6)
    return P

def hurt(t):
    P = idle(0)
    k = math.sin(PI * min(1, t * 1.2))
    P["lean"] = 0.35 - 0.5 * k
    P["head"] = -0.4 * k
    P["hx"] = -3 * k
    P["wing"] = 1.0
    P["jaw"] = k
    return P

def death(t):
    P = base()
    k = smooth(t)
    P["rot"] = -1.4 * k
    P["hy"] = 4 * k
    P["wing"] = lerp(0.5, -0.5, k)
    P["lt"], P["ls"] = lerp(0.2, 1.0, k), lerp(-0.3, 0.6, k)
    P["jaw"] = 1
    return P

ANIMS = [("idle", 8, idle, True), ("run", 8, run, True), ("attack", 8, attack, False),
         ("hurt", 3, hurt, False), ("death", 6, death, False)]
