param([string]$Godot = 'C:/Users/zq300/Desktop/Godot_v4.7.2-stable_win64.exe', [string]$RunId = '', [string]$AuditRoot = '', [string]$ResultRoot = '', [string[]]$Only = @())
$Only = @($Only | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$runsRoot = [IO.Path]::Combine($projectRoot, '.shots', 'runs')
$runsRootFull = [IO.Path]::GetFullPath($runsRoot).TrimEnd('\') + '\'

function Read-IsolationMarker([string]$projectDir) {
    $cfg = [IO.Path]::Combine($projectDir, 'project.godot')
    if (-not (Test-Path $cfg -ErrorAction SilentlyContinue)) { return '' }
    $text = [IO.File]::ReadAllText($cfg)
    $m = [regex]::Match($text, 'config/custom_user_dir_name="wuxia-audits/([^/"]+)/wuxia-regression"')
    if ($m.Success) { return $m.Groups[1].Value }
    return ''
}

if (-not $AuditRoot) {
    if (-not $RunId) { $RunId = [Guid]::NewGuid().ToString('N') }
    if ($RunId -notmatch '^[A-Za-z0-9._-]+$') { Write-Output "ERROR: 非法运行编号: $RunId"; exit 6 }
    $prep = & powershell -ExecutionPolicy Bypass -NoProfile -File (Join-Path $PSScriptRoot 'run_playthrough.ps1') -Godot $Godot -PrepareOnly -RunId $RunId -NoLink 2>&1 | Out-String
    $code = $LASTEXITCODE
    if ($code -ne 0) { Write-Output $prep.Trim(); Write-Output "ERROR: prepare 失败（exit=$code）"; exit $code }
    $m = [regex]::Match($prep, 'AUDIT_PROJECT=(.+)')
    if (-not $m.Success) { Write-Output 'ERROR: prepare 未返回 AUDIT_PROJECT'; exit 8 }
    $AuditRoot = $m.Groups[1].Value.Trim()
    Write-Output $prep.Trim()
} else {
    $AuditRoot = [IO.Path]::GetFullPath($AuditRoot)
    if ($AuditRoot.TrimEnd('\') -eq [IO.Path]::GetFullPath($projectRoot).TrimEnd('\')) { Write-Output 'ERROR: -AuditRoot 不能指向正式工程'; exit 6 }
    if (-not $AuditRoot.StartsWith($runsRootFull, [StringComparison]::OrdinalIgnoreCase)) { Write-Output "ERROR: -AuditRoot 必须在 .shots/runs/<runId>/ 内: $AuditRoot"; exit 6 }
    $markerRun = Read-IsolationMarker $AuditRoot
    if (-not $markerRun) { Write-Output "ERROR: -AuditRoot 缺少隔离存档标记: $AuditRoot"; exit 8 }
    if ($RunId -and $RunId -ne $markerRun) { Write-Output "ERROR: -RunId 与隔离标记不一致: $RunId vs $markerRun"; exit 8 }
    $RunId = $markerRun
}
if (-not $ResultRoot) { $ResultRoot = [IO.Path]::Combine($runsRoot, $RunId, 'results') }
$ResultRoot = [IO.Path]::GetFullPath($ResultRoot)
$resultPrefix = [IO.Path]::GetFullPath([IO.Path]::Combine($runsRoot, $RunId)).TrimEnd('\') + '\'
if (-not $ResultRoot.StartsWith($resultPrefix, [StringComparison]::OrdinalIgnoreCase)) { Write-Output "ERROR: 结果目录必须在该运行目录内: $ResultRoot"; exit 6 }
New-Item -ItemType Directory -Path $ResultRoot -Force | Out-Null
Write-Output "AUDIT_RUN_ID=$RunId"
Write-Output "AUDIT_PROJECT=$AuditRoot"
Write-Output "AUDIT_RESULTS=$ResultRoot"

$names = @('audio_pool','audio_shutdown','audio_window_close','save_file','save_corruption','save_shapes','save_warning','reward_save','role_advance','curio_save','curio_timing','curio_rewards','curio_wood','curio_cold','curio_paper','enemy_hazards','curio_iron','quest_targets','quest_bell','quest_gamble','quest_boundary','curio_refresh','curio_mirror','attack_crit','attack_boundary','projectile_crit','blade_boundary','ram_boundary','ram_timing','curio_coin_sword','curio_ghost','minion_boundary','backwash','medical_roster','aug_limits','choice_boundary','attr_panel','attack_timing','type_stats','damage_modifiers','damage_credit','incoming_damage','healing_boundary','basic_skill_growth','family_attack_flow','growth_bridge','rare_buff','physical_sharing','element_sharing','aura_boundary','family_stars','family_flow','external_kill','kill_once','equipment','starter_equipment','forge_undo','forge_oil','equipment_battle','preview_reward','black_market','death_prevention','result_freeze','tutorial','skill_growth','skill_boundary','mana_sync','skill_mana_effects','god_pick','draw_claim','battle_lifecycle')
$names += 'control_boundary'
$names += 'hit_chain'
$names += 'burn'
$names += 'typed_rewards'
$names += 'market_growth'
$names += 'market_inventory'
$names += 'equipment_dialogs'
$names += 'menu_popups'
$names += 'menu_wallet'
$names += 'menu_navigation'
$names += 'challenge_rewards'
$names += 'battle_navigation'
$names += 'equipment_refresh'
$names += 'result_panel'
$names += 'treasure_flow'
$names += 'outgame_loop'
$names += 'fresh_profile'
if ($Only.Count -gt 0) { $names = $Only }
$results = @()
foreach ($name in $names) {
    $logFile = [IO.Path]::Combine($ResultRoot, "$name.log")
    if (Test-Path $logFile) { Remove-Item $logFile -Force }
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $output = & $Godot --headless --path $AuditRoot --max-fps 120 --quit-after 3600 --script "res://tools/audit_$name.gd" --log-file $logFile 2>&1 | Out-String
    $engineExit = $LASTEXITCODE
    $ErrorActionPreference = $previous
    # 关键：判定用 Godot 自己写的 UTF-8 日志，避免 PowerShell 5.1 用 ANSI 解码原生输出导致中文误判
    $logText = if (Test-Path $logFile) { [IO.File]::ReadAllText($logFile) } else { $output }
    if (-not (Test-Path $logFile)) { [IO.File]::WriteAllText($logFile, $logText) }
    $unexpectedErrors = @($logText -split "`r?`n" | Where-Object {
        if ($_ -notmatch '^ERROR:') { return $false }
        if ($_ -match '^ERROR: [0-9]+ resources still in use at exit') { return $false }
        if ($name -in @('role_advance','equipment') -and $_ -match '^ERROR: (局外进度保存失败|存档保存失败)') { return $false }
        if ($name -in @('role_advance','equipment','preview_reward') -and $_ -match "Can't open file") { return $false }
        if ($name -eq 'preview_reward' -and $_ -match '^ERROR: 存档保存失败：user://level_state\.cfg \((Busy|Can.t open file)\)') { return $false }
        return $true
    })
    $needsPass = $name -ne 'audio_duration'
    $pass = $unexpectedErrors.Count -eq 0 -and $engineExit -eq 0 -and ($logText.Contains('PASS:') -or -not $needsPass) -and $logText -notmatch 'SCRIPT ERROR|Assertion failed|Parse Error'
    $diagnostics = ([regex]::Matches($logText, '(?m)^(ERROR|WARNING):')).Count
    $results += [pscustomobject]@{Test=$name; Passed=$pass; Diagnostics=$diagnostics; UnexpectedErrors=$unexpectedErrors.Count; Exit=$engineExit; Log=$logFile}
    Write-Output "$name : passed=$pass diagnostics=$diagnostics exit=$engineExit"
    if (-not $pass) { Write-Output "  log=$logFile" }
}
$results | ConvertTo-Json | Set-Content -LiteralPath ([IO.Path]::Combine($ResultRoot, 'results.json')) -Encoding utf8
$failed = @($results | Where-Object { -not $_.Passed })
Write-Output ('FAILED_COUNT=' + $failed.Count + ' TOTAL=' + $results.Count)
$failed | ForEach-Object { Write-Output ('FAIL ' + $_.Test) }
if ($failed.Count -gt 0) { exit 1 }
exit 0
