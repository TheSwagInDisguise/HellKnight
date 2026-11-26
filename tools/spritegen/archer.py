"""Rig + animations for the Bone Archer: hooded skeleton with a longbow."""
import math
from ink import *

PI = math.pi
CLOAK = hexc(0x1d2219)

def base():
    return dict(hx=0.0, hy=0.0, lean=0.05, head=0.0, lt=0.12, ls=0.05, ft=-0.12, fs=-0.05,
                bow=1.45, draw=0.0, arrow=True, sway=0.0, rot=0.0, fall=0.0)

def bone_limb(pen, a, b, w, shade=1.0):
    pen.armor(limb(a, b, w, w * 0.85), scale(BONE, 0.92 * shade), lw=1.3, hatch=False)
    pen.armor(ellipse(b[0], b[1], w * 0.75, w * 0.75), scale(BONE, shade), lw=1.0, hatch=False)

def draw(pen, P):
    c = pen.c
    c.save()
    if P["rot"]:
        c.rotate(math.degrees(P["rot"]), 0, 0)
    hip = (P["hx"], -29 + P["hy"] + P["fall"] * 12)
    lean = P["lean"]
    up = (math.sin(lean), -math.cos(lean))
    fwd = (math.cos(lean), math.sin(lean))
    def T(u, v):
        return (hip[0] + fwd[0] * u + up[0] * v, hip[1] + fwd[1] * u + up[1] * v)

    # cloak behind
    sw = P["sway"]
    cloak = smooth_path([T(-5, 22), T(-9 - sw, 10), T(-13 - sw * 2, -6), T(-8 - sw, -13), T(-2, -10), T(-4, 8)])
    pen.dark(cloak, lw=1.7, base=CLOAK, rim_col=hexc(0x9dff6e))
    pen.hatch(cloak, spacing=2.8, angle=1.35, color=hexc(0xb0a184, 0.12))

    def leg(off, th, sh, near):
        h = (hip[0] + off, hip[1])
        k = add(h, V(th, 14))
        a = add(k, V(sh, 14))
        bone_limb(pen, h, k, 3.4, 1 if near else 0.7)
        bone_limb(pen, k, a, 3.0, 1 if near else 0.7)
        pen.armor(poly([add(a, (-2, -1.5)), add(a, (6, 0)), add(a, (5, 2)), add(a, (-2, 2))]),
                  scale(BONE, 0.85 if near else 0.6), lw=1.1, hatch=False)
    leg(-2, P["ft"], P["fs"], False)
    leg(2, P["lt"], P["ls"], True)

    # pelvis + spine + ribs
    pelvis = smooth_path([T(-5, 2), T(5, 2), T(4, -3), T(0, -4), T(-4, -3)])
    pen.armor(pelvis, BONE, lw=1.4)
    pen.line([T(0, 2), T(0.5, 20)], INK, 3.2)
    pen.line([T(0, 2), T(0.5, 20)], BONE, 1.8)
    ribs = smooth_path([T(-6, 9), T(-5, 18), T(1, 21), T(7, 17), T(6, 9), T(1, 7)])
    pen.armor(ribs, BONE, lw=1.6)
    for k in range(4):
        pen.line([T(-5, 10 + k * 2.6), T(6, 10.5 + k * 2.6)], INK, 1.1)
    # tattered sash
    sash = poly([T(-6, 5), T(6, 6), T(5, 3.5), T(-6, 2.5)])
    pen.dark(sash, lw=1.1, base=hexc(0x3a0d0c))

    # hood + skull
    hc = T(2, 27)
    c.save()
    c.rotate(math.degrees(lean + P["head"]), hc[0], hc[1])
    hx, hy = hc
    hood = smooth_path([(hx - 9, hy + 6), (hx - 9, hy - 4), (hx - 2, hy - 11), (hx + 6, hy - 9), (hx + 9, hy - 2),
                        (hx + 7, hy + 7)])
    pen.dark(hood, lw=1.7, base=CLOAK, rim_col=hexc(0x9dff6e))
    skull = smooth_path([(hx - 4, hy - 1), (hx - 2, hy - 6), (hx + 4, hy - 6), (hx + 7, hy - 1), (hx + 6, hy + 4),
                         (hx + 1, hy + 6), (hx - 3, hy + 4)])
    pen.armor(skull, BONE, lw=1.5)
    pen.fill(ellipse(hx + 1.5, hy - 1, 1.9, 2.1), INK)
    pen.fill(ellipse(hx + 5.3, hy - 1, 1.6, 2.0), INK)
    pen.glow(hx + 1.5, hy - 0.8, 2.6, hexc(0x9dff6e))
    pen.glow(hx + 5.3, hy - 0.8, 2.2, hexc(0x9dff6e))
    for k in range(3):
        pen.line([(hx + 1.5 + k * 1.6, hy + 3), (hx + 1.5 + k * 1.6, hy + 5.5)], INK, 0.8)
    c.restore()

    # bow arm (far, extended forward), draw arm (near)
    sh_f = T(-1, 19)
    sh_n = T(3, 19)
    bow_a = P["bow"]
    elbow_f = add(sh_f, V(bow_a, 9))
    hand_f = add(elbow_f, V(bow_a, 9))
    bone_limb(pen, sh_f, elbow_f, 2.8, 0.75)
    bone_limb(pen, elbow_f, hand_f, 2.6, 0.75)
    # bow
    d = V(bow_a, 1)
    n = (-d[1], d[0])
    bend = 6 + 3 * P["draw"]
    top = add(hand_f, (n[0] * 17, n[1] * 17))
    bot = add(hand_f, (-n[0] * 17, -n[1] * 17))
    mid_back = add(hand_f, (-d[0] * 0.5, -d[1] * 0.5))
    arc = smooth_path([top, add(hand_f, (n[0] * 9 + d[0] * bend * 0.8, n[1] * 9 + d[1] * bend * 0.8)), hand_f,
                       add(hand_f, (-n[0] * 9 + d[0] * bend * 0.8, -n[1] * 9 + d[1] * bend * 0.8)), bot], closed=False)
    pen.stroke(arc, INK, 3.6)
    pen.stroke(arc, hexc(0x5a3a22), 2.0)
    nock = add(hand_f, (-d[0] * (4 + 13 * P["draw"]), -d[1] * (4 + 13 * P["draw"])))
    pen.line([top, nock, bot], hexc(0xebe0c8, 0.85), 0.7)
    if P["arrow"]:
        tip = add(nock, (d[0] * 28, d[1] * 28))
        pen.line([nock, tip], INK, 2.2)
        pen.line([nock, tip], BONE_DARK, 1.0)
        pen.armor(poly([add(tip, (n[0] * 2, n[1] * 2)), add(tip, (d[0] * 5, d[1] * 5)), add(tip, (-n[0] * 2, -n[1] * 2))]),
                  hexc(0x9dff6e), lw=0.9, hatch=False)
        pen.fill(poly([nock, add(nock, (n[0] * 2.5 - d[0] * 3, n[1] * 2.5 - d[1] * 3)),
                       add(nock, (-n[0] * 2.5 - d[0] * 3, -n[1] * 2.5 - d[1] * 3))]), BLOOD)
    # draw hand pulls the string
    el_n = add(sh_n, ((nock[0] - sh_n[0]) * 0.5 - 2, (nock[1] - sh_n[1]) * 0.5 + 3))
    bone_limb(pen, sh_n, el_n, 3.0)
    bone_limb(pen, el_n, nock, 2.8)
    c.restore()

