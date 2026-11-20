"""Pixel-art UI skin of pkmxtft (own drawing, 2026-11-20).

Drawn after the style of the "V21.1 Essentials UI Redesign" by LostSoulsDev (a Pokemon Essentials kit): dark
frames with a fine grid, double coloured lines, cut corners and stepped "shoulders", red corner brackets on
hover / selection, slanted bars. No image of that repo is used (it has no licence for its art): every pixel
here is drawn by this script.

1 texel = 1 canvas unit of the 1920x1080 UI; the frames are drawn in art pixels of 2x2 texels (ART: chunky
pixel art like the kit's), the small parts above the Pokemon in single texels. On the test phone (x2.0) a
texel is 2x2 screen pixels, crisp with the NEAREST filter that UiSkin picks at whole scales; on a 1600x900
window (x0.83) the LINEAR filter.

Every image is a nine-patch: `margin` = [left, top, right, bottom] in texels, the corner parts drawn 1:1, the
middle parts stretched or tiled (`axis`). `expand` = transparent room around the frame for the corner
brackets (StyleBoxTexture.expand_margin_*). `tint` = drawn in greys, coloured at runtime by modulate_color
(rarity, synergy tier...).

  python tools/ui/gen_skin.py      writes assets/ui/skin/*.png + skin.json and build/shots/ui_skin_sheet.png
"""
import json
import os

import numpy as np
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "assets", "ui", "skin")
SHEET = os.path.join(ROOT, "build", "shots", "ui_skin_sheet.png")

# ------------------------------------------------------------------ palette (RGBA); shaded sets = (light, mid, dark)
INK = (5, 6, 9, 255)
GAP = (9, 11, 15, 255)
CLEAR = (0, 0, 0, 0)


def c(r, g, b, a=255):
    return (r, g, b, a)


def shade(light, mid, dark):
    return {"hi": c(*light), "mid": c(*mid), "lo": c(*dark)}


SLATE_A = shade((196, 208, 242), (132, 148, 196), (78, 90, 136))
SLATE_B = shade((104, 120, 168), (80, 94, 140), (50, 60, 96))
SLATE_DEEP = c(50, 60, 94)
SLATE_BRIGHT = shade((236, 242, 255), (184, 198, 238), (112, 126, 176))
ORANGE_A = shade((255, 216, 144), (242, 158, 56), (176, 98, 30))
ORANGE_B = shade((210, 124, 42), (168, 92, 28), (120, 64, 20))
ORANGE_DEEP = c(84, 48, 20)
RED_A = shade((255, 160, 156), (230, 82, 86), (156, 38, 46))
RED_B = shade((196, 58, 66), (156, 38, 46), (104, 22, 30))
RED_DEEP = c(70, 12, 18)
GOLD_A = shade((255, 238, 160), (250, 206, 84), (182, 132, 32))
LIME_A = shade((206, 248, 146), (148, 214, 82), (88, 148, 42))
WHITE_A = shade((255, 255, 255), (218, 218, 218), (156, 156, 156))  # tinted frames: modulate gives the colour
GREY_B = shade((176, 176, 176), (138, 138, 138), (98, 98, 98))
GREY_DEEP = c(64, 64, 64)
DIM_A = shade((86, 94, 112), (64, 70, 84), (44, 48, 58))

BRACKET = c(238, 54, 40)
BRACKET_HI = c(255, 140, 120)
BRACKET_GOLD = c(255, 214, 90)
BRACKET_GOLD_HI = c(255, 246, 190)

GRID = 6  # pattern period of the dark fills (texels)
LIGHT = np.array([-0.3, -0.95])  # light from the top (a little from the left)


