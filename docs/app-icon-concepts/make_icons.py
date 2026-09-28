"""Render MyBhoomi app-icon concepts at 1024px (drawn at 4x, downsampled)."""
from PIL import Image, ImageDraw, ImageFilter
import math, os

OUT = os.path.dirname(os.path.abspath(__file__))
S = 4096          # supersampled canvas
K = S / 1024      # design units are 1024-based


def u(v):
    return v * K


def pts(p):
    return [(u(x), u(y)) for x, y in p]


def vgradient(top, bottom, size=S):
    g = Image.new("RGB", (1, size))
    for y in range(size):
        t = y / (size - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
    return g.resize((size, size))


def rgradient(inner, outer, cx, cy, r, size=S):
    img = Image.new("RGB", (size, size), outer)
    d = ImageDraw.Draw(img)
    steps = 180
    for i in range(steps, 0, -1):
        t = i / steps
        c = tuple(int(inner[k] + (outer[k] - inner[k]) * t) for k in range(3))
        rr = u(r) * t
        d.ellipse([u(cx) - rr, u(cy) - rr, u(cx) + rr, u(cy) + rr], fill=c)
    return img.filter(ImageFilter.GaussianBlur(u(6)))


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def overlay(base, draw_fn, blur=0, alpha=255):
    layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer))
    if blur:
        layer = layer.filter(ImageFilter.GaussianBlur(u(blur)))
    if alpha < 255:
        a = layer.split()[3].point(lambda v: v * alpha // 255)
        layer.putalpha(a)
    base.alpha_composite(layer)


def thick_poly(d, p, color, w):
    q = pts(p) + [pts(p)[0]]
    d.line(q, fill=color, width=int(u(w)), joint="curve")
    for x, y in pts(p):
        r = u(w) / 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=color)


def check(d, cx, cy, s, color, w):
    p = [(cx - 0.42 * s, cy + 0.02 * s), (cx - 0.12 * s, cy + 0.32 * s), (cx + 0.45 * s, cy - 0.30 * s)]
    q = pts(p)
    d.line(q, fill=color, width=int(u(w)), joint="curve")
    for x, y in (q[0], q[-1]):
        r = u(w) / 2
        d.ellipse([x - r, y - r, x + r, y + r], fill=color)


def finish(img, name):
    out = img.convert("RGB").resize((1024, 1024), Image.LANCZOS)
    path = os.path.join(OUT, name)
    out.save(path)
    return path


# A real-looking cadastral plot: irregular, not a perfect shape.
PARCEL = [(290, 322), (668, 286), (752, 596), (486, 772), (262, 566)]

# Neighbouring parcel boundaries (the "map" context), clipped by the canvas.
NEIGHBOURS = [
    [(-40, 346), (290, 322), (668, 286), (1080, 250)],
    [(668, 286), (630, -40)],
    [(290, 322), (230, -40)],
    [(752, 596), (1080, 640)],
    [(486, 772), (560, 1080)],
    [(262, 566), (-40, 600)],
    [(262, 566), (180, 1080)],
    [(752, 596), (900, 1080)],
]


