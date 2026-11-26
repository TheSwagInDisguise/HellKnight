"""Render rigged characters to frames, sprite sheets and preview GIFs."""
import math
import sys
import numpy as np
import skia
from PIL import Image
from ink import Pen

def render_frame(draw_fn, pose, w, h, ground, scale):
    """Render one frame. (w, h) in points; ground = distance of the feet from the bottom edge."""
    surf = skia.Surface(int(w * scale), int(h * scale))
    c = surf.getCanvas()
    c.clear(skia.Color4f(0, 0, 0, 0))
    c.scale(scale, scale)
    c.translate(w / 2, h - ground)
    draw_fn(Pen(c), pose)
    img = surf.makeImageSnapshot()
    arr = img.toarray(colorType=skia.kRGBA_8888_ColorType, alphaType=skia.kUnpremul_AlphaType)
    return Image.fromarray(arr, "RGBA")

def build_sheet(anims, draw_fn, w, h, ground, scale, cols=8):
    """Render all animations into one sheet (one row per animation). Returns (image, meta)."""
    rows = len(anims)
    fw, fh = int(w * scale), int(h * scale)
    sheet = Image.new("RGBA", (fw * cols, fh * rows), (0, 0, 0, 0))
    meta = []
    for r, (name, n, fn, loops) in enumerate(anims):
        for i in range(n):
            t = i / n if loops else (i / (n - 1) if n > 1 else 0)
            fr = render_frame(draw_fn, fn(t), w, h, ground, scale)
            sheet.paste(fr, (i * fw, r * fh), fr)
        meta.append((name, r, n, loops))
    return sheet, meta

def backdrop(size, floor=(44, 35, 30)):
    """Dark floor with a warm light pool, for previews."""
    W, H = size
    y, x = np.mgrid[0:H, 0:W]
    d = np.sqrt(((x - W / 2) / (W * 0.55)) ** 2 + ((y - H * 0.75) / (H * 0.45)) ** 2)
    k = np.clip(1 - d, 0, 1) ** 1.5
    base = np.array([10, 7, 6], dtype=float)
    lit = np.array(floor, dtype=float) * 1.4 + np.array([30, 14, 4])
    img = base[None, None, :] * (1 - k[..., None]) + lit[None, None, :] * k[..., None]
    return Image.fromarray(img.astype(np.uint8), "RGB").convert("RGBA")

def preview_gif(path, strips, w, h, ground, scale, fps=14, label_scale=1):
    """strips: list of (name, frames, pose_fn, loops, draw_fn, repeats)."""
    frames = []
    for name, n, fn, loops, draw_fn, reps in strips:
        imgs = []
        for i in range(n):
            t = i / n if loops else (i / (n - 1) if n > 1 else 0)
            imgs.append(render_frame(draw_fn, fn(t), w, h, ground, scale))
        for _ in range(reps):
            for im in imgs:
                bg = backdrop(im.size)
                bg.alpha_composite(im)
                frames.append(bg.convert("RGB"))
        if not loops:
            for _ in range(int(fps * 0.35)):
                frames.append(frames[-1])
    frames[0].save(path, save_all=True, append_images=frames[1:], duration=int(1000 / fps), loop=0, optimize=True)
