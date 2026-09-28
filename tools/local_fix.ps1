# 局部修改 · 擦除 + 重绘（LiblibAI 没有 inpaint 端点，这是等效做法）
# ------------------------------------------------------------------
# 原理：先把要改的地方【擦掉】（填成周围底色），再走 img2img。
#       擦掉后那块没有原物体的结构，模型只能按提示词画；
#       其余区域在低 denoise 下基本不变。
#
# 用法：
#   powershell -File tools\local_fix.ps1 -Shot 07a -Rect "1080,400,170,245" -Prompt "一只陶制酒盏,宽口浅腹,短圈足,不是玻璃杯" -Denoise 0.62
#   -Rect 可给多次（分号隔开）：-Rect "100,200,80,80;400,300,120,90"
#   -Fill 是擦除填充色，默认宣纸底色 0xf2efe8
# ------------------------------------------------------------------
param(
  [Parameter(Mandatory=$true)][string]$Shot,
  [Parameter(Mandatory=$true)][string]$Rect,
  [Parameter(Mandatory=$true)][string]$Prompt,
  [double]$Denoise = 0.62,
  [string]$Fill = "0xf2efe8"
)
$ErrorActionPreference = 'Stop'
$WS  = 'D:\1\wuxia-demo'
$WSK = Join-Path $WS 'assets\gen\sketches'
$WK  = Join-Path $WS 'assets\gen\keyframes'
$ff  = 'C:\Users\zq300\ffmpeg\bin\ffmpeg.exe'
Set-Location $WS

$kf = Join-Path $WK ($Shot + ".png")
$sk = Join-Path $WSK ($Shot + ".png")
if (-not (Test-Path $kf)) { Write-Output ("X 找不到关键帧 " + $kf); exit 1 }

$bak = Join-Path $WSK ($Shot + ".sketch.bak.png")
if ((Test-Path $sk) -and -not (Test-Path $bak)) { Copy-Item $sk $bak }
Copy-Item $kf $sk -Force

$vf = ($Rect -split ";" | ForEach-Object {
  $p = $_.Trim() -split ","
  "drawbox=x=$($p[0]):y=$($p[1]):w=$($p[2]):h=$($p[3]):color=$Fill@1:t=fill"
}) -join ","
$erased = Join-Path $WSK ($Shot + ".erased.png")
& $ff -y -v error -i $sk -vf $vf $erased
Copy-Item $erased $sk -Force
Write-Output ("[擦除] " + $Rect)

$gen = Join-Path $WS 'tools\gen_keyframes_liblib.mjs'
$orig = Get-Content $gen -Raw -Encoding UTF8
$i = $orig.IndexOf("['" + $Shot + "_")
if ($i -lt 0) { $i = $orig.IndexOf("['" + $Shot) }
$j = $orig.IndexOf("],", $i) + 2
$nl = [char]10
$newEntry = "['" + $Shot + "'," + $nl + "   '" + $Prompt + "']," + $nl
$patched = $orig.Substring(0, $i) + $newEntry + $orig.Substring($j)
Set-Content -Path $gen -Value $patched -Encoding UTF8 -NoNewline

try {
  node $gen --only $Shot --force --denoise $Denoise
} finally {
  Set-Content -Path $gen -Value $orig -Encoding UTF8 -NoNewline
  if (Test-Path $bak) { Copy-Item $bak $sk -Force; Remove-Item $bak -Force }
  if (Test-Path $erased) { Remove-Item $erased -Force }
  Write-Output "[还原] 生成器与草图已复位"
}