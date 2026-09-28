# 等待视频算力 → 自动重出 03 / 02 / 07a
# ------------------------------------------------------------------
# 背景：2026-09-28 LibTV 视频算力占满，所有视频模型（含 2 秒最短片段）都报「算力不足」，
#      但音频生成正常 —— 平台本身可用，是视频通道排满。
#
# 跑法：  powershell -File tools\wait_and_make.ps1
#         powershell -File tools\wait_and_make.ps1 -Interval 5 -MaxHours 6   # 每 5 分钟试一次，最多等 6 小时
#
# 成功后会直接出片并提示下一步。
# ------------------------------------------------------------------
param(
  [int]$Interval = 5,      # 每次重试间隔（分钟）
  [double]$MaxHours = 4    # 最多等多久
)
$cli = 'C:\Users\zq300\.libtv\libtv.exe'
$WS  = 'D:\1\wuxia-demo'
$K   = Join-Path $WS 'assets\gen\keyframes'
$O   = Join-Path $WS 'assets\gen\aivideo'
Set-Location $WS
$deadline = (Get-Date).AddHours($MaxHours)
$round = 0

function Try-Video([string]$name, [string]$kf, [string]$prompt, [int]$dur) {
  & $cli upload ($name + "_kf") --resource (Join-Path $K $kf) --x (Get-Random -Max 900) --y (Get-Random -Max 900) 2>&1 | Out-Null
  & $cli node delete $name 2>&1 | Out-Null
  & $cli node create $name -t video -s "model=Wan 3.0" -s "modeType=frames2video" -s ("duration=" + $dur) --left-add ($name + "_kf") --prompt $prompt 2>&1 | Out-Null
  $r = & $cli node $name --run 2>&1 | Out-String
  if ($r -match "算力不足") { return "busy" }
  if ($r -notmatch "taskId") { return ("fail: " + (($r -split [char]10) | Where-Object { $_ -match "msg" } | Select-Object -First 1)) }
  & $cli download -n $name --without-ai-watermark --vip -o $O 2>&1 | Out-Null
  if (Test-Path (Join-Path $O ($name + ".mp4"))) { return "ok" } else { return "nodl" }
}

$p03 = "中国水墨画风格。二维水墨绘画，宣纸上作画，墨色浓淡干湿，不是照片不是3D渲染。画面正中两只中国古代的陶制酒盏从左右倾斜着举起来相碰，宽口浅腹的陶器，盏身厚实，底下只有很短的圈足。盏里鲜红的酒在相碰的一刻从盏沿炸开溅出，酒液顺桌沿往下滴。案上一叠残破的书和一只倒下的陶壶。画面中没有玻璃器皿，没有细长的高脚。镜头固定，相碰瞬间轻微一颤，之后极缓推近那滩酒渍。"
$p07a = "中国水墨画风格。二维水墨绘画，宣纸上作画，墨色浓淡干湿，不是照片不是3D渲染。雨夜酒宴的一角，一只手从右侧伸进来，把案上一只中国古代的陶制酒盏碰倒，那只手连着小臂、手臂完整可见，画面里没有任何孤立的手。陶盏宽口浅腹、短圈足，倾倒后红酒在木案上淌开。四周墨色人影同时起身围拢，脸上只有两点冷光。镜头从倾倒的酒盏绕半圈到那只手。"
$p02 = "中国水墨画风格。二维水墨绘画，宣纸上作画，墨色浓淡干湿，不是照片不是3D渲染。荒原上一眼望不到头的逃难人流正在缓缓前行，衣衫褴褛、身形枯瘦，有人拄杖、有人背着孩子、有人已经倒下。旗帜与破布被风吹得猎猎翻动，地上的尘土与烟尘一阵阵卷起流动，枯树在风里摇晃。血红的残阳挂在天边。镜头缓慢横移跟拍人流，画面里的人持续在走动。"

Write-Output ("开始等待视频算力，每 " + $Interval + " 分钟试一次，最多等到 " + $deadline.ToString("HH:mm") )

while ((Get-Date) -lt $deadline) {
  $round++
  Write-Output ("--- 第 " + $round + " 轮  " + (Get-Date).ToString("HH:mm:ss"))
  $r = Try-Video "03_纸醉金迷" "03_宫殿纸醉金迷.png" $p03 8
  Write-Output ("    03 : " + $r)
  if ($r -eq "ok") {
    Write-Output "  ✓ 03 出片成功！"
    $r2 = Try-Video "02_荒原流民" "02_荒原流民.png" $p02 8
    Write-Output ("    02 : " + $r2)
    if ($r2 -eq "ok") { Write-Output "  ✓ 02 也出片成功！" }
    $r3 = Try-Video "07a_翻杯围拢" "07a_翻杯围拢.png" $p07a 6
    Write-Output ("    07a : " + $r3 + "   （原版有游离的手，重出）")
    Write-Output ""
    Write-Output "下一步：把 edl.json 里 03 从 2.5D 版换回视频版，再跑 tools\build_film.ps1"
    exit 0
  }
  if ($r -ne "busy") { Write-Output "  （不是算力问题，是其它错误，先停下）"; exit 1 }
  Start-Sleep -Seconds ($Interval * 60)
}
Write-Output "等满了 " + $MaxHours + " 小时仍无算力，稍后再跑一次本脚本。"