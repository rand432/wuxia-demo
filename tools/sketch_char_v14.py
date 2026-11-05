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
# 1 顶栏货币
d.rectangle((0, 0, W, 78), fill=(40, 36, 32, 255))
d.text((24, 26), "银两 498", font=F(18), fill=(238, 228, 204, 255))
d.text((190, 26), "元宝 0", font=F(18), fill=(238, 228, 204, 255))
d.text((580, 26), "设置", font=F(15), fill=(200, 190, 170, 255))
# 2 中间人物展示（卡牌式）
art = "D:/1/wuxia-demo/assets/char/player_face.png"
if os.path.exists(art):
    a = Image.open(art).convert("RGBA"); a.thumbnail((430, 420))
    img.alpha_composite(a, ((W - a.width) // 2, 96))
# 3 禁用技能
d.text((220, 540), "禁用技能(0/3)", font=F(18), fill=(220, 200, 150, 255))
d.ellipse((380, 542, 400, 562), outline=(200, 180, 140, 255), width=2)
# 4 方案
d.text((40, 592), "方案", font=F(16), fill=(120, 110, 90, 255))
for i, t in enumerate(["1", "2", "3", "»"]):
    x = 100 + i * 46
    on = i == 0
    d.rounded_rectangle((x, 584, x + 40, 618), 4, fill=(140, 50, 34, 255) if on else (232, 226, 212, 255), outline=(196, 160, 70, 255), width=1)
    d.text((x + 14, 592), t, font=F(17), fill=(246, 236, 212, 255) if on else (90, 82, 70, 255))
# 5 总增幅 + 禁用编辑
d.text((40, 646), "总伤害加成  0%", font=F(24), fill=(140, 96, 30, 255))
d.ellipse((300, 650, 320, 670), outline=(180, 160, 120, 255), width=2)
d.rounded_rectangle((430, 636, 680, 690), 6, fill=(214, 132, 34, 255), outline=(246, 214, 120, 255), width=2)
d.text((488, 650), "禁用编辑", font=F(22), fill=(40, 24, 8, 255))
# 6 装备 4 格（模仿技能格：图+右下角等级标签）
slots = [("武器", "良品", True), ("护甲", "", False), ("玉佩", "", False), ("鞋子", "", False)]
for i, (nm, q, filled) in enumerate(slots):
    x = 40 + i * 166
    y = 710
    if filled:
        bc = QCOL.get(q, (150, 146, 138))
        d.rounded_rectangle((x, y, x + 150, y + 150), 8, outline=bc, width=4, fill=(250, 246, 236, 255))
        d.rounded_rectangle((x + 20, y + 16, x + 130, y + 126), 6, fill=(96, 126, 112, 255))
        d.line((x + 45, y + 116, x + 110, y + 40), fill=(220, 230, 220, 255), width=6)
        d.polygon([(x + 106, y + 148), (x + 150, y + 100), (x + 150, y + 148)], fill=(74, 140, 96, 255))
        d.text((x + 112, y + 122), "良", font=F(16), fill=(250, 248, 240, 255))
    else:
        d.rounded_rectangle((x, y, x + 150, y + 150), 8, outline=(206, 196, 176, 255), width=2, fill=(252, 248, 238, 235))
        d.text((x + 22, y + 58), nm, font=F(26), fill=(168, 158, 138, 255))
# 7 属性 4 行
d.text((40, 898), "属性", font=F(20), fill=(90, 82, 70, 255))
rows = [("攻击", 24), ("气血", 99), ("防御", 6), ("速度", 9)]
for i, (k, v) in enumerate(rows):
    x = 40 + (i % 2) * 330
    y = 934 + (i // 2) * 38
    d.text((x, y), k, font=F(20), fill=(90, 82, 70, 255))
    d.text((x + 120, y), str(v), font=F(22), fill=INK)
# 8 升级/锻造
d.rounded_rectangle((40, 1046, 300, 1108), 6, fill=(40, 36, 34, 255))
d.text((130, 1062), "升 级", font=F(24), fill=(240, 232, 214, 255))
d.rounded_rectangle((420, 1046, 680, 1108), 6, fill=(200, 120, 30, 255))
d.text((500, 1062), "锻 造", font=F(24), fill=(30, 20, 10, 255))
# 9 底栏 5 格（僵尸）
d.rectangle((0, 1176, W, H), fill=(38, 34, 32, 255))
d.line((0, 1176, W, 1176), fill=(198, 156, 60, 255), width=2)
for i, t in enumerate(["商城", "角色", "战斗", "核心", "基地"]):
    x = 16 + i * 140
    on = i == 1
    d.rounded_rectangle((x, 1190, x + 124, 1262), 4, fill=(140, 50, 34, 255) if on else (56, 52, 50, 255), outline=(240, 210, 130, 255) if on else (110, 102, 92, 255), width=2)
    d.text((x + 34, 1212), t, font=F(18), fill=(246, 236, 212, 255) if on else (190, 182, 166, 255))
img.convert("RGB").save("D:/1/wuxia-demo/.shots/char_sketch_v12.png")
print("saved")
