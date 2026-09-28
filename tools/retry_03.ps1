# 03 纸醉金迷 · 重出视频（等平台算力恢复后跑）
# ------------------------------------------------------------------
# 2026-09-28：Wan 3.0 / Seedance 2.5 / Wan 3.0 Prime 三个模型全报「算力不足」，
#              这是 LibTV 服务端的容量问题，不是账号或余额问题。
#
# 跑法：  powershell -File tools\retry_03.ps1
# 成功后：powershell -File tools\build_film.ps1 -Out 开场_成片_v32.mp4
#
# 注意：03 的视频模型对「碰杯」有极强先验，会顽固地画成玻璃高脚杯。
#      提示词里已彻底避开「杯」字。若仍出玻璃杯，改用 2.5D 缓推版（当前在用）。
# ------------------------------------------------------------------
$ErrorActionPreference = 'Continue'
$cli = 'C:\Users\zq300\.libtv\libtv.exe'
$WS  = 'D:\1\wuxia-demo'
$K   = Join-Path $WS 'assets\gen\keyframes'
$O   = Join-Path $WS 'assets\gen\aivideo'
Set-Location $WS

$prompt = @'
中国水墨画风格。二维水墨绘画，宣纸上作画，墨色浓淡干湿，不是照片不是3D渲染。
画面正中两只中国古代的陶制酒盏从左右倾斜着举起来相碰，宽口浅腹的陶器，盏身厚实，底下只有很短的圈足。
盏里鲜红的酒在相碰的一刻从盏沿炸开溅出，酒液顺桌沿往下滴。案上一叠残破的书和一只倒下的陶壶。
画面中没有玻璃器皿，没有细长的高脚。镜头固定，相碰瞬间轻微一颤，之后极缓推近那滩酒渍。
'@

Write-Output "[1/3] 上传关键帧（陶盏版）..."
& $cli upload "kf_03_retry" --resource (Join-Path $K "03_宫殿纸醉金迷.png") --x 300 --y 700 2>&1 | Out-Null

Write-Output "[2/3] 建节点并提交..."
& $cli node delete "03_纸醉金迷" 2>&1 | Out-Null
$mk = & $cli node create "03_纸醉金迷" -t video -s "model=Wan 3.0" -s "modeType=frames2video" -s "duration=8" --left-add "kf_03_retry" --prompt $prompt 2>&1 | Out-String
$run = & $cli node "03_纸醉金迷" --run 2>&1 | Out-String
if ($run -match "算力不足") { Write-Output "  X 仍然算力不足，稍后再试"; exit 1 }
if ($run -notmatch "taskId") { Write-Output ("  X 提交失败：" + $run.Substring(0, [math]::Min(300, $run.Length))); exit 1 }
Write-Output "  OK 已提交"

Write-Output "[3/3] 下载（无水印原片）..."
& $cli download -n "03_纸醉金迷" --without-ai-watermark --vip -o $O 2>&1 | Select-Object -First 2
$f = Join-Path $O "03_纸醉金迷.mp4"
if (Test-Path $f) {
  Write-Output ("  OK " + [math]::Round((Get-Item $f).Length/1MB,2) + " MB")
  Write-Output "  下一步：把 edl.json 里 03 那一条从 2.5D 版换回这个视频，再跑 build_film.ps1"
} else { Write-Output "  X 下载失败" }