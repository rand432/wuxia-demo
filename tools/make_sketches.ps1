# ============================================================
# 开场分镜 · 11 镜构图草图生成器（本地，零成本）
# 用途：给 LibTV/Liblib AI 的 img2img 垫图，把构图锁死，不让模型自由发挥。
#       草图只表达「什么在哪、占多大」——不表达风格，风格交给 LoRA。
# 输出：assets/gen/sketches/<镜名>.png
# 跑法：powershell -NoProfile -ExecutionPolicy Bypass -File tools\make_sketches.ps1
# ============================================================
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

$W = 1664; $H = 928
$OUT = Join-Path (Split-Path -Parent $PSScriptRoot) 'assets\gen\sketches'
New-Item -ItemType Directory -Path $OUT -Force | Out-Null

$INK  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,24,24,28))
$INK2 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,52,56,64))
$GREY = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,150,155,163))
$PALE = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,205,208,214))
$RED  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,190,32,38))
$PEN_K  = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), 10)
$PEN_K2 = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), 5)
$PEN_G  = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,175,180,188), 4)
$PEN_R  = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,190,32,38), 9)

function Make([string]$name, [scriptblock]$draw) {
  $bmp = New-Object System.Drawing.Bitmap($W,$H)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.Clear([System.Drawing.Color]::FromArgb(255,252,251,249))
  & $draw $g
  $p = Join-Path $OUT ($name + '.png')
  $g.Dispose(); $bmp.Save($p, [System.Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
  Write-Output ("  " + $name + ".png")
}

# ---------- 01 墨入水 · 大特写 · 纯黑画面中央偏下一滴墨 ----------
Make '01_墨入水' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,12,12,14))
  $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,30,30,34))), 300, 180, 1064, 620)
  $g.FillEllipse($INK2, 760, 470, 150, 110)                    # 墨滴落点
  for ($i=0; $i -lt 26; $i++) {                                 # 晕散丝
    $a = $i * 13.8 * [math]::PI / 180
    $len = 240 + ($i % 5) * 90
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(120,70,72,80), 3)),
      (835 + [math]::Cos($a)*70), (525 + [math]::Sin($a)*50),
      (835 + [math]::Cos($a)*$len), (525 + [math]::Sin($a)*$len*0.62))
  }
  $g.DrawEllipse((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(160,150,160,175), 4)), 600, 380, 470, 290)  # 水波
}

