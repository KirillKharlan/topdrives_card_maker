"""Builds the frames of the "modern" template from the standard ones.

Run from the project root:  python3 tool/make_modern_frames.py

The modern look (seen on newer cards of the game): no stars, the tuning wrench
sits lower and is bigger, the bottom shading strip is gone (more room for the
photo), the stat panels fade in from fully transparent on the left, and the
class block is a plain colour block with a see-through chequered flag above it
(squares in the class colour, fading upwards) and no class letter.
Everything that is not listed here (title bar, logo block, country block, the
words under the numbers) is taken from the standard frame unchanged.
"""
import os
import numpy as np
from PIL import Image

FX = 2400 / 1338  # frames are 2400x1494, the card is 1338x828 units
FY = 1494 / 828
SRC = {'S': 'legendary', 'A': 'epic', 'B': 'ultra_rare', 'C': 'super_rare',
       'D': 'rare', 'E': 'uncommon', 'F': 'common'}
OUT = 'assets/frames/modern'
PANEL_RGB = np.array([50.0, 50.0, 50.0])   # neutral grey of the stat panels (measured on the new design)
# How solid the stat panels are from left to right: (x in card units, alpha). Measured on a card of the new
# design by comparing the panels with the clear photo seen in the gaps between them.
PANEL_ALPHA = [(1062, 0.0), (1100, 0.34), (1140, 0.56), (1166, 0.69), (1191, 0.78),
               (1216, 0.84), (1241, 0.87), (1290, 0.89), (1338, 0.90)]
# The chequered flag above the class block (measured): all horizontal edges are tilted by SHEAR (y = u + SHEAR * x),
# in the tilted coordinate u the squares are CHECK_PITCH tall, the first row starts at CHECK_U0, the solid block at
# CHECK_SOLID_U, and the colour fades in from clear to solid over u = CHECK_FADE (start, length).
SHEAR = 0.19
CHECK_U0 = 572.5
CHECK_PITCH = 26.5
CHECK_SOLID_U = CHECK_U0 + 4 * CHECK_PITCH   # = 678.5
CHECK_FADE = (562.0, 116.0)
CLASS_A_COLOUR = (147, 80, 255)               # the new design's purple (the standard frame's A is a bit redder)
TYRES_DX = -12        # units: the word "Tyres" under the photo ends at x=1034 like on the game's cards
TYRES_DY = 5          # and sits 5 units lower than in the standard frame
# Stat panels of the new design (card units) and how far the words baked into the standard panels move down.
NEW_PANELS = [(106, 285), (291, 468), (474, 651), (657, 828)]
WORD_GROUPS = [(99, 284, 3.8), (284, 466, 4.6), (466, 650, 5.6), (650, 757, 5.0), (757, 828, 6.3)]
# The title row is neutral grey on the new cards (the standard frame is warm brown). Colours measured
# on a card of the new design; transparency of every part is kept from the standard frame.
# (grey, alpha) of the four parts, measured against the clear photo in the gap under the row.
TITLE_LOGO = (58, 1.0)
TITLE_BAR = (47, 0.55)
TITLE_YEAR = (53, 0.95)
TITLE_COUNTRY = (53, 0.95)
TITLE_STD_ALPHA = (1.0, 191 / 255, 224 / 255, 1.0)   # what the standard frame has, to keep edges soft
COUNTRY_EDGE = (1209.5, -0.2082)   # slanted left edge of the country block: x = a + b * y


def px(x, y):
    return int(round(x * FX)), int(round(y * FY))


def region(x0, y0, x1, y1):
    xa, ya = px(x0, y0)
    xb, yb = px(x1, y1)
    return slice(ya, yb), slice(xa, xb)


def sprite(a, box, coverage):
    """Cuts a sprite out of the frame: (coverage 0..1 array, position in pixels)."""
    ys, xs = region(*box)
    cov = coverage(a[ys, xs])
    rows, cols = np.where(cov > 0.04)
    top, left = rows.min(), cols.min()          # trim the empty border around the sprite
    cov = cov[top:rows.max() + 1, left:cols.max() + 1]
    return cov, (xs.start + left, ys.start + top)


