"""Gera as capas da Steam Workshop (1024 x 1024): assets/capa.jpg (pt) e assets/cover_en.jpg (en).

Uso: python tools/gerar_capa.py [pt|en]   (precisa de pillow, numpy e lupa)
A placa é desenhada a partir do layout real de Oficina.lua. As miniaturas da fila são exemplos gerados aqui.
"""
import sys
from pathlib import Path

import lupa
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
LANG = sys.argv[1] if len(sys.argv) > 1 else "pt"
SIZE = 1024
FONTS = Path("C:/Windows/Fonts")
INNER_W, INNER_D, RIM = 7.0, 9.5, 0.4


def font(name, size):
    try:
        return ImageFont.truetype(str(FONTS / name), size)
    except OSError:
        return ImageFont.load_default()


def noise(rng, h, w, cy, cx):
    small = (rng.random((cy, cx)) * 255).astype(np.uint8)
    return np.asarray(Image.fromarray(small).resize((w, h), Image.BICUBIC), np.float32) / 255


# ---------------------------------------------------------------- miniaturas de exemplo
def token_art(kind, size=240):
    """Ilustrações simples para a fila: um token de goblin e um baú."""
    im = Image.new("RGB", (size, size), (40, 44, 52))
    d = ImageDraw.Draw(im)
    if kind == "goblin":
        d.ellipse([16, 16, size - 16, size - 16], fill=(186, 150, 84), outline=(110, 80, 34), width=10)
        d.ellipse([46, 46, size - 46, size - 46], fill=(92, 140, 70))
        d.polygon([(60, 100), (20, 70), (74, 86)], fill=(92, 140, 70))
        d.polygon([(size - 60, 100), (size - 20, 70), (size - 74, 86)], fill=(92, 140, 70))
        d.ellipse([88, 96, 108, 116], fill=(250, 220, 60)); d.ellipse([132, 96, 152, 116], fill=(250, 220, 60))
        d.arc([90, 120, 150, 170], 20, 160, fill=(40, 30, 20), width=5)
    else:
        d.rectangle([40, 96, size - 40, 196], fill=(120, 74, 38), outline=(70, 40, 18), width=6)
        d.pieslice([40, 50, size - 40, 142], 180, 360, fill=(138, 86, 44), outline=(70, 40, 18), width=6)
        d.rectangle([108, 112, 132, 140], fill=(214, 170, 64), outline=(120, 90, 30), width=3)
        for x in (70, size - 82):
            d.rectangle([x, 60, x + 12, 196], fill=(190, 150, 60))
    return im


