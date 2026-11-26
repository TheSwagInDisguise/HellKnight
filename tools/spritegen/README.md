# Sprite generator

Renders HellKnight's animated characters from 2D skeletal rigs into sprite sheets.

- `ink.py`: shared ink-style drawing helpers (shaded armor plates, hatching, rim light, glows)
- `knight.py`, `imp.py`: rigs and their animations (idle, run, attacks, hurt, death…)
- `render.py`: frame/sheet rendering and preview GIFs

Requires `skia-python`, `numpy` and `pillow`.
