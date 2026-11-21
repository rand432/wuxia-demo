import os
from PIL import Image, ImageDraw, ImageFont

SRC = r"D:\1\wuxia-demo\assets\gen\qingshen"
OUT = r"D:\1\wuxia-demo\assets\gen\qingshen\_contact_sheet.jpg"
FONT = r"D:\1\wuxia-demo\fonts\ink.ttf"

items = [
    ("portrait_zl.jpg", "张道陵"),
    ("portrait_cuisanniang.jpg", "崔三娘"),
    ("portrait_jicanghai.jpg", "季沧海"),
    ("portrait_zhujue.jpg", "主角"),
    ("portrait_chenshi.jpg", "陈石"),
    ("portrait_liuqingqing.jpg", "柳卿卿"),
    ("portrait_xiaoqier.jpg", "小乞儿"),
    ("portrait_gundilong.jpg", "滚地龙"),
    ("portrait_qingluan.jpg", "苏青鸾"),
    ("portrait_mingzhu.jpg", "明烛"),
    ("portrait_zhiyuan.jpg", "纸鸢"),
]

TW, TH = 270, 480
LABEL = 34
COLS = 4
ROWS = (len(items) + COLS - 1) // COLS
PAD = 12
BG = (247, 244, 237)

W = COLS * TW + (COLS + 1) * PAD
H = ROWS * (TH + LABEL) + (ROWS + 1) * PAD

sheet = Image.new("RGB", (W, H), BG)
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype(FONT, 24) if os.path.exists(FONT) else ImageFont.load_default()

for i, (name, label) in enumerate(items):
    col, row = i % COLS, i // COLS
    x = PAD + col * (TW + PAD)
    y = PAD + row * (TH + LABEL + PAD)
    path = os.path.join(SRC, name)
    if not os.path.exists(path):
        continue
    img = Image.open(path).convert("RGB")
    img.thumbnail((TW, TH), Image.LANCZOS)
    ox = x + (TW - img.width) // 2
    oy = y + (TH - img.height) // 2
    sheet.paste(img, (ox, oy))
    draw.rectangle([x - 1, y - 1, x + TW, y + TH], outline=(210, 200, 180), width=1)
    tw = draw.textlength(label, font=font)
    draw.text((x + (TW - tw) / 2, y + TH + 6), label, fill=(60, 55, 48), font=font)

sheet.save(OUT, quality=92)
print("saved", OUT, sheet.size)