# ---------- 02 荒原流民 · 大远景 · 下半幅塞满枯瘦流民，上半幅全空，天不管人 ----------
Make '02_荒原流民' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,250,249,247))
  # 地面带（地平线压到 y≈700，下方是密密麻麻的人）
  # 干裂荒原：只铺极淡的土色，且做成斑驳不匀（不要出现"水面/倒影"的平整横带）
  $rnd0 = New-Object System.Random(5)
  for ($i=0; $i -lt 220; $i++) {
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($rnd0.Next(10,34), 176,168,150))),
      $rnd0.Next(-60, $W), 660 + $rnd0.Next(0, 250), $rnd0.Next(60,240), $rnd0.Next(10,40))
  }
  $g.DrawLine($PEN_G, 0, 690, $W, 690)
  # 血红的残阳：全图唯一暖色，钉在右上
  $g.FillEllipse($RED, 1188, 132, 216, 216)
  $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70,190,32,38))), 1160, 108, 272, 264)
  # 远处低矮中式城郭：城墙 + 垛口 + 城门洞 + 两座城楼
  $wall = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,203,206,212))
  $g.FillRectangle($wall, 726, 664, 386, 30)
  for ($x = 732; $x -lt 1108; $x += 26) { $g.FillRectangle($wall, $x, 656, 15, 10) }
  $hole = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,250,249,247))
  $g.FillRectangle($hole, 896, 670, 38, 24)
  $g.FillEllipse($hole, 896, 658, 38, 24)
  foreach ($tx in @(772, 1016)) {
    $g.FillRectangle($wall, $tx, 636, 48, 30)
    $roof = New-Object System.Drawing.Drawing2D.GraphicsPath
    $roof.AddLine($tx-16, 640); $roof.AddLine($tx+64, 640); $roof.AddLine($tx+24, 610); $roof.AddLine($tx-16, 640)
    $g.FillPath($wall, $roof)
  }
  # 右侧一棵枯树 + 围树刨土哄抢的一簇人
  $treePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), 9)
  $g.DrawLine($treePen, 1408, 700, 1408, 508)
  foreach ($b in @(@(1408,556,1330,470),@(1408,576,1490,492),@(1408,608,1352,540),@(1408,624,1466,556))) {
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), 6)), $b[0], $b[1], $b[2], $b[3])
  }
  # ---- 密密麻麻的流民：枯瘦、佝偻、匍匐、伏地，杂乱无章 ----
  $rnd = New-Object System.Random(2024)
  $figCount = 78
  for ($i = 0; $i -lt $figCount; $i++) {
    $x = 40 + $rnd.Next(0, 1580)
    $depth = $rnd.Next(0, 100) / 100.0                       # 0=远 1=近
    $y = 688 + [int]($depth * 158)
    $scale = 1.05 + $depth * 1.55                             # 近大远小（整体放大 1.8x，密度才读得出来）
    $k = $rnd.Next(0, 100)
    if ($k -lt 42) {
      # 佝偻站立／行走：极瘦，头小，身如柴
      $bw = [int](9 * $scale); $bh = [int]((58 + $rnd.Next(0,46)) * $scale)
      $g.FillEllipse($INK, $x, $y - $bh, [int](16*$scale), [int](16*$scale))
      $g.FillRectangle($INK, $x + 2, $y - $bh + [int](14*$scale), $bw, $bh - [int](14*$scale))
      $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), [int](4*$scale))), $x + 4, $y, $x + [int](10*$scale), $y + [int](14*$scale))
    } elseif ($k -lt 64) {
      # 匍匐／爬行：身子接近水平
      $g.FillEllipse($INK, $x, $y - [int](14*$scale), [int](15*$scale), [int](13*$scale))
      $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), [int](9*$scale))), $x + [int](12*$scale), $y - [int](8*$scale), $x + [int](54*$scale), $y - [int](2*$scale))
    } elseif ($k -lt 78) {
      # 伏地不起：一条短横墨
      $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(220,24,24,28), [int](8*$scale))), $x, $y, $x + [int]((28 + $rnd.Next(0,22))*$scale), $y + [int](2*$scale))
    } elseif ($k -lt 88) {
      # 拄杖者：身＋斜杖
      $bh = [int]((64 + $rnd.Next(0,26)) * $scale)
      $g.FillEllipse($INK, $x, $y - $bh, [int](15*$scale), [int](15*$scale))
      $g.FillRectangle($INK, $x + 2, $y - $bh + [int](13*$scale), [int](9*$scale), $bh - [int](13*$scale))
      $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), [int](3*$scale))), $x + [int](14*$scale), $y - [int]($bh*0.72), $x + [int](24*$scale), $y)
    } else {
      # 抱襁褓者：身前一小团
      $bh = [int]((56 + $rnd.Next(0,20)) * $scale)
      $g.FillEllipse($INK, $x, $y - $bh, [int](15*$scale), [int](15*$scale))
      $g.FillRectangle($INK, $x + 2, $y - $bh + [int](13*$scale), [int](10*$scale), $bh - [int](13*$scale))
      $g.FillEllipse($INK, $x - [int](6*$scale), $y - [int](30*$scale), [int](16*$scale), [int](13*$scale))
    }
  }
  # 枯树上／树根旁挤着抢食的一圈人（再压一层）
  for ($i = 0; $i -lt 16; $i++) {
    $x = 1330 + $rnd.Next(0, 170); $y = 706 + $rnd.Next(0, 40)
    $g.FillEllipse($INK, $x, $y - 34, 14, 14)
    $g.FillRectangle($INK, $x + 2, $y - 22, 9, 22)
  }
  # 散落的折断木杖与森然枯枝（暗示惨状，不画血肉）
  for ($i = 0; $i -lt 26; $i++) {
    $x = 60 + $rnd.Next(0, 1520); $y = 716 + $rnd.Next(0, 96)
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(190,60,62,70), 4)),
      $x, $y, $x + 20 + $rnd.Next(0, 26), $y + $rnd.Next(-8, 9))
  }
}


