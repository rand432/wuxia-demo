# -*- coding: utf-8 -*-
from PIL import Image, ImageDraw, ImageFont
import os

R = r"D:\1\wuxia-demo"
W, H = 720, 1430
OUT = os.path.join(R, ".shots", "char_redesign_sketch.png")

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

# ---------- 底板 ----------
rr((16, 10, 704, 1264), 6, (56, 47, 37))
rr((24, 18, 696, 1256), 4, PAPER, GOLD, 2)

# ---------- 顶栏 ----------
tx((44, 20), "角色", F_INK(40), SEAL)
rr((150, 28, 292, 60), 4, (58, 47, 38), GOLD)
tx((221, 44), "上阵", F_BODY(16), (240, 232, 214), "mm")
for i, (nm, fx) in enumerate([("陈石", "chen_shi_face.png"), ("少侠", "player_face.png"), ("青鸾", "qingluan_face.png")]):
    x = 330 + i * 108
    if fx == "player_face.png":
        rr((x - 3, 14, x + 57, 66), 28, None, SEAL, 2)
    circle_paste(fx, (x + 2, 18), 50)
    tx((x + 27, 72), nm, F_BODY(13), INK if fx == "player_face.png" else INK2, "mm")

# ---------- 头部 ----------
circle_paste("player_face.png", (42, 92), 96)
d.ellipse((40, 90, 140, 190), outline=GOLD, width=2)
tx((158, 86), "少侠", F_INK(40), INK)
tx((246, 96), "★6", F_BOLD(18), GOLD)
tx((158, 140), "主角 · 江湖新客 · 1/25 级", F_BODY(15), INK2)
rr((158, 164, 268, 194), 4, (62, 93, 58), None)
tx((213, 179), "品级 黄品", F_BODY(14), (240, 245, 235), "mm")
rr((276, 164, 436, 194), 4, (86, 74, 56), None)
tx((356, 179), "进阶 九品 +0%", F_BODY(14), (240, 234, 218), "mm")
# 升级小条
for i, nm in enumerate(["升级", "连升", "突破"]):
    x = 470 + i * 76
    rr((x, 88, x + 68, 118), 4, (96, 90, 80), None)
    tx((x + 34, 103), nm, F_BODY(14), (236, 231, 220), "mm")
# 经验
rr((158, 208, 676, 232), 8, (58, 49, 38), None)
rr((158, 208, 420, 232), 8, (98, 122, 74), None)
tx((417, 220), "经验 0/40", F_BODY(12), (243, 238, 224), "rm")

