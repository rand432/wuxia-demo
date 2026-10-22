# -*- coding: utf-8 -*-
from PIL import Image, ImageDraw, ImageFont
import os

R = r"D:\1\wuxia-demo"
INK = (44, 39, 34); INK2 = (84, 75, 62); PAPER = (246, 241, 227); PAPER3 = (250, 246, 236)
GOLD = (176, 138, 62); GOLDHI = (206, 172, 102); SEAL = (140, 43, 36)
GRAY = (150, 143, 129); GREEN = (62, 93, 58); BG = (33, 27, 22)

def Fp(p, s): return ImageFont.truetype(p, s)
F_INK = lambda s: Fp(os.path.join(R, "fonts", "ink.ttf"), s)
F_BODY = lambda s: Fp(r"C:\Windows\Fonts\msyh.ttc", s)
F_BOLD = lambda s: Fp(r"C:\Windows\Fonts\msyhbd.ttc", s)

base = Image.open(os.path.join(R, ".shots", "char_redesign_v3.png")).convert("RGBA").crop((0, 0, 720, 1280))
canvas = Image.new("RGBA", (720, 1400), (0, 0, 0, 255))
dim = Image.new("RGBA", (720, 1280), (0, 0, 0, 150))
canvas.paste(Image.alpha_composite(base, dim), (0, 0))
d = ImageDraw.Draw(canvas)

def rr(xy, rad, fill, outline=None, w=1):
    d.rounded_rectangle(xy, radius=rad, fill=fill, outline=outline, width=w)

def tx(xy, s, font, fill, anchor="la"):
    d.text(xy, s, font=font, fill=fill, anchor=anchor)

def face_paste(src, box, size):
    im = Image.open(os.path.join(R, "assets/char", src)).convert("RGBA")
    im = im.resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    canvas.paste(im, box, mask)

rr((40, 250, 680, 990), 6, PAPER, GOLD, 2)
tx((70, 270), "切换角色", F_INK(34), SEAL)
tabs = ["全部", "已上阵", "未上阵"]
for i, t in enumerate(tabs):
    x = 70 + i * 198
    sel = i == 0
    rr((x, 330, x + 186, 378), 4, (58, 47, 38) if sel else (238, 231, 212), GOLD if sel else (204, 192, 168), 2)
    tx((x + 93, 354), t, F_BOLD(16), (243, 237, 222) if sel else INK2, "mm")

# 横向滑动的卡片条（5 张，第 4/5 张被裁在边上，示意可滑）
cards = [
    ("player_face.png", "少侠", "玄品", "已上阵", True),
    ("chen_shi_face.png", "陈石", "宇品", "未上阵", False),
    ("qingluan_face.png", "青鸾", "黄品", "未上阵", False),
    (None, "？？", "？？", "未解锁", False),
    (None, "？？", "？？", "未解锁", False),
]
for i, (fx, nm, grade, status, cur) in enumerate(cards):
    x = 60 + i * 176
    if x > 640:
        break
    outline = SEAL if cur else (204, 192, 168)
    rr((x, 410, x + 156, 700), 4, PAPER3, outline, 2)
    if fx:
        face_paste(fx, (x + 30, 432), 96)
    else:
        d.ellipse((x + 30, 432, x + 126, 528), fill=(220, 213, 197))
        tx((x + 78, 480), "？", F_INK(40), GRAY, "mm")
    tx((x + 78, 556), nm, F_BOLD(20), INK, "mm")
    rr((x + 38, 586, x + 118, 622), 4, (62, 93, 58) if cur else (96, 90, 80))
    tx((x + 78, 604), grade, F_BODY(15), (240, 245, 235), "mm")
    tx((x + 78, 652), status, F_BODY(14), SEAL if cur else GRAY, "mm")
    if not fx:
        tx((x + 78, 672), "后续角色", F_BODY(11), (180, 172, 156), "mm")

tx((360, 724), "◀　　左右滑动查看全部角色　　▶", F_BODY(15), INK2, "mm")
rr((280, 890, 440, 940), 4, (58, 47, 38), GOLD)
tx((360, 915), "关　闭", F_BODY(16), (243, 237, 222), "mm")

d.rectangle((0, 1280, 720, 1400), fill=BG)
tx((24, 1292), "切换角色 v5 · 讨论用", F_BOLD(15), GOLDHI)
notes = [
    "分类栏：全部 / 已上阵 / 未上阵；卡片上标“已上阵/未上阵”",
    "卡片条触屏左右滑动（横向 ScrollContainer + drag_scroll），角色多了也放得下",
    "主角已改玄品；青鸾黄品；陈石宇品；后面没解锁的显示“？？”",
]
for i, s in enumerate(notes):
    tx((24, 1318 + i * 22), s, F_BODY(12), (226, 218, 202))

canvas.convert("RGB").save(os.path.join(R, ".shots", "char_switch_v5.png"))
print("saved char_switch_v5.png")
