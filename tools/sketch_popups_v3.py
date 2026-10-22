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
    tx(d, (24, 1292), "角色界面改版 v3 · 讨论用", F_BOLD(15), GOLDHI)
    for i, s in enumerate(notes):
        tx(d, (24, 1318 + i * 22), s, F_BODY(12), (226, 218, 202))
    canvas.convert("RGB").save(os.path.join(R, ".shots", out_name))
    print("saved", out_name)

def switch_panel(canvas):
    d = ImageDraw.Draw(canvas)
    rr(d, (48, 250, 672, 990), 6, PAPER, GOLD, 2)
    tx(d, (78, 270), "切换角色", F_INK(34), SEAL)
    # 分类栏
    tabs = ["全部", "主角", "弟子", "同伴"]
    for i, t in enumerate(tabs):
        x = 78 + i * 144
        sel = i == 0
        rr(d, (x, 330, x + 132, 376), 4, (58, 47, 38) if sel else (238, 231, 212), GOLD if sel else (204, 192, 168), 2)
        tx(d, (x + 66, 353), t, F_BOLD(16), (243, 237, 222) if sel else INK2, "mm")
    cards = [("player_face.png", "少侠", "玄品", True), ("chen_shi_face.png", "陈石", "宇品", False), ("qingluan_face.png", "青鸾", "玄品", False)]
    for i, (fx, nm, grade, cur) in enumerate(cards):
        x = 78 + i * 186
        outline = SEAL if cur else (204, 192, 168)
        rr(d, (x, 410, x + 158, 700), 4, PAPER3, outline, 2)
        face_paste(canvas, fx, (x + 31, 432), 96)
        tx(d, (x + 79, 556), nm, F_BOLD(20), INK, "mm")
        rr(d, (x + 39, 586, x + 119, 622), 4, (62, 93, 58) if cur else (96, 90, 80))
        tx(d, (x + 79, 604), grade, F_BODY(15), (240, 245, 235), "mm")
        tx(d, (x + 79, 652), "当前" if cur else "点我换", F_BODY(14), SEAL if cur else GRAY, "mm")
    rr(d, (280, 900, 440, 946), 4, (58, 47, 38), GOLD)
    tx(d, (360, 923), "关　闭", F_BODY(16), (243, 237, 222), "mm")

def growth_panel(canvas):
    d = ImageDraw.Draw(canvas)
    rr(d, (64, 320, 656, 900), 6, PAPER, GOLD, 2)
    tx(d, (94, 340), "角色成长（暂定）", F_INK(28), SEAL)
    tx(d, (94, 384), "点品级打开 · 品级固定，不能升品", F_BODY(13), INK2)
    grades = ["宇", "黄", "玄", "地", "天"]
    for i, g in enumerate(grades):
        x = 118 + i * 114
        cur = g == "玄"
        d.ellipse((x, 430, x + 58, 488), fill=(62, 93, 58) if cur else (238, 231, 212), outline=GOLD if cur else (204, 192, 168), width=2)
        tx(d, (x + 29, 459), g, F_BOLD(21), (240, 245, 235) if cur else INK2, "mm")
        tx(d, (x + 29, 502), "品", F_BODY(11), GRAY, "mm")
    tx(d, (94, 552), "当前：玄品（主角 · 第三档）", F_BOLD(15), INK)
    tx(d, (94, 584), "Lv.1 / 25　　经验 0 / 40", F_BODY(14), INK2)
    rr(d, (94, 612, 626, 640), 8, (58, 49, 38))
    rr(d, (94, 612, 240, 640), 8, (98, 122, 74))
    tx(d, (94, 660), "升级：消耗经验池（不耗银两）", F_BODY(13), INK2)
    tx(d, (94, 690), "角色品级固定；主角可能在后续剧情进阶（再议）", F_BODY(13), SEAL)
    rr(d, (94, 742, 274, 794), 4, (58, 47, 38), GOLD)
    tx(d, (184, 768), "升　级", F_BOLD(17), (243, 237, 222), "mm")
    rr(d, (540, 742, 626, 794), 4, (58, 47, 38), GOLD)
    tx(d, (583, 768), "关 闭", F_BODY(14), (243, 237, 222), "mm")
    tx(d, (94, 822), "［暂定］这里还可以放：成长属性 / 等级奖励 / 剧情进阶入口", F_BODY(12), GRAY)

make(switch_panel, "char_switch_v3.png", [
    "切换角色：加了分类栏（全部 / 主角 / 弟子 / 同伴）；下面是仓库式头像格",
    "头像＋名字＋品级；当前红框；点一张换人；上阵仍留顶栏",
])
make(growth_panel, "char_growth_v3.png", [
    "点品级打开成长窗口：品级线（宇→黄→玄→地→天）+ 等级/经验 + 升级",
    "角色不能升品；去掉升品按钮；主角后续剧情进阶先留一句“再议”",
])
