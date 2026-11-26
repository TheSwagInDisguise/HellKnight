"""Rig + animations for the Brute: hulking horned demon in bone armour."""
import math
from ink import *

PI = math.pi
HIDE = hexc(0x2a1830)

def base():
    return dict(hx=0.0, hy=0.0, lean=0.35, head=0.0, lt=0.15, ls=-0.05, ft=-0.2, fs=-0.15,
                ua=0.15, fa=0.35, fua=-0.15, ffa=0.2, rot=0.0, fall=0.0)

def draw(pen, P):
    c = pen.c
    c.save()
    if P["rot"]:
        c.rotate(math.degrees(P["rot"]), 0, 0)
    hip = (P["hx"], -30 + P["hy"] + P["fall"] * 10)
    lean = P["lean"]
    up = (math.sin(lean), -math.cos(lean))
    fwd = (math.cos(lean), math.sin(lean))
    def T(u, v):
        return (hip[0] + fwd[0] * u + up[0] * v, hip[1] + fwd[1] * u + up[1] * v)

    def leg(off, th, sh, near):
        h = (hip[0] + off, hip[1])
        k = add(h, V(th, 15))
        a = add(k, V(sh, 15))
        b = HIDE if near else scale(HIDE, 0.7)
        pen.dark(limb(h, k, 13, 11), lw=1.8, base=b)
        pen.dark(limb(k, a, 11, 9), lw=1.8, base=b)
        pen.armor(poly([add(k, (-3, -5)), add(k, (6, -3)), add(k, (5, 4)), add(k, (-2, 3))]),
                  scale(BONE, 0.9 if near else 0.65), lw=1.3, hatch=False)
        hoof = poly([add(a, (-5, -2)), add(a, (7, -2)), add(a, (8, 3)), add(a, (-5, 3))])
        pen.armor(hoof, scale(STEEL, 1.6), lw=1.3, hatch=False)
    def arm(sh, ua, fa, near):
        el = add(sh, V(ua, 16))
        hd = add(el, V(fa, 16))
        b = HIDE if near else scale(HIDE, 0.7)
        pen.dark(limb(sh, el, 13, 11), lw=1.8, base=b)
        pen.dark(limb(el, hd, 12, 13), lw=1.8, base=b)
        fist = ellipse(hd[0], hd[1], 7.5, 7)
        pen.dark(fist, lw=1.8, base=scale(b, 1.2))
        for k in (-0.7, 0, 0.7):
            sp = add(hd, V(fa + k, 6.5))
            pen.armor(poly([add(sp, V(fa + k + 1.57, 1.8)), add(sp, V(fa + k, 5)), add(sp, V(fa + k - 1.57, 1.8))]),
                      BONE, lw=1, hatch=False)
        band = limb(add(el, V(fa, 5)), add(el, V(fa, 9)), 13.5, 13.5)
        pen.armor(band, scale(STEEL, 1.5), lw=1.3, hatch=False)
        return hd
    arm(T(-6, 30), P["fua"], P["ffa"], False)
    leg(-4, P["ft"], P["fs"], False)
    leg(4, P["lt"], P["ls"], True)

    body = smooth_path([T(-12, 0), T(-15, 16), T(-12, 32), T(0, 38), T(14, 33), T(16, 18), T(10, 2), T(0, -3)])
    pen.dark(body, lw=2.2, base=HIDE)
    pen.hatch(body, spacing=3, angle=1.2, color=hexc(0xb0a184, 0.1))
    plate = smooth_path([T(-4, 6), T(12, 8), T(14, 22), T(8, 30), T(-2, 28), T(-6, 16)])
    pen.armor(plate, BONE, lw=1.8)
    for k in range(3):
        pen.line([T(-2, 12 + k * 6), T(12, 13 + k * 6)], hexc(0, 0.45), 1)
    # chain
    for k in range(7):
        q = T(-10 + k * 3.6, 4 + math.sin(k) * 1.5)
        pen.stroke(ellipse(q[0], q[1], 2.2, 1.6), INK, 1.8)
        pen.stroke(ellipse(q[0], q[1], 2.2, 1.6), BONE_DARK, 0.8)

    # head (skull mask with big horns), low between the shoulders
    hc = T(10, 34)
    c.save()
    c.rotate(math.degrees(lean * 0.5 + P["head"]), hc[0], hc[1])
    hx, hy = hc
    for sgn in (-1, 1):
        horn = smooth_path([(hx - 3 * sgn - 2, hy - 6), (hx - 10 * sgn - 4, hy - 14), (hx - 16 * sgn - 3, hy - 24),
                            (hx - 12 * sgn - 3, hy - 13), (hx - 2 * sgn - 1, hy - 2)])
        pen.armor(horn, BONE if sgn < 0 else scale(BONE, 0.7), lw=1.6)
    mask = smooth_path([(hx - 8, hy - 2), (hx - 5, hy - 9), (hx + 3, hy - 10), (hx + 10, hy - 5), (hx + 11, hy + 3),
                        (hx + 6, hy + 9), (hx - 3, hy + 8)])
    pen.armor(mask, BONE, lw=2.0)
    pen.fill(ellipse(hx + 1.5, hy - 2.5, 2.6, 2.4), INK)
    pen.fill(ellipse(hx + 7.2, hy - 2.5, 2.3, 2.3), INK)
    pen.glow(hx + 1.5, hy - 2.3, 3.6, BLOOD)
    pen.glow(hx + 7.2, hy - 2.3, 3.0, BLOOD)
    for k in range(5):
        pen.line([(hx + k * 2.2, hy + 4), (hx + k * 2.2, hy + 7)], INK, 0.9)
    pen.armor(poly([(hx + 1, hy + 4), (hx + 3, hy + 11), (hx + 4.5, hy + 4)]), BONE, lw=1, hatch=False)
    pen.armor(poly([(hx + 7, hy + 4), (hx + 8.5, hy + 11), (hx + 10, hy + 4)]), BONE, lw=1, hatch=False)
    c.restore()
    arm(T(8, 30), P["ua"], P["fa"], True)
    shp = smooth_path([add(T(8, 30), (-9, 4)), add(T(8, 30), (-7, -6)), add(T(8, 30), (2, -9)),
                       add(T(8, 30), (10, -4)), add(T(8, 30), (9, 5))])
    pen.armor(shp, BONE, lw=1.8)
    c.restore()

