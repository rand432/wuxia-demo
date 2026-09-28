<# 动作落点表 · 逐格抽帧 + 烧时间码（给「先看画面再配音」用）#>
param(
  [Parameter(Mandatory=$true)][string]$Video,
  [double]$Start = 0, [double]$Dur = 12, [double]$Every = 1.0, [int]$Cols = 4, [string]$Out = ""
)
$ErrorActionPreference = 'Stop'
$ff = 'C:\Users\zq300\ffmpeg\bin\ffmpeg.exe'
if ($Out -eq "") { $Out = Join-Path (Split-Path $Video) ("动作表_" + [System.IO.Path]::GetFileNameWithoutExtension($Video) + "_" + $Start + "s.png") }
$fps  = 1.0 / $Every
$rows = [math]::Ceiling(($Dur * $fps) / $Cols)
# 注意：下面这段必须用 PowerShell 单引号串，否则 \: 会被吃掉
$draw = 'drawtext=font=Consolas:text=''%{pts\:hms}'':x=8:y=8:fontsize=20:fontcolor=0xffe066:box=1:boxcolor=0x000000@0.6:boxborderw=4,'
$vf  = "setpts=PTS+" + $Start + "/TB," + $draw
$vf += "fps=" + $fps + ",scale=400:225,"
$vf += "tile=" + $Cols + "x" + $rows + ":padding=4:margin=4:color=0x282a30"
Write-Output ("抽帧 " + $Start + "s 起 " + $Dur + "s，每 " + $Every + "s 一格，" + $Cols + " 列 x " + $rows + " 行")
& $ff -y -v error -ss $Start -t $Dur -i $Video -vf $vf -frames:v 1 $Out
if (Test-Path $Out) { Write-Output ("OK " + $Out) } else { Write-Output "FAILED" }