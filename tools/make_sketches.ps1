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


# ---------- 03 纸醉金迷（用户草图版：两只大酒杯在中间相碰，碰撞点放射出线条，下方桌面）----------
Make '03_宫殿纸醉金迷' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,246,243,236))
  $rnd = New-Object System.Random(303)
  for ($k=0; $k -lt 900; $k++) {
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($rnd.Next(6,22), 120,116,104))),
      $rnd.Next(0,$W), $rnd.Next(0,$H), $rnd.Next(1,4), $rnd.Next(1,3))
  }
  $CX = 832; $CY = 430
  $wine = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,146,22,30))
  for ($k=0; $k -lt 30; $k++) {
    $ang = ($k * 12 + $rnd.Next(-4,5)) * [math]::PI / 180
    $r0 = 60 + $rnd.Next(0,40); $r1 = $r0 + 90 + $rnd.Next(0,240)
    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($rnd.Next(70,180), 26,27,31), $rnd.Next(2,7))
    $g.DrawLine($pen, [int]($CX+[math]::Cos($ang)*$r0), [int]($CY+[math]::Sin($ang)*$r0),
                     [int]($CX+[math]::Cos($ang)*$r1), [int]($CY+[math]::Sin($ang)*$r1))
  }
  # 陶瓷酒盏（不是高脚杯）：宽浅盏身 + 短圈足，两盏相碰
  $cups = @(@{cx=$CX-232; cy=$CY+92; rot=-30}, @{cx=$CX+232; cy=$CY+92; rot=30})
  foreach ($c in $cups) {
    $g.ResetTransform()
    $g.TranslateTransform($c.cx, $c.cy)
    $g.RotateTransform($c.rot)
    $bowl = New-Object System.Drawing.Drawing2D.GraphicsPath
    $bowl.AddBezier(-92,-56, -86,24, -34,54, 0,54)
    $bowl.AddBezier(0,54, 34,54, 86,24, 92,-56)
    $bowl.AddBezier(92,-56, 46,-78, -46,-78, -92,-56)
    $g.FillPath($INK, $bowl)
    # 盏口（口沿）
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,246,243,236))), -92, -74, 184, 38)
    $g.DrawEllipse((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 7)), -92, -74, 184, 38)
    # 盏中酒
    $g.FillEllipse($wine, -78, -66, 156, 26)
    # 短圈足（没有细高脚）
    $g.FillRectangle($INK, -30, 48, 60, 18)
    $g.FillEllipse($INK, -40, 60, 80, 18)
    $g.ResetTransform()
  }
  for ($k=0; $k -lt 26; $k++) {
    $ang = $rnd.Next(0,360) * [math]::PI / 180
    $r = [math]::Pow($rnd.NextDouble(), 0.5) * 110
    $rr = 20 + $rnd.Next(0,46)
    $g.FillEllipse($wine, [int]($CX+[math]::Cos($ang)*$r-$rr/2), [int]($CY+[math]::Sin($ang)*$r*0.8-$rr/2), $rr, [int]($rr*0.8))
  }
  for ($k=0; $k -lt 18; $k++) {
    $ang = $rnd.Next(0,360) * [math]::PI / 180
    $r = 110 + $rnd.Next(0,190)
    $g.FillEllipse($wine, [int]($CX+[math]::Cos($ang)*$r), [int]($CY+[math]::Sin($ang)*$r*0.75), $rnd.Next(5,16), $rnd.Next(4,12))
  }
  $table = New-Object System.Drawing.Drawing2D.GraphicsPath
  $table.AddLine(120, 700); $table.AddLine(1544, 700); $table.AddLine(1664, 928); $table.AddLine(0, 928)
  $table.CloseFigure()
  $g.FillPath($INK2, $table)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 14)), 120, 700, 1544, 700)
  for ($k=0; $k -lt 5; $k++) {
    $x = 620 + $k * 96 + $rnd.Next(-14,14)
    $hh = 50 + $rnd.Next(0,110)
    $g.FillRectangle($wine, $x, 706, $rnd.Next(14,28), $hh)
    $g.FillEllipse($wine, $x, 706+$hh-6, $rnd.Next(16,28), $rnd.Next(18,32))
  }
  for ($k=0; $k -lt 3; $k++) {
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,238,234,226))), 300-$k*7, 660-$k*18, 122+$k*12, 17)
    $g.FillRectangle($INK, 300-$k*7, 660-$k*18, 122+$k*12, 4)
  }
  $g.FillEllipse($INK, 1180, 640, 122, 56)
  $g.FillRectangle($INK, 1236, 612, 22, 42)
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
  # 打翻的陶制酒盏（侧倒：宽浅盏身 + 短圈足，没有细高脚）+ 淌开的酒
  $g.FillEllipse($INK, 318, 504, 176, 94)                      # 侧倒的盏身
  $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,246,245,242))), 456, 518, 46, 66)
  $g.DrawEllipse((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), 6)), 456, 518, 46, 66)
  $g.FillEllipse($INK, 292, 556, 60, 46)                       # 短圈足，贴着案面
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