# ------------------------------------------------------------------ shapes
def box_mask(w, h, cut=0, corners="tl tr br bl", shoulder=0, shoulder_end=10, shoulder_sides="top bottom",
             left_cut=None, right_cut=None, pad=0):
    """Mask of a frame in a w x h image (pad texels of free room around it): 45° cuts of `cut` texels at the
    listed corners; `shoulder` > 0: the top / bottom edge is that much lower at both ends (`shoulder_end`
    texels after the cut) and rises at 45° to the middle (the stepped edges of the style); `left_cut` /
    `right_cut`: (top, bottom) cut sizes overriding `cut` on that side (pointed ends = h / 2)."""
    y, x = np.mgrid[0:h, 0:w]
    x = x - pad
    y = y - pad
    w -= 2 * pad
    h -= 2 * pad
    m = (x >= 0) & (y >= 0) & (x < w) & (y < h)
    if shoulder:
        a = cut + shoulder_end
        prof = np.clip(np.minimum(x - a, (w - 1 - x) - a), 0, None)  # 0 at the ends, grows inwards
        lift = np.clip(shoulder - prof, 0, shoulder)  # shoulder depth at the ends, 0 in the middle
        if "top" in shoulder_sides:
            m &= y >= lift
        if "bottom" in shoulder_sides:
            m &= (h - 1 - y) >= lift
    lt, lb = left_cut if left_cut else (cut if "tl" in corners else 0, cut if "bl" in corners else 0)
    rt, rb = right_cut if right_cut else (cut if "tr" in corners else 0, cut if "br" in corners else 0)
    # corner cuts measured from the (lowered) edge at that end
    sh_t = shoulder if (shoulder and "top" in shoulder_sides) else 0
    sh_b = shoulder if (shoulder and "bottom" in shoulder_sides) else 0
    if lt:
        m &= (x + (y - sh_t)) >= lt
    if rt:
        m &= ((w - 1 - x) + (y - sh_t)) >= rt
    if rb:
        m &= ((w - 1 - x) + (h - 1 - y - sh_b)) >= rb
    if lb:
        m &= (x + (h - 1 - y - sh_b)) >= lb
    return m


def slanted_mask(w, h, pad=0, left=True, right=True):
    """Parallelogram leaning like '/': each end moves one texel right every two rows up (the bars)."""
    y, x = np.mgrid[0:h, 0:w]
    x = x - pad
    y = y - pad
    w -= 2 * pad
    h -= 2 * pad
    span = (h - 1) // 2  # how far the top is right of the bottom
    up = (h - 1 - y) // 2  # 0 on the bottom row
    m = (x >= 0) & (y >= 0) & (x < w) & (y < h)
    if left:
        m &= x >= up
    if right:
        m &= x <= (w - 1) - (span - up)
    return m


def erode(m):
    e = m.copy()
    e[1:, :] &= m[:-1, :]
    e[:-1, :] &= m[1:, :]
    e[:, 1:] &= m[:, :-1]
    e[:, :-1] &= m[:, 1:]
    e[0, :] = False
    e[-1, :] = False
    e[:, 0] = False
    e[:, -1] = False
    return e


def depth(m, n=12):
    """Distance (4-neighbour steps) of every pixel of the mask from its edge: 0 = the outline."""
    d = np.full(m.shape, -1, int)
    cur = m.copy()
    for k in range(n):
        nxt = erode(cur)
        d[cur & ~nxt] = k
        cur = nxt
        if not cur.any():
            break
    d[cur] = n
    return d


def edge_dirs(d):
    """Outward direction (nx, ny) of every pixel: towards its 4-neighbours of a lower depth."""
    h, w = d.shape
    p = np.pad(d, 1, constant_values=-1)
    up = p[0:h, 1:w + 1] < d
    down = p[2:h + 2, 1:w + 1] < d
    left = p[1:h + 1, 0:w] < d
    right = p[1:h + 1, 2:w + 2] < d
    return right.astype(int) - left, down.astype(int) - up


def light_of(d):
    """'hi' / 'mid' / 'lo' of every pixel: which way its edge faces (light from the top)."""
    h, w = d.shape
    p = np.pad(d, 1, constant_values=-1)
    up = p[0:h, 1:w + 1] < d
    down = p[2:h + 2, 1:w + 1] < d
    left = p[1:h + 1, 0:w] < d
    right = p[1:h + 1, 2:w + 2] < d
    nx = right.astype(float) - left
    ny = down.astype(float) - up
    norm = np.hypot(nx, ny)
    norm[norm == 0] = 1
    s = (nx * LIGHT[0] + ny * LIGHT[1]) / norm
    out = np.full(d.shape, "mid", dtype=object)
    out[s > 0.4] = "hi"
    out[s < -0.4] = "lo"
    return out


