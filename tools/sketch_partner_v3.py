from PIL import Image, ImageDraw, ImageFont
import os, math
W, H = 720, 1280
img = Image.new("RGBA", (W, H), (245, 240, 230, 255))
d = ImageDraw.Draw(img)
INK = (36, 33, 38, 255)
GOLD = (198, 156, 60, 255)
def F(sz):
    p = "D:/1/wuxia-demo/fonts/ink.ttf"
    return ImageFont.truetype(p, sz) if os.path.exists(p) else ImageFont.load_default()
# 顶栏货币
d.rectangle((0, 0, W, 78), fill=(40, 36, 32, 255))
d.text((24, 26), "银两 498", font=F(18), fill=(238, 228, 204, 255))
d.text((190, 26), "元宝 0", font=F(18), fill=(238, 228, 204, 255))
d.text((580, 26), "设置", font=F(15), fill=(200, 190, 170, 255))
# 人物展示（卡牌式，胸像）
art = "D:/1/wuxia-demo/assets/char/player_face.png"
if os.path.exists(art):
    a = Image.open(art).convert("RGBA"); a.thumbnail((420, 400))
    img.alpha_composite(a, ((W - a.width) // 2, 92))
# 禁用技能
d.text((222, 512), "禁用技能(0/3)", font=F(18), fill=(220, 200, 150, 255))
d.ellipse((382, 514, 402, 534), outline=(200, 180, 140, 255), width=2)
# 方案
d.text((40, 562), "方案", font=F(16), fill=(120, 110, 90, 255))
for i, t in enumerate(["1", "2", "3"]):
    x = 100 + i * 46
    on = i == 0
    d.rounded_rectangle((x, 554, x + 40, 588), 4, fill=(140, 50, 34, 255) if on else (232, 226, 212, 255), outline=(196, 160, 70, 255), width=1)
    d.text((x + 14, 562), t, font=F(17), fill=(246, 236, 212, 255) if on else (90, 82, 70, 255))
# 总增幅 + 禁用编辑
d.text((40, 614), "总伤害加成  0%", font=F(24), fill=(140, 96, 30, 255))
d.ellipse((300, 618, 320, 638), outline=(180, 160, 120, 255), width=2)
d.rounded_rectangle((430, 604, 680, 658), 6, fill=(214, 132, 34, 255), outline=(246, 214, 120, 255), width=2)
d.text((488, 618), "禁用编辑", font=F(22), fill=(40, 24, 8, 255))
# 武学格：4 + 3
cols = [(170, 70, 50), (70, 110, 150), (90, 130, 170), (60, 140, 100)]
talents = [("落日剑法", "1级"), ("落日剑诀", "1级"), ("", ""), ("", "")]
for i in range(4):
    x = 36 + i * 166
    y = 686
    if i < 2:
        d.rounded_rectangle((x, y, x + 150, y + 150), 8, outline=(150, 146, 138), width=3, fill=(250, 246, 236, 255))
        d.rounded_rectangle((x + 22, y + 18, x + 128, y + 118), 8, fill=cols[i])
        nm, lv = talents[i]
        d.polygon([(x + 106, y + 148), (x + 150, y + 100), (x + 150, y + 148)], fill=(150, 146, 138))
        d.text((x + 108, y + 124), lv, font=F(15), fill=(250, 248, 240, 255))
    else:
        d.rounded_rectangle((x, y, x + 150, y + 150), 8, outline=(206, 196, 176, 255), width=2, fill=(252, 248, 238, 235))
for i in range(3):
    x = 36 + i * 166
    y = 858
    d.rounded_rectangle((x, y, x + 150, y + 150), 8, outline=(206, 196, 176, 255), width=2, fill=(252, 248, 238, 235))
# 底栏 4 图标（我们的）
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
img.convert("RGB").save("D:/1/wuxia-demo/.shots/partner_sketch_v3.png")
print("saved")