def idle(t):
    P = base()
    s = math.sin(2 * PI * t)
    P["hy"] = 1.2 * s
    P["lean"] = 0.35 + 0.03 * s
    P["ua"] = 0.15 + 0.05 * s
    P["fua"] = -0.15 + 0.05 * s
    P["head"] = 0.05 * s
    return P

def walk(t, speed=1.0):
    P = base()
    p = 2 * PI * t
    s = math.sin(p)
    P["lean"] = 0.4 + 0.15 * (speed - 1)
    P["hy"] = -2.5 * abs(math.cos(p)) + 1.5
    P["lt"], P["ft"] = 0.45 * s * speed, -0.45 * s * speed
    P["ls"] = P["lt"] - 0.1 - 0.7 * max(0, -math.sin(p + 0.9))
    P["fs"] = P["ft"] - 0.1 - 0.7 * max(0, math.sin(p + 0.9))
    P["ua"] = -0.35 * s * speed + 0.1
    P["fua"] = 0.35 * s * speed
    P["fa"], P["ffa"] = P["ua"] + 0.3, P["fua"] + 0.3
    return P

def windup(t):
    P = base()
    k = smooth(min(1, t * 1.3))
    P["lean"] = lerp(0.35, 0.85, k)
    P["hy"] = 4 * k + math.sin(t * 40) * 0.8 * k
    P["hx"] = -3 * k
    P["head"] = 0.2 * k
    P["lt"], P["ls"] = lerp(0.15, 0.5, k), lerp(-0.05, -0.3, k)
    P["ft"], P["fs"] = lerp(-0.2, -0.7, k), lerp(-0.15, -0.6, k)
    P["ua"], P["fa"] = lerp(0.15, -0.5, k), lerp(0.35, 0.3, k)
    P["fua"] = lerp(-0.15, -0.7, k)
    return P

def charge(t):
    P = walk(t, 1.6)
    P["lean"] = 0.9
    P["head"] = 0.25
    P["ua"], P["fa"] = -0.4, 0.2
    return P

def hurt(t):
    P = idle(0)
    k = math.sin(PI * min(1, t * 1.2))
    P["lean"] = 0.35 - 0.3 * k
    P["head"] = -0.3 * k
    P["hx"] = -2 * k
    return P

def death(t):
    P = base()
    k = smooth(t)
    P["fall"] = k
    P["lt"], P["ls"] = lerp(0.15, 1.4, k), lerp(-0.05, -0.4, k)
    P["ft"], P["fs"] = lerp(-0.2, 1.2, k), lerp(-0.15, -0.6, k)
    P["lean"] = lerp(0.35, 0.9, k)
    P["rot"] = 0.5 * smooth(max(0, (t - 0.4) / 0.6))
    P["ua"], P["fua"] = lerp(0.15, 1.2, k), lerp(-0.15, 1.0, k)
    return P

ANIMS = [("idle", 8, idle, True), ("run", 8, walk, True), ("attack", 6, windup, False), ("charge", 6, charge, True),
         ("hurt", 3, hurt, False), ("death", 8, death, False)]
