param([string]$Godot = 'C:/Users/zq300/Desktop/Godot_v4.7.2-stable_win64.exe')
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'run_playthrough.ps1') -Godot $Godot -PrepareOnly
$projectRoot = Split-Path $PSScriptRoot -Parent
$auditRoot = Join-Path $projectRoot '.shots/audit_project'
$resultRoot = Join-Path $projectRoot '.shots/audit_results'
New-Item -ItemType Directory -Path $resultRoot -Force | Out-Null
$names = @('save_file','reward_save','role_advance','family_stars','equipment','forge_undo','forge_oil','equipment_battle','preview_reward','black_market','tutorial','skill_growth','god_pick','draw_claim','battle_lifecycle')
$results = @()
foreach ($name in $names) {
    $output = & $Godot --headless --path $auditRoot --max-fps 120 --quit-after 3600 --script "res://tools/audit_$name.gd" 2>&1 | Out-String
    $engineExit = $LASTEXITCODE
    [IO.File]::WriteAllText((Join-Path $resultRoot "$name.log"), $output)
    $pass = $engineExit -eq 0 -and $output.Contains('PASS:') -and $output -notmatch 'SCRIPT ERROR|Assertion failed|Parse Error'
    $diagnostics = ([regex]::Matches($output, '(?m)^(ERROR|WARNING):')).Count
    $results += [pscustomobject]@{Test=$name; Passed=$pass; Diagnostics=$diagnostics; Exit=$engineExit}
    Write-Output "$name : passed=$pass diagnostics=$diagnostics"
}
$results | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $resultRoot 'results.json') -Encoding utf8
if ($results.Passed -contains $false) { exit 1 }
exit 0
