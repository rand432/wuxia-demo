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
# 顶部
d.rounded_rectangle((20, 18, 82, 70), 6, outline=INK, width=2)
d.line((38, 44, 64, 44), fill=INK, width=3); d.line((38, 44, 48, 34), fill=INK, width=3); d.line((38, 44, 48, 54), fill=INK, width=3)
d.text((252, 18), "少侠 ★6", font=F(42), fill=GREEN)
d.text((300, 70), "Lv.2 · 玄品", font=F(19), fill=GREEN)
# 立绘
art = "D:/1/wuxia-demo/assets/char/player_full.png"
if os.path.exists(art):
    a = Image.open(art).convert("RGBA"); a.thumbnail((400, 620))
    img.alpha_composite(a, (160, 176))
# 四角
slots = [("武", "武器", "青锋剑", 26, 164), ("护", "护甲", "空", 524, 164),
         ("玉", "玉佩", "空", 26, 802), ("鞋", "鞋子", "空", 524, 802)]
for g, nm, it, x, y in slots:
    d.rounded_rectangle((x, y, x + 170, y + 118), 6, outline=(200, 180, 140, 255), width=2, fill=(252, 248, 238, 220))
    d.rounded_rectangle((x + 10, y + 30, x + 60, y + 84), 6, outline=GOLD, width=2)
    d.text((x + 20, y + 42), g, font=F(26), fill=GOLD)
    d.text((x + 72, y + 12), nm, font=F(17), fill=(120, 110, 90, 255))
    d.text((x + 72, y + 40), it, font=F(19), fill=INK)
# 属性
d.text((60, 940), "属性", font=F(21), fill=(90, 82, 70, 255))
rows = [("攻击", 24), ("气血", 99), ("防御", 6), ("速度", 9)]
for i, (k, v) in enumerate(rows):
    x = 60 + (i % 2) * 320
    y = 978 + (i // 2) * 42
    d.text((x, y), k, font=F(21), fill=(90, 82, 70, 255))
    d.text((x + 120, y), str(v), font=F(23), fill=INK)
# 两颗按钮
d.rounded_rectangle((60, 1072, 320, 1134), 6, fill=(40, 36, 34, 255))
d.text((150, 1088), "升 级", font=F(24), fill=(240, 232, 214, 255))
d.rounded_rectangle((400, 1072, 660, 1134), 6, fill=(200, 120, 30, 255))
d.text((480, 1088), "锻 造", font=F(24), fill=(30, 20, 10, 255))
# 底栏：图标无字（人物 / 背包 / 返回）
d.rectangle((0, 1176, W, H), fill=(38, 34, 32, 255))
d.line((0, 1176, W, 1176), fill=(198, 156, 60, 255), width=2)
def icon_person(cx, cy, col):
    d.ellipse((cx - 17, cy - 34, cx + 17, cy), outline=col, width=4)
    d.arc((cx - 30, cy + 2, cx + 30, cy + 62), 180, 360, fill=col, width=4)
def icon_bag(cx, cy, col):
    d.rounded_rectangle((cx - 26, cy - 22, cx + 26, cy + 34), 6, outline=col, width=4)
    d.arc((cx - 14, cy - 36, cx + 14, cy - 6), 180, 360, fill=col, width=4)
    d.line((cx, cy - 8, cx, cy + 18), fill=col, width=4)
def icon_back(cx, cy, col):
    d.line((cx + 20, cy, cx - 20, cy), fill=col, width=5)
    d.line((cx - 20, cy, cx - 4, cy - 16), fill=col, width=5)
    d.line((cx - 20, cy, cx - 4, cy + 16), fill=col, width=5)
for i, fn in enumerate([icon_person, icon_bag, icon_back]):
    cx = 150 + i * 210
    cy = 1228
    on = i == 0
    d.rounded_rectangle((cx - 62, 1188, cx + 62, 1268), 6, fill=(140, 50, 34, 255) if on else (56, 52, 50, 255), outline=(240, 210, 130, 255) if on else (110, 102, 92, 255), width=2)
    fn(cx, cy, (248, 236, 208, 255) if on else (196, 188, 172, 255))
img.convert("RGB").save("D:/1/wuxia-demo/.shots/char_sketch_v4.png")
print("saved")
