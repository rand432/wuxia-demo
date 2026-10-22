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

base = Image.open(os.path.join(R, ".shots", "char_redesign_v2.png")).convert("RGBA").crop((0, 0, 720, 1280))

def rr(d, xy, rad, fill, outline=None, w=1):
    d.rounded_rectangle(xy, radius=rad, fill=fill, outline=outline, width=w)

def tx(d, xy, s, font, fill, anchor="la"):
    d.text(xy, s, font=font, fill=fill, anchor=anchor)

def face_paste(img, src, box, size):
    im = Image.open(os.path.join(R, "assets/char", src)).convert("RGBA")
    im = im.resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    img.paste(im, box, mask)

def make(panel_fn, out_name, notes):
    W, H = 720, 1400
    canvas = Image.new("RGBA", (W, H), (0, 0, 0, 255))
    dim = Image.new("RGBA", (720, 1280), (0, 0, 0, 150))
    comp = Image.alpha_composite(base, dim)
    canvas.paste(comp, (0, 0))
    panel_fn(canvas)
    d = ImageDraw.Draw(canvas)
    d.rectangle((0, 1280, W, H), fill=BG)
    tx(d, (24, 1292), "角色界面改版 v2 · 讨论用", F_BOLD(15), GOLDHI)
    for i, s in enumerate(notes):
        tx(d, (24, 1318 + i * 22), s, F_BODY(12), (226, 218, 202))
    canvas.convert("RGB").save(os.path.join(R, ".shots", out_name))
    print("saved", out_name)

def switch_panel(canvas):
    d = ImageDraw.Draw(canvas)
    rr(d, (56, 300, 664, 940), 6, PAPER, GOLD, 2)
    tx(d, (86, 322), "切换角色", F_INK(34), SEAL)
    tx(d, (86, 372), "点一张卡换人 · 仓库式头像格（带品级）", F_BODY(14), INK2)
    cards = [("player_face.png", "少侠", "黄品", True), ("chen_shi_face.png", "陈石", "宇品", False), ("qingluan_face.png", "青鸾", "玄品", False)]
    for i, (fx, nm, grade, cur) in enumerate(cards):
        x = 82 + i * 180
        outline = SEAL if cur else (204, 192, 168)
        rr(d, (x, 410, x + 150, 700), 4, PAPER3, outline, 2)
        face_paste(canvas, fx, (x + 27, 430), 96)
        tx(d, (x + 75, 552), nm, F_BOLD(20), INK, "mm")
        rr(d, (x + 35, 580, x + 115, 610), 4, (62, 93, 58) if cur else (96, 90, 80))
        tx(d, (x + 75, 595), grade, F_BODY(14), (240, 245, 235), "mm")
        if cur:
            tx(d, (x + 75, 640), "当前", F_BODY(13), SEAL, "mm")
        else:
            tx(d, (x + 75, 640), "点我换", F_BODY(13), GRAY, "mm")
    rr(d, (280, 860, 440, 900), 4, (58, 47, 38), GOLD)
    tx(d, (360, 880), "关　闭", F_BODY(15), (243, 237, 222), "mm")

def growth_panel(canvas):
    d = ImageDraw.Draw(canvas)
    rr(d, (64, 330, 656, 900), 6, PAPER, GOLD, 2)
    tx(d, (94, 350), "角色成长 [暂定]", F_INK(28), SEAL)
    tx(d, (94, 392), "点品级打开的窗口 · 内容等你定", F_BODY(13), INK2)
    grades = ["宇", "黄", "玄", "地", "天"]
    for i, g in enumerate(grades):
        x = 120 + i * 112
        cur = g == "黄"
        d.ellipse((x, 440, x + 56, 496), fill=(62, 93, 58) if cur else (238, 231, 212), outline=GOLD if cur else (204, 192, 168), width=2)
        tx(d, (x + 28, 468), g, F_BOLD(20), (240, 245, 235) if cur else INK2, "mm")
        tx(d, (x + 28, 510), "品", F_BODY(11), GRAY, "mm")
    tx(d, (94, 560), "当前：黄品（主角，倒数第二档）", F_BODY(14), INK)
    tx(d, (94, 592), "Lv.1 / 25　　经验 0 / 40", F_BODY(14), INK2)
    rr(d, (94, 620, 626, 644), 8, (58, 49, 38))
    rr(d, (94, 620, 240, 644), 8, (98, 122, 74))
    tx(d, (94, 664), "升级：消耗经验池（暂定：不耗银两）", F_BODY(13), INK2)
    tx(d, (94, 692), "品级提升条件 / 成长属性 / 下一档加成 —— 待定", F_BODY(13), SEAL)
    rr(d, (94, 740, 254, 784), 4, (58, 47, 38), GOLD)
    tx(d, (174, 762), "升　级", F_BODY(15), (243, 237, 222), "mm")
    rr(d, (286, 740, 446, 784), 4, (96, 90, 80))
    tx(d, (366, 762), "升　品", F_BODY(15), (236, 231, 220), "mm")
    tx(d, (94, 820), "［暂定］这里放什么由你定：品级线 / 经验 / 成长属性 / 突破材料 ……", F_BODY(12), GRAY)
    rr(d, (540, 744, 626, 780), 4, (58, 47, 38), GOLD)
    tx(d, (583, 762), "关 闭", F_BODY(13), (243, 237, 222), "mm")

make(switch_panel, "char_switch_popup.png", [
    "切换角色：仓库式头像格——头像＋名字＋品级；当前那张红框；点一张就换人",
    "上阵仍留顶栏；换人后整个面板（四栏/属性/武学/天赋）跟着刷新",
])
make(growth_panel, "char_growth_window.png", [
    "点品级开「角色成长窗口」[暂定]：品级线（宇→黄→玄→地→天）＋等级/经验＋升级",
    "窗口内容先留白：品级提升条件 / 成长属性 / 下一档加成，等你定；升级只花经验池",
])