class Img:
    def __init__(self, w, h):
        self.w = w
        self.h = h
        self.a = np.zeros((h, w, 4), np.uint8)

    def put(self, mask, color):
        self.a[mask] = color

    def frame(self, m, rings, fill, fill_from=None):
        """Rings of colours from the outline inwards (a colour or a shaded set), then the fill: a colour or a
        function (x, y) -> colour, from depth `fill_from` (default: after the rings)."""
        d = depth(m, 24)
        lit = light_of(d)
        for k, col in enumerate(rings):
            ring = (d == k)
            if col is None:
                continue
            if isinstance(col, dict):
                for key in ("hi", "mid", "lo"):
                    self.put(ring & (lit == key), col[key])
            else:
                self.put(ring, col)
        start = len(rings) if fill_from is None else fill_from
        inside = d >= start
        if fill is None:
            return d
        if callable(fill):
            ys, xs = np.nonzero(inside)
            for yy, xx in zip(ys, xs):
                self.a[yy, xx] = fill(xx, yy)
        else:
            self.put(inside, fill)
        return d

    def save(self, path):
        Image.fromarray(self.a, "RGBA").save(path)


def grid(base, line, period=GRID, phase=0):
    def f(x, y):
        return line if (x % period == phase or y % period == phase) else base
    return f


def bands(rows, h, pad=0, inset=0):
    """Fill by rows of the fill (`inset` = rings above it, `pad` = free room around the frame): rows = list of
    (count, colour): positive counts from the top down, negative counts from the bottom up (listed top to
    bottom), count 0 = the body between them."""
    top = [(n, col) for n, col in rows if n > 0]
    bottom = [(-n, col) for n, col in rows if n < 0]
    body = [col for n, col in rows if n == 0][0]
    inner = h - 2 * pad - 2 * inset

    def f(x, y):
        yy = y - pad - inset
        acc = 0
        for n, col in top:
            if yy < acc + n:
                return col
            acc += n
        acc = 0
        for n, col in reversed(bottom):
            if (inner - 1 - yy) < acc + n:
                return col
            acc += n
        return body
    return f


def brackets(img, x0, y0, x1, y1, color, hi, arm=7, width=2, cut=3):
    """Corner brackets (the selection cursor of the style) around the box x0..x1, y0..y1 (inclusive): an L
    at each corner, bent along a 45° cut, with a dark edge and a light inner pixel line."""
    a = img.a

    def setp(x, y, col):
        if 0 <= x < img.w and 0 <= y < img.h:
            a[y, x] = col
    for corner in range(4):
        sx = 1 if corner in (0, 3) else -1  # 0 tl, 1 tr, 2 br, 3 bl
        sy = 1 if corner in (0, 1) else -1
        ox = x0 if sx == 1 else x1
        oy = y0 if sy == 1 else y1
        # outline (dark) first, then the bracket
        shape = []
        for k in range(width):
            for t in range(cut + k, arm):  # along x
                shape.append((ox + sx * t, oy + sy * k))
            for t in range(cut + k, arm):  # along y
                shape.append((ox + sx * k, oy + sy * t))
            for t in range(cut + 1):  # the cut
                shape.append((ox + sx * (cut - t + k), oy + sy * (t + k)))
        border = set()
        for (px, py) in shape:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    border.add((px + dx, py + dy))
        for (px, py) in border - set(shape):
            if 0 <= px < img.w and 0 <= py < img.h and a[py, px, 3] == 0:
                setp(px, py, (30, 4, 2, 200))
        for (px, py) in shape:
            setp(px, py, color)
        # light pixels on the outer line
        for t in range(cut + 1, arm - 1):
            setp(ox + sx * t, oy, hi)
            setp(ox, oy + sy * t, hi)


# ------------------------------------------------------------------ the skin
SPEC = {}  # name -> {"size", "margin": [l, t, r, b], "axis": [h, v], "expand", "tint", "scale", "note"}
ART = 2  # texels per art pixel: the frames are drawn on a grid of 2x2 texels (chunky pixel art, like the kit)


