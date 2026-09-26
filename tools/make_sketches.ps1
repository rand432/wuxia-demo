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


# ---------- 03 纸醉金迷（以物代事：几只从画外伸进来的手**在中间碰杯**，酒溅出来，垫桌脚的是残破的书）----------
Make '03_宫殿纸醉金迷' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,248,246,242))
  # 案面
  $g.FillRectangle($INK2, 0, 600, $W, 328)
  $g.FillRectangle($INK, 0, 592, $W, 24)
  $CX = 832; $CY = 470                       # 碰杯的中心点
  $wine = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,150,22,30))
  # 四只手从画面四角伸向中心，杯子在中心相撞
  $arms = @(
    @{x= 120; y=690; tx=$CX-150; ty=$CY+86},   # 左下
    @{x=1540; y=690; tx=$CX+150; ty=$CY+86},   # 右下
    @{x= 150; y=170; tx=$CX-176; ty=$CY-72},   # 左上
    @{x=1520; y=170; tx=$CX+176; ty=$CY-72}    # 右上
  )
  foreach ($a in $arms) {
    $pw = [int](48 + [math]::Abs($a.y-$CY)/60)
    $penArm = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,26,30), $pw)
    $g.DrawLine($penArm, $a.x, $a.y, $a.tx, $a.ty)
    $g.FillEllipse($INK, $a.tx-42, $a.ty-18, 84, 62)          # 手
    # 杯：从手的位置指向中心，杯口朝中心
    $dx = $CX - $a.tx; $dy = $CY - $a.ty
    $len = [math]::Sqrt($dx*$dx + $dy*$dy); if ($len -lt 1) { $len = 1 }
    $ux = $dx/$len; $uy = $dy/$len
    $bx = $a.tx + $ux*96; $by = $a.ty + $uy*96
    $cup = New-Object System.Drawing.Drawing2D.GraphicsPath
    $cup.AddLine([int]($a.tx + $ux*92 - $uy*26), [int]($a.ty + $uy*92 + $ux*26))
    $cup.AddLine([int]($bx + $ux*40 - $uy*30), [int]($by + $uy*40 + $ux*30))
    $cup.AddLine([int]($bx + $ux*40 + $uy*30), [int]($by + $uy*40 - $ux*30))
    $cup.AddLine([int]($a.tx + $ux*92 + $uy*26), [int]($a.ty + $uy*92 - $ux*26))
    $cup.CloseFigure()
    $g.FillPath($INK, $cup)
    $g.FillEllipse($wine, [int]($bx + $ux*28 - $uy*22), [int]($by + $uy*28 + $ux*22), 44, 18)  # 杯中红酒
  }
  # 碰杯处溅开的酒（全图唯一暖色，也是画面的中心）
  $g.FillEllipse($wine, $CX-96, $CY-62, 192, 132)
  for ($i=0; $i -lt 16; $i++) {
    $ang = $i * 22.5 * [math]::PI / 180
    $r = 60 + ($i % 4) * 34
    $g.FillEllipse($wine, [int]($CX + [math]::Cos($ang)*$r - 16), [int]($CY + [math]::Sin($ang)*$r*0.7 - 12), 32, 24)
  }
  # 酒顺着案沿往下淌
  for ($i=0; $i -lt 5; $i++) {
    $x = 620 + $i * 96
    $g.FillRectangle($wine, $x, 616, 30, 90 + $i*26)
    $g.FillEllipse($wine, $x + 3, 690 + $i*28, 24, 34)
  }
  # 案腿 + 垫在桌脚的三本残破的书
  $g.FillRectangle($INK, 130, 700, 56, 228)
  $g.FillRectangle($INK, 1420, 700, 56, 228)
  for ($i=0; $i -lt 3; $i++) {
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,236,232,224))),
      104 - $i*7, 928 - 17 - $i*19, 108 + $i*14, 17)
    $g.FillRectangle($INK, 104 - $i*7, 928 - 17 - $i*19, 108 + $i*14, 4)
  }
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

