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
# 顶栏（僵尸那套：货币）
d.rectangle((0, 0, W, 76), fill=(40, 36, 32, 255))
d.text((24, 24), "银两 498", font=F(18), fill=(238, 228, 204, 255))
d.text((190, 24), "元宝 0", font=F(18), fill=(238, 228, 204, 255))
d.text((560, 24), "设置", font=F(15), fill=(200, 190, 170, 255))
# 伙伴卡牌（三张，选中的大卡在前）
faces = [("D:/1/wuxia-demo/assets/char/chen_shi_face.png", "陈石"),
         ("D:/1/wuxia-demo/assets/char/player_face.png", "少侠"),
         ("D:/1/wuxia-demo/assets/char/qingluan_face.png", "青鸾")]
# 两侧小卡
for i, (fp, nm) in enumerate([faces[0], faces[2]]):
    x = 20 if i == 0 else 500
    d.rounded_rectangle((x, 150, x + 200, 560), 8, fill=(222, 214, 198, 255), outline=(170, 160, 140, 255), width=2)
    if os.path.exists(fp):
        a = Image.open(fp).convert("RGBA"); a.thumbnail((190, 400))
        img.alpha_composite(a, (x + 5, 155))
    d.text((x + 70, 470), nm, font=F(18), fill=(110, 100, 82, 255))
# 中间大卡
d.rounded_rectangle((200, 110, 520, 600), 10, fill=(250, 246, 236, 255), outline=(198, 156, 60, 255), width=4)
if os.path.exists(faces[1][0]):
    a = Image.open(faces[1][0]).convert("RGBA"); a.thumbnail((310, 470))
    img.alpha_composite(a, (205, 118))
d.text((228, 128), "少侠", font=F(22), fill=(60, 54, 46, 255))
d.text((210, 606), "关于【少侠】", font=F(18), fill=(120, 110, 90, 255))
# 方案（僵尸那套）
d.text((40, 650), "方案", font=F(16), fill=(120, 110, 90, 255))
for i, t in enumerate(["1", "2", "3"]):
    x = 90 + i * 44
    on = i == 0
    d.rounded_rectangle((x, 642, x + 38, 672), 4, fill=(140, 50, 34, 255) if on else (232, 226, 212, 255), outline=(196, 160, 70, 255), width=1)
    d.text((x + 13, 648), t, font=F(16), fill=(246, 236, 212, 255) if on else (90, 82, 70, 255))
# 属性
d.text((40, 700), "属性", font=F(20), fill=(90, 82, 70, 255))
rows = [("攻击", 24), ("气血", 99), ("防御", 6), ("速度", 9)]
for i, (k, v) in enumerate(rows):
    x = 40 + (i % 2) * 330
    y = 736 + (i // 2) * 38
    d.text((x, y), k, font=F(20), fill=(90, 82, 70, 255))
    d.text((x + 120, y), str(v), font=F(22), fill=INK)
# 装备/功法两栏
d.text((40, 830), "装备", font=F(20), fill=(90, 82, 70, 255))
for i in range(3):
    y = 868 + i * 46
    d.rounded_rectangle((40, y, 330, y + 38), 4, fill=(252, 248, 238, 235), outline=(198, 188, 168, 255), width=2)
d.text((380, 830), "功法", font=F(20), fill=(90, 82, 70, 255))
for r in range(2):
    for c in range(3):
        x = 380 + c * 100
        y = 868 + r * 90
        d.rounded_rectangle((x, y, x + 90, y + 80), 6, fill=(252, 248, 238, 235), outline=(198, 188, 168, 255), width=2)
# 底部圆形按钮
d.ellipse((60, 1140, 120, 1200), outline=(120, 110, 90, 255), width=3)
d.ellipse((160, 1140, 220, 1200), outline=(120, 110, 90, 255), width=3)
d.ellipse((500, 1140, 560, 1200), outline=(120, 110, 90, 255), width=3)
d.ellipse((600, 1140, 660, 1200), outline=(120, 110, 90, 255), width=3)
# 底栏（僵尸 5 格）
d.rectangle((0, 1200, W, H), fill=(38, 34, 32, 255))
for i, t in enumerate(["商城", "角色", "战斗", "核心", "基地"]):
    x = 20 + i * 140
    on = i == 1
    d.rounded_rectangle((x, 1206, x + 120, 1276), 4, fill=(140, 50, 34, 255) if on else (56, 52, 50, 255), outline=(240, 210, 130, 255) if on else (110, 102, 92, 255), width=2)
    d.text((x + 34, 1228), t, font=F(16), fill=(246, 236, 212, 255) if on else (190, 182, 166, 255))
img.convert("RGB").save("D:/1/wuxia-demo/.shots/partner_sketch_v1.png")
print("saved")