# ---------- 03 宫殿纸醉金迷 · 中景略仰 · 剪影宴饮群像 + 举杯的手 ----------
Make '03_宫殿纸醉金迷' {
  param($g)
  $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,228,229,232))), 0, 0, 1664, 928)
  $g.FillRectangle($INK2, 0, 640, 1664, 288)                    # 长案
  $g.FillRectangle($INK, 0, 700, 1664, 60)
  $rnd = New-Object System.Random(3)
  for ($i=0; $i -lt 9; $i++) {                                   # 宴饮剪影（夸张姿态）
    $x = 120 + $i * 168
    $bh = 200 + $rnd.Next(0, 110)
    $g.FillEllipse($INK, $x, 640 - $bh, 92, 92)
    $g.FillRectangle($INK, $x + 14, 640 - $bh + 84, 62, $bh - 84)
    $ang = -40 + $rnd.Next(0, 80)
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), 16)), $x + 46, 640 - $bh + 120, $x + 46 + 120, 640 - $bh + 120 + $ang)
  }
  $g.FillEllipse($INK, 700, 300, 150, 150)                      # 举杯的手（特写，压在推近的终点）
  $g.FillRectangle($INK, 760, 250, 34, 70)
}

# ---------- 04 刀在膝上 · 特写 · 刀横放膝上；右手握柄、左手压刀身（两手都要明确）----------
Make '04_刀在膝上_B擦刀' {
  param($g)
  $g.DrawLine($PEN_G, 700, 812, 1520, 812)
  $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90,120,124,132))), 900, 770, 620, 70)
  # 跪坐身躯（墨块）
  $body = New-Object System.Drawing.Drawing2D.GraphicsPath
  $body.AddBezier(1080,400,1420,430,1460,640,1400,790); $body.AddLine(1400,790,980,790)
  $body.AddBezier(980,790,960,620,1010,430,1080,400); $g.FillPath($INK,$body)
  # 斗笠
  $hat = New-Object System.Drawing.Drawing2D.GraphicsPath
  $hat.AddBezier(1010,330,1250,250,1420,330,1440,360); $hat.AddLine(1440,360,1010,360); $g.FillPath($INK,$hat)
  $g.FillRectangle($INK, 1200, 268, 42, 60)
  $g.FillEllipse($GREY, 1180, 350, 96, 110)
  # ---- 长刀：**粗横条**，横放膝上；柄在右（贴近身体），刃向左伸出 ----
  $g.FillRectangle($INK, 790, 606, 500, 26)                     # 刀身（粗）
  $tip = New-Object System.Drawing.Drawing2D.GraphicsPath      # 刀尖
  $tip.AddLine(790, 606); $tip.AddLine(726, 619); $tip.AddLine(790, 632); $tip.CloseFigure()
  $g.FillPath($INK, $tip)
  $g.FillRectangle($INK, 1288, 594, 126, 44)                    # 刀柄（右侧贴身处）
  $g.FillEllipse($INK, 1256, 584, 44, 62)                       # 刀镡
  # ---- 右手：握住刀柄 ----
  $g.FillEllipse($GREY, 1300, 566, 104, 70)
  for ($f=0; $f -lt 4; $f++) { $g.FillRectangle($GREY, 1308 + $f*24, 546, 16, 30) }
  # ---- 左手：掌心压在刀身上（画成明确的手形，不是一团灰）----
  $g.FillEllipse($GREY, 968, 560, 118, 72)
  for ($f=0; $f -lt 4; $f++) { $g.FillRectangle($GREY, 976 + $f*28, 636, 18, 34) }   # 四指垂在刀身下缘
  # 刀身一线暗红（画粗才留得住）
  $g.DrawLine($PEN_R, 812, 620, 1240, 620)
}

# ---------- 05 红烛婚礼 · 近景 · 一对红烛 + 手把红绸系到刀鞘上 ----------
Make '05_红烛婚礼' {
  param($g)
  foreach ($cx in @(430, 700)) {                                 # 一对红烛
    $g.FillRectangle($INK, $cx, 250, 54, 300)
    $g.FillEllipse($RED, $cx - 4, 190, 62, 108)                 # 烛火（暖色）
  }
  $g.FillRectangle($INK, 980, 470, 420, 76)                      # 刀鞘横在下方
  $g.FillEllipse($GREY, 1150, 380, 210, 130)                     # 涂蔻丹的手
  $g.DrawLine($PEN_R, 1020, 430, 1330, 500)                      # 红绸
  $g.FillEllipse($RED, 1240, 470, 66, 60)                        # 结
}