# ---------- 纸娃娃 ----------
rr((30, 250, 690, 812), 4, PAPER2, GOLD, 2)
rr((40, 262, 176, 292), 3, (58, 47, 38), GOLD)
tx((108, 277), "攻击属性 物理", F_BODY(14), (243, 237, 222), "mm")
rr((540, 262, 680, 292), 3, (58, 47, 38), GOLD)
tx((610, 277), "升星 0/6", F_BODY(14), (243, 237, 222), "mm")
full = Image.open(os.path.join(R, "assets/char", "player_full.png")).convert("RGBA")
fw = 200; fh = int(full.height * fw / full.width)
full = full.resize((fw, fh), Image.LANCZOS)
img.paste(full, (350 - fw // 2, 836 - fh), full)

def slot(x0, y0, title, name, line, empty=False):
    rr((x0, y0, x0 + 202, y0 + 104), 3, PAPER3, GOLD if not empty else (204, 192, 168), 2)
    tx((x0 + 10, y0 + 6), title, F_BOLD(14), GOLD)
    tx((x0 + 10, y0 + 28), name, F_BODY(16), INK if not empty else GRAY)
    tx((x0 + 10, y0 + 60), line, F_BODY(13), SEAL if not empty else GRAY)
    if empty:
        tx((x0 + 10, y0 + 82), "点格 → 查看 / 换装", F_BODY(11), (168, 160, 144))

slot(38, 306, "武器", "寻常的·普通·铁剑 +11", "攻 +18 · 伤 +2")
slot(480, 306, "护甲", "寻常的·凡品·战甲 +1", "气血 +31")
slot(38, 700, "玉佩", "—  未装备", "暴击 +3% · 爆伤 +10%", True)
slot(480, 700, "鞋子", "—  未装备", "速度 +2", True)
tx((360, 794), "四栏围着角色：武器 ↖ / 护甲 ↗ / 玉佩 ↙ / 鞋子 ↘", F_BODY(12), (146, 138, 122), "mm")

# ---------- 属性 ----------
tx((36, 822), "属性 · 基础＋额外", F_BOLD(20), INK)
rr((560, 814, 686, 846), 4, (58, 47, 38), GOLD)
tx((623, 830), "详细属性 ▸", F_BODY(14), (243, 237, 222), "mm")
stats = [("atk", "攻击", "23"), ("hp", "气血", "144"), ("speed", "速度", "9"),
         ("crit", "暴击", "8%"), ("crit_dmg", "爆伤", "50%"), ("def", "防御", "10")]
for i, (ic, lb, v) in enumerate(stats):
    col = i % 3; row = i // 3
    x = 34 + col * 218; y = 854 + row * 50
    rr((x, y, x + 206, y + 42), 3, PAPER3, (208, 197, 176), 1)
    stat_icon(ic, (x + 8, y + 8), 26)
    tx((x + 40, y + 22), lb, F_BODY(14), INK2, "lm")
    tx((x + 196, y + 22), v, F_BOLD(18), INK, "rm")

# ---------- 武学 ----------
tx((36, 962), "武学", F_BOLD(20), INK)
tx((102, 968), "功法固定 · 绝学共用", F_BODY(13), (150, 143, 129))
arts = [("功法", "落日剑法", "固定", GREEN), ("武学 1", "疾风剑法", "可换", GOLD),
        ("武学 2", "—", "可换", GOLD), ("武学 3", "—", "可换", GOLD),
        ("绝学", "落日剑诀", "绝品 · 共用", SEAL)]
for i, (tag, nm, sub, col) in enumerate(arts):
    x = 34 + i * 130
    rr((x, 990, x + 122, 1086), 3, PAPER3, (208, 197, 176), 1)
    tx((x + 61, 1004), tag, F_BODY(12), GOLD, "mm")
    tx((x + 61, 1030), nm, F_BODY(16), INK, "mm")
    tx((x + 61, 1062), sub, F_BODY(11), col, "mm")

# ---------- 天赋 / 服药 ----------
rr((34, 1096, 420, 1200), 3, PAPER3, (208, 197, 176), 1)
tx((44, 1102), "天赋", F_BOLD(16), INK)
tx((44, 1126), "赤子之心 · 天生神力", F_BODY(12), INK2)
tx((44, 1148), "剑心通明 · 明察秋毫", F_BODY(12), INK2)
tx((44, 1170), "【被动】引气归元：怒气 +30%", F_BODY(11), SEAL)
rr((436, 1096, 686, 1152), 3, (58, 47, 38), GOLD)
tx((561, 1124), "服药 · 包裹", F_BODY(15), (243, 237, 222), "mm")
tx((561, 1172), "包裹空（点开药包）", F_BODY(12), (150, 143, 129), "mm")

# 关闭
rr((280, 1210, 440, 1248), 3, (58, 47, 38), GOLD)
tx((360, 1229), "关　闭", F_BODY(16), (243, 237, 222), "mm")

# ---------- 标号 ----------
marks = [(30, 250, "1"), (30, 816, "2"), (30, 958, "3"), (462, 84, "4"), (30, 1092, "5")]
for x, y, n in marks:
    d.ellipse((x, y, x + 24, y + 24), fill=SEAL)
    tx((x + 12, y + 12), n, F_BOLD(14), (255, 245, 235), "mm")

# ---------- 说明条 ----------
notes = [
    "1  四栏围着立绘；空栏也写“攻伤 / 气血 / 暴击爆伤 / 速度”，一眼知道每栏管什么",
    "2  属性压成 6 格速览 +［详细属性］；全伤害 / 闪避等放进详细页，不再和顶部速览重复",
    "3  武学拆成：功法×1（固定·无品阶）+ 武学×3（可换）+ 绝学×1（五档·共用）",
    "4  升级 / 连升 / 突破挪进头部小条，不再占一整条灰按钮；品级与进阶并排",
    "5  天赋 / 服药保留底部；角色头像页签、上阵保留；关闭固定底部",
]
d.rectangle((0, 1272, W, H), fill=(33, 27, 22))
tx((24, 1284), "角色界面改版草图 · 讨论用", F_BOLD(15), GOLDHI)
for i, s in enumerate(notes):
    tx((24, 1310 + i * 22), s, F_BODY(12), (226, 218, 202))

img.save(OUT)
print("saved", OUT, img.size)