def add(name, img, margin, axis=("stretch", "stretch"), expand=0, tint=False, note="", scale=ART):
    """Saves an image drawn in art pixels, enlarged `scale` times (NEAREST); margins / expand in art pixels."""
    im = Image.fromarray(img.a, "RGBA")
    if scale != 1:
        im = im.resize((img.w * scale, img.h * scale), Image.NEAREST)
    im.save(os.path.join(OUT, name + ".png"))
    SPEC[name] = {"size": [im.width, im.height], "margin": [m * scale for m in margin], "axis": list(axis),
                  "expand": expand * scale, "tint": tint, "scale": scale, "note": note}


def glint(img, d, length=4, color=c(255, 255, 255)):
    """White highlight of the style on the coloured line (depth 1): the top left cut, the start of the top edge
    and of the left edge."""
    nx, ny = edge_dirs(d)
    ring = d == 1
    h, w = d.shape
    y, x = np.mgrid[0:h, 0:w]
    top = ring & (ny < 0) & (nx == 0) & (y < h // 2)
    left = ring & (nx < 0) & (ny == 0) & (x < w // 2)
    diag = ring & (nx < 0) & (ny < 0)
    sel = diag.copy()
    if top.any():
        x0 = x[top].min()
        sel |= top & (x < x0 + length)
    if left.any():
        y0 = y[left].min()
        sel |= left & (y < y0 + max(1, length // 2))
    img.put(sel, color)


def frame(name, w, h, cut, rings, fill, margin, shoulder=0, shoulder_end=5, axis=("tile_fit", "tile_fit"),
          pad=0, expand=0, tint=False, note="", extra=None, shine=True, scale=ART, corners="tl tr br bl"):
    img = Img(w, h)
    m = box_mask(w, h, cut, corners=corners, shoulder=shoulder, shoulder_end=shoulder_end, pad=pad)
    d = img.frame(m, rings, fill)
    if shine and len(rings) > 1:
        glint(img, d)
    if extra:
        extra(img, m, d)
    add(name, img, margin, axis, expand, tint, note, scale)
    return img


def build():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".png"):
            os.remove(os.path.join(OUT, f))
    # dark fills with the fine grid of the kit (period 4 art pixels: every middle part is 4 or 8 wide, so the
    # tiled parts keep the grid)
    dark_grid = grid(c(19, 22, 28, 244), c(29, 33, 43, 244), 4)
    tip_grid = grid(c(21, 25, 32, 250), c(32, 37, 48, 250), 4)
    grey_grid = grid(c(24, 24, 27, 246), c(36, 36, 41, 246), 4)
    deep_grid = grid(c(13, 15, 20, 246), c(24, 27, 35, 246), 4)
    red_grid = grid(c(40, 15, 13, 246), c(56, 22, 18, 246), 4)

    # HUD panels: stage bar, player panel, game over, generic PanelContainer (32 x 22 art, middle 8 x 4)
    rings = [INK, SLATE_A, SLATE_DEEP]
    frame("panel", 32, 22, 4, rings, dark_grid, [12, 9, 12, 9], shoulder=1,
          note="HUD panels (stage bar, player panel...): slate line, stepped top / bottom, grid")

    def shop_accent(img, m, d):
        band = np.zeros(m.shape, bool)
        band[:m.shape[0] // 2, 12:20] = True  # the middle of the top edge only
        img.put(band & (d == 1), ORANGE_A["mid"])
        img.put(band & (d == 2), ORANGE_A["lo"])
    frame("panel_shop", 32, 22, 4, rings, dark_grid, [12, 9, 12, 9], shoulder=1, extra=shop_accent,
          note="shop bar: the panel with an orange top edge")
    frame("panel_tint", 32, 22, 4, [INK, WHITE_A, GREY_DEEP], grey_grid, [12, 9, 12, 9], shoulder=1, tint=True,
          note="unit panel: grey frame coloured by modulate (rarity)")
    frame("panel_plain", 16, 16, 3, rings, dark_grid, [6, 6, 6, 6],
          note="small HUD panels (DPS meter, shop dock)")
    frame("frame_tint", 16, 16, 3, [INK, WHITE_A, GREY_DEEP], grey_grid, [6, 6, 6, 6], tint=True,
          note="frame coloured by modulate (Battle Pass cards, buttons made in code)")
    frame("tip", 14, 14, 3, [INK, SLATE_BRIGHT, SLATE_DEEP], tip_grid, [5, 5, 5, 5], note="tooltip")
    frame("tip_pinned", 14, 14, 3, [INK, ORANGE_A, ORANGE_DEEP], tip_grid, [5, 5, 5, 5],
          note="pinned tooltip (orange)")
    frame("choice", 34, 24, 5, [INK, ORANGE_A, ORANGE_DEEP], deep_grid, [13, 10, 13, 10], shoulder=1,
          note="choice popups (orange)")

    # sell zone: red-brown grid, orange frame, red brackets around it (3 art pixels of room)
    sell = Img(24, 24)
    m = box_mask(24, 24, 4, pad=3)
    d = sell.frame(m, [INK, ORANGE_A, c(92, 32, 22)], red_grid)
    glint(sell, d)
    brackets(sell, 0, 0, 23, 23, BRACKET, BRACKET_HI, arm=6, width=1, cut=2)
    add("sell", sell, [10, 10, 10, 10], ("tile_fit", "tile_fit"), expand=3, note="drop zone to sell")

    # small boxes of the unit panel
    frame("box", 8, 8, 2, [c(42, 48, 62)], c(9, 11, 14, 244), [3, 3, 3, 3], axis=("stretch", "stretch"),
          note="inset boxes (unit panel)")
    frame("banner", 8, 8, 2, [c(30, 35, 46)], c(12, 14, 18, 255), [3, 3, 3, 3], axis=("stretch", "stretch"),
          note="behind the portrait of the unit panel")

    # item slots
    flat = ("stretch", "stretch")
    frame("item_slot", 12, 12, 2, [INK, SLATE_A], c(17, 20, 26, 238), [4, 4, 4, 4], axis=flat,
          note="item slot with an item")
    frame("item_slot_empty", 12, 12, 2, [c(16, 18, 23, 170), c(58, 64, 80, 200)], c(12, 14, 18, 120), [4, 4, 4, 4],
          axis=flat, shine=False, note="empty item slot")
    frame("unit_item_slot", 12, 12, 2, [INK, SLATE_B], c(8, 10, 13, 238), [4, 4, 4, 4], axis=flat,
          note="item slot of the unit panel")

    # shop cards (rarity tint), the pulsing synergy frame (tint)
    frame("card", 16, 16, 4, [INK, WHITE_A, GREY_B], c(8, 9, 11, 255), [6, 6, 6, 6], axis=flat, tint=True,
          note="shop card frame (rarity tint)")
    frame("card_empty", 16, 16, 4, [c(12, 14, 17, 220), c(42, 46, 55, 220)], c(12, 14, 17, 200), [6, 6, 6, 6],
          axis=flat, shine=False, note="empty shop slot")
    glow = Img(16, 16)
    d = depth(box_mask(16, 16, 4), 8)
    for k, a in enumerate((255, 200, 120, 55)):
        glow.put(d == k, c(255, 255, 255, a))
    add("glow", glow, [6, 6, 6, 6], tint=True, note="pulsing synergy frame of a shop card (tint)")

    # selection brackets: inside the box (hovered shop card: it clips), outside a button (keyboard focus)
    sel = Img(16, 16)
    brackets(sel, 0, 0, 15, 15, BRACKET, BRACKET_HI, arm=6, width=1, cut=2)
    add("select", sel, [6, 6, 6, 6], note="red corner brackets (hover / selection)")
    foc = Img(20, 20)
    brackets(foc, 0, 0, 19, 19, BRACKET, BRACKET_HI, arm=5, width=1, cut=2)
    add("focus", foc, [6, 6, 6, 6], expand=2, note="keyboard focus: brackets around the button")

    # buttons: 2 art pixels of room around for the brackets
    def button(name, rings, top, body, bottom, bracket=None, bracket_hi=None):
        img = Img(20, 20)
        m = box_mask(20, 20, 3, pad=2)
        d = img.frame(m, rings, bands([(1, top), (0, body), (-1, bottom)], 20, 2, len(rings)))
        glint(img, d, length=3)
        if bracket:
            brackets(img, 0, 0, 19, 19, bracket, bracket_hi, arm=5, width=1, cut=2)
        add(name, img, [6, 6, 6, 6], expand=2, note="button: " + name)
    button("button", [INK, SLATE_A, c(30, 36, 50)], c(56, 65, 86), c(36, 42, 56), c(24, 28, 37))
    button("button_hover", [INK, SLATE_BRIGHT, c(46, 54, 74)], c(84, 96, 126), c(52, 60, 80), c(32, 37, 49),
           BRACKET, BRACKET_HI)
    button("button_pressed", [INK, ORANGE_A, c(56, 36, 20)], c(18, 21, 28), c(24, 28, 36), c(30, 35, 45),
           BRACKET, BRACKET_HI)
    button("button_disabled", [c(10, 11, 14), DIM_A, c(24, 27, 32)], c(33, 36, 43), c(27, 30, 35), c(21, 23, 27))

    # fight button: red, cut corners, gold brackets on hover
    def fight(name, rings, top, body, bottom, bracket=None, bracket_hi=None):
        img = Img(24, 24)
        m = box_mask(24, 24, 5, pad=2)
        d = img.frame(m, rings, bands([(1, top[0]), (1, top[1]), (0, body), (-1, bottom[1]), (-1, bottom[0])],
                                      24, 2, len(rings)))
        glint(img, d, length=4, color=c(255, 236, 230))
        if bracket:
            brackets(img, 0, 0, 23, 23, bracket, bracket_hi, arm=6, width=1, cut=2)
        add(name, img, [9, 9, 9, 9], expand=2, note="fight button: " + name)
    fight("fight", [INK, RED_A, c(255, 150, 150, 110)], (c(244, 118, 118), c(226, 88, 94)), c(204, 62, 70),
          (c(128, 26, 36), c(160, 40, 50)))
    fight("fight_hover", [INK, shade((255, 222, 210), (255, 146, 146), (196, 64, 70)), c(255, 196, 186, 130)],
          (c(255, 146, 140), c(244, 108, 112)), c(226, 76, 84), (c(148, 32, 42), c(184, 50, 60)), BRACKET_GOLD,
          BRACKET_GOLD_HI)
    fight("fight_pressed", [INK, ORANGE_A, c(255, 150, 150, 80)], (c(148, 38, 46), c(160, 44, 52)), c(172, 48, 56),
          (c(198, 66, 72), c(186, 56, 62)), BRACKET_GOLD, BRACKET_GOLD_HI)

    # synergy rows (46 high = 23 art): dark bar, the right end leaning '/', a lime band along it when active
    def synergy_row(name, rings, fill, cap):
        w, h = 32, 23
        img = Img(w, h)
        m = slanted_mask(w, h, left=False)
        y, x = np.mgrid[0:h, 0:w]
        m &= (x + y) >= 2
        m &= (x + (h - 1 - y)) >= 2
        d = img.frame(m, rings, fill)
        if cap:
            span = (h - 1) // 2
            edge = (w - 1) - (span - (h - 1 - y) // 2)  # x of the right end on each row
            inside = d >= len(rings)
            img.put(inside & (x > edge - 6) & (x <= edge - 4), cap["lo"])
            img.put(inside & (x > edge - 4) & (x <= edge - 3), cap["mid"])
            img.put(inside & (x > edge - 3) & (x <= edge - 2), cap["hi"])
        add(name, img, [4, 0, 18, 0], ("stretch", "stretch"),
            note="synergy row, 46 high (the slanted end is drawn for that height)")
    synergy_row("synergy_row", [INK, SLATE_B], c(17, 20, 26, 234), LIME_A)
    synergy_row("synergy_row_off", [c(8, 9, 12, 200), c(40, 46, 60, 210)], c(12, 14, 18, 170), None)

    # compact chips (phones): upright, a lime band on the right when active
    def chip(name, rings, fill, cap):
        img = Img(12, 12)
        m = box_mask(12, 12, 2)
        d = img.frame(m, rings, fill)
        if cap:
            y, x = np.mgrid[0:12, 0:12]
            inside = d >= len(rings)
            img.put(inside & (x == 8), cap["mid"])
            img.put(inside & (x == 9), cap["hi"])
        add(name, img, [4, 4, 4, 4], note="synergy chip of the compact HUD")
    chip("synergy_chip", [INK, SLATE_B], c(17, 20, 26, 234), LIME_A)
    chip("synergy_chip_off", [c(8, 9, 12, 200), c(40, 46, 60, 210)], c(12, 14, 18, 170), None)
    frame("synergy_badge", 12, 12, 3, [INK, WHITE_A, GREY_B], c(44, 44, 46, 255), [4, 4, 4, 4], axis=flat,
          tint=True, note="synergy icon frame (tier tint)")

    # tags: slanted label behind a highlighted synergy of a shop card (tint), pointed chips (role, passive)
    tag = Img(14, 9)
    tag.frame(slanted_mask(14, 9), [c(255, 255, 255, 235)], c(255, 255, 255, 105))
    add("tag", tag, [5, 0, 5, 0], note="slanted synergy tag (tint), 18 high")
    pill = Img(15, 12)
    pill.frame(box_mask(15, 12, 0, left_cut=(6, 6), right_cut=(6, 6)), [WHITE_A], c(255, 255, 255, 52))
    add("chip", pill, [6, 0, 6, 0], tint=True, note="pointed chip (role, passive), 24 high (tint)")

    # bars: slanted ends, the margins hold them
    def bar(name, h, body, top=None, bottom=None, outline=None, scale=ART):
        lean = (h - 1) // 2
        w = 2 * (lean + 2) + 2
        img = Img(w, h)
        rows = []
        if top:
            rows.append((1, top))
        rows.append((0, body))
        if bottom:
            rows.append((-1, bottom))
        rings = [outline] if outline else []
        img.frame(slanted_mask(w, h), rings, bands(rows, h, 0, len(rings)))
        add(name, img, [lean + 2, 0, lean + 2, 0], ("stretch", "stretch"), note="bar %d high" % (h * scale),
            scale=scale)
    bar("bar_bg_8", 8, c(5, 7, 10, 210), outline=c(0, 0, 0, 235), scale=1)
    bar("bar_blue_8", 8, c(90, 164, 255), top=c(170, 210, 255), bottom=c(52, 110, 210), scale=1)
    bar("bar_orange_8", 8, c(246, 160, 56), top=c(255, 220, 140), bottom=c(196, 104, 26), scale=1)
    bar("bar_bg_16", 8, c(5, 7, 10, 210), outline=c(0, 0, 0, 235))
    bar("bar_bg_18", 9, c(5, 7, 10, 210), outline=c(0, 0, 0, 235))
    bar("bar_xp_16", 8, c(96, 182, 255), top=c(184, 226, 255), bottom=c(46, 112, 214))
    bar("bar_pp_16", 8, c(84, 150, 250), top=c(160, 204, 255), bottom=c(42, 92, 196))
    bar("bar_hp_18", 9, c(96, 214, 92), top=c(178, 246, 166), bottom=c(46, 150, 60))

    # small parts drawn by UnitOverlay above the Pokémon (they shrink with the cells): single texels
    bar("ubar_bg_9", 9, c(0, 0, 0, 200), outline=c(0, 0, 0, 230), scale=1)
    bar("ubar_bg_6", 6, c(0, 0, 0, 200), outline=c(0, 0, 0, 230), scale=1)
    bar("ubar_hp_7", 7, c(110, 222, 100), top=c(196, 250, 180), bottom=c(54, 156, 62), scale=1)
    bar("ubar_foe_7", 7, c(240, 90, 80), top=c(255, 176, 160), bottom=c(170, 40, 36), scale=1)
    bar("ubar_shield_7", 7, c(236, 238, 242), top=c(255, 255, 255), bottom=c(170, 176, 186), scale=1)
    bar("ubar_pp_4", 4, c(84, 150, 250), top=c(170, 210, 255), scale=1)
    frame("item_frame_small", 10, 10, 2, [INK, SLATE_B], c(5, 8, 10, 230), [3, 3, 3, 3], axis=flat, shine=False,
          scale=1, note="held item above a Pokémon")
    frame("count_badge", 10, 10, 2, [INK, GOLD_A], c(13, 13, 18, 236), [3, 3, 3, 3], axis=flat, shine=False,
          scale=1, note="'x2' badge of a bench slot")
    frame("portrait_cell", 12, 12, 3, [INK, WHITE_A], c(0, 0, 0, 130), [4, 4, 4, 4], axis=flat, tint=True,
          shine=False, scale=1, note="Pokémon cell of the synergy tooltip (rarity tint)")

    with open(os.path.join(OUT, "skin.json"), "w", encoding="utf-8", newline="\n") as f:
        json.dump({"_doc": "Pixel-art UI skin of pkmxtft, generated by tools/ui/gen_skin.py (own drawing after the "
                   "style of LostSoulsDev's V21.1 Essentials UI Redesign): do not edit the images by hand. "
                   "Margins / expand / size in texels (1 texel = 1 canvas unit).", "images": SPEC}, f, indent=1,
                  ensure_ascii=False)
        f.write("\n")


# ------------------------------------------------------------------ preview sheet
def nine_patch(src, w, h, margin):
    """Rough nine-patch stretch of a PIL image (preview only: middles stretched with NEAREST)."""
    l, t, r, b = margin
    sw, sh = src.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    xs = [(0, l, 0, l), (l, sw - r, l, w - r), (sw - r, sw, w - r, w)]
    ys = [(0, t, 0, t), (t, sh - b, t, h - b), (sh - b, sh, h - b, h)]
    for sx0, sx1, dx0, dx1 in xs:
        for sy0, sy1, dy0, dy1 in ys:
            if sx1 <= sx0 or sy1 <= sy0 or dx1 <= dx0 or dy1 <= dy0:
                continue
            part = src.crop((sx0, sy0, sx1, sy1)).resize((dx1 - dx0, dy1 - dy0), Image.NEAREST)
            out.alpha_composite(part, (dx0, dy0))
    return out


def sheet():
    zoom = 3
    bg = Image.new("RGBA", (1400, 1000), (52, 74, 48, 255))  # board-green behind, like the HUD
    d = ImageDraw.Draw(bg)
    for yy in range(0, 1000, 40):
        for xx in range(0, 1400, 40):
            if (xx // 40 + yy // 40) % 2:
                d.rectangle((xx, yy, xx + 39, yy + 39), fill=(60, 84, 54, 255))
    x, y = 10, 10
    row_h = 0
    for name, spec in SPEC.items():
        src = Image.open(os.path.join(OUT, name + ".png"))
        im = src.resize((src.width * zoom, src.height * zoom), Image.NEAREST)
        if x + im.width > 1390:
            x = 10
            y += row_h + 18
            row_h = 0
        bg.alpha_composite(im, (x, y + 14))
        d.text((x, y), name, fill=(255, 255, 200, 255))
        x += im.width + 14
        row_h = max(row_h, im.height + 14)
    # a few stretched examples at 2x
    y += row_h + 30
    examples = [("panel", 300, 70), ("panel_shop", 420, 90), ("tip", 220, 120), ("button", 160, 54),
                ("button_hover", 160, 54), ("button_pressed", 160, 54), ("fight", 170, 86),
                ("synergy_row", 220, 46), ("synergy_row_off", 220, 46), ("bar_bg_18", 200, 18), ("bar_hp_18", 140, 18)]
    x = 10
    for name, w, h in examples:
        spec = SPEC[name]
        src = Image.open(os.path.join(OUT, name + ".png"))
        e = spec["expand"]
        im = nine_patch(src, w + 2 * e, h + 2 * e, spec["margin"])
        im = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
        if x + im.width > 1390:
            x = 10
            y += 200
        bg.alpha_composite(im, (x, y))
        x += im.width + 16
    os.makedirs(os.path.dirname(SHEET), exist_ok=True)
    bg.save(SHEET)


if __name__ == "__main__":
    build()
    sheet()
    print("%d images -> %s" % (len(SPEC), OUT))
    print("preview -> %s" % SHEET)
