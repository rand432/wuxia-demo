from PIL import Image, ImageDraw, ImageFont
import os, math
W, H = 720, 1280
img = Image.new("RGBA", (W, H), (245, 240, 230, 255))
d = ImageDraw.Draw(img)
INK = (36, 33, 38, 255)
GREEN = (32, 110, 88, 255)
GOLD = (198, 156, 60, 255)
QCOL = {"凡品": (150, 146, 138), "良品": (74, 140, 96), "上品": (58, 112, 176), "极品": (140, 86, 170), "绝品": (206, 150, 48)}
def F(sz):
    p = "D:/1/wuxia-demo/fonts/ink.ttf"
    return ImageFont.truetype(p, sz) if os.path.exists(p) else ImageFont.load_default()
d.rounded_rectangle((20, 18, 82, 70), 6, outline=INK, width=2)
d.line((38, 44, 64, 44), fill=INK, width=3); d.line((38, 44, 48, 34), fill=INK, width=3); d.line((38, 44, 48, 54), fill=INK, width=3)
d.text((252, 14), "少侠 ★6", font=F(40), fill=GREEN)
d.text((300, 62), "Lv.2 · 玄品", font=F(18), fill=GREEN)
# 立绘收小（上半屏）
art = "D:/1/wuxia-demo/assets/char/player_full.png"
if os.path.exists(art):
    a = Image.open(art).convert("RGBA"); a.thumbnail((300, 440))
    img.alpha_composite(a, (210, 92))
# 四角装备格（绕着小立绘）
slots = [("武器", "良品", True, 30, 110), ("护甲", "", False, 520, 110),
         ("玉佩", "", False, 30, 430), ("鞋子", "", False, 520, 430)]
for nm, q, filled, x, y in slots:
    if filled:
        bc = QCOL.get(q, (150, 146, 138))
        d.rounded_rectangle((x, y, x + 170, y + 104), 6, outline=bc, width=4, fill=(252, 248, 238, 235))
        d.rounded_rectangle((x + 34, y + 12, x + 136, y + 92), 6, fill=(96, 126, 112, 255))
        d.line((x + 54, y + 82, x + 116, y + 22), fill=(220, 230, 220, 255), width=5)
    else:
        d.rounded_rectangle((x, y, x + 170, y + 104), 6, outline=(206, 196, 176, 255), width=2, fill=(252, 248, 238, 220))
        d.text((x + 22, y + 36), nm, font=F(28), fill=(168, 158, 138, 255))
# 背包（4 类 + 材料）
d.text((40, 570), "背包", font=F(24), fill=(90, 82, 70, 255))
cats = ["武器", "护甲", "玉佩", "鞋子", "材料"]
for i, c in enumerate(cats):
    x = 40 + i * 132
    on = i == 0
    d.rounded_rectangle((x, 610, x + 120, 656), 4, fill=(140, 50, 34, 255) if on else (232, 226, 212, 255), outline=(196, 160, 70, 255) if on else (198, 188, 168, 255), width=2)
    d.text((x + 34, 620), c, font=F(20), fill=(246, 236, 212, 255) if on else (90, 82, 70, 255))
# 物品格 5×2
for r in range(2):
    for c in range(5):
        x = 40 + c * 132
        y = 676 + r * 128
        d.rounded_rectangle((x, y, x + 120, y + 116), 6, outline=(198, 188, 168, 255), width=2, fill=(252, 248, 238, 235))
        d.text((x + 8, y + 92), "1", font=F(14), fill=(120, 110, 90, 255))
# 属性
d.text((40, 940), "属性", font=F(20), fill=(90, 82, 70, 255))
rows = [("攻击", 24), ("气血", 99), ("防御", 6), ("速度", 9)]
for i, (k, v) in enumerate(rows):
    x = 40 + (i % 2) * 330
    y = 976 + (i // 2) * 38
    d.text((x, y), k, font=F(20), fill=(90, 82, 70, 255))
    d.text((x + 120, y), str(v), font=F(22), fill=INK)
d.rounded_rectangle((40, 1064, 300, 1126), 6, fill=(40, 36, 34, 255))
d.text((130, 1080), "升 级", font=F(24), fill=(240, 232, 214, 255))
d.rounded_rectangle((420, 1064, 680, 1126), 6, fill=(200, 120, 30, 255))
d.text((500, 1080), "锻 造", font=F(24), fill=(30, 20, 10, 255))
# 底栏 4 图标
d.rectangle((0, 1176, W, H), fill=(38, 34, 32, 255))
d.line((0, 1176, W, 1176), fill=(198, 156, 60, 255), width=2)
def ic_play(cx, cy, col):
    d.polygon([(cx - 14, cy - 20), (cx - 14, cy + 20), (cx + 22, cy)], fill=col)
def ic_sword(cx, cy, col):
    d.line((cx - 18, cy + 20, cx + 16, cy - 20), fill=col, width=5)
    d.line((cx - 6, cy + 8, cx - 18, cy - 2), fill=col, width=4)
    d.line((cx - 2, cy + 12, cx + 6, cy + 22), fill=col, width=4)
def ic_friend(cx, cy, col):
    d.ellipse((cx - 26, cy - 20, cx - 2, cy + 4), outline=col, width=4)
    d.ellipse((cx + 2, cy - 20, cx + 26, cy + 4), outline=col, width=4)
    d.arc((cx - 34, cy + 8, cx + 2, cy + 44), 180, 360, fill=col, width=4)
    d.arc((cx - 2, cy + 8, cx + 34, cy + 44), 180, 360, fill=col, width=4)
def ic_gear(cx, cy, col):
    d.ellipse((cx - 14, cy - 14, cx + 14, cy + 14), outline=col, width=4)
    for k in range(8):
        a = k * math.pi / 4
        d.line((cx + math.cos(a) * 16, cy + math.sin(a) * 16, cx + math.cos(a) * 26, cy + math.sin(a) * 26), fill=col, width=5)
for i, fn in enumerate([ic_play, ic_sword, ic_friend, ic_gear]):
    cx = 100 + i * 174
    cy = 1226
    on = i == 1
    d.rounded_rectangle((cx - 66, 1186, cx + 66, 1266), 6, fill=(140, 50, 34, 255) if on else (56, 52, 50, 255), outline=(240, 210, 130, 255) if on else (110, 102, 92, 255), width=2)
    fn(cx, cy, (248, 236, 208, 255) if on else (196, 188, 172, 255))
img.convert("RGB").save("D:/1/wuxia-demo/.shots/char_sketch_v7.png")
print("saved")
