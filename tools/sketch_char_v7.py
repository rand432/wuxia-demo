from PIL import Image, ImageDraw, ImageFont
import os
W, H = 720, 1280
img = Image.new("RGBA", (W, H), (245, 240, 230, 255))
d = ImageDraw.Draw(img)
INK = (36, 33, 38, 255)
GREEN = (32, 110, 88, 255)
GOLD = (198, 156, 60, 255)
def F(sz):
    p = "D:/1/wuxia-demo/fonts/ink.ttf"
    return ImageFont.truetype(p, sz) if os.path.exists(p) else ImageFont.load_default()
d.rounded_rectangle((20, 18, 82, 70), 6, outline=INK, width=2)
d.line((38, 44, 64, 44), fill=INK, width=3); d.line((38, 44, 48, 34), fill=INK, width=3); d.line((38, 44, 48, 54), fill=INK, width=3)
d.text((252, 18), "少侠 ★6", font=F(42), fill=GREEN)
d.text((300, 70), "Lv.2 · 玄品", font=F(19), fill=GREEN)
art = "D:/1/wuxia-demo/assets/char/player_full.png"
if os.path.exists(art):
    a = Image.open(art).convert("RGBA"); a.thumbnail((400, 620))
    img.alpha_composite(a, (160, 176))
# 四角：空=名称大字；有=图像
slots = [("武器", "青锋剑", True, 26, 164), ("护甲", "护甲", False, 524, 164),
         ("玉佩", "玉佩", False, 26, 802), ("鞋子", "鞋子", False, 524, 802)]
for nm, it, filled, x, y in slots:
    d.rounded_rectangle((x, y, x + 170, y + 118), 6, outline=(200, 180, 140, 255), width=2, fill=(252, 248, 238, 220))
    if filled:
        d.rounded_rectangle((x + 12, y + 16, x + 98, y + 102), 6, fill=(96, 126, 112, 255), outline=GOLD, width=2)
        d.text((x + 106, y + 40), "武器", font=F(20), fill=(120, 110, 90, 255))
        d.text((x + 106, y + 66), it, font=F(19), fill=INK)
    else:
        d.text((x + 22, y + 44), nm, font=F(30), fill=(150, 138, 116, 255))
# 属性
d.text((60, 940), "属性", font=F(21), fill=(90, 82, 70, 255))
rows = [("攻击", 24), ("气血", 99), ("防御", 6), ("速度", 9)]
for i, (k, v) in enumerate(rows):
    x = 60 + (i % 2) * 320
    y = 978 + (i // 2) * 42
    d.text((x, y), k, font=F(21), fill=(90, 82, 70, 255))
    d.text((x + 120, y), str(v), font=F(23), fill=INK)
d.rounded_rectangle((60, 1072, 320, 1134), 6, fill=(40, 36, 34, 255))
d.text((150, 1088), "升 级", font=F(24), fill=(240, 232, 214, 255))
d.rounded_rectangle((400, 1072, 660, 1134), 6, fill=(200, 120, 30, 255))
d.text((480, 1088), "锻 造", font=F(24), fill=(30, 20, 10, 255))
# 底栏：4 个图标（开始游戏 / 装备 / 伙伴 / 设置）
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
        import math
        a = k * math.pi / 4
        d.line((cx + math.cos(a) * 16, cy + math.sin(a) * 16, cx + math.cos(a) * 26, cy + math.sin(a) * 26), fill=col, width=5)
for i, fn in enumerate([ic_play, ic_sword, ic_friend, ic_gear]):
    cx = 100 + i * 174
    cy = 1226
    on = i == 1
    d.rounded_rectangle((cx - 66, 1186, cx + 66, 1266), 6, fill=(140, 50, 34, 255) if on else (56, 52, 50, 255), outline=(240, 210, 130, 255) if on else (110, 102, 92, 255), width=2)
    fn(cx, cy, (248, 236, 208, 255) if on else (196, 188, 172, 255))
img.convert("RGB").save("D:/1/wuxia-demo/.shots/char_sketch_v5.png")
print("saved")