# ---------------------------------------------------------------- placa a partir do layout real
def board_image(px=100):
    L = lupa.LuaRuntime()
    L.execute('''BTNS = {}; DECALS = {}
    self = { getScale=function() return {x=1,y=1,z=1} end, getCustomObject=function() return {mesh="m"} end,
      createButton=function(t) table.insert(BTNS,t) end, clearButtons=function() BTNS={} end,
      setDecals=function(d) DECALS=d end }''')
    L.execute((ROOT / "Oficina.lua").read_text(encoding="utf-8"))
    if LANG == "pt":
        q = '{ {name="Goblin arqueiro", pname="Ana", kind="token", url="a"}, {name="Baú do tesouro", pname="Bruno", kind="model", url="b"} }'
    else:
        q = '{ {name="Goblin archer", pname="Anna", kind="token", url="a"}, {name="Treasure chest", pname="Ben", kind="model", url="b"} }'
    L.execute(f'D.lang = "{LANG}"; D.approval = true; D.queue = {q}; build()')

    tex = Image.open(ROOT / "assets" / "oficina.png").convert("RGB")
    t = tex.width
    leather = tex.crop((int(0.02 * t), int(0.02 * t), int(0.48 * t), int(0.48 * t)))
    wood = tex.crop((int(0.02 * t), int(0.52 * t), int(0.48 * t), int(0.98 * t)))
    brass = tex.crop((int(0.52 * t), int(0.02 * t), int(0.98 * t), int(0.48 * t)))
    W, H = int((INNER_W + 2 * RIM) * px), int((INNER_D + 2 * RIM) * px)
    img = wood.resize((W, H))
    img.paste(leather.resize((int(INNER_W * px), int(INNER_D * px))), (int(RIM * px), int(RIM * px)))
    c = int(0.62 * px)
    for x in (0, W - c):
        for y in (0, H - c):
            img.paste(brass.resize((c, c)), (x, y))
    img.paste(brass.resize((int(2.4 * px), int(0.3 * px))), (W // 2 - int(1.2 * px), int(0.05 * px)))
    d = ImageDraw.Draw(img)

    def to_px(x, z_local):
        return (x + INNER_W / 2 + RIM) * px, (INNER_D / 2 + RIM + z_local) * px

    def col(cv):
        return tuple(int(cv[i] * 255) for i in (1, 2, 3))

    arts = ["goblin", "chest"]
    for k, dc in enumerate(L.eval("DECALS").values()):
        cx, cy = to_px(-dc.position[1], dc.position[3])  # decals têm o x espelhado
        w, h = dc.scale[1] * px, dc.scale[2] * px
        img.paste(token_art(arts[k % 2]).resize((int(w), int(h))), (int(cx - w / 2), int(cy - h / 2)))

    for b in L.eval("BTNS").values():
        cx, cy = to_px(b.position[1], b.position[3])
        w, h = (b.width or 0) / 450 * px, (b.height or 0) / 450 * px
        if w > 0:
            d.rounded_rectangle([cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2], 6, fill=col(b.color))
        fs = max(9, int(b.font_size / 450 * px * 0.92))
        f = font("arialbd.ttf", fs)
        tw = d.textlength(b.label, font=f)
        d.text((cx - tw / 2, cy - fs * 0.62), b.label, fill=col(b.font_color), font=f)
    return img


# ---------------------------------------------------------------- fundo e composição
def background():
    rng = np.random.default_rng(3)
    base = np.array([28, 64, 52], np.float32)  # pano verde, para diferenciar da capa do Atlas
    n = noise(rng, SIZE, SIZE, 300, 300) * 0.22 + noise(rng, SIZE, SIZE, 40, 40) * 0.12 + noise(rng, SIZE, SIZE, 6, 6) * 0.1
    img = base * (0.82 + n)[..., None]
    y, x = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32) / SIZE
    img *= np.clip(1 - 0.8 * ((x - 0.5) ** 2 + (y - 0.58) ** 2), 0.35, 1)[..., None]
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))


def perspective_coeffs(src, dst):
    m = []
    for (x, y), (u, v) in zip(dst, src):
        m.append([x, y, 1, 0, 0, 0, -u * x, -u * y])
        m.append([0, 0, 0, x, y, 1, -v * x, -v * y])
    return np.linalg.solve(np.array(m, np.float64), np.array(src, np.float64).reshape(8)).tolist()


def main():
    canvas = background()
    board = board_image()
    bw, bh = board.size
    dst = [(300, 262), (724, 262), (870, 1000), (154, 1000)]
    coeffs = perspective_coeffs([(0, 0), (bw, 0), (bw, bh), (0, bh)], dst)
    warped = board.convert("RGBA").transform((SIZE, SIZE), Image.PERSPECTIVE, coeffs, Image.BICUBIC)
    shadow = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(shadow).polygon([(p[0] + 16, p[1] + 22) for p in dst], fill=180)
    canvas.paste((8, 18, 14), (0, 0), shadow.filter(ImageFilter.GaussianBlur(22)))
    canvas.paste(warped, (0, 0), warped)

    d = ImageDraw.Draw(canvas)
    title = "Oficina de Peças" if LANG == "pt" else "Piece Workshop"
    sub = "Tokens  ·  Cartas  ·  Figuras  ·  Modelos 3D" if LANG == "pt" else "Tokens  ·  Cards  ·  Standees  ·  3D models"
    ft = font("georgiab.ttf", 96)
    fs = font("georgia.ttf", 36)
    tw = d.textlength(title, font=ft)
    d.text(((SIZE - tw) / 2, 50), title, font=ft, fill=(242, 205, 120), stroke_width=5, stroke_fill=(12, 26, 20))
    sw = d.textlength(sub, font=fs)
    d.text(((SIZE - sw) / 2, 168), sub, font=fs, fill=(234, 230, 210), stroke_width=3, stroke_fill=(12, 26, 20))

    out = ROOT / "assets" / ("capa.jpg" if LANG == "pt" else "cover_en.jpg")
    canvas.convert("RGB").save(out, quality=90, optimize=True)
    print(out, out.stat().st_size // 1024, "KB")


if __name__ == "__main__":
    main()