# ---------------------------------------------------------------- Concept A
def concept_a():
    """Verified Parcel — deep brand indigo, white plot, green verified seal."""
    img = vgradient(hexc("#5B12F0"), hexc("#1A0766")).convert("RGBA")
    glow = rgradient(hexc("#7A3BFF"), hexc("#1A0766"), 470, 380, 620).convert("RGBA")
    glow.putalpha(110)
    img.alpha_composite(glow)

    def lines(d):
        for ln in NEIGHBOURS:
            d.line(pts(ln), fill=(255, 255, 255, 46), width=int(u(7)), joint="curve")
    overlay(img, lines)

    # soft shadow under plot
    overlay(img, lambda d: d.polygon(pts([(x + 6, y + 26) for x, y in PARCEL]), fill=(10, 0, 40, 150)), blur=26)
    # plot fill + crisp boundary
    overlay(img, lambda d: d.polygon(pts(PARCEL), fill=(255, 255, 255, 255)))
    overlay(img, lambda d: d.polygon(pts([(x, y) for x, y in PARCEL]), fill=None), alpha=255)
    # subtle survey hatch inside plot for texture
    def hatch(d):
        for i in range(-6, 12):
            x0 = 200 + i * 56
            d.line(pts([(x0, 800), (x0 + 420, 200)]), fill=(118, 0, 255, 18), width=int(u(5)))
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).polygon(pts(PARCEL), fill=255)
    h = Image.new("RGBA", img.size, (0, 0, 0, 0))
    hatch(ImageDraw.Draw(h))
    h.putalpha(Image.composite(h.split()[3], Image.new("L", img.size, 0), mask))
    img.alpha_composite(h)
    # boundary pegs (survey corner markers)
    def pegs(d):
        for x, y in PARCEL:
            r = u(22)
            d.ellipse([u(x) - r, u(y) - r, u(x) + r, u(y) + r], fill=(255, 255, 255, 255))
            r = u(12)
            d.ellipse([u(x) - r, u(y) - r, u(x) + r, u(y) + r], fill=hexc("#5B12F0") + (255,))
    overlay(img, pegs)

    # verified seal
    cx, cy, r = 716, 716, 150
    overlay(img, lambda d: d.ellipse([u(cx - r), u(cy - r + 18), u(cx + r), u(cy + r + 18)], fill=(10, 0, 40, 160)), blur=22)
    overlay(img, lambda d: d.ellipse([u(cx - r), u(cy - r), u(cx + r), u(cy + r)], fill=(255, 255, 255, 255)))
    rr = r - 20
    seal = rgradient(hexc("#22C55E"), hexc("#15803D"), cx - 30, cy - 40, rr + 60).convert("RGBA")
    m = Image.new("L", img.size, 0)
    ImageDraw.Draw(m).ellipse([u(cx - rr), u(cy - rr), u(cx + rr), u(cy + rr)], fill=255)
    seal.putalpha(m)
    img.alpha_composite(seal)
    overlay(img, lambda d: check(d, cx, cy, 150, (255, 255, 255, 255), 30))
    return finish(img, "concept-A-verified-parcel.png")


# ---------------------------------------------------------------- Concept B
def concept_b():
    """Official Seal — navy + gold, like a government registry stamp."""
    img = vgradient(hexc("#16235C"), hexc("#070D2B")).convert("RGBA")
    glow = rgradient(hexc("#24367E"), hexc("#070D2B"), 512, 430, 600).convert("RGBA")
    glow.putalpha(120)
    img.alpha_composite(glow)
    gold, gold_dim = hexc("#F2C75C"), hexc("#B8892B")
    cx = cy = 512

    def rings(d):
        R = 372
        d.ellipse([u(cx - R), u(cy - R), u(cx + R), u(cy + R)], outline=gold + (255,), width=int(u(34)))
        R2 = 318
        d.ellipse([u(cx - R2), u(cy - R2), u(cx + R2), u(cy + R2)], outline=gold_dim + (255,), width=int(u(6)))
        for i in range(72):  # engraved rim ticks
            a = 2 * math.pi * i / 72
            r1, r2 = 330, 346
            d.line([(u(cx + r1 * math.cos(a)), u(cy + r1 * math.sin(a))),
                    (u(cx + r2 * math.cos(a)), u(cy + r2 * math.sin(a)))],
                   fill=gold_dim + (255,), width=int(u(5)))
    overlay(img, rings)

    P = [(x * 0.74 + 512 * 0.26 + 4, y * 0.74 + 512 * 0.26 - 6) for x, y in PARCEL]
    overlay(img, lambda d: d.polygon(pts(P), fill=gold + (48,)))
    overlay(img, lambda d: thick_poly(d, P, gold + (255,), 22))
    def pegs(d):
        for x, y in P:
            r = u(13)
            d.ellipse([u(x) - r, u(y) - r, u(x) + r, u(y) + r], fill=gold + (255,))
    overlay(img, pegs)
    overlay(img, lambda d: check(d, 512, 522, 190, gold + (255,), 34))
    return finish(img, "concept-B-official-seal.png")


