from PIL import Image, ImageDraw, ImageFont
import os
W, H = 720, 1280
img = Image.new("RGBA", (W, H), (245, 240, 230, 255))
d = ImageDraw.Draw(img)
INK = (36, 33, 38, 255)
PAPER = (245, 240, 230, 255)
GREEN = (32, 110, 88, 255)
GOLD = (198, 156, 60, 255)
def F(sz):
    for p in ["D:/1/wuxia-demo/fonts/ink.ttf"]:
        if os.path.exists(p):
            return ImageFont.truetype(p, sz)
    return ImageFont.load_default()
# 左上返回
d.rounded_rectangle((20, 20, 84, 74), 6, outline=INK, width=2)
d.text((40, 32), "←", font=F(30), fill=INK)
# 名字（品级色）
d.text((250, 26), "少侠 ★6", font=F(46), fill=GREEN)
d.text((300, 82), "Lv.2 · 玄品", font=F(20), fill=GREEN)
# 立绘区域
art = "D:/1/wuxia-demo/assets/char/player_full.png"
if os.path.exists(art):
    a = Image.open(art).convert("RGBA")
    a.thumbnail((520, 760))
    img.alpha_composite(a, (100, 210))
# 四角装备格
slots = [("武", "武器", "青锋剑", 30, 200), ("护", "护甲", "空", 520, 200),
         ("玉", "玉佩", "空", 30, 860), ("鞋", "鞋子", "空", 520, 860)]
for g, nm, it, x, y in slots:
    d.rounded_rectangle((x, y, x + 170, y + 128), 6, outline=(200, 180, 140, 255), width=2, fill=(252, 248, 238, 220))
    d.rounded_rectangle((x + 10, y + 34, x + 66, y + 92), 6, outline=GOLD, width=2)
    d.text((x + 20, y + 48), g, font=F(28), fill=GOLD)
    d.text((x + 78, y + 16), nm, font=F(18), fill=(120, 110, 90, 255))
    d.text((x + 78, y + 46), it, font=F(20), fill=INK)
# 属性 4 行
d.text((60, 990), "属性", font=F(22), fill=(90, 82, 70, 255))
rows = [("攻击", 24), ("气血", 99), ("防御", 6), ("速度", 9)]
for i, (k, v) in enumerate(rows):
    x = 60 + (i % 2) * 320
    y = 1030 + (i // 2) * 44
    d.text((x, y), k, font=F(22), fill=(90, 82, 70, 255))
    d.text((x + 120, y), str(v), font=F(24), fill=INK)
# 底部两颗按钮
d.rounded_rectangle((60, 1140, 320, 1204), 6, fill=(40, 36, 34, 255))
d.text((150, 1156), "升 级", font=F(26), fill=(240, 232, 214, 255))
d.rounded_rectangle((400, 1140, 660, 1204), 6, fill=(200, 120, 30, 255))
d.text((480, 1156), "锻 造", font=F(26), fill=(30, 20, 10, 255))
img.convert("RGB").save("D:/1/wuxia-demo/.shots/char_sketch_v2.png")
print("saved")
