param([string]$Godot = 'C:/Users/zq300/Desktop/Godot_v4.7.2-stable_win64.exe', [ValidateRange(1,10)][int]$StartLevel = 1, [ValidateRange(1,10)][int]$EndLevel = 10, [switch]$PrepareOnly, [ValidateRange(60,1800)][int]$TimeoutSeconds = 420, [string]$Curio = '', [ValidateRange(1,5)][int]$CurioLevel = 1, [ValidateRange(0,1000)][int]$BasicSkillLevel = 0, [ValidateRange(0,5)][int]$BasicFamilyStars = 0)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$runId = [Guid]::NewGuid().ToString("N")
$userDirectory = "wuxia-audits/$runId/wuxia-regression"
$auditRoot = Join-Path $projectRoot '.shots/audit_project'
New-Item -ItemType Directory -Path $auditRoot -Force | Out-Null
foreach ($part in @('menu','shared','kushou','tools','assets','fonts','.godot')) {
    if (-not (Test-Path (Join-Path $auditRoot $part))) {
        New-Item -ItemType Junction -Path (Join-Path $auditRoot $part) -Target (Join-Path $projectRoot $part) | Out-Null
    }
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'icon.svg') -Destination (Join-Path $auditRoot 'icon.svg') -Force
$config = [IO.File]::ReadAllText((Join-Path $projectRoot 'project.godot')).Replace('[application]', "[application]
config/use_custom_user_dir=true
config/custom_user_dir_name=`"$userDirectory`"")
[IO.File]::WriteAllText((Join-Path $auditRoot 'project.godot'), $config)
Write-Output "Isolated user directory: $userDirectory"
if ($PrepareOnly) { return }
& $Godot --headless --path $auditRoot res://tools/playthrough.tscn --fixed-fps 60 -- "--start-level=$StartLevel" "--end-level=$EndLevel" "--timeout-seconds=$TimeoutSeconds" "--curio-id=$Curio" "--curio-level=$CurioLevel" "--basic-skill-level=$BasicSkillLevel" "--basic-family-stars=$BasicFamilyStars" 2>&1 | Out-String
exit $LASTEXITCODE
