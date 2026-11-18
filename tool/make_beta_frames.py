"""Builds the frames of the "beta" template (the look of the game's beta test) at 2400x1494.

The source was five small pictures (597x372) of the empty card, one per class colour.
Everything in them is flat colour, so the frame is redrawn here from measured rectangles
at full size (sharp edges, sharp labels in Roboto Condensed) instead of being enlarged.
All numbers below are in the 597x372 grid of those pictures.

Run from the project root:  python3 tool/make_beta_frames.py [path/to/small/green/frame.png]
The optional argument is one of the small frames; its wrench icon is copied (the wrench
is the only thing that is not redrawn from numbers). Writes assets/frames/beta/*.png.
"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont

OUT_W, OUT_H = 2400, 1494
SS = 2  # supersampling for smooth edges
GRID_W, GRID_H = 595.0, 372.0  # the card spans x 1..596 and y 0..372 of the small picture


def X(gx):
    return (gx - 1.0) * OUT_W / GRID_W


def Y(gy):
    return gy * OUT_H / GRID_H


CLASS_COLORS = {
    'S': (241, 187, 21),   # yellow
    'A': (92, 82, 158),    # purple
    'B': (58, 191, 240),   # blue
    'C': (124, 190, 102),  # green
    'D': (133, 131, 132),  # grey
}
PANEL = (49, 49, 49, 229)
TILE = (92, 93, 85, 252)
LABEL = (55, 55, 54, 252)
FONT = 'assets/fonts/RobotoCondensed-Regular.ttf'

# value tile top/bottom and label strip top/bottom (grid rows)
ROWS = [(49, 98, 99, 123), (129, 178, 179, 202), (208, 257, 258, 282), (288, 336, 337, 362)]
LABELS = [('TOP SPEED', 533.5, 116.6), ('0-60MPH', 533.5, 196.4), ('WEIGHT', 533.5, 276.1)]
SPLIT_LABELS = [('WD', 503.0, 355.4), ('GRIP', 562.5, 355.4)]


def poly(draw, pts, fill):
    draw.polygon([(X(x) * SS, Y(y) * SS) for x, y in pts], fill=fill)


def rect(draw, x0, y0, x1, y1, fill):
    poly(draw, [(x0, y0), (x1, y0), (x1, y1), (x0, y1)], fill)


def layer():
    img = Image.new('RGBA', (OUT_W * SS, OUT_H * SS), (0, 0, 0, 0))
    return img, ImageDraw.Draw(img)


def wrench_mask(small_path):
    """Soft 0..1 mask of the wrench icon, from a small frame (badge colour vs. lighter icon)."""
    a = np.asarray(Image.open(small_path).convert('RGBA')).astype(float)
    x0, x1, y0, y1 = 6, 58, 341, 361
    crop = a[y0:y1, x0:x1, :3]
    base = np.median(crop.reshape(-1, 3), axis=0)
    diff = (crop - base).sum(axis=2)
    mask = np.clip(diff / max(diff.max(), 1), 0, 1)
    img = Image.fromarray((mask * 255).astype(np.uint8))
    w = int(round((x1 - x0) * OUT_W / GRID_W))
    h = int(round((y1 - y0) * OUT_H / GRID_H))
    img = img.resize((w, h), Image.BICUBIC)
    m = np.asarray(img).astype(float) / 255
    m = np.clip((m - 0.2) / 0.5, 0, 1)  # sharpen the soft edge
    return m, (int(round(X(x0))), int(round(Y(y0))))


def cap_height_size(target_px):
    font = ImageFont.truetype(FONT, 100)
    box = font.getbbox('H')
    return 100 * target_px / (box[3] - box[1])


def build(color, out, wrench, neutral=False):
    base_rgb = (49, 49, 49) if neutral else color
    badge_alpha = 229 if neutral else 255

    bg, d = layer()
    rect(d, 470, 45, 596, 372, PANEL)                      # right panel
    rect(d, 1, 0, 63, 44.5, (23, 24, 19, 229))             # logo tile
    rect(d, 63, 0, 471, 44.5, (49, 50, 44, 229))           # title bar
    poly(d, [(471, 0), (536.4, 0), (528, 44.5), (471, 44.5)], (46, 46, 42, 235))   # year
    poly(d, [(536.4, 0), (596, 0), (596, 44.5), (528, 44.5)], (58, 57, 58, 229))   # country
    for v0, v1, l0, l1 in ROWS[:3]:
        rect(d, 477, v0, 590, v1, TILE)
        rect(d, 477, l0, 590, l1, LABEL)
    v0, v1, l0, l1 = ROWS[3]
    for x0, x1 in ((477, 529), (536, 589)):
        rect(d, x0, v0, x1, v1, TILE)
        rect(d, x0, l0, x1, l1, LABEL)
    poly(d, [(1, 277.6), (63, 290), (63, 372), (1, 372)], base_rgb + (badge_alpha,))  # class badge
    img = bg.resize((OUT_W, OUT_H), Image.LANCZOS)

    if wrench is not None:
        m, (wx, wy) = wrench
        icon = np.zeros(m.shape + (4,), np.uint8)
        icon[..., :3] = 255
        icon[..., 3] = (m * 0.24 * 255).astype(np.uint8)
        img.alpha_composite(Image.fromarray(icon, 'RGBA'), (wx, wy))

    # labels (white, Roboto Condensed Regular), 12.6 grid px tall capitals
    size = cap_height_size(12.6 * OUT_H / GRID_H)
    font = ImageFont.truetype(FONT, size)
    txt = ImageDraw.Draw(img)
    for text, cx, base in LABELS + SPLIT_LABELS:
        w = txt.textlength(text, font=font)
        txt.text((X(cx) - w / 2, Y(base)), text, font=font, fill=(242, 242, 242, 255), anchor='ls')
    img.save(out, optimize=True)
    print('written', out)


if __name__ == '__main__':
    small = sys.argv[1] if len(sys.argv) > 1 else None
    wrench = wrench_mask(small) if small else None
    for key, color in CLASS_COLORS.items():
        build(color, f'assets/frames/beta/{key}.png', wrench)
    build((49, 49, 49), 'assets/frames/beta/none.png', wrench, neutral=True)