# ---------------------------------------------------------------- Concept C
def concept_c():
    """Trust Shield — brand purple, white shield holding the plot outline."""
    img = vgradient(hexc("#7C1BFF"), hexc("#3A00A8")).convert("RGBA")
    glow = rgradient(hexc("#9B55FF"), hexc("#3A00A8"), 420, 300, 620).convert("RGBA")
    glow.putalpha(90)
    img.alpha_composite(glow)

    def shield_path(scale=1.0, dy=0):
        # Heraldic shield: slightly arched top, straight sides, curved taper to a point.
        L, R, top, mid, tip = 206, 818, 196, 520, 872
        p = []
        for i in range(41):
            t = i / 40
            p.append((L + (R - L) * t, top + 22 - 22 * math.sin(math.pi * t) * -1 * 0 + 30 * (2 * t - 1) ** 2 - 30))
        p.append((R, mid))
        for i in range(1, 41):  # right curve to tip (quadratic bezier)
            t = i / 40
            c = (R, 760)
            x = (1 - t) ** 2 * R + 2 * (1 - t) * t * c[0] + t * t * 512
            y = (1 - t) ** 2 * mid + 2 * (1 - t) * t * c[1] + t * t * tip
            p.append((x, y))
        for i in range(1, 41):  # left curve back up
            t = i / 40
            c = (L, 760)
            x = (1 - t) ** 2 * 512 + 2 * (1 - t) * t * c[0] + t * t * L
            y = (1 - t) ** 2 * tip + 2 * (1 - t) * t * c[1] + t * t * mid
            p.append((x, y))
        return [(x, y + dy) for x, y in p]

    overlay(img, lambda d: d.polygon(pts(shield_path(1.0, 24)), fill=(20, 0, 60, 150)), blur=26)
    overlay(img, lambda d: d.polygon(pts(shield_path(1.0)), fill=(255, 255, 255, 255)))
    P = [(x * 0.62 + 512 * 0.38, y * 0.62 + 512 * 0.38 - 4) for x, y in PARCEL]
    overlay(img, lambda d: d.polygon(pts(P), fill=hexc("#7600FF") + (30,)))
    overlay(img, lambda d: thick_poly(d, P, hexc("#6A00F0") + (255,), 18))
    overlay(img, lambda d: check(d, 512, 512, 150, hexc("#16A34A") + (255,), 28))
    return finish(img, "concept-C-trust-shield.png")


def contact_sheet(paths):
    """Each concept at App Store size and at home-screen size, iOS-masked."""
    W, H = 3 * 420 + 80, 560
    sheet = Image.new("RGB", (W, H), (242, 242, 247))
    d = ImageDraw.Draw(sheet)
    for i, p in enumerate(paths):
        x0 = 40 + i * 420
        for size, (ox, oy) in ((360, (x0 + 20, 30)), (120, (x0 + 20, 410)), (60, (x0 + 170, 440)), (40, (x0 + 260, 450))):
            ic = Image.open(p).resize((size, size), Image.LANCZOS)
            m = Image.new("L", (size * 4, size * 4), 0)
            ImageDraw.Draw(m).rounded_rectangle([0, 0, size * 4 - 1, size * 4 - 1], radius=int(size * 4 * 0.2237), fill=255)
            m = m.resize((size, size), Image.LANCZOS)
            sheet.paste(ic, (ox, oy), m)
    out = os.path.join(OUT, "concepts-sheet.png")
    sheet.save(out)
    return out


if __name__ == "__main__":
    ps = [concept_a(), concept_b(), concept_c()]
    print(contact_sheet(ps))
