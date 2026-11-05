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
# 顶栏：货币
d.rectangle((0, 0, W, 92), fill=(40, 36, 32, 255))
d.text((24, 28), "银两 498", font=F(20), fill=(238, 228, 204, 255))
d.text((210, 28), "元宝 0", font=F(20), fill=(238, 228, 204, 255))
d.text((600, 28), "设置", font=F(16), fill=(200, 190, 170, 255))
# 关卡
d.text((0, 120), "第 1 关 · 村口小道", font=F(34), fill=INK)
d.text((0, 168), "主角 · 江湖新客", font=F(16), fill=(120, 110, 90, 255))
# 难度
d.rounded_rectangle((80, 210, 360, 262), 4, fill=(140, 50, 34, 255), outline=(196, 160, 70, 255), width=2)
d.text((178, 220), "普 通", font=F(22), fill=(246, 236, 212, 255))
d.rounded_rectangle((372, 210, 652, 262), 4, fill=(232, 226, 212, 255), outline=(198, 188, 168, 255), width=2)
d.text((474, 220), "精 英", font=F(22), fill=(90, 82, 70, 255))
# 图（场景）
bg = "D:/1/wuxia-demo/assets/art/bg/bg_village.jpg"
if os.path.exists(bg):
    a = Image.open(bg).convert("RGBA")
    a.thumbnail((640, 560))
    img.alpha_composite(a, ((W - a.width) // 2, 290))
else:
    d.rectangle((40, 290, 680, 850), fill=(210, 200, 180, 255))
# 提升等级
d.text((440, 872), "提升等级(0/3)", font=F(18), fill=(200, 180, 140, 255))
# 宝箱
for i, t in enumerate(["成功通关", "50%血量通关", "完美通关"]):
    x = 70 + i * 200
    d.rounded_rectangle((x, 910, x + 140, 986), 6, fill=(120, 92, 52, 255), outline=(196, 160, 70, 255), width=2)
    d.text((x + 20, 1002), t, font=F(16), fill=(90, 82, 70, 255))
# 开始游戏
d.rounded_rectangle((90, 1050, 630, 1140), 8, fill=(214, 132, 34, 255), outline=(246, 214, 120, 255), width=3)
d.text((250, 1070), "开始游戏", font=F(38), fill=(40, 24, 8, 255))
# 底栏
d.rectangle((0, 1180, W, H), fill=(38, 34, 32, 255))
for i, t in enumerate(["商城", "角色", "战斗", "核心", "基地"]):
    x = 20 + i * 140
    on = i == 2
    d.rounded_rectangle((x, 1190, x + 120, 1270), 4, fill=(140, 50, 34, 255) if on else (56, 52, 50, 255), outline=(240, 210, 130, 255) if on else (110, 102, 92, 255), width=2)
    d.text((x + 30, 1216), t, font=F(18), fill=(246, 236, 212, 255) if on else (190, 182, 166, 255))
img.convert("RGB").save("D:/1/wuxia-demo/.shots/main_sketch_v1.png")
print("saved")