# ---------- 07e 被逼崖边（用户草图版：夜色，左侧大树，他靠在树干边警惕侧望；灌木线外全是追杀的敌人）----------
Make '07e_被逼崖边' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,238,238,236))
  $rnd = New-Object System.Random(707)
  for ($k=0; $k -lt 700; $k++) {
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($rnd.Next(6,20), 120,116,104))),
      $rnd.Next(0,$W), $rnd.Next(0,$H), $rnd.Next(1,4), $rnd.Next(1,3))
  }
  $far = @()
  foreach ($pt in @(@(0,404),@(70,330),@(120,378),@(180,316),@(240,392),@(300,344),@(360,410))) {
    $far += New-Object System.Drawing.Point($pt[0], $pt[1])
  }
  $g.DrawLines((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(150,40,42,48), 7)), $far)
  $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,228,228,224))), 1380, 46, 148, 148)
  # 大树：树冠（大团墨，边缘有碎叶）+ 分叉的树干（V 形露在树冠下方）
  $g.FillEllipse($INK, 190, 120, 290, 210)
  for ($k=0; $k -lt 190; $k++) {
    $a = $rnd.Next(0,360) * [math]::PI / 180
    $r = 100 + $rnd.Next(0,104)
    $g.FillEllipse($INK, [int](336+[math]::Cos($a)*$r), [int](222+[math]::Sin($a)*$r*0.78), $rnd.Next(16,56), $rnd.Next(12,42))
  }
  # 树干：从下往上，在树冠下方分成两叉（V 要露出来）
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 74)), 336, 470, 348, 764)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 50)), 340, 452, 264, 286)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 50)), 348, 452, 420, 288)
  # **他：靠在树干右侧，小，侧脸朝右警惕张望**
  $px = 476; $py = 520
  $g.FillEllipse($INK, $px-38, $py-6, 76, 80)
  $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,238,238,236))), $px-16, $py+16, 46, 40)
  $g.FillEllipse($INK, $px+8, $py+24, 13, 11)
  $g.FillEllipse($INK, $px-42, $py-26, 84, 30)
  $body = New-Object System.Drawing.Drawing2D.GraphicsPath
  $body.AddBezier($px-44, $py+68, $px+36, $py+68, $px+40, $py+196, $px+36, $py+246)
  $body.AddLine($px+36, $py+246, $px-48, $py+246)
  $body.AddBezier($px-48, $py+246, $px-44, $py+196, $px-50, $py+68, $px-44, $py+68)
  $g.FillPath($INK, $body)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 22)), $px-34, $py+100, 384, $py+152)
  $g.FillEllipse($INK, 366, $py+144, 46, 36)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 20)), $px+28, $py+112, $px+62, $py+172)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 14)), $px+32, $py+178, $px+88, $py+238)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 32)), $px-18, $py+244, $px-26, $py+348)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 32)), $px+22, $py+244, $px+42, $py+346)
  # 灌木线：横贯画面的一条参差不齐的墨带
  for ($x=-60; $x -lt $W+60; $x+=34) {
    $hh = 44 + $rnd.Next(0,64)
    $g.FillEllipse($INK, $x, 646 + $rnd.Next(-22,14), 96, $hh)
  }
  $g.FillRectangle($INK, 0, 700, $W, 228)
  # **灌木外全是追杀的敌人**（只露头与肩，越往右越小）
  $ex = 560
  while ($ex -lt $W + 40) {
    $sc = 1.0 - ($ex - 560) / 1500.0 * 0.48
    $hw = [int](64 * $sc); $hh = [int](72 * $sc)
    $ty = 646 - $hh + $rnd.Next(-16, 10)
    $g.FillEllipse($INK, $ex, $ty, $hw, $hh)
    $g.FillRectangle($INK, $ex - 10, $ty + $hh - 8, $hw + 20, [int](46*$sc))
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), [int](9*$sc))),
      $ex + $hw + 6, $ty + $hh + 10, $ex + $hw + [int](48*$sc), $ty + [int](8*$sc))
    $ex += [int]($hw * (1.55 + $rnd.NextDouble() * 0.5))
  }
}
# ---------- 08 坠崖（侧面机位：崖在右，面具人站在崖沿；主角在崖壁外横着翻滚下坠）----------
Make '08_坠崖' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,247,245,240))
  $rnd = New-Object System.Random(808)
  $PALE = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,246,244,240))
  for ($k=0; $k -lt 800; $k++) {
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($rnd.Next(6,20), 120,116,104))),
      $rnd.Next(0,$W), $rnd.Next(0,$H), $rnd.Next(1,4), $rnd.Next(1,3))
  }
  for ($k=0; $k -lt 130; $k++) {
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($rnd.Next(5,18), 116,122,134))),
      $rnd.Next(-300,1160), 420 + $rnd.Next(0,540), $rnd.Next(320,980), $rnd.Next(110,320))
  }
  # 崖：右半幅，用密集墨块铺实
  for ($yy = 356; $yy -lt $H + 80; $yy += 22) {
    for ($xx = 740; $xx -lt $W + 80; $xx += 22) {
      $edgeY = 560 + (($xx - 820) / 844.0) * (392 - 560) + $rnd.Next(-16, 17)
      if ($yy -ge $edgeY) { $g.FillEllipse($INK, $xx - 26, $yy - 26, 56, 56) }
    }
  }
  for ($k=0; $k -lt 240; $k++) {
    $x = 840 + $rnd.Next(0, 824); $y = 470 + $rnd.Next(0, 440); $h = $rnd.Next(50, 190)
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($rnd.Next(26,96), 246,244,240), $rnd.Next(2,7))),
      $x, $y, $x + $rnd.Next(-7,8), $y + $h)
  }
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 18)), 818, 558, 1664, 390)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 18)), 824, 556, 762, 928)
  # 崖顶三个斗笠黑面具人（原点在脚上）
  foreach ($c in @(@{x=1010; y=526; s=0.92}, @{x=1245; y=484; s=0.84}, @{x=1470; y=446; s=0.76})) {
    $g.ResetTransform()
    $g.TranslateTransform($c.x, $c.y)
    $g.ScaleTransform($c.s, $c.s)
    $cloak = New-Object System.Drawing.Drawing2D.GraphicsPath
    $cloak.AddBezier(-104, -232, 104, -232, 158, -70, 176, 0)
    $cloak.AddLine(176, 0, -176, 0)
    $cloak.AddBezier(-176, 0, -158, -70, -104, -232, -104, -232)
    $g.FillPath($INK, $cloak)
    $g.FillEllipse($INK, -120, -196, 240, 130)
    $brim = New-Object System.Drawing.Drawing2D.GraphicsPath
    $brim.AddBezier(-176, -286, 0, -330, 0, -330, 176, -286)
    $brim.AddBezier(176, -286, 0, -242, 0, -242, -176, -286)
    $g.FillPath($INK, $brim)
    $cone = New-Object System.Drawing.Drawing2D.GraphicsPath
    $cone.AddLine(-118, -282); $cone.AddLine(-8, -392)
    $cone.AddLine(8, -392); $cone.AddLine(118, -282)
    $cone.CloseFigure(); $g.FillPath($INK, $cone)
    $g.FillEllipse($INK, -20, -412, 40, 34)
    $mask = New-Object System.Drawing.Drawing2D.GraphicsPath
    $mask.AddBezier(-82, -282, -86, -196, -38, -148, 0, -116)
    $mask.AddBezier(0, -116, 38, -148, 86, -196, 82, -282)
    $mask.AddBezier(82, -282, 44, -302, -44, -302, -82, -282)
    $g.FillPath($INK, $mask)
    $g.DrawPath((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(180,246,244,240), 3)), $mask)
    $browPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,246,244,240), 18)
    $g.DrawArc($browPen, -66, -274, 54, 42, 200, 140)
    $g.DrawArc($browPen, 12,  -274, 54, 42, 200, 140)
    $g.FillEllipse($INK, -46, -258, 20, 20)
    $g.FillEllipse($INK, 26,  -258, 20, 20)
    $mouth = New-Object System.Drawing.Drawing2D.GraphicsPath
    $mouth.AddBezier(-68, -222, -28, -128, 28, -128, 68, -222)
    $mouth.AddBezier(68, -222, 28, -172, -28, -172, -68, -222)
    $mouth.CloseFigure(); $g.FillPath($PALE, $mouth)
    for ($t=0; $t -lt 6; $t++) {
      $tx = -40 + $t * 16
      $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 4)), $tx, -214, $tx, -168)
    }
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 46)), -96, -190, -232, -150)
    $g.FillEllipse($INK, -262, -172, 62, 52)
    $g.ResetTransform()
  }
  # 主角：崖壁外的空中，横着翻滚下坠
  $g.TranslateTransform(430, 500)
  $g.RotateTransform(-40)
  $g.FillEllipse($INK, -50, -150, 100, 104)
  $g.FillEllipse($INK, -22, -218, 48, 52)
  $torso = New-Object System.Drawing.Drawing2D.GraphicsPath
  $torso.AddBezier(-62, -46, 62, -46, 50, 140, 42, 190)
  $torso.AddLine(42, 190, -42, 190)
  $torso.AddBezier(-42, 190, -50, 140, -62, -46, -62, -46)
  $g.FillPath($INK, $torso)
  $g.FillRectangle($INK, -168, -106, 118, 46)
  $g.FillRectangle($INK, 50, -106, 118, 46)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 42)), -62, -26, -228, -92)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 42)), 62, -26, 228, -92)
  $g.FillEllipse($INK, -258, -124, 66, 56)
  $g.FillEllipse($INK, 192, -124, 66, 56)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 50)), -24, 190, -44, 322)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 50)), 24, 190, 48, 318)
  $blood = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,146,22,30))
  $g.FillEllipse($blood, -40, -30, 78, 48)
  $g.FillEllipse($blood, 16, 44, 48, 30)
  for ($k=0; $k -lt 16; $k++) {
    $g.FillEllipse($blood, $rnd.Next(-280,280), $rnd.Next(-150,320), $rnd.Next(6,20), $rnd.Next(5,16))
  }
  $g.ResetTransform()
}
# ---------- 09 没死（用户第三版：崖在画面正中一整块，顶部三个小人，崖壁上部扒着一只手）----------
Make '09_没死' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,247,245,240))
  $rnd = New-Object System.Random(908)
  $PALE = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,246,244,240))
  for ($k=0; $k -lt 800; $k++) {
    $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($rnd.Next(6,20), 120,116,104))),
      $rnd.Next(0,$W), $rnd.Next(0,$H), $rnd.Next(1,4), $rnd.Next(1,3))
  }
  # 云雾（画面四周）
  for ($k=0; $k -lt 110; $k++) {
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($rnd.Next(5,16), 116,122,134))),
      $rnd.Next(-300,$W+200), $rnd.Next(-80, 980), $rnd.Next(320,900), $rnd.Next(110,320))
  }
  # ===== 崖：画面正中一整块（顶弧 + 左右收窄到底），用密集墨块铺实 =====
  $topY = 214
  for ($yy = 120; $yy -lt $H + 80; $yy += 20) {
    $tt = ($yy - $topY) / 760.0
    if ($tt -lt 0) { $tt = 0 }
    $halfW = 272 * [math]::Sqrt(1.0 - $tt * 0.24)          # 越往下略窄
    $cxx = 806 - $tt * 34                                   # 略微向左倾
    if ($yy -lt $topY) { $dd = ($topY - $yy) / 150.0; $halfW = 272 * [math]::Sqrt([math]::Max(0.0, 1.0 - $dd*$dd)) }
    for ($xx = [int]($cxx-$halfW); $xx -lt [int]($cxx+$halfW); $xx += 20) {
      $g.FillEllipse($INK, $xx - 24, $yy - 24, 52, 52)
    }
  }
  # 崖壁的竖向皴笔（露白的岩纹）
  for ($k=0; $k -lt 220; $k++) {
    $x = 640 + $rnd.Next(0, 400); $y = 200 + $rnd.Next(0, 700); $h = $rnd.Next(50, 190)
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($rnd.Next(22,80), 246,244,240), $rnd.Next(2,6))),
      $x, $y, $x + $rnd.Next(-7,8), $y + $h)
  }
  # ===== **崖壁上扒着的一只手，五指张开朝上**（他是画面里唯一的浅色）=====
  $hx = 800; $hy = 520          # 掌心的位置（落在崖面正中）
  # 掌：一块方的、上宽下窄的手掌（不是圆球）
  $palm = New-Object System.Drawing.Drawing2D.GraphicsPath
  $palm.AddBezier($hx-70, $hy-56, $hx+70, $hy-56, $hx+62, $hy+40, $hx+50, $hy+72)
  $palm.AddLine($hx+50, $hy+72, $hx-50, $hy+72)
  $palm.AddBezier($hx-50, $hy+72, $hx-62, $hy+40, $hx-70, $hy-56, $hx-70, $hy-56)
  $g.FillPath($PALE, $palm)
  $g.DrawPath((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 5)), $palm)
  # 四指：长短不一（中指最长、小指最短），朝上微微张开
  $fingers = @(
    @{x=-54; len=112; ang=-18},
    @{x=-20; len=134; ang= -6},
    @{x= 14; len=128; ang=  6},
    @{x= 46; len=104; ang= 19}
  )
  foreach ($f in $fingers) {
    $bx = $hx + $f.x; $by = $hy - 44
    $a = $f.ang * [math]::PI / 180
    $ex = $bx + [math]::Sin($a) * $f.len
    $ey = $by - [math]::Cos($a) * $f.len
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,246,244,240), 30)), $bx, $by, $ex, $ey)
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 4)), $bx - 15, $by, $ex - 15, $ey)
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 4)), $bx + 15, $by, $ex + 15, $ey)
    $g.FillEllipse($PALE, [int]($ex - 16), [int]($ey - 6), 32, 30)   # 指尖
    $g.DrawEllipse((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 4)), [int]($ex - 16), [int]($ey - 6), 32, 30)
  }
  # 拇指：从掌心左下斜着伸出去
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,246,244,240), 32)), $hx-66, $hy+8, $hx-158, $hy-38)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 4)), $hx-70, $hy-8, $hx-160, $hy-54)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 4)), $hx-62, $hy+24, $hx-152, $hy-22)
  # 小臂往下没入崖壁
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,246,244,240), 52)), $hx, $hy+70, $hx-18, $hy+320)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 4)), $hx-34, $hy+80, $hx-52, $hy+320)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,26,27,31), 4)), $hx+34, $hy+80, $hx+16, $hy+320)
  # 指节上的一点暗红（唯一暖色）
  $blood = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,146,22,30))
  $g.FillEllipse($blood, $hx-30, $hy+8, 30, 20)
  $g.FillEllipse($blood, $hx+8, $hy+16, 22, 15)
  for ($k=0; $k -lt 10; $k++) {
    $g.FillEllipse($blood, $hx + $rnd.Next(-90,90), $hy + $rnd.Next(-40,260), $rnd.Next(5,15), $rnd.Next(4,12))
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


# ============================================================
# 主角定版 + 《剑意》式减法镜头（一刀光 / 雨空镜）
# ============================================================

# ---------- 00 主角定版 · 正面/侧面全身 + 头部特写 ----------
Make '00_主角定版' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,252,251,249))
  function DrawMan($cx, $feetY, $h, $face) {
    $headR = $h * 0.075
    $headY = $feetY - $h
    $tl = New-Object System.Drawing.Drawing2D.GraphicsPath
    $tl.AddBezier($cx-6, $headY+6, $cx+$headR*1.6, $headY-16, $cx+$headR*1.9, $headY+30, $cx+$headR*0.9, $headY+$headR*1.6)
    $tl.AddLine($cx+$headR*0.9, $headY+$headR*1.6, $cx+6, $headY+14); $tl.CloseFigure()
    $g.FillPath($INK, $tl)
    $g.FillEllipse($INK, $cx-$headR, $headY, $headR*2, $headR*2.15)
    $g.FillRectangle($INK, $cx-$headR*0.34, $headY+$headR*1.9, $headR*0.68, $headR*0.7)
    $sy = $headY + $headR*2.55
    $g.FillEllipse($INK, $cx-$h*0.145, $sy-$h*0.012, $h*0.29, $h*0.075)
    $robe = New-Object System.Drawing.Drawing2D.GraphicsPath
    $robe.AddBezier($cx-$h*0.135, $sy+$h*0.02, $cx+$h*0.135, $sy+$h*0.02, $cx+$h*0.098, $feetY-$h*0.34, $cx+$h*0.108, $feetY-$h*0.26)
    $robe.AddBezier($cx+$h*0.108, $feetY-$h*0.26, $cx, $feetY-$h*0.225, $cx, $feetY-$h*0.225, $cx-$h*0.108, $feetY-$h*0.26)
    $robe.AddBezier($cx-$h*0.108, $feetY-$h*0.26, $cx-$h*0.098, $feetY-$h*0.34, $cx-$h*0.135, $sy+$h*0.02, $cx-$h*0.135, $sy+$h*0.02)
    $g.FillPath($INK, $robe)
    if ($face -eq 1) {
      $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,252,251,249), 7)), $cx-$h*0.045, $sy+$h*0.01, $cx, $sy+$h*0.075)
      $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,252,251,249), 7)), $cx+$h*0.045, $sy+$h*0.01, $cx, $sy+$h*0.075)
    }
    $g.FillRectangle($INK, $cx-$h*0.095, $feetY-$h*0.46, $h*0.19, $h*0.026)
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), [int]($h*0.042))), $cx-$h*0.135, $sy+$h*0.04, $cx-$h*0.14, $feetY-$h*0.42)
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), [int]($h*0.042))), $cx+$h*0.135, $sy+$h*0.04, $cx+$h*0.14, $feetY-$h*0.42)
    $g.FillRectangle($INK, $cx-$h*0.16, $feetY-$h*0.44, $h*0.042, $h*0.05)
    $g.FillRectangle($INK, $cx+$h*0.118, $feetY-$h*0.44, $h*0.042, $h*0.05)
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), [int]($h*0.055))), $cx-$h*0.045, $feetY-$h*0.26, $cx-$h*0.05, $feetY)
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), [int]($h*0.055))), $cx+$h*0.045, $feetY-$h*0.26, $cx+$h*0.05, $feetY)
    $g.FillRectangle($INK, $cx-$h*0.085, $feetY-$h*0.035, $h*0.16, $h*0.035)
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), [int]($h*0.022))),
      $cx-$h*0.10, $feetY-$h*0.44, $cx-$h*0.20, $feetY-$h*0.20)
    $g.FillEllipse($INK, $cx-$h*0.115, $feetY-$h*0.475, $h*0.038, $h*0.038)
  }
  DrawMan 430 830 690 1 | Out-Null
  DrawMan 1080 830 690 0 | Out-Null
  $g.FillEllipse($INK, 1400, 210, 150, 162)
  $g.FillEllipse($INK, 1478, 168, 96, 60)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255,24,24,28), 14)), 1486, 222, 1560, 300)
}