# ---------- 05 婚礼（古代婚房：喜烛/喜帐/喜床；他穿新郎吉服靠在门框边）----------
Make '05_红烛婚礼' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,244,240,234))
  $RED = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,158,26,32))
  # 左侧：门框（深墨竖条），他靠在这
  $g.FillRectangle($INK, 0, 0, 150, 928)
  $g.FillRectangle($INK, 150, 0, 22, 928)
  # 右侧：婚房内景
  $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,228,222,212))), 172, 0, 1492, 928)
  # 两根高烛台 + 喜烛（红）
  foreach ($cx in @(560, 1180)) {
    $g.FillRectangle($INK, $cx, 430, 26, 400)
    $g.FillEllipse($INK, $cx-24, 812, 74, 40)
    $g.FillEllipse($RED, $cx-6, 344, 38, 92)
  }
  # 喜帐：从上方垂下的红绸
  foreach ($dx in @(400, 760, 1120, 1420)) {
    $dr = New-Object System.Drawing.Drawing2D.GraphicsPath
    $dr.AddLine($dx, 0); $dr.AddLine($dx+130, 0)
    $dr.AddBezier($dx+130, 0, $dx+150, 200, $dx+96, 330, $dx+40, 420)
    $dr.AddBezier($dx+40, 420, $dx-16, 330, $dx-20, 160, $dx, 0); $dr.CloseFigure()
    $g.FillPath($RED, $dr)
  }
  # 喜床一角（右侧）
  $g.FillRectangle($INK2, 1180, 640, 484, 288)
  $g.FillRectangle($RED, 1200, 600, 464, 60)
  # **他：穿新郎吉服，靠在门框边**
  $px = 300
  $g.FillEllipse($INK, $px-46, 236, 116, 120)
  $robe = New-Object System.Drawing.Drawing2D.GraphicsPath
  $robe.AddBezier($px-64, 356, $px+84, 360, $px+96, 560, $px+88, 748)
  $robe.AddLine($px+88, 748, $px-80, 748)
  $robe.AddBezier($px-80, 748, $px-92, 560, $px-72, 356, $px-64, 356)
  $g.FillPath($RED, $robe)
  $g.FillRectangle($INK, $px-80, 560, 176, 30)
  $g.FillEllipse($RED, $px-26, 420, 84, 84)
  $penArm = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), 28)
  $g.DrawLine($penArm, $px-52, 400, 130, 470)
  $g.FillRectangle($INK, $px-18, 748, 52, 150)
  $g.FillRectangle($INK, $px+46, 748, 52, 150)
  $g.FillEllipse($INK, $px-38, 878, 92, 40)
  $g.FillEllipse($INK, $px+28, 878, 92, 40)
  $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(50,120,124,132))), 240, 890, 460, 40)
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

# ============================================================
# 07 暗算 · 扩写为五段：翻杯围拢 → 混战中刀 → 师傅的话 → 宗门焚毁 → 被逼崖边
# 来源：用户看了参考片《剑意》3-39s「师门毁灭」后重排的结构
# ============================================================

# ---------- 07a 翻杯围拢（室内酒宴，人影成弧围拢；必须画成"人"不是柱子）----------
Make '07a_翻杯围拢' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,246,245,242))
  $g.FillRectangle($INK2, 0, 620, $W, 308)                       # 长案
  $g.FillRectangle($INK, 0, 700, $W, 50)
  # 打翻的酒杯 + 淌开的酒
  $g.FillEllipse($INK, 340, 500, 130, 100)
  $g.FillRectangle($INK, 396, 470, 22, 50)
  $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,126,26,32))), 300, 610, 300, 44)
  # 人影：成弧围拢，每个人都有头/肩/双臂，姿态各不相同
  $cfg = @(
    @{x=150; y=470; h=250; lean= 12},
    @{x=390; y=420; h=300; lean=  8},
    @{x=640; y=396; h=320; lean=  2},
    @{x=890; y=420; h=300; lean= -8},
    @{x=1130; y=470; h=250; lean=-12},
    @{x=1330; y=560; h=180; lean=-16}
  )
  foreach ($c in $cfg) {
    $x = $c.x; $y = $c.y; $h = $c.h; $ln = $c.lean
    $g.FillEllipse($INK, $x, $y, 74, 74)                                          # 头
    $sh = New-Object System.Drawing.Drawing2D.GraphicsPath                          # 肩+躯干（有肩宽，不是矩形）
    $sh.AddBezier($x-6, $y+66, $x+80, $y+66, $x+86, $y+$h, $x+80, 700)
    $sh.AddLine($x+80, 700, $x-18, 700)
    $sh.AddBezier($x-18, 700, $x-24, $y+$h, $x-18, $y+66, $x-6, $y+66)
    $g.FillPath($INK, $sh)
    # 双臂：向外张开或前伸（关键：有手臂才像人）
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), 22)),
      $x+8, $y+112, $x-70, $y+150+$ln)
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), 22)),
      $x+66, $y+112, $x+132, $y+150-$ln)
    # 眼里两点冷光
    $g.FillEllipse($PALE, $x+16, $y+30, 15, 10)
    $g.FillEllipse($PALE, $x+44, $y+30, 15, 10)
  }
  # 前景：他自己（背对，跪坐在案前，握刀）
  $g.FillEllipse($INK, 796, 402, 96, 96)
  $k = New-Object System.Drawing.Drawing2D.GraphicsPath
  $k.AddBezier(802,498, 888,502, 900,620, 890,760); $k.AddLine(890,760, 800,760)
  $k.AddBezier(800,760, 790,620, 792,498, 802,498); $g.FillPath($INK,$k)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), 24)), 810, 560, 742, 400)  # 举起的手/刀柄
  $g.FillRectangle($INK, 706, 336, 30, 76)                       # 刀柄
}

