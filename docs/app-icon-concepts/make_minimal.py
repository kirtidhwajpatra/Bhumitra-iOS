"""Minimal MyBhoomi app-icon concepts — one mark, one ground, nothing else."""
from PIL import Image, ImageDraw, ImageFilter
import math, os

OUT = os.path.dirname(os.path.abspath(__file__))
S = 4096
K = S / 1024


def u(v): return v * K
def pts(p): return [(u(x), u(y)) for x, y in p]
def hexc(h):
    h = h.lstrip("#"); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))


def ground(top, bottom):
    g = Image.new("RGB", (1, S))
    for y in range(S):
        t = y / (S - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bottom[i]-top[i])*t) for i in range(3)))
    return g.resize((S, S)).convert("RGBA")


def overlay(base, fn, blur=0):
    l = Image.new("RGBA", base.size, (0, 0, 0, 0))
    fn(ImageDraw.Draw(l))
    if blur: l = l.filter(ImageFilter.GaussianBlur(u(blur)))
    base.alpha_composite(l)


def thick(d, p, color, w, close=True):
    q = pts(p) + ([pts(p)[0]] if close else [])
    d.line(q, fill=color, width=int(u(w)), joint="curve")
    for x, y in pts(p):
        r = u(w)/2; d.ellipse([x-r, y-r, x+r, y+r], fill=color)


def finish(img, name):
    img.convert("RGB").resize((1024, 1024), Image.LANCZOS).save(os.path.join(OUT, name))
    return os.path.join(OUT, name)


PURPLE = (hexc("#7A1FFF"), hexc("#5B12F0"))
WHITE = (255, 255, 255, 255)

# A calm, near-regular parcel — reads as "a plot of land" instantly.
PLOT = [(360, 320), (664, 356), (704, 664), (400, 704), (320, 500)]


def a_outline():
    """Just the parcel outline, thick and white, dead center. Nothing else."""
    img = ground(*PURPLE)
    overlay(img, lambda d: thick(d, PLOT, WHITE, 34))
    return finish(img, "min-A-outline.png")


def b_solid():
    """Solid white parcel, a single notch of ground cut into one edge."""
    img = ground(*PURPLE)
    overlay(img, lambda d: d.polygon(pts([(x, y+22) for x, y in PLOT]), fill=(20, 0, 60, 130)), blur=22)
    overlay(img, lambda d: d.polygon(pts(PLOT), fill=WHITE))
    return finish(img, "min-B-solid.png")


def c_pin_parcel():
    """A location pin whose body is a tiny parcel — map + land, one glyph."""
    img = ground(*PURPLE)
    # pin teardrop
    cx, cy, r = 512, 452, 210
    def pin(d):
        d.ellipse([u(cx-r), u(cy-r), u(cx+r), u(cy+r)], fill=WHITE)
        d.polygon(pts([(cx-150, cy+120), (cx+150, cy+120), (cx, cy+340)]), fill=WHITE)
    overlay(img, lambda d: (d.polygon(pts([(cx-150, cy+140), (cx+150, cy+140), (cx, cy+362)]), fill=(20,0,60,120)),), blur=20)
    overlay(img, pin)
    # parcel cut into the pin head
    P = [(x*0.34 + cx*0.66, y*0.34 + (cy-30)*0.66) for x, y in PLOT]
    overlay(img, lambda d: thick(d, P, PURPLE[1] + (255,), 24))
    return finish(img, "min-C-pin-parcel.png")


def d_monogram():
    """The initial ব (Bhoomi/Bhumitra) — but land apps read better as a mark,
    so: a white square 'plot' with one corner folded, like a land deed."""
    img = ground(*PURPLE)
    x0, y0, s = 300, 300, 424
    fold = 150
    body = [(x0, y0), (x0+s-fold, y0), (x0+s, y0+fold), (x0+s, y0+s), (x0, y0+s)]
    overlay(img, lambda d: d.polygon(pts([(x, y+20) for x, y in body]), fill=(20,0,60,120)), blur=20)
    overlay(img, lambda d: d.polygon(pts(body), fill=WHITE))
    overlay(img, lambda d: d.polygon(pts([(x0+s-fold, y0), (x0+s-fold, y0+fold), (x0+s, y0+fold)]), fill=hexc("#D9C4FF")+(255,)))
    # a single parcel line + check on the deed
    overlay(img, lambda d: thick(d, [(x0+70, y0+150), (x0+s-90, y0+150)], PURPLE[1]+(255,), 20, close=False))
    def chk(d):
        cx, cy, sc, w = 512, 560, 150, 30
        p = [(cx-0.42*sc, cy+0.02*sc), (cx-0.12*sc, cy+0.32*sc), (cx+0.45*sc, cy-0.30*sc)]
        q = pts(p); d.line(q, fill=hexc("#16A34A")+(255,), width=int(u(w)), joint="curve")
        for x, y in (q[0], q[-1]):
            r=u(w)/2; d.ellipse([x-r,y-r,x+r,y+r], fill=hexc("#16A34A")+(255,))
    overlay(img, chk)
    return finish(img, "min-D-deed.png")


def sheet(paths):
    W, H = len(paths)*400+60, 540
    sh = Image.new("RGB", (W, H), (242, 242, 247))
    for i, p in enumerate(paths):
        x0 = 30 + i*400
        for size, (ox, oy) in ((340, (x0+20, 24)), (110, (x0+20, 390)), (56, (x0+160, 420)), (40, (x0+250, 434))):
            ic = Image.open(p).resize((size, size), Image.LANCZOS)
            m = Image.new("L", (size*4, size*4), 0)
            ImageDraw.Draw(m).rounded_rectangle([0,0,size*4-1,size*4-1], radius=int(size*4*0.2237), fill=255)
            sh.paste(ic, (ox, oy), m.resize((size, size), Image.LANCZOS))
    out = os.path.join(OUT, "min-concepts-sheet.png"); sh.save(out); return out


if __name__ == "__main__":
    print(sheet([a_outline(), b_solid(), c_pin_parcel(), d_monogram()]))
