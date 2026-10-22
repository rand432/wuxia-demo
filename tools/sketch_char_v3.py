# -*- coding: utf-8 -*-
from PIL import Image, ImageDraw, ImageFont
import os

R = r"D:\1\wuxia-demo"
W, H = 720, 1430
OUT = os.path.join(R, ".shots", "char_redesign_v3.png")

INK = (44, 39, 34); INK2 = (84, 75, 62); PAPER = (246, 241, 227); PAPER2 = (238, 231, 212)
PAPER3 = (250, 246, 236); GOLD = (176, 138, 62); GOLDHI = (206, 172, 102)
SEAL = (140, 43, 36); GRAY = (150, 143, 129); GREEN = (62, 93, 58); BG = (43, 36, 29)

def Fp(p, s): return ImageFont.truetype(p, s)
F_INK = lambda s: Fp(os.path.join(R, "fonts", "ink.ttf"), s)
F_BODY = lambda s: Fp(r"C:\Windows\Fonts\msyh.ttc", s)
F_BOLD = lambda s: Fp(r"C:\Windows\Fonts\msyhbd.ttc", s)

img = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(img)

def rr(xy, rad, fill, outline=None, w=1):
    d.rounded_rectangle(xy, radius=rad, fill=fill, outline=outline, width=w)

def tx(xy, s, font, fill, anchor="la"):
    d.text(xy, s, font=font, fill=fill, anchor=anchor)

def circle_paste(src, box, size):
    im = Image.open(os.path.join(R, "assets/char", src)).convert("RGBA")
    im = im.resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, size - 1, size - 1), fill=255)
    img.paste(im, box, mask)

def stat_icon(name, xy, size=26):
    p = os.path.join(R, "assets/ui/stats", name + ".png")
    if os.path.exists(p):
        im = Image.open(p).convert("RGBA").resize((size, size), Image.LANCZOS)
        img.paste(im, xy, im)

rr((16, 10, 704, 1264), 6, (56, 47, 37))
rr((24, 18, 696, 1256), 4, PAPER, GOLD, 2)

# 顶栏：字更大、按钮 44~48 高
tx((44, 18), "角色", F_INK(42), SEAL)
rr((150, 18, 300, 62), 4, (58, 47, 38), GOLD)
tx((225, 40), "上阵", F_BODY(17), (240, 232, 214), "mm")
rr((420, 18, 688, 62), 4, (58, 47, 38), GOLD)
tx((554, 40), "切换角色", F_BODY(17), (240, 232, 214), "mm")

# 头部
circle_paste("player_face.png", (42, 90), 96)
d.ellipse((40, 88, 140, 188), outline=GOLD, width=2)
tx((158, 84), "少侠", F_INK(40), INK)
tx((246, 94), "★6", F_BOLD(18), GOLD)
tx((158, 136), "主角 · 江湖新客 · 1/25 级", F_BODY(15), INK2)
rr((158, 158, 302, 206), 4, (62, 93, 58), None)
tx((230, 182), "品级 玄品", F_BOLD(17), (240, 245, 235), "mm")
rr((314, 158, 424, 206), 4, (58, 47, 38), GOLD)
tx((369, 182), "升级", F_BOLD(17), (243, 237, 222), "mm")
rr((158, 212, 676, 240), 8, (58, 49, 38), None)
rr((158, 212, 420, 240), 8, (98, 122, 74), None)
tx((417, 226), "经验 0/40", F_BODY(12), (243, 238, 224), "rm")