# ---------- 07b 混战中刀（被围攻，墨爆，胸口一道暗红）----------
Make '07b_混战中刀' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,244,243,240))
  $rnd = New-Object System.Random(19)
  for ($i = 0; $i -lt 9; $i++) {                                  # 四周扑上来的围攻者
    $a = $i * 40 * [math]::PI / 180
    $x = 832 + [math]::Cos($a) * (330 + $rnd.Next(0, 190))
    $y = 470 + [math]::Sin($a) * (230 + $rnd.Next(0, 130))
    $hh = 120 + $rnd.Next(0, 90)
    $g.FillEllipse($INK, [int]$x, [int]$y, 96, 96)
    $g.FillRectangle($INK, [int]$x + 14, [int]$y + 88, 68, $hh)
    $ang = -50 + $rnd.Next(0, 100)
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), 14)),
      [int]($x + 48), [int]($y + 110), [int]($x + 48 + 150 * [math]::Cos($a)), [int]($y + 110 + $ang))
  }
  # 主角：被围在正中，屈身撑地
  $g.FillEllipse($INK, 780, 400, 100, 104)
  $t = New-Object System.Drawing.Drawing2D.GraphicsPath
  $t.AddBezier(786,496, 878,500, 892,596, 882,684); $t.AddLine(882,684, 772,684)
  $t.AddBezier(772,684, 762,596, 776,496, 786,496); $g.FillPath($INK,$t)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), 28)), 790, 540, 640, 690)   # 撑地的手
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), 26)), 878, 552, 1010, 700)
  # 胸口一道暗红
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,182,26,32), 12)), 800, 540, 866, 606)
  $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,182,26,32))), 846, 596, 46, 30)
  # 墨点炸开
  for ($i=0; $i -lt 90; $i++) {
    $g.FillEllipse($INK, $rnd.Next(60, 1600), $rnd.Next(160, 900), $rnd.Next(4,16), $rnd.Next(4,16))
  }
  for ($i=0; $i -lt 12; $i++) {                                   # 甩出去的墨线
    $x0 = $rnd.Next(300, 1300); $y0 = $rnd.Next(300, 700)
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200,24,24,28), $rnd.Next(3,9))),
      $x0, $y0, $x0 + $rnd.Next(-320,320), $y0 + $rnd.Next(-220,220))
  }
}

# ---------- 07c 师傅的话（暗底闪回，老者与跪坐的他）----------
Make '07c_师傅的话' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,26,27,31))
  for ($i=0; $i -lt 7; $i++) {                                    # 墨雾
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(34,150,158,175))),
      20 + $i * 230, 80 + ($i % 3) * 200, 560, 320)
  }
  # 师傅：一整个身形（头 + 长袍），头身相连
  $robe = New-Object System.Drawing.Drawing2D.GraphicsPath
  $robe.AddBezier(688, 300, 1000, 304, 1046, 640, 1024, 928)
  $robe.AddLine(1024, 928, 664, 928)
  $robe.AddBezier(664, 928, 642, 640, 688, 300, 688, 300)
  $g.FillPath($INK2, $robe)                                       # 长袍
  $g.FillEllipse($GREY, 748, 132, 200, 190)                       # 头部外圈（须发皆白）
  $g.FillEllipse($INK, 774, 158, 148, 150)                        # 面部暗部
  $g.FillRectangle($INK2, 806, 300, 84, 60)                       # 颈/领
  # 他跪坐在前下方（背对画面，小）
  $g.FillEllipse($INK, 292, 646, 78, 82)
  $k = New-Object System.Drawing.Drawing2D.GraphicsPath
  $k.AddBezier(298,726, 372,730, 382,812, 376,892); $k.AddLine(376,892, 286,892)
  $k.AddBezier(286,892, 278,812, 290,726, 298,726); $g.FillPath($INK,$k)
}