def put(out, cov, pos, rgb, opacity=1.0, scale=1.0, anchor=None):
    """Draws a coverage mask in one colour on out (RGBA float), source-over."""
    img = Image.fromarray((cov * 255).astype(np.uint8))
    if scale != 1.0:
        img = img.resize((max(1, round(img.width * scale)), max(1, round(img.height * scale))), Image.LANCZOS)
    cov = np.asarray(img).astype(float) / 255.0 * opacity
    x, y = anchor if anchor else pos
    h, w = cov.shape
    dst = out[y:y + h, x:x + w]
    da = dst[..., 3:4] / 255.0
    ca = cov[..., None]
    oa = ca + da * (1 - ca)
    rgb_new = np.where(oa > 0, (np.array(rgb) * ca + dst[..., :3] * da * (1 - ca)) / np.maximum(oa, 1e-6), 0)
    dst[..., :3] = rgb_new
    dst[..., 3:4] = oa * 255.0


def build(letter, name):
    a = np.array(Image.open(f'assets/frames/{name}.png').convert('RGBA')).astype(float)
    out = a.copy()
    cls = a[px(70, 480)[1], px(70, 480)[0], :3]          # class colour
    panel_bg = a[px(70, 700)[1], px(70, 700)[0], :3]     # brown RQ panel behind the logo

    # --- title row: recolour the four parts, keep their shapes and transparency ---
    ys_title = slice(0, px(0, 99.5)[1])
    xs_all = np.arange(a.shape[1]) / FX
    ys_all = np.arange(ys_title.stop) / FY
    edge = COUNTRY_EDGE[0] + COUNTRY_EDGE[1] * ys_all[:, None]
    X = np.broadcast_to(xs_all[None, :], (ys_title.stop, a.shape[1]))
    part = np.where(X < 141, 0, np.where(X < 1062, 1, np.where(X < edge, 2, 3)))
    for idx, ((grey, alpha), std) in enumerate(zip((TITLE_LOGO, TITLE_BAR, TITLE_YEAR, TITLE_COUNTRY), TITLE_STD_ALPHA)):
        sel = (part == idx) & (out[ys_title, :, 3] > 0)
        out[ys_title, :, :3][sel] = grey
        scaled = out[ys_title, :, 3] * (alpha / std)
        out[ys_title, :, 3] = np.where(sel, np.clip(scaled, 0, 255), out[ys_title, :, 3])

    # --- sprites to keep (cut before the areas are cleared) ---
    tyres_cov, tyres_pos = sprite(a, (945, 765, 1062, 822),
                                  lambda s: np.clip((s[..., :3].mean(axis=2) - 45) / 210, 0, 1) * (s[..., 3] > 100))
    wrench_cov, wrench_pos = sprite(a, (175, 685, 295, 722),
                                    lambda s: np.clip((s[..., :3].mean(axis=2) - 40) / 120, 0, 1) * (s[..., 3] > 60))
    d = cls - panel_bg

    def logo_cov(s):
        c = np.clip(((s[..., :3] - panel_bg) @ d) / (d @ d), 0, 1)
        return np.clip((c - 0.25) / 0.6, 0, 1)   # the panel's own shading is not part of the logo
    logo_cov_arr, logo_pos = sprite(a, (20, 762, 122, 812), logo_cov)

    # --- clear: class block + RQ panel, and the bottom strip with stars and wrench ---
    out[region(0, 430, 150, 828)] = 0
    out[region(141, 640, 1066, 828)] = 0

    # --- stat panels: fade in from the left; panels and words sit where the new design has them ---
    col = a[:, px(1200, 0)[0], 3]
    rows = np.where(col > 0)[0]
    rows = rows[rows >= px(0, 100)[1]]
    spans, start, prev = [], rows[0], rows[0]
    for r in rows[1:]:
        if r - prev > 1:
            spans.append((start, prev + 1))
            start = r
        prev = r
    spans.append((start, prev + 1))
    x0p, x1p = px(1060, 0)[0], px(1338, 0)[0]
    H = out.shape[0]
    # how much of a pixel is a "word" (TOP SPEED, DRIVE...), read out of the standard panels
    word_old = np.zeros((H, x1p - x0p))
    for ya, yb in spans:
        block = a[ya:yb, x0p:x1p]
        inside = block[..., 3] > 0
        grey = block[..., :3].mean(axis=2)
        base = np.median(grey[inside])                       # the panel's own brightness
        word_old[ya:yb] = np.clip((grey - base) / (255 - base), 0, 1) * inside
    word = np.zeros_like(word_old)
    for y0u, y1u, dy in WORD_GROUPS:                    # move every group of words to its new place
        ya, yb = px(0, y0u)[1], px(0, y1u)[1]
        shift = round(dy * FY)
        dst_b = min(H, yb + shift)
        word[ya + shift:dst_b] = np.maximum(word[ya + shift:dst_b], word_old[ya:ya + (dst_b - ya - shift)])
    out[px(0, 99)[1]:, x0p:x1p] = 0                     # the old panels go
    xs = np.arange(x0p, x1p)
    panel_alpha = np.interp(xs / FX, [p[0] for p in PANEL_ALPHA], [p[1] for p in PANEL_ALPHA])
    for u0, u1 in NEW_PANELS:
        ya, yb = px(0, u0)[1], px(0, u1)[1]
        pa = np.broadcast_to(panel_alpha, (yb - ya, x1p - x0p))
        c = word[ya:yb]
        oa = pa + c * (1 - pa)
        rgb = (PANEL_RGB * pa[..., None] * (1 - c[..., None]) + 255 * c[..., None]) / np.maximum(oa[..., None], 1e-6)
        out[ya:yb, x0p:x1p, :3] = np.where(oa[..., None] > 0, rgb, 0)
        out[ya:yb, x0p:x1p, 3] = oa * 255

    # --- new class block: solid colour and, above it, the tilted chequered flag that fades in ---
    if letter == 'A':
        cls = np.array(CLASS_A_COLOUR, dtype=float)
    ys_, xs_ = region(0, 520, 141, 828)
    yy = (np.arange(ys_.start, ys_.stop) / FY)[:, None]            # card units
    xx = (np.arange(xs_.start, xs_.stop) / FX)[None, :]
    u = yy - SHEAR * xx                                             # tilted coordinate
    col = np.clip((xx // (141 / 3)).astype(int), 0, 2)
    row = np.floor((u - CHECK_U0) / CHECK_PITCH).astype(int)
    # chequered: the outer columns are filled on even rows, the middle one on odd rows; row -1 is the faint square above
    filled = np.where(row == -1, col == 1, (col % 2 == 0) == (row % 2 == 0))
    fade = np.clip((u - CHECK_FADE[0]) / CHECK_FADE[1], 0, 1)
    alpha = np.where(u >= CHECK_SOLID_U, 1.0, np.where(filled, fade, 0.0))
    # soft edges: one pixel of anti-aliasing across the tilted edges
    edge_u = np.minimum((u - CHECK_U0) % CHECK_PITCH, CHECK_PITCH - (u - CHECK_U0) % CHECK_PITCH) * FY
    alpha = alpha * np.where(u >= CHECK_SOLID_U, np.clip((u - CHECK_SOLID_U) * FY + 0.5, 0, 1),
                             np.clip(edge_u + 0.5, 0, 1))
    blk = out[ys_, xs_]
    da = blk[..., 3:4] / 255.0
    al = alpha[..., None]
    oa = al + da * (1 - al)
    blk[..., :3] = (cls * al + blk[..., :3] * da * (1 - al)) / np.maximum(oa, 1e-6)
    blk[..., 3:4] = oa * 255

    # --- sprites back: dark RQ logo on the block, words under the photo, wrench ---
    put(out, logo_cov_arr, logo_pos, (40, 38, 42), scale=0.78, anchor=px(36, 799))
    put(out, tyres_cov, tyres_pos, (255, 255, 255), anchor=(tyres_pos[0] + round(TYRES_DX * FX), tyres_pos[1] + round(TYRES_DY * FY)))
    put(out, wrench_cov, wrench_pos, (255, 255, 255), opacity=0.45, scale=1.5, anchor=px(185, 750))

    # --- the rounded card corners: the standard frame paints them as opaque black pixels; every part above
    # (title row, class block, panels) was drawn over them, so they are copied back at the very end ---
    corner = 40
    H, W = out.shape[:2]
    for ys_c, xs_c in ((slice(0, corner), slice(0, corner)), (slice(0, corner), slice(W - corner, W)),
                       (slice(H - corner, H), slice(0, corner)), (slice(H - corner, H), slice(W - corner, W))):
        lum = a[ys_c, xs_c, :3].mean(axis=2)
        m = np.clip((30 - lum) / 30, 0, 1)[..., None]       # 1 on the black corner, soft on its edge
        out[ys_c, xs_c, :3] = out[ys_c, xs_c, :3] * (1 - m)
        out[ys_c, xs_c, 3:4] = out[ys_c, xs_c, 3:4] * (1 - m) + 255 * m

    os.makedirs(OUT, exist_ok=True)
    Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), 'RGBA').save(f'{OUT}/{letter}.png', optimize=True)


if __name__ == '__main__':
    for letter, name in SRC.items():
        build(letter, name)
        print('written', f'{OUT}/{letter}.png')