def idle(t):
    P = base()
    s = math.sin(2 * PI * t)
    P["hy"] = 0.6 * s
    P["sway"] = 1.2 * s
    P["head"] = 0.05 * s
    P["bow"] = 1.0 + 0.04 * s
    return P

def run(t):
    P = base()
    p = 2 * PI * t
    s = math.sin(p)
    P["lean"] = 0.15
    P["hy"] = -1.5 * abs(math.cos(p)) + 1
    P["lt"], P["ft"] = 0.5 * s, -0.5 * s
    P["ls"] = P["lt"] - 0.15 - 0.8 * max(0, -math.sin(p + 0.9))
    P["fs"] = P["ft"] - 0.15 - 0.8 * max(0, math.sin(p + 0.9))
    P["sway"] = 3 + 1.5 * math.sin(2 * p)
    P["bow"] = 0.8
    return P

def shoot(t):
    P = base()
    P["lt"], P["ls"] = 0.3, 0.1
    P["ft"], P["fs"] = -0.3, -0.15
    if t < 0.65:
        k = smooth(t / 0.65)
        P["draw"] = k
        P["bow"] = lerp(1.0, 1.57, k)
        P["lean"] = lerp(0.05, -0.08, k)
    elif t < 0.78:
        P["draw"] = 0
        P["arrow"] = False
        P["bow"] = 1.57
        P["lean"] = -0.15
        P["hx"] = -1.5
    else:
        k = smooth((t - 0.78) / 0.22)
        P["arrow"] = False
        P["bow"] = lerp(1.57, 1.0, k)
        P["lean"] = lerp(-0.15, 0.05, k)
    return P

def hurt(t):
    P = idle(0)
    k = math.sin(PI * min(1, t * 1.2))
    P["lean"] = -0.3 * k
    P["head"] = -0.3 * k
    P["hx"] = -2.5 * k
    return P

def death(t):
    P = base()
    k = smooth(t)
    P["fall"] = k
    P["lt"], P["ls"] = lerp(0.12, 1.3, k), lerp(0.05, -0.5, k)
    P["ft"], P["fs"] = lerp(-0.12, 1.0, k), lerp(-0.05, -0.8, k)
    P["rot"] = 1.2 * smooth(max(0, (t - 0.3) / 0.7))
    P["arrow"] = False
    P["bow"] = lerp(1.0, 0.2, k)
    return P

ANIMS = [("idle", 8, idle, True), ("run", 8, run, True), ("attack", 8, shoot, False),
         ("hurt", 3, hurt, False), ("death", 6, death, False)]
