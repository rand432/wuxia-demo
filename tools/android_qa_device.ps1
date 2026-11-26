param([string]$Adb = 'D:/Android/platform-tools/adb.exe', [string]$Apk = '', [string]$Serial = '', [string]$OutDir = '')
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not $OutDir) { $OutDir = [IO.Path]::Combine($root, '.shots', 'android_qa_device') }
New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$report = [IO.Path]::Combine($OutDir, 'report_' + $stamp + '.md')
$lines = New-Object System.Collections.Generic.List[string]
$lines.Add('# Android QA 设备验收 ' + $stamp)

function Invoke-Adb {
    param([string[]]$Arguments)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & $Adb @Arguments 2>&1 | Out-String
    $script:adbExit = $LASTEXITCODE
    $ErrorActionPreference = $prev
    return $out
}

if (-not (Test-Path $Adb)) { Write-Output ('ERROR: adb 不存在: ' + $Adb); exit 2 }
if (-not $Apk) {
    $cands = @(Get-ChildItem ([IO.Path]::Combine($root, '.shots', 'qa')) -Depth 2 -File -Filter 'wuxia_qa_android.apk' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    if ($cands.Count -gt 0) { $Apk = $cands[0].FullName }
}
if (-not $Apk -or -not (Test-Path $Apk)) { Write-Output 'ERROR: 找不到 QA APK'; exit 2 }
$lines.Add('- APK: `' + $Apk + '`')
$devOut = Invoke-Adb @('devices')
$devices = @($devOut -split '\r?\n' | Where-Object { $_ -match '\sdevice$' } | ForEach-Object { ($_ -split '\s+')[0] })
if ($Serial) { $devices = @($devices | Where-Object { $_ -eq $Serial }) }
$lines.Add('- adb devices: `' + (($devOut -split '\r?\n' | Where-Object { $_ -match 'List of devices|\sdevice$' }) -join ' | ') + '`')
if ($devices.Count -eq 0) {
    $lines.Add('- 设备: **0**（未接机，安装/启动/触控/帧率未执行）')
    $lines.Add('- 结论: SKIP（工具已生成，等待设备）')
    [IO.File]::WriteAllLines($report, $lines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output 'DEVICE=0 SKIP=1'
    Write-Output ('REPORT=' + $report)
    exit 0
}
$serial = $devices[0]
$lines.Add('- 设备: `' + $serial + '`')
$lines.Add('')
$results = @()
function Add-Step([string]$name, [bool]$ok, [string]$detail) {
    $script:results += [pscustomobject]@{UseCase=$name; Passed=$ok; Detail=$detail}
    $lines.Add(('- ' + $name + ': **' + ($(if ($ok) { 'PASS' } else { 'FAIL' })) + '** — ' + $detail))
}

$pm = Invoke-Adb @('-s', $serial, 'shell', 'dumpsys', 'package', 'com.wuxia.demo.qa')
$installed = $pm -match 'Package \[com\.wuxia\.demo\.qa\]'
Add-Step '已安装 QA 包' $installed ($(if ($installed) { '存在' } else { '未安装，执行安装' }))
$beforeSave = ''
if ($installed) {
    $beforeSave = Invoke-Adb @('-s', $serial, 'exec-out', 'run-as', 'com.wuxia.demo.qa', 'cat', 'files/level_state.cfg')
}
$lines.Add('- 安装前存档长度: ' + $beforeSave.Length)
$install = Invoke-Adb @('-s', $serial, 'install', '-r', $Apk)
$installOk = $install -match 'Success'
Add-Step '安装/覆盖安装' $installOk (($install -split '\r?\n' | Select-Object -Last 2) -join ' ')
$ver = Invoke-Adb @('-s', $serial, 'shell', 'dumpsys', 'package', 'com.wuxia.demo.qa')
$versionLine = (($ver -split '\r?\n' | Where-Object { $_ -match 'versionName=|versionCode=' }) -join ' ')
$lines.Add('- 包版本: `' + $versionLine + '`')
$afterSave = Invoke-Adb @('-s', $serial, 'exec-out', 'run-as', 'com.wuxia.demo.qa', 'cat', 'files/level_state.cfg')
Add-Step '升级后存档可读' ($afterSave -match 'first_clear|max_unlocked') ('长度 ' + $afterSave.Length)

Invoke-Adb @('-s', $serial, 'logcat', '-c') | Out-Null
Invoke-Adb @('-s', $serial, 'shell', 'am', 'force-stop', 'com.wuxia.demo.qa') | Out-Null
$launch = Invoke-Adb @('-s', $serial, 'shell', 'monkey', '-p', 'com.wuxia.demo.qa', '-c', 'android.intent.category.LAUNCHER', '1')
Add-Step '冷启动' ($launch -notmatch 'No activities found|monkey aborted') (($launch -split '\r?\n' | Select-Object -Last 2) -join ' ')
Start-Sleep -Seconds 6
$shot1 = [IO.Path]::Combine($OutDir, 'cold_' + $stamp + '.png')
Invoke-Adb @('-s', $serial, 'shell', 'screencap', '-p', '/sdcard/qa_cold.png') | Out-Null
Invoke-Adb @('-s', $serial, 'pull', '/sdcard/qa_cold.png', $shot1) | Out-Null
Add-Step '冷启动截图' (Test-Path $shot1) $shot1

Invoke-Adb @('-s', $serial, 'shell', 'input', 'keyevent', '3') | Out-Null
Start-Sleep -Seconds 2
$relaunch = Invoke-Adb @('-s', $serial, 'shell', 'monkey', '-p', 'com.wuxia.demo.qa', '-c', 'android.intent.category.LAUNCHER', '1')
Add-Step '切后台返回' ($relaunch -notmatch 'No activities found|monkey aborted') 'HOME 后重新进入'
Invoke-Adb @('-s', $serial, 'shell', 'am', 'force-stop', 'com.wuxia.demo.qa') | Out-Null
$launch2 = Invoke-Adb @('-s', $serial, 'shell', 'monkey', '-p', 'com.wuxia.demo.qa', '-c', 'android.intent.category.LAUNCHER', '1')
Add-Step '杀进程重开' ($launch2 -notmatch 'No activities found|monkey aborted') 'force-stop 后重开'

$log = Invoke-Adb @('-s', $serial, 'logcat', '-d', '-t', '800')
$fatal = @($log -split '\r?\n' | Where-Object { $_ -match 'FATAL EXCEPTION|ANR in com\.wuxia\.demo\.qa' })
Add-Step '无崩溃/ANR' ($fatal.Count -eq 0) ('FATAL/ANR=' + $fatal.Count)
$logPath = [IO.Path]::Combine($OutDir, 'logcat_' + $stamp + '.txt')
[IO.File]::WriteAllText($logPath, $log)
$results | ConvertTo-Json | Set-Content -LiteralPath ([IO.Path]::Combine($OutDir, 'results_' + $stamp + '.json')) -Encoding utf8
$failed = @($results | Where-Object { -not $_.Passed })
$lines.Add('')
$lines.Add('- 汇总: ' + ($results.Count - $failed.Count) + ' / ' + $results.Count + ' 通过')
[IO.File]::WriteAllLines($report, $lines, (New-Object System.Text.UTF8Encoding($false)))
Write-Output ('DEVICE=1 SERIAL=' + $serial)
Write-Output ('REPORT=' + $report)
if ($failed.Count -gt 0) { exit 1 }
exit 0
