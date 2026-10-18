# cut_white_bg.py —— 把"白底立绘/胸像"抠成透明底（只抠与画布边界连通的近白区域）
#
# 用法：python tools/cut_white_bg.py assets/char/chen_shi_face.png
# 产出：同目录的 <name>_cut.png
# 说明：用边界洪泛（tolerance 可调），只吃与边缘连通的白，不会吃掉人物身上的浅色。
import sys, os
from collections import deque
from PIL import Image

TOL = 18      # 近白判定：三通道都 >= 255-TOL
FEATHER = 0   # 0 = 硬边；想柔一点给 1~2（暂不用）


def cut(path: str) -> str:
    im = Image.open(path).convert("RGBA")
    w, h = im.size
    px = im.load()
    white = [[False] * w for _ in range(h)]
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            white[y][x] = a > 0 and r >= 255 - TOL and g >= 255 - TOL and b >= 255 - TOL
    seen = [[False] * w for _ in range(h)]
    q = deque()
    for x in range(w):
        for y in (0, h - 1):
            if white[y][x] and not seen[y][x]:
                seen[y][x] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if white[y][x] and not seen[y][x]:
                seen[y][x] = True
                q.append((x, y))
    while q:
        x, y = q.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not seen[ny][nx] and white[ny][nx]:
                seen[ny][nx] = True
                q.append((nx, ny))
    for y in range(h):
        for x in range(w):
            if seen[y][x]:
                r, g, b, a = px[x, y]
                px[x, y] = (r, g, b, 0)
    out = os.path.splitext(path)[0] + "_cut.png"
    im.save(out)
    return out


def main() -> None:
    for p in sys.argv[1:]:
        print("wrote", cut(p))


if __name__ == "__main__":
    main()
