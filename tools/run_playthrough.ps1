param([string]$Godot = 'C:/Users/zq300/Desktop/Godot_v4.7.2-stable_win64.exe', [ValidateRange(1,10)][int]$StartLevel = 1, [ValidateRange(1,10)][int]$EndLevel = 10, [switch]$PrepareOnly, [ValidateRange(60,1800)][int]$TimeoutSeconds = 420, [string]$Curio = '', [ValidateRange(1,5)][int]$CurioLevel = 1, [ValidateRange(0,1000)][int]$BasicSkillLevel = 0, [ValidateRange(0,5)][int]$BasicFamilyStars = 0, [switch]$BackwashAtFinal, [string]$RunId = '', [string]$AuditRoot = '', [int]$Seed = 20261116, [switch]$RestrictStrength, [switch]$Windowed)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $RunId) { $RunId = [Guid]::NewGuid().ToString('N') }
$userDirectory = "wuxia-audits/$RunId/wuxia-regression"
if (-not $AuditRoot) { $AuditRoot = Join-Path $projectRoot ".shots/runs/$RunId/audit_project" }
New-Item -ItemType Directory -Path $AuditRoot -Force | Out-Null
foreach ($part in @('menu','shared','kushou','tools','assets','fonts','.godot')) {
    $target = Join-Path $AuditRoot $part
    if (-not (Test-Path $target)) {
        New-Item -ItemType Junction -Path $target -Target (Join-Path $projectRoot $part) | Out-Null
    }
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'icon.svg') -Destination (Join-Path $AuditRoot 'icon.svg') -Force
$config = [IO.File]::ReadAllText((Join-Path $projectRoot 'project.godot')).Replace('[application]', "[application]
config/use_custom_user_dir=true
config/custom_user_dir_name=`"$userDirectory`"")
[IO.File]::WriteAllText((Join-Path $AuditRoot 'project.godot'), $config)
# 稳定指针：.shots/audit_project 指向最近一次准备的项目（仅顺序使用时有效；并发请用打印出的 AUDIT_PROJECT）
$legacy = Join-Path $projectRoot '.shots/audit_project'
if (Test-Path $legacy) {
    $item = Get-Item $legacy -Force
    if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
        [IO.Directory]::Delete($legacy)
    } else {
        Get-ChildItem $legacy -Force | ForEach-Object {
            if ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) { [IO.Directory]::Delete($_.FullName) }
            else { Remove-Item $_.FullName -Recurse -Force }
        }
        Remove-Item $legacy -Recurse -Force
    }
}
New-Item -ItemType Junction -Path $legacy -Target $AuditRoot | Out-Null
Write-Output "AUDIT_RUN_ID=$RunId"
Write-Output "AUDIT_PROJECT=$AuditRoot"
Write-Output "AUDIT_USER_DIR=$userDirectory"
if ($PrepareOnly) { return }
$engineArgs = @()
if (-not $Windowed) { $engineArgs += '--headless' }
& $Godot @engineArgs --path $AuditRoot res://tools/playthrough.tscn --fixed-fps 60 -- "--start-level=$StartLevel" "--end-level=$EndLevel" "--timeout-seconds=$TimeoutSeconds" "--curio-id=$Curio" "--curio-level=$CurioLevel" "--basic-skill-level=$BasicSkillLevel" "--basic-family-stars=$BasicFamilyStars" "--backwash-at-final=$($BackwashAtFinal.IsPresent)" "--seed=$Seed" "--restrict-strength=$($RestrictStrength.IsPresent)" 2>&1 | Out-String
exit $LASTEXITCODE
