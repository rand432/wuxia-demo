import os, sys
from PIL import Image, ImageDraw, ImageFont

SRC = r"C:\Users\zq300\.dsh\dsh-imagegen\images"
OUT = r"D:\1\wuxia-demo\assets\gen\qingshen\_icon_pilot_sheet.jpg"
FONT = r"D:\1\wuxia-demo\fonts\ink.ttf"

items = [
    ("mwqz6etqc65d32ee", "铁剑"),
    ("mwqz6ed052cdd769", "皮甲"),
    ("mwqz6dvp006e46a5", "玉佩"),
    ("mwqz6ez6d14a14aa", "披风"),
    ("mwqz6fr4c3cf1557", "血葫芦"),
    ("mwqz6dxf23362700", "铜钱剑"),
]

T, PAD = 320, 14
COLS, ROWS = 3, 2
LABEL = 30
W = COLS * T + (COLS + 1) * PAD
H = ROWS * (T + LABEL) + (ROWS + 1) * PAD
sheet = Image.new("RGB", (W, H), (247, 244, 237))
draw = ImageDraw.Draw(sheet)
font = ImageFont.truetype(FONT, 22)

for i, (name, label) in enumerate(items):
    col, row = i % COLS, i // COLS
    x = PAD + col * (T + PAD)
    y = PAD + row * (T + LABEL + PAD)
    p = os.path.join(SRC, name + ".jpg")
    if not os.path.exists(p):
        continue
    img = Image.open(p).convert("RGB")
    img.thumbnail((T, T), Image.LANCZOS)
    sheet.paste(img, (x + (T - img.width) // 2, y + (T - img.height) // 2))
    draw.rectangle([x - 1, y - 1, x + T, y + T], outline=(210, 200, 180), width=1)
    tw = draw.textlength(label, font=font)
    draw.text((x + (T - tw) / 2, y + T + 4), label, fill=(60, 55, 48), font=font)

sheet.save(OUT, quality=92)
print("saved", OUT, sheet.size)