# ---------- 06 门外护卫 · 中景 · 门缝一线光 + 背对按刀的剪影 + 长影 ----------
Make '06_门外护卫' {
  param($g)
  $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,26,27,31))), 0, 0, 1664, 928)
  $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,232,222,196))), 1180, 90, 26, 700)  # 门缝金线
  $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70,232,222,196))), 1120, 120, 150, 640)
  $g.FillEllipse($INK, 330, 300, 104, 104)                       # 头
  $g.FillRectangle($INK, 336, 392, 92, 300)                      # 身
  $g.FillRectangle($INK, 336, 690, 40, 130); $g.FillRectangle($INK, 388, 690, 40, 130)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,140,143,150), 14)), 250, 818, 900, 818)  # 拉长的影
}

# ---------- 07 暗算 · 中景转特写 · 打翻的酒杯 + 围拢人影 + 两点冷光 ----------
Make '07_暗算' {
  param($g)
  $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,214,215,219))), 0, 0, 1664, 928)
  $g.FillRectangle($INK2, 0, 620, 1664, 308)                     # 长案
  $g.FillEllipse($INK, 250, 470, 190, 150)                       # 打翻的杯
  $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,120,30,38))), 300, 600, 300, 60)  # 淌开的酒（暗红）
  $rnd = New-Object System.Random(7)
  for ($i=0; $i -lt 7; $i++) {                                   # 四周起身围拢的墨色人影
    $x = 60 + $i * 240; $bh = 250 + $rnd.Next(0,140)
    $g.FillEllipse($INK, $x, 620 - $bh, 116, 116)
    $g.FillRectangle($INK, $x + 18, 620 - $bh + 106, 80, $bh - 106)
    $g.FillEllipse($PALE, $x + 38, 620 - $bh + 44, 16, 10)       # 眼里两点冷光
    $g.FillEllipse($PALE, $x + 62, 620 - $bh + 44, 16, 10)
  }
  $g.FillRectangle($INK, 820, 380, 34, 240)                      # 将出未出的刀
}

