
import sys, os
sys.stdout.reconfigure(encoding="utf-8")
from PIL import Image, ImageDraw, ImageFont
R = r"D:\1\wuxia-demo\.yingzhi\UI"
picks = [("Entrance_Lunjian.png","论剑"),("Entrance_Sidou.png","死斗"),
         ("Entrance_Xuezhan.png","血战"),("Entrance_Waizhuan.png","外传"),
         ("Entrance_zhuisha.png","追杀"),("Entrance_Qiangdi.png","抢地")]
cell=148; n=len(picks)
img=Image.new("RGB",(cell*n, cell+34),(22,20,18))
d=ImageDraw.Draw(img)
f=ImageFont.truetype("C:/Windows/Fonts/msyh.ttc",16)
for i,(fn,lab) in enumerate(picks):
    p=os.path.join(R,fn)
    im=Image.open(p).convert("RGBA"); im.thumbnail((cell-14,cell-14))
    bg=Image.new("RGBA",(cell,cell),(34,30,26,255)); bg.alpha_composite(im,((cell-im.width)//2,(cell-im.height)//2))
    img.paste(bg.convert("RGB"),(i*cell,0))
    w=d.textlength(lab,font=f); d.text((i*cell+(cell-w)/2, cell+6), lab, font=f, fill=(226,206,150))
img.save(r"D:\1\wuxia-demo\.shots\yz_entrance_icons.png")
print("ok", img.size)
