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

# ---------- 02 荒原流民 · 大远景 · 地平线极低、人物如蝼蚁、残阳血红 ----------
Make '02_荒原流民' {
  param($g)
  $g.DrawLine($PEN_G, 0, 742, 1664, 742)                       # 地平线压到 y=742
  $g.FillRectangle((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255,120,124,132))), 700, 726, 964, 16)  # 地面带
  $g.FillEllipse($RED, 1210, 190, 210, 210)                    # 残阳（唯一暖色）
  # 王城轮廓（低矮、压在线上）
  for ($x=760; $x -lt 1180; $x += 46) {
    $hh = 16 + (($x * 7919) % 40)
    $g.FillRectangle($PALE, $x, 742 - $hh, 34, $hh)
  }
  # 流民：极小墨点，成串挪动
  $rnd = New-Object System.Random(11)
  for ($i=0; $i -lt 46; $i++) {
    $x = 150 + $rnd.Next(0, 1180); $y = 706 + $rnd.Next(0, 30)
    $s = 5 + $rnd.Next(0, 5)
    $g.FillEllipse($INK, $x, $y, $s, $s + 5)
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

# ---------- 04 刀在膝上 · 特写 · 半剪影跪坐，刀横膝上，一手握柄一手擦身 ----------
Make '04_刀在膝上_B擦刀' {
  param($g)
  $g.DrawLine($PEN_G, 700, 812, 1520, 812)
  $g.FillEllipse((New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90,120,124,132))), 900, 770, 620, 70)
  $body = New-Object System.Drawing.Drawing2D.GraphicsPath
  $body.AddBezier(1080,400,1420,430,1460,640,1400,790); $body.AddLine(1400,790,980,790)
  $body.AddBezier(980,790,960,620,1010,430,1080,400); $g.FillPath($INK,$body)
  $hat = New-Object System.Drawing.Drawing2D.GraphicsPath
  $hat.AddBezier(1010,330,1250,250,1420,330,1440,360); $hat.AddLine(1440,360,1010,360); $g.FillPath($INK,$hat)
  $g.FillRectangle($INK, 1200, 268, 42, 60)
  $g.FillEllipse($GREY, 1180, 350, 96, 110)                     # 柔灰头部（斗笠阴影下）
  $g.DrawLine($PEN_K, 880, 628, 1330, 600)                      # 刀横放
  $g.FillRectangle($INK, 1300, 588, 130, 34)
  $g.FillEllipse($INK, 1268, 578, 46, 54)
  $g.FillEllipse($GREY, 1080, 578, 110, 74)                     # 左手按刀身
  $g.DrawLine($PEN_R, 900, 626, 1210, 610)                      # 刀身一线暗红（画粗，才留得住）
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

# ---------- 08 坠崖 · 大远景 · 崖墨黑 + 天惨白 + 极小坠落剪影 ----------
Make '08_坠崖' {
  param($g)
  $g.FillRectangle($INK, 1230, 0, 434, 928)                      # 崖体（右侧墨黑）
  $c = New-Object System.Drawing.Drawing2D.GraphicsPath
  $c.AddBezier(1230,0,1180,300,1130,560,1010,928); $c.AddLine(1664,928); $c.AddLine(1664,0); $g.FillPath($INK,$c)
  $g.FillEllipse($INK, 1290, 30, 150, 90)                        # 崖顶站立的人（转身离去）
  # 坠落的极小剪影 + 断墨衣袂
  $g.FillEllipse($INK, 880, 470, 40, 40)
  $g.FillRectangle($INK, 886, 506, 28, 78)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(200,40,42,48), 8)), 890, 560, 780, 700)
  $g.DrawLine((New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(160,60,62,70), 6)), 900, 566, 1010, 690)
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

Write-Output ''
Write-Output ('共 ' + (Get-ChildItem $OUT -Filter *.png | Measure-Object).Count + ' 张 → ' + $OUT)