# ---------- 08 坠崖 · 崖顶一排满覆盖诡笑傩面黑袍人（手持带血匕首）俯视；主角仰头、浑身是伤、双臂张开坠落 ----------
Make '08_坠崖' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,250,249,247))
  # 崖体：真岩石感——墨块 + 竖向皴笔 + 参差下缘
  $g.FillRectangle($INK, 0, 236, $W, 196)
  $rnd = New-Object System.Random(88)
  for ($i=0; $i -lt 150; $i++) {                                  # 竖向皴笔（岩纹）
    $x = $rnd.Next(0, $W); $h = $rnd.Next(30, 120)
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($rnd.Next(50,170), 60,62,70), $rnd.Next(2,7))),
      $x, 240 + $rnd.Next(0,60), $x + $rnd.Next(-6,7), 240 + $rnd.Next(0,60) + $h)
  }
  foreach ($ex in @(60, 300, 560, 820, 1080, 1340)) {              # 参差下缘
    $g.FillEllipse($INK, $ex, 400, 300, 96)
  }
  # 崖顶六个黑袍人：**满覆盖的惨白傩面**（看不到人脸），咧到耳根的诡笑，手持带血匕首
  $maskBr = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,233,229,221))
  $hole   = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,10,10,14))
  $redPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,186,30,36), 7)
  for ($i = 0; $i -lt 6; $i++) {
    $cx = 236 + $i * 240
    $cy = 150 + (($i % 2) * 20)
    # 站姿躯干（逆光剪影，立于崖顶）
    $g.FillRectangle($INK, $cx-56, $cy+40, 112, 236-$cy)
    $g.FillEllipse($INK, $cx-76, $cy+96, 152, 96)
    # 前伸的双臂（撑在崖沿上俯身）
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,20,20,24), 28)), $cx-48, $cy+84, $cx-92, 232)
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,20,20,24), 28)), $cx+48, $cy+84, $cx+92, 232)
    # **满覆盖面具**：整个头就是面具，没有头发没有兜帽
    $g.FillEllipse($maskBr, $cx-66, $cy-84, 132, 168)
    # 眼窝：两个深洞
    $g.FillEllipse($hole, $cx-44, $cy-38, 32, 26)
    $g.FillEllipse($hole, $cx+12, $cy-38, 32, 26)
    # 鼻孔／眉心竖痕（傩面的骨相感）
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,10,10,14), 5)), $cx, $cy-30, $cx, $cy-2)
    # 咧到耳根的诡笑 + 露牙
    $mouth = New-Object System.Drawing.Drawing2D.GraphicsPath
    $mouth.AddArc($cx-58, $cy+8, 116, 80, 8, 164)
    $mouth.AddArc($cx-48, $cy+24, 96, 46, 172, -164)
    $mouth.CloseFigure()
    $g.FillPath($hole, $mouth)
    for ($t = 0; $t -lt 8; $t++) { $g.FillRectangle($maskBr, $cx - 42 + $t * 11, $cy + 40, 8, 14) }
    # 手中攥着的**带血匕首**
    foreach ($sx in @(-92, 92)) {
      $hx = $cx + $sx
      $g.FillEllipse($INK, $hx-16, 216, 32, 30)                  # 拳
      $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,190,194,200))), $hx-5, 244, 11, 74)  # 刃
      $g.FillRectangle($INK, $hx-11, 240, 23, 10)                # 护手
      $g.DrawLine($redPen, $hx-2, 252, $hx+2, 312)               # 刃上血痕
    }
  }
  # 下方虚空：极淡雾带
  $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(24,150,158,170))), 0, 560, $W, 120)
  $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(16,150,158,170))), 0, 740, $W, 140)
  # ---- 主角：仰头看崖顶、浑身是伤、双臂张开的背影（照参考图的姿态）----
  $g.FillEllipse($INK, 790, 424, 92, 96)                           # 后脑（仰头 → 略向后倾）
  $torso = New-Object System.Drawing.Drawing2D.GraphicsPath
  $torso.AddBezier(796,512, 884,516, 896,606, 888,690)
  $torso.AddLine(888,690, 782,690)
  $torso.AddBezier(782,690, 774,606, 788,512, 796,512)
  $g.FillPath($INK, $torso)                                        # 肩背
  # 双臂大幅张开（参考图的关键姿态）
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,22,22,26), 30)), 800, 556, 612, 600)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,22,22,26), 30)), 884, 556, 1072, 600)
  $g.FillEllipse($INK, 588, 586, 40, 40)                           # 左手
  $g.FillEllipse($INK, 1056, 586, 40, 40)                          # 右手
  # 双腿：一屈一伸
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,22,22,26), 34)), 812, 686, 742, 812)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,22,22,26), 34)), 866, 686, 952, 800)
  # 破碎的衣袂向上翻飞
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(220,24,24,28), 15)), 796, 604, 690, 520)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(190,24,24,28), 13)), 884, 608, 992, 516)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(150,54,56,64), 11)), 806, 656, 716, 640)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(150,54,56,64), 11)), 874, 658, 962, 636)
  # 浑身是伤：背上几道暗红血痕
  $wound = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,178,28,34), 9)
  $g.DrawLine($wound, 806, 552, 856, 616)
  $g.DrawLine($wound, 826, 596, 784, 660)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(220,178,28,34), 6)), 862, 540, 838, 596)
  # 周围墨点飞溅（坠落的速度感）
  $r2 = New-Object System.Random(404)
  for ($i=0; $i -lt 40; $i++) {
    $g.FillEllipse($INK, $r2.Next(300, 1400), $r2.Next(400, 900), $r2.Next(3,9), $r2.Next(3,9))
  }
}

# ---------- 09 没死 · 特写 · 黑暗中一只染血的手攀住石缝 ----------
Make '09_没死' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,14,14,16))
  $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,34,35,40))), 0, 0, 1664, 928)
  $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,10,10,12))), 700, 0, 60, 928)   # 石缝
  # 手：掌 + 五指
  $g.FillEllipse($INK, 620, 430, 250, 190)
  for ($f=0; $f -lt 5; $f++) {
    $g.FillRectangle($INK, 640 + $f*48, 350 + ($f%2)*18, 34, 110)
  }
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,170,28,34), 8)), 640, 470, 800, 520)  # 伤口暗红
  $g.FillEllipse($RED, 700, 500, 44, 30)
}

