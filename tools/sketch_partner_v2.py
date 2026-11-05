from PIL import Image, ImageDraw, ImageFont
import os, math
W, H = 720, 1280
img = Image.new("RGBA", (W, H), (245, 240, 230, 255))
d = ImageDraw.Draw(img)
INK = (36, 33, 38, 255)
GREEN = (32, 110, 88, 255)
GOLD = (198, 156, 60, 255)
def F(sz):
    p = "D:/1/wuxia-demo/fonts/ink.ttf"
    return ImageFont.truetype(p, sz) if os.path.exists(p) else ImageFont.load_default()
# 顶栏
d.rectangle((0, 0, W, 78), fill=(40, 36, 32, 255))
d.text((24, 26), "银两 498", font=F(18), fill=(238, 228, 204, 255))
d.text((190, 26), "元宝 0", font=F(18), fill=(238, 228, 204, 255))
d.text((580, 26), "设置", font=F(15), fill=(200, 190, 170, 255))
# 伙伴卡牌：三张，中间选中
faces = [("D:/1/wuxia-demo/assets/char/chen_shi_face.png", "陈石"),
         ("D:/1/wuxia-demo/assets/char/player_face.png", "少侠"),
         ("D:/1/wuxia-demo/assets/char/qingluan_face.png", "青鸾")]
for i, (fp, nm) in enumerate([faces[0], faces[2]]):
    x = 14 if i == 0 else 506
    d.rounded_rectangle((x, 130, x + 200, 520), 8, fill=(222, 214, 198, 255), outline=(170, 160, 140, 255), width=2)
    if os.path.exists(fp):
        a = Image.open(fp).convert("RGBA"); a.thumbnail((190, 360))
        img.alpha_composite(a, (x + 5, 136))
    d.text((x + 72, 440), nm, font=F(18), fill=(110, 100, 82, 255))
d.rounded_rectangle((198, 96, 522, 560), 10, fill=(250, 246, 236, 255), outline=(198, 156, 60, 255), width=4)
if os.path.exists(faces[1][0]):
    a = Image.open(faces[1][0]).convert("RGBA"); a.thumbnail((310, 430))
    img.alpha_composite(a, (203, 104))
d.text((226, 112), "少侠", font=F(22), fill=(60, 54, 46, 255))
d.text((210, 566), "关于【少侠】", font=F(18), fill=(120, 110, 90, 255))
# 方案
d.text((40, 604), "方案", font=F(16), fill=(120, 110, 90, 255))
for i, t in enumerate(["1", "2", "3"]):
    x = 100 + i * 46
    on = i == 0
    d.rounded_rectangle((x, 596, x + 40, 630), 4, fill=(140, 50, 34, 255) if on else (232, 226, 212, 255), outline=(196, 160, 70, 255), width=1)
    d.text((x + 14, 604), t, font=F(17), fill=(246, 236, 212, 255) if on else (90, 82, 70, 255))
# 属性
d.text((40, 652), "属性", font=F(20), fill=(90, 82, 70, 255))
rows = [("攻击", 24), ("气血", 99), ("防御", 6), ("速度", 9)]
for i, (k, v) in enumerate(rows):
    x = 40 + (i % 2) * 330
    y = 688 + (i // 2) * 38
    d.text((x, y), k, font=F(20), fill=(90, 82, 70, 255))
    d.text((x + 120, y), str(v), font=F(22), fill=INK)
# 装备/功法
d.text((40, 782), "装备", font=F(20), fill=(90, 82, 70, 255))
for i in range(3):
    y = 820 + i * 48
    d.rounded_rectangle((40, y, 330, y + 40), 4, fill=(252, 248, 238, 235), outline=(198, 188, 168, 255), width=2)
d.text((380, 782), "功法", font=F(20), fill=(90, 82, 70, 255))
for r in range(2):
    for c in range(3):
        x = 380 + c * 100
        y = 820 + r * 94
        d.rounded_rectangle((x, y, x + 90, y + 84), 6, fill=(252, 248, 238, 235), outline=(198, 188, 168, 255), width=2)
# 圆形按钮
for x in (60, 160, 520, 620):
    d.ellipse((x, 1080, x + 62, 1142), outline=(120, 110, 90, 255), width=3)
# 底栏（我们的 4 图标）
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
    on = i == 2
    d.rounded_rectangle((cx - 66, 1186, cx + 66, 1266), 6, fill=(140, 50, 34, 255) if on else (56, 52, 50, 255), outline=(240, 210, 130, 255) if on else (110, 102, 92, 255), width=2)
    fn(cx, cy, (248, 236, 208, 255) if on else (196, 188, 172, 255))
img.convert("RGB").save("D:/1/wuxia-demo/.shots/partner_sketch_v2.png")
print("saved")