# ---------- 07b2 一刀光 · 几乎全黑，只有一道纯白弧光斜贯画面 ----------
Make '07b2_一刀光' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,12,12,15))
  $rnd = New-Object System.Random(9)
  for ($i = 0; $i -lt 34; $i++) {
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb($rnd.Next(8,26), 60,62,70))),
      $rnd.Next(-200, $W), $rnd.Next(-100, $H), $rnd.Next(320,900), $rnd.Next(220,620))
  }
  $g.DrawBezier((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(80,198,210,228), 58)), 1580, 30, 1130, 330, 660, 646, 110, 902)
  $g.DrawBezier((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(170,238,242,252), 30)), 1580, 30, 1130, 330, 660, 646, 110, 902)
  $g.DrawBezier((New-Object System.Drawing.Pen([System.Drawing.Color]::White, 12)), 1576, 26, 1126, 326, 656, 642, 106, 898)
  for ($i = 0; $i -lt 30; $i++) {
    $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(210,18,18,22))),
      $rnd.Next(160, 1520), $rnd.Next(90, 870), $rnd.Next(4,20), $rnd.Next(4,20))
  }
}

# ---------- 07b3 雨空镜 · 只有雨和地面，什么都没有 ----------
Make '07b3_雨空镜' {
  param($g)
  $g.Clear([System.Drawing.Color]::FromArgb(255,243,243,241))
  $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(22,120,126,136))), 0, 806, $W, 122)
  $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(30,110,120,134))), 520, 792, 620, 54)
  $g.DrawLine($PEN_G, 0, 806, $W, 806)
  $rnd = New-Object System.Random(2024)
  for ($i = 0; $i -lt 420; $i++) {
    $x = $rnd.Next(-40, $W + 40); $y = $rnd.Next(-60, 880); $len = $rnd.Next(60, 220)
    $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($rnd.Next(40,130), 90,96,110), $rnd.Next(1,3))), $x, $y, $x - 8, $y + $len)
  }
  for ($i=0; $i -lt 7; $i++) {
    $g.DrawEllipse((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70,120,128,142), 2)),
      560 + $rnd.Next(0,520), 800 + $rnd.Next(0,34), $rnd.Next(30,90), $rnd.Next(8,20))
  }
}

Write-Output ''
Write-Output ('共 ' + (Get-ChildItem $OUT -Filter *.png | Measure-Object).Count + ' 张 → ' + $OUT)