# ---------- 07d 宗门焚毁（夜，山门牌楼在烈火中）----------
Make '07d_宗门焚毁' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,20,20,24))
  $fire  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,206,116,28))
  $fire2 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,246,196,96))
  $rnd = New-Object System.Random(41)
  # 火：大量不规则堆叠，越靠中越亮（不要规整椭圆）
  for ($i = 0; $i -lt 150; $i++) {
    $x = 480 + $rnd.Next(0, 760); $y = 340 + $rnd.Next(0, 380)
    $g.FillEllipse($fire, $x, $y, $rnd.Next(70, 240), $rnd.Next(60, 260))
  }
  for ($i = 0; $i -lt 80; $i++) {
    $x = 660 + $rnd.Next(0, 380); $y = 470 + $rnd.Next(0, 260)
    $g.FillEllipse($fire2, $x, $y, $rnd.Next(50, 170), $rnd.Next(40, 170))
  }
  for ($i = 0; $i -lt 46; $i++) {                                 # 窜起的火舌
    $x = 560 + $rnd.Next(0, 580); $h = 90 + $rnd.Next(0, 260)
    $fl = New-Object System.Drawing.Drawing2D.GraphicsPath
    $fl.AddLine($x, 760); $fl.AddLine($x + 24, 760 - $h); $fl.AddLine($x + 48, 760); $fl.CloseFigure()
    $g.FillPath($fire2, $fl)
  }
  # 山门牌楼剪影（压在火前）
  $g.FillRectangle($INK, 640, 452, 44, 320); $g.FillRectangle($INK, 1052, 452, 44, 320)
  $g.FillRectangle($INK, 596, 418, 548, 40)
  $roof = New-Object System.Drawing.Drawing2D.GraphicsPath
  $roof.AddLine(560, 422); $roof.AddLine(1180, 422); $roof.AddLine(1086, 352); $roof.AddLine(654, 352); $roof.CloseFigure()
  $g.FillPath($INK, $roof)
  $g.FillRectangle($INK, 736, 306, 268, 50)                       # 匾额（不写字，后期程序叠）
  $g.DrawRectangle((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(170,246,196,96), 5)), 736, 306, 268, 50)
  # 黑烟冲天
  for ($i = 0; $i -lt 30; $i++) {
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($rnd.Next(30, 95), 16,16,20))),
      $rnd.Next(160, 1440), $rnd.Next(-40, 300), $rnd.Next(180, 460), $rnd.Next(130, 320))
  }
}

# ---------- 07e 被逼崖边（他在崖沿，追兵自左下逼来，天边一线火光）----------
Make '07e_被逼崖边' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,241,241,239))
  $g.FillRectangle($INK, 0, 758, $W, 170)                        # 崖沿地面
  # 天边一线火光（低矮不规则）
  $rndF = New-Object System.Random(77)
  $fb  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(190,208,118,30))
  $fb2 = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235,246,196,96))
  for ($i = 0; $i -lt 70; $i++) {
    $g.FillEllipse($fb, 1080 + $rndF.Next(0, 520), 712 + $rndF.Next(0, 46), $rndF.Next(50, 150), $rndF.Next(16, 46))
  }
  for ($i = 0; $i -lt 30; $i++) {
    $g.FillEllipse($fb2, 1140 + $rndF.Next(0, 440), 722 + $rndF.Next(0, 32), $rndF.Next(36, 96), $rndF.Next(12, 30))
  }
  # 追兵：左下，小，成散兵线压过来
  $rnd = New-Object System.Random(63)
  for ($i = 0; $i -lt 6; $i++) {
    $x = 60 + $i * 108; $hh = 70 + $rnd.Next(0, 34)
    $g.FillEllipse($INK, $x, 758 - $hh, 40, 40)
    $g.FillRectangle($INK, $x + 6, 758 - $hh + 36, 28, $hh - 36)
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), 8)),
      $x + 20, 758 - $hh + 52, $x + 44, 758 - $hh + 84)
  }
  # 他：站在崖沿，大得多，背对画面，孤身一人
  $g.FillEllipse($INK, 938, 402, 92, 96)
  $k = New-Object System.Drawing.Drawing2D.GraphicsPath
  $k.AddBezier(944,498, 1032,502, 1044,632, 1034,772); $k.AddLine(1034,772, 930,772)
  $k.AddBezier(930,772, 920,632, 932,498, 944,498); $g.FillPath($INK,$k)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), 26)), 946, 560, 890, 646)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), 26)), 1028, 560, 1084, 646)
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