# ---------- 10 五问 · 中景 · 墨雾中老者剪影 + 跪坐人影 ----------
Make '10_五问' {
  param($g)
  $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,236,237,240))), 0, 0, 1664, 928)
  for ($i=0; $i -lt 9; $i++) {                                   # 墨雾
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(46,120,126,140))), 120+$i*150, 180+($i%3)*130, 420, 260)
  }
  $g.FillEllipse($INK2, 700, 230, 170, 170)                      # 老者头（须发皆白 → 淡灰外圈）
  $g.FillEllipse($GREY, 668, 200, 234, 200)
  $g.FillEllipse($INK2, 700, 230, 170, 170)
  $g.FillRectangle($INK2, 660, 396, 250, 300)                    # 老者身
  $g.FillEllipse($INK, 1160, 560, 120, 120)                      # 跪坐的他
  $g.FillRectangle($INK, 1160, 672, 120, 170)
}

# ---------- 11 江湖新客 · 大远景背拍 · 一个点走向雾深处 ----------
Make '11_江湖新客' {
  param($g)
  $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,238,240,243))), 0, 0, 1664, 928)
  $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(60,150,168,180))), 0, 640, 1664, 288)  # 江面
  $g.DrawLine($PEN_G, 0, 640, 1664, 640)
  $g.FillEllipse($INK, 800, 470, 68, 68)                         # 背影（小）
  $g.FillRectangle($INK, 806, 536, 56, 104)
  $g.DrawLine($PEN_K2, 812, 520, 700, 470)                       # 背上斜插的刀
  $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(40,180,190,200))), 0, 0, 1664, 360)    # 上方雾
}


# ============================================================
# 02 镜分层素材：背景（无人） + 两条人群带（供程序合成人海）
# ============================================================

# ---------- 层·02背景 · 荒原 + 血红残阳 + 中式城郭 + 枯树，**完全无人** ----------
Make '_层_02背景' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,250,249,247))
  $rnd0 = New-Object System.Random(5)
  for ($i=0; $i -lt 260; $i++) {
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($rnd0.Next(8,30), 176,168,150))),
      $rnd0.Next(-60, $W), 640 + $rnd0.Next(0, 270), $rnd0.Next(70,260), $rnd0.Next(10,42))
  }
  $g.DrawLine($PEN_G, 0, 690, $W, 690)
  # 血红残阳：唯一暖色
  $g.FillEllipse($RED, 1188, 132, 216, 216)
  $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70,190,32,38))), 1160, 108, 272, 264)
  # 中式城郭
  $wall = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,203,206,212))
  $g.FillRectangle($wall, 726, 664, 386, 30)
  for ($x = 732; $x -lt 1108; $x += 26) { $g.FillRectangle($wall, $x, 656, 15, 10) }
  $hole = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,250,249,247))
  $g.FillRectangle($hole, 896, 670, 38, 24); $g.FillEllipse($hole, 896, 658, 38, 24)
  foreach ($tx in @(772, 1016)) {
    $g.FillRectangle($wall, $tx, 636, 48, 30)
    $roof = New-Object System.Drawing.Drawing2D.GraphicsPath
    $roof.AddLine($tx-16, 640); $roof.AddLine($tx+64, 640); $roof.AddLine($tx+24, 610); $roof.AddLine($tx-16, 640)
    $g.FillPath($wall, $roof)
  }
  # 枯树
  $tp = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), 9)
  $g.DrawLine($tp, 1408, 700, 1408, 508)
  foreach ($b in @(@(1408,556,1330,470),@(1408,576,1490,492),@(1408,608,1352,540),@(1408,624,1466,556))) {
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), 6)), $b[0], $b[1], $b[2], $b[3])
  }
}

