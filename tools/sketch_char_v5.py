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
# 返回
d.rounded_rectangle((20, 18, 82, 70), 6, outline=INK, width=2)
d.line((38, 44, 64, 44), fill=INK, width=3); d.line((38, 44, 48, 34), fill=INK, width=3); d.line((38, 44, 48, 54), fill=INK, width=3)
# 名字 + 等级/品级
d.text((252, 18), "少侠 ★6", font=F(42), fill=GREEN)
d.text((300, 70), "Lv.2 · 玄品", font=F(19), fill=GREEN)
# 立绘（收小）
art = "D:/1/wuxia-demo/assets/char/player_full.png"
if os.path.exists(art):
    a = Image.open(art).convert("RGBA")
    a.thumbnail((400, 620))
    img.alpha_composite(a, (160, 180))
# 四角装备格（贴着立绘四个角）
slots = [("武", "武器", "青锋剑", 26, 168), ("护", "护甲", "空", 524, 168),
         ("玉", "玉佩", "空", 26, 806), ("鞋", "鞋子", "空", 524, 806)]
for g, nm, it, x, y in slots:
    d.rounded_rectangle((x, y, x + 170, y + 118), 6, outline=(200, 180, 140, 255), width=2, fill=(252, 248, 238, 220))
    d.rounded_rectangle((x + 10, y + 30, x + 60, y + 84), 6, outline=GOLD, width=2)
    d.text((x + 20, y + 42), g, font=F(26), fill=GOLD)
    d.text((x + 72, y + 12), nm, font=F(17), fill=(120, 110, 90, 255))
    d.text((x + 72, y + 40), it, font=F(19), fill=INK)
# 属性 4 行
d.text((60, 944), "属性", font=F(21), fill=(90, 82, 70, 255))
rows = [("攻击", 24), ("气血", 99), ("防御", 6), ("速度", 9)]
for i, (k, v) in enumerate(rows):
    x = 60 + (i % 2) * 320
    y = 982 + (i // 2) * 42
    d.text((x, y), k, font=F(21), fill=(90, 82, 70, 255))
    d.text((x + 120, y), str(v), font=F(23), fill=INK)
# 两颗按钮
d.rounded_rectangle((60, 1076, 320, 1138), 6, fill=(40, 36, 34, 255))
d.text((150, 1092), "升 级", font=F(24), fill=(240, 232, 214, 255))
d.rounded_rectangle((400, 1076, 660, 1138), 6, fill=(200, 120, 30, 255))
d.text((480, 1092), "锻 造", font=F(24), fill=(30, 20, 10, 255))
# 底栏（三格）
d.rectangle((0, 1180, W, H), fill=(38, 34, 32, 255))
d.line((0, 1180, W, 1180), fill=(198, 156, 60, 255), width=2)
for i, t in enumerate(["角色", "行囊", "返回"]):
    x = 24 + i * 232
    on = i == 0
    d.rounded_rectangle((x, 1194, x + 216, 1262), 4, fill=(140, 50, 34, 255) if on else (56, 52, 50, 255), outline=(240, 210, 130, 255) if on else (110, 102, 92, 255), width=2)
    d.text((x + 76, 1210), t, font=F(22), fill=(245, 236, 214, 255))
img.convert("RGB").save("D:/1/wuxia-demo/.shots/char_sketch_v3.png")
print("saved")
