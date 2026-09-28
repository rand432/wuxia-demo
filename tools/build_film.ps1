<#
  开场动画 · 一键构建
  node tools\make_build_filters.mjs 生成滤镜 -> 三遍 ffmpeg -> export\<Out>
  改 edl.json / subs.json / audio_mix.json 任一处，重跑本脚本即可。
#>
param([string]$Out = '开场_成片_v6.mp4')
$ErrorActionPreference = 'Continue'
$ff  = 'C:\Users\zq300\ffmpeg\bin\ffmpeg.exe'
$fp  = 'C:\Users\zq300\ffmpeg\bin\ffprobe.exe'
$WS  = 'D:\1\wuxia-demo'
$EX  = Join-Path $WS 'export'
$W   = Join-Path $EX '_work'
Set-Location $WS

Write-Output '[生成] 滤镜...'
node (Join-Path $WS 'tools\make_build_filters.mjs')

$vf   = (Get-Content (Join-Path $W 'vf.txt')   -Raw -Encoding UTF8).Trim()
$af   = (Get-Content (Join-Path $W 'af.txt')   -Raw -Encoding UTF8).Trim()
$subs = (Get-Content (Join-Path $W 'subs.txt') -Raw -Encoding UTF8).Trim()
$vin  = (Get-Content (Join-Path $W 'inputs.json')  -Raw -Encoding UTF8 | ConvertFrom-Json)
$ain  = (Get-Content (Join-Path $W 'ainputs.json') -Raw -Encoding UTF8 | ConvertFrom-Json)
$tj   = Get-Content (Join-Path $W 'times.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$DUR  = [math]::Round($tj.total, 2)
$enc  = @('-c:v','libx264','-crf','18','-preset','medium','-pix_fmt','yuv420p')

$silent = Join-Path $W 'silent.mp4'
$mix    = Join-Path $W 'mix.m4a'
$out    = Join-Path $EX $Out

Write-Output ('[1/3] 拼片（' + $DUR + 's）...')
$a1 = @('-y','-v','error')
foreach ($p in $vin) { $a1 += @('-i', $p) }
$a1 += @('-filter_complex', $vf, '-map', '[vout]') + $enc + @($silent)
& $ff @a1 2>&1 | Select-Object -First 4
Write-Output ('      ' + (Test-Path $silent))

Write-Output '[2/3] 混音...'
$a2 = @('-y','-v','error')
foreach ($p in $ain) { $a2 += @('-i', $p) }
$a2 += @('-filter_complex', $af, '-map', '[aout]', '-c:a', 'aac', '-b:a', '192k', '-t', $DUR, $mix)
& $ff @a2 2>&1 | Select-Object -First 4
Write-Output ('      ' + (Test-Path $mix))

Write-Output '[3/3] 烧字幕 + 合成...'
$a3 = @('-y','-v','error','-i', $silent, '-i', $mix, '-vf', $subs, '-map','0:v','-map','1:a') + $enc + @('-c:a','copy','-t', $DUR, $out)
& $ff @a3 2>&1 | Select-Object -First 4
if (Test-Path $out) {
  $sz = [math]::Round((Get-Item $out).Length/1MB,1)
  $dd = & $fp -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $out
  Write-Output ('OK ' + $Out + '  ' + $sz + ' MB  ' + $dd + 's')
  (& $ff -v info -i $out -af volumedetect -f null - 2>&1) | Select-String 'mean_volume|max_volume'
} else { Write-Output 'FAILED' }