# ---------- 层·02人群A · 极密人群带（下半幅塞满，供合成中景） ----------
Make '_层_02人群A' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,252,251,249))
  $rnd = New-Object System.Random(31337)
  for ($i = 0; $i -lt 230; $i++) {
    $x = -20 + $rnd.Next(0, 1700)
    $depth = $rnd.Next(0, 100) / 100.0
    $y = 520 + [int]($depth * 300)
    $scale = 0.55 + $depth * 1.15
    $k = $rnd.Next(0, 100)
    if ($k -lt 34) {                       # 佝偻站立
      $bh = [int]((52 + $rnd.Next(0,44)) * $scale)
      $g.FillEllipse($INK, $x, $y - $bh, [int](15*$scale), [int](15*$scale))
      $g.FillRectangle($INK, $x + 2, $y - $bh + [int](13*$scale), [int](9*$scale), $bh - [int](13*$scale))
      $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), [int](4*$scale))), $x+4, $y, $x+[int](11*$scale), $y+[int](15*$scale))
      $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), [int](4*$scale))), $x+5, $y, $x-[int](2*$scale), $y+[int](15*$scale))
    } elseif ($k -lt 60) {                 # 爬行／匍匐
      $g.FillEllipse($INK, $x, $y-[int](13*$scale), [int](14*$scale), [int](12*$scale))
      $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), [int](9*$scale))), $x+[int](11*$scale), $y-[int](7*$scale), $x+[int](50*$scale), $y-[int](1*$scale))
      $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), [int](5*$scale))), $x+[int](22*$scale), $y-[int](3*$scale), $x+[int](30*$scale), $y+[int](10*$scale))
    } elseif ($k -lt 76) {                 # 伏地不起
      $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(230,24,24,28), [int](8*$scale))), $x, $y, $x+[int]((26+$rnd.Next(0,20))*$scale), $y+[int](2*$scale))
    } elseif ($k -lt 88) {                 # 拄杖
      $bh = [int]((58 + $rnd.Next(0,26)) * $scale)
      $g.FillEllipse($INK, $x, $y - $bh, [int](14*$scale), [int](14*$scale))
      $g.FillRectangle($INK, $x + 2, $y - $bh + [int](12*$scale), [int](8*$scale), $bh - [int](12*$scale))
      $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), [int](3*$scale))), $x+[int](13*$scale), $y-[int]($bh*0.7), $x+[int](23*$scale), $y)
    } else {                               # 抱襁褓
      $bh = [int]((50 + $rnd.Next(0,18)) * $scale)
      $g.FillEllipse($INK, $x, $y - $bh, [int](14*$scale), [int](14*$scale))
      $g.FillRectangle($INK, $x + 2, $y - $bh + [int](12*$scale), [int](9*$scale), $bh - [int](12*$scale))
      $g.FillEllipse($INK, $x - [int](5*$scale), $y - [int](28*$scale), [int](15*$scale), [int](12*$scale))
    }
  }
}

# ---------- 层·02人群B · 远景色带（更小更密，供铺远景） ----------
Make '_层_02人群B' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,252,251,249))
  $rnd = New-Object System.Random(90210)
  for ($row = 0; $row -lt 3; $row++) {
    $baseY = 360 + $row * 84
    $sc = 0.42 + $row * 0.28
    for ($i = 0; $i -lt 190; $i++) {
      $x = -20 + $rnd.Next(0, 1700)
      $y = $baseY + $rnd.Next(-16, 17)
      $k = $rnd.Next(0, 100)
      if ($k -lt 55) {
        $bh = [int]((46 + $rnd.Next(0, 30)) * $sc)
        $g.FillEllipse($INK, $x, $y - $bh, [int](12*$sc), [int](12*$sc))
        $g.FillRectangle($INK, $x + 1, $y - $bh + [int](10*$sc), [int](7*$sc), $bh - [int](10*$sc))
      } elseif ($k -lt 82) {
        $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(235,24,24,28), [int](7*$sc))), $x, $y, $x + [int]((22+$rnd.Next(0,16))*$sc), $y)
      } else {
        $g.FillEllipse($INK, $x, $y - [int](10*$sc), [int](12*$sc), [int](10*$sc))
        $g.FillRectangle($INK, $x + 1, $y, [int](6*$sc), [int](12*$sc))
      }
    }
  }
}

Write-Output ''
Write-Output ('共 ' + (Get-ChildItem $OUT -Filter *.png | Measure-Object).Count + ' 张 → ' + $OUT)