# 纸娃娃
rr((30, 252, 690, 814), 4, PAPER2, GOLD, 2)
rr((40, 264, 176, 298), 3, (58, 47, 38), GOLD)
tx((108, 281), "攻击属性 物理", F_BODY(14), (243, 237, 222), "mm")
rr((522, 262, 680, 300), 3, (58, 47, 38), GOLD)
tx((601, 281), "升星 0/6", F_BODY(15), (243, 237, 222), "mm")
full = Image.open(os.path.join(R, "assets/char", "player_full.png")).convert("RGBA")
fw = 200; fh = int(full.height * fw / full.width)
full = full.resize((fw, fh), Image.LANCZOS)
img.paste(full, (350 - fw // 2, 838 - fh), full)

def slot(x0, y0, title, name, line, empty=False):
    rr((x0, y0, x0 + 202, y0 + 104), 3, PAPER3, GOLD if not empty else (204, 192, 168), 2)
    tx((x0 + 10, y0 + 6), title, F_BOLD(14), GOLD)
    tx((x0 + 10, y0 + 28), name, F_BODY(16), INK if not empty else GRAY)
    tx((x0 + 10, y0 + 60), line, F_BODY(13), SEAL if not empty else GRAY)
    if empty:
        tx((x0 + 10, y0 + 82), "点格 → 查看 / 换装", F_BODY(11), (168, 160, 144))

slot(38, 308, "武器", "寻常的·普通·铁剑 +11", "攻 +18 · 伤 +2")
slot(480, 308, "护甲", "寻常的·凡品·战甲 +1", "气血 +31")
slot(38, 702, "玉佩", "—  未装备", "暴击 +3% · 爆伤 +10%", True)
slot(480, 702, "鞋子", "—  未装备", "速度 +2", True)
tx((360, 796), "四栏围着角色：武器 ↖ / 护甲 ↗ / 玉佩 ↙ / 鞋子 ↘", F_BODY(12), (146, 138, 122), "mm")

# 属性
tx((36, 824), "属性 · 基础＋额外", F_BOLD(20), INK)
rr((544, 814, 686, 854), 4, (58, 47, 38), GOLD)
tx((615, 834), "详细属性", F_BODY(15), (243, 237, 222), "mm")
stats = [("atk", "攻击", "23"), ("hp", "气血", "144"), ("speed", "速度", "9"),
         ("crit", "暴击", "8%"), ("crit_dmg", "爆伤", "50%"), ("def", "防御", "10")]
for i, (ic, lb, v) in enumerate(stats):
    col = i % 3; row = i // 3
    x = 34 + col * 218; y = 862 + row * 50
    rr((x, y, x + 206, y + 42), 3, PAPER3, (208, 197, 176), 1)
    stat_icon(ic, (x + 8, y + 8), 26)
    tx((x + 40, y + 22), lb, F_BODY(14), INK2, "lm")
    tx((x + 196, y + 22), v, F_BOLD(18), INK, "rm")

# 武学：两格
tx((36, 970), "武学", F_BOLD(20), INK)
tx((102, 976), "功法固定 · 绝学共用", F_BODY(13), (150, 143, 129))
rr((34, 998, 342, 1090), 3, PAPER3, (208, 197, 176), 1)
tx((44, 1006), "功法", F_BODY(13), GOLD)
tx((44, 1028), "落日剑法", F_BOLD(22), INK)
tx((44, 1062), "固定 · 无品阶 · 150% · 20 秒", F_BODY(12), INK2)
rr((350, 998, 676, 1090), 3, PAPER3, (208, 197, 176), 1)
tx((360, 1006), "绝学", F_BODY(13), GOLD)
tx((360, 1028), "落日剑诀", F_BOLD(22), INK)
tx((360, 1062), "绝品 · 共用 · 200% ×4", F_BODY(12), SEAL)

# 天赋 / 服药
rr((34, 1100, 420, 1200), 3, PAPER3, (208, 197, 176), 1)
tx((44, 1104), "天赋", F_BOLD(16), INK)
tx((44, 1128), "赤子之心 · 天生神力", F_BODY(12), INK2)
tx((44, 1150), "剑心通明 · 明察秋毫", F_BODY(12), INK2)
tx((44, 1172), "【被动】引气归元：怒气 +30%", F_BODY(11), SEAL)
rr((436, 1100, 686, 1150), 3, (58, 47, 38), GOLD)
tx((561, 1125), "服药 · 包裹", F_BODY(15), (243, 237, 222), "mm")
tx((561, 1172), "包裹空（点开药包）", F_BODY(12), (150, 143, 129), "mm")

rr((280, 1208, 440, 1252), 3, (58, 47, 38), GOLD)
tx((360, 1230), "关　闭", F_BODY(16), (243, 237, 222), "mm")

for x, y, n in [(30, 252, "1"), (30, 818, "2"), (30, 966, "3"), (310, 154, "4"), (416, 14, "5")]:
    d.ellipse((x, y, x + 26, y + 26), fill=SEAL)
    tx((x + 13, y + 13), n, F_BOLD(15), (255, 245, 235), "mm")

notes = [
    "1  四栏围着立绘；空栏写“攻伤 / 气血 / 暴击爆伤 / 速度”；升星保留",
    "2  属性 6 格 +［详细属性］；按钮放大（详细属性 40 高）",
    "3  武学两格：功法×1（固定·无品阶）+ 绝学×1（绝品·共用）",
    "4  品级（玄品）与［升级］放大到 48 高；进阶 / 突破 / 连升全去掉；角色不能升品",
    "5  ［切换角色］放大，点开是带分类栏的头像格（全部/主角/弟子/同伴）",
]
d.rectangle((0, 1272, W, H), fill=(33, 27, 22))
tx((24, 1284), "角色界面改版草图 v3 · 讨论用", F_BOLD(15), GOLDHI)
for i, s in enumerate(notes):
    tx((24, 1310 + i * 22), s, F_BODY(12), (226, 218, 202))

img.save(OUT)
print("saved", OUT, img.size)
