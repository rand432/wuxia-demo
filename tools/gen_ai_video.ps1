<#
  开场动画 · LibTV 批量出片（v1）
  逐镜：上传关键帧 -> 建视频节点 -> 跑 -> 无水印下载
  关键：下载必须带 --without-ai-watermark --vip（会员走原链，去品牌水印且画质是原片）
  日期：2026-09-27
#>
param([string]$Only = '', [switch]$SkipUpload)
$ErrorActionPreference = 'Continue'
$cli = 'C:\Users\zq300\.libtv\libtv.exe'
$WS  = 'D:\1\wuxia-demo'
$NL  = [char]10
$KDIR = Join-Path $WS 'assets\gen\keyframes'
$ODIR = Join-Path $WS 'assets\gen\aivideo'
New-Item -ItemType Directory -Force -Path $ODIR | Out-Null
Set-Location $WS

$plan = Get-Content (Join-Path $WS 'tools\motion_plan.json') -Raw -Encoding UTF8 | ConvertFrom-Json

foreach ($s in $plan) {
  if ($Only -ne '' -and $s.id -notlike "$Only*") { continue }
  $ref = Join-Path $KDIR ($s.kf + '.png')
  if (-not (Test-Path $ref)) { Write-Output ("x " + $s.id + " 缺关键帧 " + $s.kf); continue }

  Write-Output ("──── " + $s.id + "  " + $s.dur + "s  " + $s.note)

  $imgNode = $s.id + '_kf'
  if (-not $SkipUpload) {
    & $cli upload $imgNode --resource $ref --x 0 --y ((Get-Random -Max 9000)) 2>&1 | Out-Null
  }

  & $cli node delete $s.id 2>&1 | Out-Null
  $a = @('node','create',$s.id,'-t','video',
         '-s','model=Wan 3.0', '-s', ('modeType=' + $s.mode),
         '-s', ('duration=' + $s.dur),
         '--left-add', $imgNode,
         '--prompt', $s.prompt)
  if ($s.mode -eq 'mixed2video' -and $s.ref) { $a += @('--left-add', $s.ref) }
  $mk = & $cli @a 2>&1 | Out-String
  if ($mk -match '校验失败') { Write-Output ('  x 建节点失败: ' + (($mk -split $NL)[0])); continue }

  $run = & $cli node $s.id --run 2>&1 | Out-String
  if ($run -match 'failedReason') {
    $fr = (($run -split $NL) | Where-Object { $_ -match 'failedReason' } | Select-Object -First 1)
    Write-Output ('  x 生成失败: ' + $fr.Trim()); continue
  }

  & $cli download -n $s.id --without-ai-watermark --vip -o $ODIR 2>&1 | Out-Null
  $out = Join-Path $ODIR ($s.id + '.mp4')
  if (Test-Path $out) {
    Write-Output ('  OK ' + [math]::Round((Get-Item $out).Length/1MB,2) + ' MB')
  } else { Write-Output '  x 下载失败' }
}
Write-Output ''
Write-Output '批量完成'
