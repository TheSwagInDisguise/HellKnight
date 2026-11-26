"""Hex Priest: tall hooded caster that hovers, with bone hands and a void face."""
import math
from ink import *

PI = math.pi
ROBE = hexc(0x2a1244)
MAG = hexc(0xff40c0)

def base():
    return dict(hy=0.0, sway=0.0, lean=0.0, ua=0.4, fa=0.9, fua=-0.3, ffa=0.3, glow=0.0, head=0.0,
                collapse=0.0)

def draw(pen, P):
    c = pen.c
    col = P["collapse"]
    top = -62 + P["hy"] + col * 40
    lean = P["lean"]
    sw = P["sway"]
    def R(u, v):  # robe-local: v from top downward
        return (u + lean * (60 - v) * 0.3 + sw * (v / 60) ** 2, top + v * (1 - col * 0.6))

    def arm(sh, ua, fa, near):
        el = add(sh, V(ua, 11))
        hd = add(el, V(fa, 10))
        b = ROBE if near else scale(ROBE, 0.7)
        pen.dark(limb(sh, el, 8, 9), lw=1.6, base=b, rim_col=MAG)
        pen.dark(limb(el, hd, 9, 10), lw=1.6, base=b, rim_col=MAG)
        for k in (-0.5, -0.15, 0.2, 0.55):
            f = add(hd, V(fa + k, 2))
            pen.line([f, add(f, V(fa + k * 1.2, 6))], INK, 2.4)
            pen.line([f, add(f, V(fa + k * 1.2, 6))], BONE, 1.2)
        if P["glow"] > 0:
            pen.glow(*add(hd, V(fa, 5)), 9 * P["glow"], MAG)
    arm(R(-6, 18), P["fua"], P["ffa"], False)

    robe = smooth_path([R(-6, 10), R(-12, 30), R(-17, 52), R(-12, 60), R(-6, 56), R(0, 61), R(6, 56), R(12, 60),
                        R(16, 50), R(11, 28), R(6, 10)])
    pen.dark(robe, lw=2.0, base=ROBE, rim_col=MAG)
    pen.hatch(robe, spacing=3, angle=1.45, color=hexc(0xb0a184, 0.14))
    trim = poly([R(-2, 14), R(3, 14), R(5, 58), R(-3, 58)])
    pen.armor(trim, BONE, lw=1.2, hatch=False)
    for v in (24, 36, 48):
        q = R(1, v)
        pen.stroke(ellipse(q[0], q[1], 1.8, 1.8), INK, 1)
    # hood + void face
    hc = R(1, 4)
    c.save()
    c.rotate(math.degrees(P["head"] + lean * 0.5), hc[0], hc[1])
    hx, hy = hc
    hood = smooth_path([(hx - 9, hy + 8), (hx - 9, hy - 3), (hx - 1, hy - 16), (hx + 8, hy - 4), (hx + 10, hy + 8)])
    pen.dark(hood, lw=1.8, base=ROBE, rim_col=MAG)
    pen.fill(ellipse(hx + 2, hy + 1, 5.5, 6.5), hexc(0x000000))
    pen.glow(hx + 3, hy, 5, MAG)
    c.restore()
    arm(R(6, 18), P["ua"], P["fa"], True)

def idle(t):
    P = base()
    s = math.sin(2 * PI * t)
    P["hy"] = 2.5 * s
    P["sway"] = 2.5 * math.sin(2 * PI * t + 1)
    P["ua"] = 0.4 + 0.06 * s
    return P

def walk(t):
    P = idle(t)
    P["lean"] = 0.12
    P["sway"] = -4 + 2 * math.sin(4 * PI * t)
    return P

def cast(t):
    P = base()
    k = smooth(min(1, t / 0.6))
    r = 1 - smooth(max(0, (t - 0.75) / 0.25))
    P["ua"], P["fa"] = lerp(0.4, 2.6, k * r), lerp(0.9, 2.9, k * r)
    P["fua"], P["ffa"] = lerp(-0.3, 2.2, k * r), lerp(0.3, 2.6, k * r)
    P["glow"] = k * r * (1.4 if t > 0.55 else 1)
    P["hy"] = -3 * k * r
    P["head"] = -0.15 * k * r
    return P

def hurt(t):
    P = idle(0)
    k = math.sin(PI * min(1, t * 1.2))
    P["lean"] = -0.15 * k
    P["head"] = -0.3 * k
    return P

def death(t):
    P = base()
    P["collapse"] = smooth(t)
    P["ua"], P["fua"] = lerp(0.4, 1.6, t), lerp(-0.3, 1.2, t)
    return P

ANIMS = [("idle", 8, idle, True), ("run", 8, walk, True), ("attack", 8, cast, False), ("hurt", 3, hurt, False),
         ("death", 8, death, False)]