# ---------- 09 没死（极简：几乎全黑，只有一只手从下方伸上来扣住石缝）----------
Make '09_没死' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,14,14,16))
  # 一道竖直的石缝（唯一的结构）
  $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,26,27,32))), 806, 120, 52, 700)
  $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,8,8,10))), 824, 120, 16, 700)
  # 一只手从下方伸上来，五指扣进石缝
  $hand = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,38,39,45))
  $g.FillEllipse($hand, 754, 552, 168, 132)                      # 掌
  for ($f=0; $f -lt 4; $f++) {                                   # 四指分开，扣住石缝
    $fx = 782 + $f * 34
    $g.FillRectangle($hand, $fx, 486, 26, 92)
    $g.FillEllipse($hand, $fx - 3, 468, 32, 36)
  }
  $g.FillRectangle($hand, 716, 596, 34, 84)                      # 拇指
  $g.FillEllipse($hand, 706, 664, 44, 42)
  # 掌心的暗影（让手读得出来）
  $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(180,14,14,18))), 796, 596, 96, 62)
  # 指节上的暗红（唯一一点暖色）
  $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,168,24,30))), 800, 520, 34, 22)
  $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(200,168,24,30))), 860, 540, 26, 18)
  # 石屑
  $rnd = New-Object System.Random(5)
  for ($i=0; $i -lt 24; $i++) {
    $g.FillEllipse($INK2, $rnd.Next(700, 960), $rnd.Next(620, 900), $rnd.Next(3,10), $rnd.Next(3,10))
  }
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

# ---------- 11 江湖新客（一笔墨路：一道书法枯笔当路，他走在上面）----------
Make '11_江湖新客' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,242,242,240))
  # 一道书法感的枯笔墨痕，从左下斜斜拉向雾的深处
  $stroke = New-Object System.Drawing.Drawing2D.GraphicsPath
  $stroke.AddBezier(60, 800, 380, 742, 620, 700, 900, 612)
  $stroke.AddBezier(900, 612, 1120, 548, 1300, 512, 1470, 492)
  $stroke.AddLine(1470, 452)
  $stroke.AddBezier(1470, 452, 1290, 470, 1104, 508, 884, 574)
  $stroke.AddBezier(884, 574, 604, 660, 366, 704, 40, 762)
  $stroke.CloseFigure()
  $g.FillPath($INK, $stroke)
  # 枯笔飞白（沿笔痕撒一些断点）
  $rnd = New-Object System.Random(88)
  for ($i=0; $i -lt 90; $i++) {
    $t = $rnd.Next(0, 100) / 100.0
    $x = 60 + $t * 1410
    $y = 780 - $t * 300 + $rnd.Next(-16, 17)
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($rnd.Next(60,190), 24,24,28))),
      $x, $y, $rnd.Next(6,34), $rnd.Next(4,14))
  }
  # 他的背影：很小，走在墨痕上，背插长刀
  $g.FillEllipse($INK, 986, 492, 44, 46)
  $k = New-Object System.Drawing.Drawing2D.GraphicsPath
  $k.AddBezier(990,538, 1032,540, 1038,586, 1034,632); $k.AddLine(1034,632, 982,632)
  $k.AddBezier(982,632, 978,586, 986,538, 990,538); $g.FillPath($INK,$k)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), 11)), 992, 512, 944, 470)   # 背上的刀
  # 雾：用渐变把路的尽头软软地吃掉（不要硬边）
  $rectF = New-Object System.Drawing.RectangleF(980, 0, 684, 928)
  $lgb = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rectF,
    [System.Drawing.Color]::FromArgb(0,242,242,240), [System.Drawing.Color]::FromArgb(235,242,242,240), 0.0)
  $g.FillRectangle($lgb, $rectF)
  $rectF2 = New-Object System.Drawing.RectangleF(0, 0, 260, 928)
  $lgb2 = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rectF2,
    [System.Drawing.Color]::FromArgb(200,242,242,240), [System.Drawing.Color]::FromArgb(0,242,242,240), 0.0)
  $g.FillRectangle($lgb2, $rectF2)
}

Write-Output ''
Write-Output ('共 ' + (Get-ChildItem $OUT -Filter *.png | Measure-Object).Count + ' 张 → ' + $OUT)
