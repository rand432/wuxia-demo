# make_rail_icons.py —— 把原素材转成"影之刃式金刻线"图标（v211 主界面右栏用）
#
# 用法：
#   python tools/make_rail_icons.py
#   然后：godot --headless --path . --import
#
# 产出：assets/ui/rail_shop.png / rail_beast.png / rail_cave.png / rail_treasure.png / rail_craft.png
# 做法：按原图 alpha 抠形，亮度重映射成"深金 → 浅金"的刻线，深底上像压出来的金线。
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "ui")

SRCS = {
    "rail_shop": "assets/ui/shop_stall.png",
    "rail_beast": "assets/char/mob_dog_q.png",
    "rail_cave": "assets/ui/cave_mouth.png",
    "rail_treasure": "assets/ui/treasure_shelf.png",
    "rail_craft": "assets/ui/craft_bench.png",
}

LO = (0.36, 0.26, 0.10)   # 深金（阴影）
HI = (0.99, 0.86, 0.55)   # 亮金（受光）
AMIN = 0.62               # 最暗处的 alpha（别让影子化成一团黑）


def goldify(im: Image.Image, size: int = 128) -> Image.Image:
    im = im.convert("RGBA")
    bbox = im.getchannel("A").getbbox()
    if bbox:
        im = im.crop(bbox)
    w, h = im.size
    s = max(w, h)
    canvas = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    canvas.alpha_composite(im, ((s - w) // 2, (s - h) // 2))
    canvas = canvas.resize((size, size), Image.LANCZOS)
    src = canvas.load()
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    dst = out.load()
    for y in range(size):
        for x in range(size):
            r, g, b, a = src[x, y]
            if a == 0:
                continue
            lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            lum = lum ** 0.65
            c = tuple(lo + (hi - lo) * lum for lo, hi in zip(LO, HI))
            dst[x, y] = (int(c[0] * 255), int(c[1] * 255), int(c[2] * 255),
                         int(a * (AMIN + (1.0 - AMIN) * lum)))
    return out


def main() -> None:
    for name, rel in SRCS.items():
        path = os.path.join(ROOT, rel)
        im = Image.open(path)
        out = goldify(im)
        dst = os.path.join(OUT_DIR, name + ".png")
        out.save(dst)
        print("wrote", dst, out.size)


if __name__ == "__main__":
    main()
