#!/usr/bin/env python3
"""Draws the OneSource mark (maroon tile, nine-point serrated band, ring, gold dot) as app icon PNGs."""
import pathlib
from PIL import Image, ImageDraw

out = pathlib.Path(__file__).resolve().parent.parent / 'assets' / 'brand'
out.mkdir(parents=True, exist_ok=True)
S = 1024
k = S / 64


def gradient(size):
    img = Image.new('RGB', (size, size))
    a, b = (0xB0, 0x20, 0x4F), (0x5E, 0x0B, 0x26)
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))
    return img


def mark(draw, scale, ox=0, oy=0, ring=True):
    pts = [(ox, oy), (ox + 13 * scale, oy)]
    for i in range(10):
        y = i * 6.4 * scale
        pts += [(ox + 20 * scale, oy + y + 3.2 * scale), (ox + 13 * scale, oy + y + 6.4 * scale)]
    pts += [(ox, oy + 64 * scale)]
    draw.polygon(pts, fill='white')
    if ring:
        cx, cy, r, w = ox + 40 * scale, oy + 32 * scale, 11.5 * scale, 5 * scale
        draw.ellipse([cx - r - w / 2, cy - r - w / 2, cx + r + w / 2, cy + r + w / 2], fill='white')
        draw.ellipse([cx - r + w / 2, cy - r + w / 2, cx + r - w / 2, cy + r - w / 2], fill=None)
        inner = r - w / 2
        return cx, cy, inner
    return None


# full icon (iOS + legacy Android)
img = gradient(S)
d = ImageDraw.Draw(img)
cx, cy, inner = mark(d, k)
grad = gradient(S)
mask = Image.new('L', (S, S), 0)
ImageDraw.Draw(mask).ellipse([cx - inner, cy - inner, cx + inner, cy + inner], fill=255)
img.paste(grad, (0, 0), mask)
d = ImageDraw.Draw(img)
d.ellipse([cx - 3 * k, cy - 3 * k, cx + 3 * k, cy + 3 * k], fill=(0xE6, 0xCF, 0x8F))
img.save(out / 'icon.png')

# adaptive foreground: same artwork scaled into the 66% safe zone on transparency
fg = Image.new('RGBA', (S, S), (0, 0, 0, 0))
small = img.resize((int(S * .62), int(S * .62)), Image.LANCZOS)
rmask = Image.new('L', small.size, 0)
ImageDraw.Draw(rmask).rounded_rectangle([0, 0, small.size[0] - 1, small.size[1] - 1], radius=int(small.size[0] * .22), fill=255)
fg.paste(small, ((S - small.size[0]) // 2, (S - small.size[1]) // 2), rmask)
fg.save(out / 'icon_foreground.png')
print('icons written to', out)
