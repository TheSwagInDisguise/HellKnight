"""Wisp: a living flame with a skull face (drawn pale; tinted by area colour in game)."""
import math
from ink import *

PI = math.pi

def base():
    return dict(phase=0.0, size=1.0, bright=0.0, burst=0.0)

def draw(pen, P):
    c = pen.c
    s = P["size"]
    ph = P["phase"]
    cy = -30
    pts = []
    n = 14
    for i in range(n):
        a = i / n * 2 * PI
        # teardrop flame: tall tip upward, wobbling tongues
        r = 13 * s * (1 + 0.15 * math.sin(a * 3 + ph * 2))
        x = math.sin(a) * r
        y = -math.cos(a) * r
        k = math.cos(a)
        if k > 0:  # upper half: stretch into a flickering tip
            y *= 1.0 + 1.1 * k ** 3 * (1 + 0.2 * math.sin(ph * 3 + a * 2))
            x *= 1 - 0.5 * k ** 2
        lick = math.sin(ph * 2 + y * 0.2) * 2.2 * (-y / 25 if y < 0 else 0)
        pts.append((x + lick, cy + y))
    flame = smooth_path(pts)
    pen.glow(0, cy - 2, 26 * s, hexc(0xffffff, 0.45 + 0.2 * P["bright"]))
    pen.gradient_fill(flame, hexc(0xffffff, 0.95), hexc(0xb8b8b8, 0.9))
    inner = smooth_path([(x * 0.55, cy + (y - cy) * 0.55 + 3) for (x, y) in pts])
    pen.fill(inner, hexc(0xffffff, 0.9))
    pen.hatch(flame, spacing=3.0, angle=1.2, color=hexc(0, 0.12),
              region=poly([(2, cy - 40), (20, cy - 40), (20, cy + 20), (2, cy + 20)]))
    pen.stroke(flame, INK, 1.8)
    for (x0, y0, x1, y1) in ((-4, cy - 10, -2, cy - 22), (3, cy - 8, 5, cy - 18)):
        pen.line([(x0, y0), (x1 + math.sin(ph) * 2, y1)], hexc(0, 0.35), 0.8)
    # skull face
    pen.fill(ellipse(-3.5, cy + 1, 2.6, 3.2), INK)
    pen.fill(ellipse(3.5, cy + 1, 2.6, 3.2), INK)
    pen.fill(poly([(-2.5, cy + 6), (2.5, cy + 6), (1.5, cy + 8.5 + P["bright"] * 2), (-1.5, cy + 8.5 + P["bright"] * 2)]), INK)
    if P["burst"] > 0:
        for k in range(10):
            a = k / 10 * 2 * PI
            r0, r1 = 10 + 18 * P["burst"], 16 + 26 * P["burst"]
            pen.line([(math.cos(a) * r0, cy + math.sin(a) * r0), (math.cos(a) * r1, cy + math.sin(a) * r1)],
                     hexc(0xffffff, 1 - P["burst"]), 2)

def idle(t):
    P = base()
    P["phase"] = 2 * PI * t
    P["size"] = 1 + 0.05 * math.sin(4 * PI * t)
    return P

def fuse(t):
    P = base()
    P["phase"] = 4 * PI * t
    P["size"] = 1.1 + 0.15 * math.sin(4 * PI * t)
    P["bright"] = 0.5 + 0.5 * math.sin(4 * PI * t)
    return P

def death(t):
    P = base()
    P["phase"] = t * 4
    P["size"] = lerp(1.2, 0.2, smooth(t))
    P["burst"] = t
    return P

ANIMS = [("idle", 8, idle, True), ("run", 8, idle, True), ("attack", 6, fuse, True), ("hurt", 2, fuse, False),
         ("death", 5, death, False)]
