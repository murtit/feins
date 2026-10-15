import math, random, sys, os
from PIL import Image, ImageDraw, ImageFilter

S = 4  # supersampling
def jitter_path(points, amp, rng):
    out = []
    n = len(points)
    phase = rng.random()*10
    for i,(x,y) in enumerate(points):
        t = i/max(1,n-1)
        dx = amp*(math.sin(t*7.3+phase)*0.6 + rng.uniform(-0.25,0.25))
        dy = amp*(math.cos(t*5.1+phase*1.3)*0.6 + rng.uniform(-0.25,0.25))
        out.append((x+dx, y+dy))
    return out

def stroke(draw, pts, width, color, rng, passes=2, amp=6):
    for p in range(passes):
        jp = jitter_path(pts, amp*(1 if p==0 else 1.4), rng)
        w = width*(1 if p==0 else 0.55)
        for i in range(len(jp)-1):
            # taper ends a bit
            t = i/len(jp)
            taper = 0.75+0.25*math.sin(math.pi*t)
            draw.line([jp[i], jp[i+1]], fill=color, width=max(1,int(w*taper)))
            r = w*taper/2
            draw.ellipse([jp[i][0]-r, jp[i][1]-r, jp[i][0]+r, jp[i][1]+r], fill=color)

def arc(cx, cy, rx, ry, a0, a1, n=160, wobble=0.0, rng=None):
    pts = []
    for i in range(n+1):
        a = math.radians(a0 + (a1-a0)*i/n)
        r = 1 + (wobble*math.sin(a*3+1.7) if wobble else 0)
        pts.append((cx + rx*r*math.cos(a), cy + ry*r*math.sin(a)))
    return pts

def tongue_outline(cx, top, w, h, n=120):
    # U-shape hanging from the mouth
    pts = []
    for i in range(n+1):
        a = math.pi*i/n  # 0..pi
        x = cx + (w/2)*math.cos(a)
        y = top + h*math.sin(a)**0.9
        pts.append((x,y))
    return pts

def render(size, bg, ink, tongue_col, layers="all", seed=7):
    rng = random.Random(seed)
    W = size*S
    img = Image.new("RGBA", (W,W), bg)
    d = ImageDraw.Draw(img)
    u = W/1024
    lw = 34*u
    cx, cy = 512*u, 500*u
    # tongue fill (drawn first so strokes sit on top)
    t_cx, t_top, t_w, t_h = 598*u, 628*u, 168*u, 160*u
    if layers in ("all","tongue"):
        poly = tongue_outline(t_cx, t_top, t_w, t_h)
        d.polygon(poly, fill=tongue_col)
        # soft highlight
        hl = Image.new("RGBA",(W,W),(0,0,0,0))
        hd = ImageDraw.Draw(hl)
        hd.ellipse([t_cx-40*u, t_top+30*u, t_cx-5*u, t_top+70*u], fill=(255,255,255,70))
        hl = hl.filter(ImageFilter.GaussianBlur(10*u))
        img.alpha_composite(hl)
    if layers in ("all","lines"):
        # face
        stroke(d, arc(cx, cy, 330*u, 322*u, -96, 268, wobble=0.018), lw, ink, rng, amp=5*u)
        # winking left eye  (like ";")
        stroke(d, arc(390*u, 430*u, 62*u, 34*u, 200, 340), lw*0.95, ink, rng, amp=3*u)
        # right eye: dot
        for p in range(2):
            ox, oy = rng.uniform(-4,4)*u, rng.uniform(-4,4)*u
            d.ellipse([630*u-30*u+ox, 395*u-40*u+oy, 630*u+30*u+ox, 395*u+40*u+oy], fill=ink)
        # mouth: big grin
        stroke(d, arc(512*u, 520*u, 205*u, 125*u, 18, 162, wobble=0.01), lw, ink, rng, amp=4*u)
        # tongue outline + middle line
        stroke(d, tongue_outline(t_cx, t_top, t_w, t_h), lw*0.85, ink, rng, amp=3*u)
        stroke(d, [(t_cx+rng.uniform(-1,1)*u, t_top + 15*u + i*2.0*u) for i in range(40)], lw*0.6, ink, rng, passes=1, amp=2*u)
    return img.resize((size,size), Image.LANCZOS)

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
paper=(246,239,227,255); ink=(30,27,24,255); pap=(217,71,43,255)
dark=(24,21,19,255); cream=(243,238,230,255); pap_d=(238,102,70,255)
render(1024, paper, ink, pap).convert("RGB").save(f"{out}/AppIcon.png")
render(1024, dark, cream, pap_d).convert("RGB").save(f"{out}/AppIcon-Dark.png")
t = render(1024, (0,0,0,255), (235,235,235,255), (150,150,150,255)).convert("L")
t.save(f"{out}/AppIcon-Tinted.png")
for scale in (1,2,3):
    render(120*scale, (0,0,0,0), (0,0,0,255), pap, layers="lines").save(f"{out}/Smiley@{scale}x.png")
    render(120*scale, (0,0,0,0), ink, pap, layers="tongue").save(f"{out}/SmileyTongue@{scale}x.png")
