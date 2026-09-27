<#
  开场动画 · 音频批量生成（LibTV Seed Audio 1.0 / text2audio）
  纯文字 -> 音频。先生成素材，再用 ffmpeg 按时间轴摆位。
#>
$ErrorActionPreference = 'Continue'
$cli = 'C:\Users\zq300\.libtv\libtv.exe'
$WS  = 'D:\1\wuxia-demo'
$ODIR = Join-Path $WS 'assets\gen\audio'
$NL  = [char]10
New-Item -ItemType Directory -Force -Path $ODIR | Out-Null
Set-Location $WS

$plan = Get-Content (Join-Path $WS 'tools\audio_plan.json') -Raw -Encoding UTF8 | ConvertFrom-Json

foreach ($s in $plan) {
  Write-Output ("──── " + $s.id)
  & $cli node delete $s.id 2>&1 | Out-Null
  $mk = & $cli node create $s.id -t audio -s 'model=Seed Audio 1.0' -s 'modeType=text2audio' -s 'format=wav' -s 'sampleRate=48000' --prompt $s.prompt 2>&1 | Out-String
  if ($mk -match '校验失败') { Write-Output ('  x 建节点失败'); continue }
  $run = & $cli node $s.id --run 2>&1 | Out-String
  if ($run -match 'failedReason') { Write-Output ('  x 生成失败: ' + ((($run -split $NL) | Where-Object { $_ -match 'failedReason' } | Select-Object -First 1)).Trim()); continue }
  $dur = (($run -split $NL) | Where-Object { $_ -match 'durationSec' } | Select-Object -First 1)
  & $cli download -n $s.id --without-ai-watermark --vip -o $ODIR 2>&1 | Out-Null
  $out = Join-Path $ODIR ($s.id + '.wav')
  if (Test-Path $out) { Write-Output ('  OK ' + [math]::Round((Get-Item $out).Length/1KB) + ' KB   ' + ($dur -replace '\s','')) }
  else { Write-Output '  x 下载失败' }
}
Write-Output ''
Write-Output '音频批量完成'
