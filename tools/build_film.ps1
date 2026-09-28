<#
  开场动画 · 一键构建
  node tools\make_build_filters.mjs 生成滤镜 -> 三遍 ffmpeg -> export\<Out>

  v2 修复：每遍都检查退出码与产物；开工前先清中间文件。
  为什么：第一遍失败时，_work\silent.mp4 若是上一轮的旧文件，第 2/3 遍会接着用它，
  结果「构建成功但片子是旧的」。必须让它大声失败。
#>
param([string]$Out = '开场_成片_v25.mp4')
$ErrorActionPreference = 'Continue'
$ff  = 'C:\Users\zq300\ffmpeg\bin\ffmpeg.exe'
$fp  = 'C:\Users\zq300\ffmpeg\bin\ffprobe.exe'
$WS  = 'D:\1\wuxia-demo'
$EX  = Join-Path $WS 'export'
$W   = Join-Path $EX '_work'
Set-Location $WS

Write-Output '[生成] 滤镜...'
node (Join-Path $WS 'tools\make_build_filters.mjs')
if ($LASTEXITCODE -ne 0) { Write-Output 'X 滤镜生成失败（可能有锚点匹配不上）'; exit 3 }

$vf   = (Get-Content (Join-Path $W 'vf.txt')   -Raw -Encoding UTF8).Trim()
$af   = (Get-Content (Join-Path $W 'af.txt')   -Raw -Encoding UTF8).Trim()
$subs = (Get-Content (Join-Path $W 'subs.txt') -Raw -Encoding UTF8).Trim()
$vin  = (Get-Content (Join-Path $W 'inputs.json')  -Raw -Encoding UTF8 | ConvertFrom-Json)
$ain  = (Get-Content (Join-Path $W 'ainputs.json') -Raw -Encoding UTF8 | ConvertFrom-Json)
$tj   = Get-Content (Join-Path $W 'times.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$DUR  = [math]::Round($tj.total, 2)
$enc  = @('-c:v','libx264','-crf','18','-preset','medium','-pix_fmt','yuv420p')

# 开工前先清中间产物，杜绝「用旧文件」
$silent = Join-Path $W 'silent.mp4'
$mix    = Join-Path $W 'mix.m4a'
$out    = Join-Path $EX $Out
Remove-Item $silent, $mix, $out -Force -ErrorAction SilentlyContinue

# 输入文件存在性 —— 缺一个就停，不要靠 ffmpeg 报错
$missing = @()
foreach ($p in $vin)  { if (-not (Test-Path ($p -replace '/','\'))) { $missing += $p } }
foreach ($p in $ain)  { if (-not (Test-Path ($p -replace '/','\'))) { $missing += $p } }
if ($missing.Count -gt 0) {
  Write-Output 'X 以下素材不存在：'
  $missing | ForEach-Object { Write-Output ('   ' + $_) }
  exit 4
}
Write-Output ('[检查] 输入 ' + $vin.Count + ' 段视频 + ' + $ain.Count + ' 路音频，全部存在')

Write-Output ('[1/3] 拼片（' + $DUR + 's）...')
$a1 = @('-y','-v','error')
foreach ($p in $vin) { $a1 += @('-i', $p) }
$a1 += @('-filter_complex', $vf, '-map', '[vout]') + $enc + @($silent)
& $ff @a1 2>&1 | Select-Object -First 4
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $silent)) { Write-Output 'X 拼片失败'; exit 1 }
Write-Output ('      OK ' + [math]::Round((Get-Item $silent).Length/1MB,1) + ' MB')

Write-Output '[2/3] 混音...'
$a2 = @('-y','-v','error')
foreach ($p in $ain) { $a2 += @('-i', $p) }
$a2 += @('-filter_complex', $af, '-map', '[aout]', '-c:a', 'aac', '-b:a', '192k', '-t', $DUR, $mix)
& $ff @a2 2>&1 | Select-Object -First 4
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $mix)) { Write-Output 'X 混音失败'; exit 2 }
Write-Output ('      OK ' + [math]::Round((Get-Item $mix).Length/1MB,1) + ' MB')

Write-Output '[3/3] 烧字幕 + 合成...'
$a3 = @('-y','-v','error','-i', $silent, '-i', $mix, '-vf', $subs, '-map','0:v','-map','1:a') + $enc + @('-c:a','copy','-t', $DUR, $out)
& $ff @a3 2>&1 | Select-Object -First 4
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $out)) { Write-Output 'X 成片合成失败'; exit 5 }
$sz = [math]::Round((Get-Item $out).Length/1MB,1)
$dd = & $fp -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 $out
Write-Output ('OK ' + $Out + '  ' + $sz + ' MB  ' + $dd + 's')
(& $ff -v info -i $out -af volumedetect -f null - 2>&1) | Select-String 'mean_volume|max_volume'