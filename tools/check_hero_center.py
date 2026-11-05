from PIL import Image
im = Image.open("D:/1/wuxia-demo/assets/char/player_full.png").convert("RGBA")
a = im.split()[-1]
bb = a.getbbox()
w = bb[2] - bb[0]
cx = (bb[0] + bb[2]) / 2.0
print("size", im.size, "bbox", bb, "subject_cx", cx, "img_center", im.size[0] / 2.0, "offset", cx - im.size[0] / 2.0)
