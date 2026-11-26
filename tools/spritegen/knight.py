"""Skeletal rig + animations for the Hell Knight (3/4 view facing right; mirrored in game)."""
import math
from ink import *

PI = math.pi
THIGH, SHIN, TORSO, UARM, FARM = 15.0, 15.0, 21.0, 11.5, 11.0

def base_pose():
    return dict(hx=0.0, hy=0.0, torso=0.06, head=0.0,
                lt=0.18, ls=0.05, ft=-0.14, fs=-0.06,
                ua=0.3, fa=0.9, fua=-0.2, ffa=0.3, wpn=0.5,
                cape=[-0.15, -0.05, -0.05, 0.0], smear=None, rot=0.0, glow=0.0, drop=0.0)

# ---------------------------------------------------------------- drawing

def draw(pen, P, weapon="blade"):
    c = pen.c
    c.save()
    if P["rot"]:
        c.rotate(math.degrees(P["rot"]), -6, 0)
    hip = (P["hx"], -(THIGH + SHIN - 1.5) + P["hy"])
    up = (math.sin(P["torso"]), -math.cos(P["torso"]))
    fwd = (math.cos(P["torso"]), math.sin(P["torso"]))
    def T(u, v):  # torso-local (u forward, v up) -> world
        return (hip[0] + fwd[0] * u + up[0] * v, hip[1] + fwd[1] * u + up[1] * v)
    neck = T(0, TORSO)

    def leg(off, th, sh, near):
        h = (hip[0] + off, hip[1])
        knee = add(h, V(th, THIGH))
        ankle = add(knee, V(sh, SHIN))
        shade = 1.0 if near else 0.7
        steel = scale(STEEL, 1.25 * shade)
        p_th = limb(h, knee, 8.5, 7.2)
        pen.armor(p_th, steel, lw=1.7, rim_col=hexc(0xffffff, 0.35))
        p_sh = limb(knee, ankle, 7.0, 6.0)
        pen.armor(p_sh, steel, lw=1.7, rim_col=hexc(0xffffff, 0.35))
        boot = poly([add(ankle, (-3.5, -2.5)), add(ankle, (3.0, -3)), add(ankle, (8.5, 1.5)),
                     add(ankle, (8.0, 3.0)), add(ankle, (-3.5, 3.0))])
        pen.armor(boot, scale(BONE, 0.85 * shade), lw=1.5)
        kc = poly([add(knee, (-1.5, -3.2)), add(knee, (3.6, -1.8)), add(knee, (3.2, 2.6)), add(knee, (-1.2, 2.2))])
        pen.armor(kc, scale(BONE, 0.85 * shade), lw=1.2, hatch=False)

    def arm(sh_pt, ua, fa, near, hand_glow=0.0):
        elbow = add(sh_pt, V(ua, UARM))
        hand = add(elbow, V(fa, FARM))
        shade = 1.0 if near else 0.68
        pen.armor(limb(sh_pt, elbow, 6.4, 5.6), scale(STEEL, 1.3 * shade), lw=1.6, rim_col=hexc(0xffffff, 0.3))
        pen.armor(limb(elbow, hand, 5.8, 5.2), scale(STEEL, 1.3 * shade), lw=1.6, rim_col=hexc(0xffffff, 0.3))
        g = ellipse(hand[0], hand[1], 3.6, 3.6)
        pen.armor(g, scale(BONE, 0.95 * shade), lw=1.4, hatch=False)
        if hand_glow > 0:
            pen.glow(hand[0], hand[1], 9 * hand_glow, hexc(0xff5a2a, 0.9))
        return hand

    # --- cape (behind everything)
    root = T(-3.5, TORSO - 1.5)
    pts_l, pts_r = [], []
    p = root
    ang = -P["torso"] * 0.4
    widths = [9, 11.5, 13.5, 15]
    chain = [p]
    for i, da in enumerate(P["cape"]):
        ang += da
        p = add(p, V(ang, 12.5))
        chain.append(p)
    for i, q in enumerate(chain):
        w = [6, 9, 11.5, 13.5, 15][i]
        if i < len(chain) - 1:
            d = (chain[i + 1][0] - q[0], chain[i + 1][1] - q[1])
        else:
            d = (q[0] - chain[i - 1][0], q[1] - chain[i - 1][1])
        l = math.hypot(*d) or 1
        n = (-d[1] / l, d[0] / l)
        pts_l.append((q[0] + n[0] * w * 0.55, q[1] + n[1] * w * 0.55))
        pts_r.append((q[0] - n[0] * w * 0.45, q[1] - n[1] * w * 0.45))
    hem_a, hem_b = pts_l[-1], pts_r[-1]
    hem = []
    for k in range(1, 5):
        t = k / 5
        hx_, hy_ = hem_a[0] + (hem_b[0] - hem_a[0]) * t, hem_a[1] + (hem_b[1] - hem_a[1]) * t
        hem.append((hx_, hy_ + (2.5 if k % 2 else -1.5)))
    cape = poly(pts_l + hem + list(reversed(pts_r)))
    pen.dark(cape, lw=1.9)
    pen.hatch(cape, spacing=3.2, angle=1.3, color=hexc(0xb0a184, 0.12))
    pen.line([pts_l[-1]] + hem + [pts_r[-1]], BLOOD, 1.5)

    # --- far limbs
    far_sh = T(-3.5, TORSO - 3)
    arm(far_sh, P["fua"], P["ffa"], False, hand_glow=P["glow"])
    leg(-2.0, P["ft"], P["fs"], False)
    leg(2.0, P["lt"], P["ls"], True)

    # --- torso
    plate = poly([T(-7.5, 1), T(7.5, 1), T(9.5, 13), T(8.5, TORSO + 1), T(-8.5, TORSO + 1), T(-9, 12)])
    pen.armor(plate, BONE, lw=2.0)
    pen.line([T(1.5, 3), T(2.5, TORSO - 1)], INK, 0.9)
    pen.line([T(-7, 12), T(9, 12)], hexc(0, 0.45), 0.8)
    tasset = poly([T(-9, 2), T(9.5, 2), T(10.5, -6), T(5, -8), T(0, -6.5), T(-5, -8), T(-10, -6)])
    pen.armor(tasset, scale(STEEL, 1.5), lw=1.6, rim_col=hexc(0xffffff, 0.3))
    belt = poly([T(-8.5, 3.5), T(9.5, 3.5), T(9.5, 0.5), T(-8.5, 0.5)])
    pen.fill(belt, scale(STEEL, 0.8))
    pen.stroke(belt, INK, 1.2)
    bc = T(4, 2)
    pen.glow(bc[0], bc[1], 3.2, BLOOD)
    sway = P["lt"] * 0.5
    tb = [T(1, 1), T(8, 1)]
    a_tab = P["torso"] + sway
    bot_l = add(T(1.5, -2), V(a_tab + 0.15, 15))
    bot_r = add(T(8.5, -2), V(a_tab, 14))
    tab = poly([tb[0], tb[1], bot_r, add(bot_r, (-2.2, 2.5)), bot_l])
    pen.gradient_fill(tab, hexc(0xa3171e), hexc(0x3d0609))
    pen.hatch(tab, spacing=2.6, angle=1.4, color=hexc(0, 0.25))
    pen.stroke(tab, INK, 1.4)
    pen.line([add(tb[0], (0.8, 1)), add(bot_l, (0.8, -1))], GOLD, 0.8)
    mid = ((tb[0][0] + bot_r[0]) / 2 + 1, (tb[0][1] + bot_r[1]) / 2)
    pen.armor(ellipse(mid[0], mid[1], 2.4, 2.8), BONE, lw=0.9, hatch=False)
    far_p = ellipse(*T(-5.5, TORSO - 1), 6, 5.2)
    pen.armor(far_p, scale(BONE, 0.72), lw=1.6)

    # --- head
    hc = add(neck, (up[0] * 9.5, up[1] * 9.5))
    c.save()
    c.rotate(math.degrees(P["torso"] + P["head"]), hc[0], hc[1])
    hx, hy = hc
    h1 = smooth_path([(hx - 3, hy - 7), (hx - 10, hy - 14), (hx - 14, hy - 22), (hx - 9, hy - 16), (hx - 2, hy - 10)])
    h2 = smooth_path([(hx + 3, hy - 8), (hx + 6, hy - 16), (hx + 4, hy - 25), (hx + 9, hy - 17), (hx + 7, hy - 8)])
    pen.armor(h1, scale(BONE, 0.8), lw=1.5)
    pen.armor(h2, BONE, lw=1.5)
    helm = smooth_path([(hx - 8, hy - 2), (hx - 6, hy - 9), (hx + 1, hy - 11), (hx + 8, hy - 7),
                        (hx + 10, hy + 1), (hx + 7, hy + 8), (hx - 2, hy + 9), (hx - 8, hy + 5)])
    pen.armor(helm, BONE, lw=2.0)
    visor = poly([(hx + 1, hy - 1.5), (hx + 10.2, hy - 1.5), (hx + 10.2, hy + 1.8), (hx + 1, hy + 1.8)])
    pen.fill(visor, INK)
    pen.fill(poly([(hx + 5, hy - 1.5), (hx + 7.5, hy - 1.5), (hx + 7.2, hy + 7), (hx + 5.2, hy + 7)]), INK)
    pen.glow(hx + 4.2, hy + 0.2, 3.6, BLOOD)
    pen.glow(hx + 8.8, hy + 0.2, 3.0, BLOOD)
    pen.line([(hx - 6, hy + 4), (hx - 1, hy + 7)], hexc(0, 0.5), 0.8)
    c.restore()

    # --- near pauldron + arm + weapon
    near_sh = T(2.0, TORSO - 2.5)
    hand = arm(near_sh, P["ua"], P["fa"], True)
    np_ = smooth_path([add(near_sh, (-5.5, 2.5)), add(near_sh, (-4.5, -3.5)), add(near_sh, (1, -5.2)),
                       add(near_sh, (5.5, -2.5)), add(near_sh, (5, 2.5)), add(near_sh, (0, 3.6))])
    pen.armor(np_, BONE, lw=1.8)
    wa = P["fa"] + P["wpn"]
    if P["smear"] is not None and weapon in ("blade",):
        a0, a1 = P["smear"], wa
        steps = 10
        arc_pts_o, arc_pts_i = [], []
        for k in range(steps + 1):
            a = a0 + (a1 - a0) * k / steps
            f = k / steps
            arc_pts_o.append(add(hand, V(a, 45)))
            arc_pts_i.append(add(hand, V(a, 45 - 3 - 11 * f)))
        sm = poly(arc_pts_o + list(reversed(arc_pts_i)))
        pen.fill(sm, hexc(0xfff0e0, 0.42))
        pen.line(arc_pts_o[steps // 3:], hexc(0xffffff, 0.85), 1.6)
    if weapon == "blade" and P["drop"] < 1:
        draw_blade(pen, hand, wa)
    elif weapon == "pike" and P["drop"] < 1:
        draw_pike(pen, hand, wa)
    elif weapon == "fists":
        sp = [add(hand, V(wa + d, 5.5)) for d in (-0.6, 0, 0.6)]
        for s in sp:
            pen.armor(poly([add(s, V(wa + 1.57, 1.4)), add(s, V(wa, 3.5)), add(s, V(wa - 1.57, 1.4))]), BONE, lw=1)
        pen.glow(hand[0], hand[1], 5, hexc(0xff6a2a, 0.8))
    c.restore()

def draw_blade(pen, hand, a):
    d = V(a, 1)
    n = (-d[1], d[0])
    def at(l, w=0):
        return (hand[0] + d[0] * l + n[0] * w, hand[1] + d[1] * l + n[1] * w)
    pen.armor(limb(at(-6), at(1), 3, 3), scale(STEEL, 1.4), lw=1.2, hatch=False)
    pen.armor(ellipse(*at(-7), 2.4, 2.4), GOLD, lw=1.1, hatch=False)
    guard = poly([at(2, -6), at(4, -6.5), at(4, 6.5), at(2, 6)])
    pen.armor(guard, GOLD, lw=1.2, hatch=False)
    blade = poly([at(4, -2.6), at(34, -2.2), at(43, 0), at(34, 2.4), at(4, 2.8)])
    pen.gradient_fill(blade, hexc(0xf4efe6), hexc(0x8d8a86))
    pen.hatch(blade, spacing=1.6, region=poly([at(4, 0), at(44, 0), at(44, 4), at(4, 4)]), color=hexc(0, 0.35))
    pen.stroke(blade, INK, 1.3)
    pen.line([at(6, 0), at(36, 0)], BLOOD, 1.1)

def draw_pike(pen, hand, a):
    d = V(a, 1)
    n = (-d[1], d[0])
    def at(l, w=0):
        return (hand[0] + d[0] * l + n[0] * w, hand[1] + d[1] * l + n[1] * w)
    pen.armor(limb(at(-26), at(44), 2.6, 2.6), hexc(0x4a3524), lw=1.2, hatch=False)
    pen.armor(poly([at(42, -4.5), at(44, -4.5), at(44, 4.5), at(42, 4.5)]), STEEL, lw=1, hatch=False)
    head = poly([at(44, -3.2), at(62, 0), at(44, 3.2), at(48, 0)])
    pen.gradient_fill(head, hexc(0xf4efe6), hexc(0x8d8a86))
    pen.stroke(head, INK, 1.3)
    pen.line([at(48, 0), at(58, 0)], BLOOD, 1)

# ---------------------------------------------------------------- animations

def idle(t):
    P = base_pose()
    b = math.sin(2 * PI * t)
    P["hy"] = 0.7 * b
    P["torso"] = 0.07 + 0.025 * b
    P["head"] = -0.03 * b
    P["ls"] = 0.05 - 0.04 * b
    P["fs"] = -0.06 - 0.04 * b
    P["ua"] = 0.3 + 0.04 * b
    P["fa"] = 0.85 + 0.05 * b
    P["wpn"] = 0.4 - P["fa"]
    P["fua"] = -0.2 + 0.03 * b
    P["cape"] = [-0.18 + 0.05 * math.sin(2 * PI * t + 0.6), -0.04 + 0.04 * math.sin(2 * PI * t + 1.4), -0.04, 0.02]
    return P

def run(t):
    P = base_pose()
    p = 2 * PI * t
    s = math.sin(p)
    P["hy"] = -2.2 * abs(math.cos(p)) + 1.4
    P["hx"] = 0
    P["torso"] = 0.24 + 0.03 * math.sin(2 * p)
    P["head"] = -0.12
    P["lt"] = 0.62 * s
    P["ft"] = -0.62 * s
    P["ls"] = P["lt"] - (0.15 + 1.05 * max(0, -math.sin(p + 0.9)))
    P["fs"] = P["ft"] - (0.15 + 1.05 * max(0, math.sin(p + 0.9)))
    P["ua"] = -0.55 * s - 0.1
    P["fa"] = P["ua"] + 0.9
    P["wpn"] = -0.9 - P["fa"]
    P["fua"] = 0.55 * s
    P["ffa"] = P["fua"] + 0.9
    P["cape"] = [-0.62 + 0.08 * math.sin(2 * p), 0.12 + 0.16 * math.sin(2 * p + 1.1),
                 0.16 + 0.14 * math.sin(2 * p + 2.2), 0.12 + 0.12 * math.sin(2 * p + 3)]
    return P

def swing(t, a_from, a_to, ua_from, ua_to, lunge=4.0, crouch=0.0, wind=0.28):
    """Generic sword swing: windup, fast strike, recovery."""
    P = base_pose()
    if t < wind:
        k = smooth(t / wind)
        wa = lerp(0.5, a_from, k)
        ua = lerp(0.3, ua_from, k)
        P["torso"] = lerp(0.06, -0.12, k)
        P["hx"] = -1.5 * k
        smear = None
    elif t < wind + 0.22:
        k = smooth((t - wind) / 0.22)
        wa = lerp(a_from, a_to, k)
        ua = lerp(ua_from, ua_to, k)
        P["torso"] = lerp(-0.12, 0.32, k)
        P["hx"] = lerp(-1.5, lunge, k)
        P["hy"] = crouch * k
        smear = lerp(a_from, a_to, max(0, k - 0.6))
    else:
        k = smooth((t - wind - 0.22) / (1 - wind - 0.22))
        wa = lerp(a_to, 0.5, k * 0.7)
        ua = lerp(ua_to, 0.3, k * 0.7)
        P["torso"] = lerp(0.32, 0.1, k)
        P["hx"] = lerp(lunge, lunge * 0.6, k)
        P["hy"] = crouch * (1 - k)
        smear = None
    P["ua"] = ua
    P["fa"] = ua + 0.35
    P["wpn"] = wa - P["fa"]
    P["smear"] = smear
    P["lt"], P["ls"] = 0.42, 0.1
    P["ft"], P["fs"] = -0.35, -0.2
    P["fua"] = -0.6
    P["ffa"] = -0.1
    P["cape"] = [-0.45 - 0.2 * P["torso"], -0.12, -0.08, 0.0]
    return P

def attack_a(t):
    return swing(t, 3.3, 0.55, 2.7, 0.75)

def attack_b(t):
    return swing(t, -0.5, 2.5, -0.4, 2.0)

def attack_heavy(t):
    return swing(t, 3.7, 0.25, 3.0, 0.45, lunge=8, crouch=4.0, wind=0.38)

def thrust(t, far=False):
    P = base_pose()
    if t < 0.3:
        k = smooth(t / 0.3)
        reach = lerp(0, -1, k)
    elif t < 0.5:
        k = smooth((t - 0.3) / 0.2)
        reach = lerp(-1, 1, k)
    else:
        k = smooth((t - 0.5) / 0.5)
        reach = lerp(1, 0.2, k)
    P["torso"] = 0.08 + 0.22 * reach
    P["hx"] = 3.5 * reach
    P["ua"] = 1.2 + 0.35 * reach
    P["fa"] = 1.5 + 0.1 * reach
    P["wpn"] = PI / 2 + 0.05 - P["fa"]
    P["lt"], P["ls"] = 0.45, 0.12
    P["ft"], P["fs"] = -0.4, -0.25
    P["fua"] = 1.0 + 0.3 * reach
    P["ffa"] = 1.4
    P["cape"] = [-0.5 - 0.2 * reach, -0.1, -0.06, 0.0]
    return P

def punch(t, near=True):
    P = base_pose()
    if t < 0.25:
        r = -smooth(t / 0.25)
    elif t < 0.45:
        r = lerp(-1, 1, smooth((t - 0.25) / 0.2))
    else:
        r = lerp(1, 0, smooth((t - 0.45) / 0.55))
    P["torso"] = 0.1 + 0.2 * r
    P["hx"] = 2.5 * r
    P["lt"], P["ls"] = 0.4, 0.1
    P["ft"], P["fs"] = -0.4, -0.25
    a_ext, a_rest = (1.55, 1.55), (0.6, 2.2)
    ext = max(0, r)
    if near:
        P["ua"] = lerp(a_rest[0], a_ext[0], ext) - 0.3 * max(0, -r)
        P["fa"] = lerp(a_rest[1], a_ext[1], ext)
        P["fua"], P["ffa"] = 0.5, 2.3
    else:
        P["fua"] = lerp(a_rest[0], a_ext[0], ext)
        P["ffa"] = lerp(a_rest[1], a_ext[1], ext)
        P["ua"], P["fa"] = 0.6, 2.3
    P["wpn"] = 0
    P["cape"] = [-0.45, -0.1, -0.05, 0]
    return P

def dash(t):
    P = run(0.25)
    P["torso"] = 0.55
    P["head"] = -0.3
    P["lt"], P["ls"] = 0.5, 0.2
    P["ft"], P["fs"] = -0.9, -1.4
    P["ua"], P["fa"] = -0.9, -0.5
    P["wpn"] = -1.3 - P["fa"]
    P["cape"] = [-1.05 + 0.08 * math.sin(2 * PI * t), 0.05 + 0.1 * math.sin(2 * PI * t + 0.7),
                 0.08 + 0.12 * math.sin(2 * PI * t + 1.6), 0.06]
    P["hy"] = 2
    return P

def cast(t):
    P = base_pose()
    k = smooth(min(1, t / 0.45))
    r = 1 - smooth(max(0, (t - 0.6) / 0.4))
    P["torso"] = 0.05 + 0.15 * k * r
    P["fua"] = lerp(-0.2, 1.65, k * r)
    P["ffa"] = lerp(0.3, 1.6, k * r)
    P["glow"] = k * r * (1.2 if 0.35 < t < 0.7 else 0.7)
    P["ua"], P["fa"] = 0.2, 0.7
    P["wpn"] = 0.3 - P["fa"]
    P["lt"], P["ls"] = 0.35, 0.1
    P["ft"], P["fs"] = -0.3, -0.15
    P["cape"] = [-0.3, -0.08, -0.05, 0]
    return P

def hurt(t):
    P = idle(0)
    k = math.sin(PI * min(1, t * 1.2))
    P["torso"] = 0.06 - 0.35 * k
    P["head"] = -0.25 * k
    P["hx"] = -3 * k
    P["ua"], P["fa"] = 0.6 + 0.6 * k, 1.4 + 0.5 * k
    P["wpn"] = 0.3 - P["fa"]
    P["fua"] = -0.6 * k
    P["cape"] = [0.1 * k - 0.15, 0.05, 0, 0]
    return P

def death(t):
    P = base_pose()
    k1 = smooth(min(1, t / 0.4))
    k2 = smooth(max(0, (t - 0.35) / 0.55))
    P["torso"] = lerp(0.06, 0.5, k1) - 0.4 * k2
    P["head"] = lerp(0, 0.4, k1)
    P["hy"] = lerp(0, 9, k1)
    P["lt"], P["ls"] = lerp(0.18, 1.2, k1), lerp(0.05, -0.6, k1)
    P["ft"], P["fs"] = lerp(-0.14, 0.9, k1), lerp(-0.06, -0.8, k1)
    P["ua"], P["fa"] = lerp(0.3, 0.9, k1), lerp(0.9, 1.5, k1)
    P["wpn"] = 1.6 - P["fa"]
    P["fua"] = lerp(-0.2, 0.6, k1)
    P["rot"] = -1.35 * k2
    P["drop"] = 1 if t > 0.5 else 0
    P["cape"] = [-0.2 + 0.4 * k2, 0.1, 0.05, 0]
    return P

def anims_for(weapon):
    """(name, frame count, pose fn, loops)"""
    common_head = [("idle", 8, idle, True), ("run", 8, run, True)]
    if weapon == "blade":
        atk = [("attack1", 6, attack_a, False), ("attack2", 6, attack_b, False), ("attack3", 8, attack_heavy, False)]
    elif weapon == "pike":
        atk = [("attack1", 6, thrust, False), ("attack2", 6, thrust, False), ("attack3", 8, thrust, False)]
    else:
        atk = [("attack1", 5, lambda t: punch(t, True), False), ("attack2", 5, lambda t: punch(t, False), False),
               ("attack3", 7, lambda t: punch(t, True), False)]
    tail = [("dash", 4, dash, True), ("cast", 6, cast, False), ("hurt", 3, hurt, False), ("death", 8, death, False)]
    return common_head + atk + tail
