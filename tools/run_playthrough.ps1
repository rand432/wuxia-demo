param([string]$Godot = 'C:/Users/zq300/Desktop/Godot_v4.7.2-stable_win64.exe', [ValidateRange(1,10)][int]$StartLevel = 1, [ValidateRange(1,10)][int]$EndLevel = 10, [switch]$PrepareOnly, [ValidateRange(60,1800)][int]$TimeoutSeconds = 420, [string]$Curio = '', [ValidateRange(1,5)][int]$CurioLevel = 1, [ValidateRange(0,1000)][int]$BasicSkillLevel = 0, [ValidateRange(0,5)][int]$BasicFamilyStars = 0, [switch]$BackwashAtFinal, [string]$RunId = '', [string]$AuditRoot = '', [switch]$NoLink, [switch]$ReuseExisting, [int]$Seed = 20261116, [switch]$RestrictStrength, [switch]$Windowed, [string]$LegacyLink = '')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$projectRootFull = [IO.Path]::GetFullPath($projectRoot).TrimEnd('\')
$runsRoot = [IO.Path]::Combine($projectRoot, '.shots', 'runs')
$runsRootFull = [IO.Path]::GetFullPath($runsRoot).TrimEnd('\') + '\'
if (-not $RunId) { $RunId = [Guid]::NewGuid().ToString('N') }
if ($RunId -notmatch '^[A-Za-z0-9._-]+$') { Write-Output "ERROR: 非法运行编号: $RunId"; exit 6 }
$runDir = [IO.Path]::Combine($runsRoot, $RunId)
$defaultAudit = [IO.Path]::Combine($runDir, 'audit_project')
$reuse = -not [string]::IsNullOrEmpty($AuditRoot)
$auditPath = if ($reuse) { [IO.Path]::GetFullPath($AuditRoot) } else { [IO.Path]::GetFullPath($defaultAudit) }
if ($auditPath.TrimEnd('\') -eq $projectRootFull) { Write-Output 'ERROR: 测试项目不能指向正式工程目录'; exit 6 }
if (-not $auditPath.StartsWith($runsRootFull, [StringComparison]::OrdinalIgnoreCase)) { Write-Output ("ERROR: 测试项目必须在 .shots/runs/<runId>/ 内: " + $auditPath); exit 6 }
$userDirectory = 'wuxia-audits/' + $RunId + '/wuxia-regression'
$marker = 'custom_user_dir_name="' + $userDirectory + '"'
$nl = [char]10
if ($reuse) {
    $cfgPath = [IO.Path]::Combine($auditPath, 'project.godot')
    if (-not (Test-Path $cfgPath -ErrorAction SilentlyContinue)) { Write-Output ("ERROR: -AuditRoot 缺少 project.godot: " + $auditPath); exit 8 }
    if (-not ([IO.File]::ReadAllText($cfgPath)).Contains($marker)) { Write-Output ("ERROR: -AuditRoot 的隔离存档标记与运行编号不匹配: " + $auditPath); exit 8 }
    Write-Output ("AUDIT_RUN_ID=" + $RunId)
    Write-Output ("AUDIT_PROJECT=" + $auditPath)
    Write-Output ("AUDIT_USER_DIR=" + $userDirectory)
    if ($PrepareOnly) { return }
} else {
    if (Test-Path $runDir) {
        if (-not $ReuseExisting) { Write-Output ("ERROR: 运行编号已存在: " + $RunId + "（如需续用请显式传 -ReuseExisting）"); exit 9 }
        $cfgPath = [IO.Path]::Combine($auditPath, 'project.godot')
        if (-not (Test-Path $cfgPath -ErrorAction SilentlyContinue)) { Write-Output ("ERROR: 既有运行缺少 project.godot: " + $auditPath); exit 8 }
        if (-not ([IO.File]::ReadAllText($cfgPath)).Contains($marker)) { Write-Output ("ERROR: 既有运行编号与存档标记不匹配: " + $RunId); exit 8 }
    } else {
        New-Item -ItemType Directory -Path $runsRoot -Force | Out-Null
        try { New-Item -ItemType Directory -Path $runDir -ErrorAction Stop | Out-Null } catch { Write-Output ("ERROR: 运行编号已存在: " + $RunId); exit 9 }
    }
    New-Item -ItemType Directory -Path $auditPath -Force | Out-Null
    foreach ($part in @('menu','shared','kushou','tools','assets','fonts','.godot')) {
        $target = [IO.Path]::Combine($auditPath, $part)
        if (-not (Test-Path $target)) { New-Item -ItemType Junction -Path $target -Target ([IO.Path]::Combine($projectRoot, $part)) | Out-Null }
    }
    Copy-Item -LiteralPath ([IO.Path]::Combine($projectRoot, 'icon.svg')) -Destination ([IO.Path]::Combine($auditPath, 'icon.svg')) -Force
    $config = [IO.File]::ReadAllText([IO.Path]::Combine($projectRoot, 'project.godot'))
    $insert = '[application]' + $nl + 'config/use_custom_user_dir=true' + $nl + 'config/custom_user_dir_name="' + $userDirectory + '"'
    $config = $config.Replace('[application]', $insert)
    [IO.File]::WriteAllText([IO.Path]::Combine($auditPath, 'project.godot'), $config)
    if (-not $NoLink) {
        $legacy = if ([string]::IsNullOrEmpty($LegacyLink)) { [IO.Path]::Combine($projectRoot, '.shots', 'audit_project') } else { [IO.Path]::GetFullPath($LegacyLink) }
        if (Test-Path $legacy) {
            $it = Get-Item $legacy -Force
            if (-not ($it.Attributes -band [IO.FileAttributes]::ReparsePoint)) { Write-Output ('ERROR: 便捷路径是真实目录，请手动迁移；未做任何修改: ' + $legacy); exit 7 }
            [IO.Directory]::Delete($legacy)
        }
        New-Item -ItemType Junction -Path $legacy -Target $auditPath | Out-Null
    }
    Write-Output ("AUDIT_RUN_ID=" + $RunId)
    Write-Output ("AUDIT_PROJECT=" + $auditPath)
    Write-Output ("AUDIT_USER_DIR=" + $userDirectory)
    if ($PrepareOnly) { return }
}
$engineArgs = @()
if (-not $Windowed) { $engineArgs += '--headless' }
& $Godot @engineArgs --path $auditPath res://tools/playthrough.tscn --fixed-fps 60 -- "--start-level=$StartLevel" "--end-level=$EndLevel" "--timeout-seconds=$TimeoutSeconds" "--curio-id=$Curio" "--curio-level=$CurioLevel" "--basic-skill-level=$BasicSkillLevel" "--basic-family-stars=$BasicFamilyStars" "--backwash-at-final=$($BackwashAtFinal.IsPresent)" "--seed=$Seed" "--restrict-strength=$($RestrictStrength.IsPresent)" 2>&1 | Out-String
exit $LASTEXITCODE
