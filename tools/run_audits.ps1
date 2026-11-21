param([string]$Godot = 'C:/Users/zq300/Desktop/Godot_v4.7.2-stable_win64.exe')
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'run_playthrough.ps1') -Godot $Godot -PrepareOnly
$projectRoot = Split-Path $PSScriptRoot -Parent
$auditRoot = Join-Path $projectRoot '.shots/audit_project'
$resultRoot = Join-Path $projectRoot '.shots/audit_results'
New-Item -ItemType Directory -Path $resultRoot -Force | Out-Null
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
$results = @()
foreach ($name in $names) {
    $output = & $Godot --headless --path $auditRoot --max-fps 120 --quit-after 3600 --script "res://tools/audit_$name.gd" 2>&1 | Out-String
    $engineExit = $LASTEXITCODE
    [IO.File]::WriteAllText((Join-Path $resultRoot "$name.log"), $output)
    $unexpectedErrors = @($output -split "`n" | Where-Object {
        $_ -match "^ERROR:" -and
        $_ -notmatch "^ERROR: [0-9]+ resources still in use at exit" -and
        -not ($name -in @("role_advance", "equipment") -and $_ -match "^ERROR: (局外进度保存失败|存档保存失败)")
    })
    $pass = $unexpectedErrors.Count -eq 0 -and $engineExit -eq 0 -and $output.Contains('PASS:') -and $output -notmatch 'SCRIPT ERROR|Assertion failed|Parse Error'
    $diagnostics = ([regex]::Matches($output, '(?m)^(ERROR|WARNING):')).Count
    $results += [pscustomobject]@{Test=$name; Passed=$pass; Diagnostics=$diagnostics; UnexpectedErrors=$unexpectedErrors.Count; Exit=$engineExit}
    Write-Output "$name : passed=$pass diagnostics=$diagnostics"
}
$results | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $resultRoot 'results.json') -Encoding utf8
if ($results.Passed -contains $false) { exit 1 }
exit 0
