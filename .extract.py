
import sys, zipfile, os, collections
sys.stdout.reconfigure(encoding="utf-8")
os.makedirs(r"D:\1\wuxia-demo\refs\yingzhiren", exist_ok=True)
z = zipfile.ZipFile(r"E:\BaiduNetdiskDownload\3637 物华弥新【202506】\水墨动作手游《影之刃》素材（UI+场景+音效+特效）_爱给网_aigei_com.zip")
names = z.namelist()

# decode mojibake top folders (GBK bytes misread as cp437 by zipfile)
def fix(n):
    try:
        return n.encode("cp437").decode("gbk")
    except Exception:
        return n

ui = [n for n in names if n.startswith("UI/") and n.lower().endswith(".png")]
picked = [n for n in ui if any(k in n for k in ("button","box.png","Gacha.png","character3","blood2","horizontalslider","Atlas_character_back","Atlas_enemypublic","Entrance_"))][:16]
for n in picked:
    with z.open(n) as s, open(os.path.join(r"D:\1\wuxia-demo\refs\yingzhiren", os.path.basename(n)), "wb") as d:
        d.write(s.read())
print("extracted:", len(picked))

print("--- scene/character folders (decoded) ---")
tops = collections.Counter(fix(n).split("/")[0] for n in names)
for k, v in tops.most_common(10):
    print(v, k)

print("--- 场景 sample ---")
sc = [fix(n) for n in names if fix(n).startswith("场景")][:20]
for n in sc: print(n)
print("--- 角色 sample ---")
ch = [fix(n) for n in names if fix(n).startswith("角色")][:20]
for n in ch: print(n)

from PIL import Image
print("--- extracted sizes ---")
for fn in sorted(os.listdir(r"D:\1\wuxia-demo\refs\yingzhiren")):
    p = os.path.join(r"D:\1\wuxia-demo\refs\yingzhiren", fn)
    try:
        im = Image.open(p)
        print(f"{fn:36} {im.size[0]}x{im.size[1]}  {im.mode}")
    except Exception as e:
        print(fn, "ERR", e)
