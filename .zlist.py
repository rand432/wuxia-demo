
import sys, zipfile, io
sys.stdout.reconfigure(encoding="utf-8")
from PIL import Image
z = zipfile.ZipFile(r"E:\BaiduNetdiskDownload\3637 物华弥新【202506】\水墨动作手游《影之刃》素材（UI+场景+音效+特效）_爱给网_aigei_com.zip")
keys = ["UI/mainmenu.png","UI/UI_Battle_hunbase.png","UI/UI_Battle_Public.png","UI/UI_City_Back.png",
        "UI/UI_City_Public.png","UI/UI_Logo.png","UI/UI_Heads.png","UI/Gacha.png","UI/Gacha2.png",
        "UI/box.png","UI/button.png","UI/Entrance_Lunjian.png","UI/UI_Process.png","UI/UI_Billboardback.png"]
for k in keys:
    try:
        with z.open(k) as s:
            im = Image.open(io.BytesIO(s.read()))
            print(f"{k:34} {im.size[0]:5d}x{im.size[1]:<5d} {im.mode}")
    except Exception as e:
        print(k, "ERR", e)
