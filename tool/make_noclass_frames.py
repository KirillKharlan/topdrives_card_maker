"""Builds the "no class chosen" frame of each template.

A new card has no class yet, and the class-coloured badge at the bottom left of the frame
(with the class letter in the standard template) must not show then. This takes the B frame
and removes that badge; the grey base panel under it stays, and the other class colours
(the RQ mark, the stars) are turned neutral.

Run from the project root:  python3 tool/make_noclass_frames.py
Writes assets/frames/none.png and assets/frames/modern/none.png (templates register them
under the frame key "none").
"""
import json
import numpy as np
from PIL import Image

CLASSES = ['S', 'A', 'B', 'C', 'D', 'E', 'F']


def load(path):
    return np.asarray(Image.open(path).convert('RGBA')).astype(int)


def class_dependent(paths):
    stack = np.stack([load(p) for p in paths])
    return (stack.max(0) - stack.min(0)).max(axis=2) > 12


def is_base(px):
    """The brown-grey base panel under the badge of the standard frame."""
    r, g, b, a = px
    return a > 250 and 85 <= r <= 125 and r >= g - 2 and g >= b - 2 and (r - b) <= 30


def standard(frames, out):
    """Standard frames: banner with the letter, a darker strip, then the grey base panel."""
    img = load(frames['B'])
    h, w = img.shape[:2]
    s = w / 1338
    mask = class_dependent(list(frames.values()))
    removed = np.zeros((h, w), bool)
    x_end, y_from, y_to = int(148 * s), int(400 * s), int(700 * s)  # banner is ~141 units wide
    run = 8
    last_cut = None
    for x in range(x_end):
        y = y_from
        while y < y_to and img[y, x, 3] == 0:
            y += 1  # first painted pixel of the badge
        top = y
        while y < y_to:
            if all(is_base(img[y + k, x]) for k in range(run)):
                break
            y += 1
        if y < y_to:
            last_cut = y
            removed[top:y, x] = True
        elif last_cut is not None and top < last_cut:
            # The edge column of the panel is half transparent, so no base colour is found
            # in it: cut it where the column next to it was cut.
            removed[top:last_cut, x] = True
    # a pixel of anti-aliasing next to the cut
    removed = removed | (np.roll(removed, -1, axis=0) & mask)
    out_img = img.copy()
    out_img[removed, 3] = 0
    # Other class colours (RQ mark, stars): neutral.
    rest = mask & ~removed & (img[..., 3] > 0)
    rest[:int(700 * s)] = False
    ys, xs = np.where(rest)
    for y, x in zip(ys, xs):
        if x < int(148 * s):
            if x > int(18 * s):  # the rounded card corner at the very left stays as it is
                out_img[y, x, :3] = (232, 232, 236)
        else:
            lum = int(0.3 * img[y, x, 0] + 0.59 * img[y, x, 1] + 0.11 * img[y, x, 2])
            out_img[y, x, :3] = (lum, lum, lum)
    Image.fromarray(np.clip(out_img, 0, 255).astype(np.uint8), 'RGBA').save(out, optimize=True)
    print('written', out, 'removed px', int(removed.sum()))


def modern(frames, out):
    """Modern frames: a chequered flag and a solid block in the class colour; only the dark RQ mark stays."""
    img = load(frames['B'])
    h, w = img.shape[:2]
    s = w / 1338
    out_img = img.copy()
    x_end, y_from = int(142 * s), int(540 * s)
    region = np.zeros((h, w), bool)
    region[y_from:, :x_end] = True
    painted = img[..., 3] > 0
    r, g, b = img[..., 0], img[..., 1], img[..., 2]
    dark = (np.maximum(np.maximum(r, g), b) < 100) & ((np.maximum(np.maximum(r, g), b) - np.minimum(np.minimum(r, g), b)) < 40)
    removed = region & painted & ~dark
    out_img[removed, 3] = 0
    Image.fromarray(np.clip(out_img, 0, 255).astype(np.uint8), 'RGBA').save(out, optimize=True)
    print('written', out, 'removed px', int(removed.sum()))


if __name__ == '__main__':
    std = json.load(open('assets/templates/standard.json'))['frames']
    standard({k: v for k, v in std.items()}, 'assets/frames/none.png')
    mod = json.load(open('assets/templates/modern.json'))['frames']
    modern({k: v for k, v in mod.items()}, 'assets/frames/modern/none.png')
