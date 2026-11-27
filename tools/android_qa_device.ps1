param(
  [string]$Adb = 'D:/Android/platform-tools/adb.exe',
  [string]$Apk = '',
  [string]$Serial = '',
  [string]$OutDir = '',
  [int]$CheckLevel = 6
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not $OutDir) { $OutDir = [IO.Path]::Combine($root, '.shots', 'android_qa_device') }
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$runDir = [IO.Path]::Combine($OutDir, $stamp)
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$report = [IO.Path]::Combine($runDir, 'report.md')
$lines = New-Object System.Collections.Generic.List[string]
$results = New-Object System.Collections.Generic.List[object]
$lines.Add('# Android QA 设备验收 ' + $stamp)

function Invoke-Adb {
    param([string[]]$Arguments)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & $Adb @Arguments 2>&1 | Out-String
    $script:adbExit = $LASTEXITCODE
    $ErrorActionPreference = $prev
    return $out.TrimEnd()
}

function Add-Result {
    param([string]$UseCase, [string]$Status, [string]$Detail)
    $script:results.Add([pscustomobject]@{UseCase=$UseCase; Status=$Status; Detail=$Detail})
    $lines.Add('- ' + $UseCase + ': **' + $Status + '** — ' + $Detail)
}

function Get-CfgValue {
    param([string]$Text, [string]$Name)
    $m = [regex]::Match($Text, '(?m)^' + [regex]::Escape($Name) + '=(\d+)')
    if ($m.Success) { return $m.Groups[1].Value }
    return ''
}

function Get-FirstClearValue {
    param([string]$Text, [int]$Level)
    $block = [regex]::Match($Text, 'first_clear=\{[^}]*\}')
    if (-not $block.Success) { return '' }
    $m = [regex]::Match($block.Value, '"' + $Level + '":\s*(true|false)')
    if ($m.Success) { return $m.Groups[1].Value }
    return ''
}

function Test-Foreground {
    param([string]$Pkg)
    $pidText = Invoke-Adb @('-s', $script:serial, 'shell', 'pidof', $Pkg)
    $procOk = ($pidText -match '^\s*\d+\s*$')
    $act = Invoke-Adb @('-s', $script:serial, 'shell', 'dumpsys', 'activity', 'activities')
    $fgOk = ($act -match 'mResumedActivity.*' + [regex]::Escape($Pkg))
    return @{ proc = $procOk; fg = $fgOk; pid = $pidText.Trim() }
}

function Save-Screenshot {
    param([string]$Stage)
    $remote = '/sdcard/qa_' + $Stage + '.png'
    Invoke-Adb @('-s', $script:serial, 'shell', 'screencap', '-p', $remote) | Out-Null
    $local = [IO.Path]::Combine($runDir, 'screen_' + $Stage + '.png')
    Invoke-Adb @('-s', $script:serial, 'pull', $remote, $local) | Out-Null
    return (Test-Path $local)
}

if (-not [IO.File]::Exists($Adb)) { Write-Output ('ERROR: adb 不存在: ' + $Adb); exit 2 }
if (-not $Apk) {
    $cands = @(Get-ChildItem ([IO.Path]::Combine($root, '.shots', 'qa')) -Depth 2 -File -Filter 'wuxia_qa_android.apk' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    if ($cands.Count -gt 0) { $Apk = $cands[0].FullName }
}
if (-not $Apk -or -not (Test-Path $Apk)) { Write-Output 'ERROR: 找不到 QA APK'; exit 2 }
$apkSha = (Get-FileHash $Apk -Algorithm SHA256).Hash
$lines.Add('- APK: `' + $Apk + '`')
$lines.Add('- APK SHA-256: `' + $apkSha + '`')

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
$model = (Invoke-Adb @('-s', $serial, 'shell', 'getprop', 'ro.product.model')).Trim()
$android = (Invoke-Adb @('-s', $serial, 'shell', 'getprop', 'ro.build.version.release')).Trim()
$lines.Add('- 设备: `' + $serial + '` / ' + $model + ' / Android ' + $android)
$lines.Add('')

$pkg = 'com.wuxia.demo.qa'
$pm = Invoke-Adb @('-s', $serial, 'shell', 'dumpsys', 'package', $pkg)
$wasInstalled = ($pm -match ('Package \[' + [regex]::Escape($pkg) + '\]'))
$beforeSave = ''
if ($wasInstalled) {
    Add-Result '已有 QA 包' 'INFO' '已安装，走覆盖安装'
    $beforeSave = Invoke-Adb @('-s', $serial, 'exec-out', 'run-as', $pkg, 'cat', 'files/level_state.cfg')
    Add-Result '安装前测试档' ($(if ($beforeSave.Trim().Length -gt 0) { 'PASS' } else { 'SKIP' })) ('长度 ' + $beforeSave.Length)
} else {
    Add-Result '已有 QA 包' 'INFO' '未安装，走初装'
}

$install = Invoke-Adb @('-s', $serial, 'install', '-r', $Apk)
$installOk = ($install -match '(?m)^Success')
Add-Result '安装/覆盖安装' ($(if ($installOk) { 'PASS' } else { 'FAIL' })) (($install -split '\r?\n' | Select-Object -Last 2) -join ' ')
if (-not $installOk) {
    [IO.File]::WriteAllText([IO.Path]::Combine($runDir, 'install_fail.txt'), $install)
    $log = Invoke-Adb @('-s', $serial, 'logcat', '-d', '-t', '400')
    [IO.File]::WriteAllText([IO.Path]::Combine($runDir, 'install_fail_logcat.txt'), $log)
    Add-Result '安装失败诊断' 'INFO' ('install_fail.txt / install_fail_logcat.txt')
    $lines.Add('')
    $lines.Add('- 汇总: FAIL（安装失败）')
    [IO.File]::WriteAllLines($report, $lines, (New-Object System.Text.UTF8Encoding($false)))
    Write-Output ('DEVICE=1 SERIAL=' + $serial)
    Write-Output ('REPORT=' + $report)
    exit 1
}

$afterSave = Invoke-Adb @('-s', $serial, 'exec-out', 'run-as', $pkg, 'cat', 'files/level_state.cfg')
if (-not $wasInstalled) {
    Add-Result '覆盖安装存档保留' 'SKIP' '初装无旧档，跳过对比'
} elseif ($beforeSave.Trim().Length -eq 0) {
    Add-Result '覆盖安装存档保留' 'SKIP' '安装前测试档缺失，覆盖存档用例未执行'
} else {
    $bMax = Get-CfgValue $beforeSave 'max_unlocked'
    $aMax = Get-CfgValue $afterSave 'max_unlocked'
    $bFc = Get-FirstClearValue $beforeSave $CheckLevel
    $aFc = Get-FirstClearValue $afterSave $CheckLevel
    $detail = ('max_unlocked ' + $bMax + ' -> ' + $aMax + '；first_clear[' + $CheckLevel + '] ' + $bFc + ' -> ' + $aFc)
    if ($bMax -eq '' -or $bFc -eq '' -or $aMax -eq '' -or $aFc -eq '') {
        Add-Result '覆盖安装存档保留' 'SKIP' ('字段缺失，覆盖存档用例未执行；' + $detail)
    } elseif ($bMax -eq $aMax -and $bFc -eq $aFc) {
        Add-Result '覆盖安装存档保留' 'PASS' $detail
    } else {
        Add-Result '覆盖安装存档保留' 'FAIL' $detail
    }
}

Invoke-Adb @('-s', $serial, 'logcat', '-c') | Out-Null
$launchCmd = Invoke-Adb @('-s', $serial, 'shell', 'am', 'force-stop', $pkg)
$launch = Invoke-Adb @('-s', $serial, 'shell', 'monkey', '-p', $pkg, '-c', 'android.intent.category.LAUNCHER', '1')
$launchIssued = ($launch -notmatch 'No activities found|monkey aborted')
Add-Result '冷启动命令' ($(if ($launchIssued) { 'PASS' } else { 'FAIL' })) (($launch -split '\r?\n' | Select-Object -Last 1).Trim())
Start-Sleep -Seconds 6
$fg = Test-Foreground $pkg
Add-Result '冷启动进程' ($(if ($fg.proc) { 'PASS' } else { 'FAIL' })) ('pid=' + $fg.pid)
Add-Result '冷启动前台' ($(if ($fg.fg) { 'PASS' } else { 'FAIL' })) 'mResumedActivity 匹配'
$shots = @()
$shots += (Save-Screenshot 'cold')

Invoke-Adb @('-s', $serial, 'shell', 'input', 'keyevent', '3') | Out-Null
Start-Sleep -Seconds 2
$re = Invoke-Adb @('-s', $serial, 'shell', 'monkey', '-p', $pkg, '-c', 'android.intent.category.LAUNCHER', '1')
$reIssued = ($re -notmatch 'No activities found|monkey aborted')
Start-Sleep -Seconds 3
$fg2 = Test-Foreground $pkg
Add-Result '后台返回命令' ($(if ($reIssued) { 'PASS' } else { 'FAIL' })) 'HOME 后重新进入'
Add-Result '后台返回进程/前台' ($(if ($fg2.proc -and $fg2.fg) { 'PASS' } else { 'FAIL' })) ('pid=' + $fg2.pid)
$shots += (Save-Screenshot 'resume')

Invoke-Adb @('-s', $serial, 'shell', 'am', 'force-stop', $pkg) | Out-Null
Start-Sleep -Seconds 1
$re2 = Invoke-Adb @('-s', $serial, 'shell', 'monkey', '-p', $pkg, '-c', 'android.intent.category.LAUNCHER', '1')
$re2Issued = ($re2 -notmatch 'No activities found|monkey aborted')
Start-Sleep -Seconds 6
$fg3 = Test-Foreground $pkg
Add-Result '杀进程重开命令' ($(if ($re2Issued) { 'PASS' } else { 'FAIL' })) 'force-stop 后重开'
Add-Result '杀进程重开进程/前台' ($(if ($fg3.proc -and $fg3.fg) { 'PASS' } else { 'FAIL' })) ('pid=' + $fg3.pid)
$shots += (Save-Screenshot 'relaunch')

$shotOk = (@($shots | Where-Object { $_ }).Count -gt 0)
Add-Result '首屏截图' ($(if ($shotOk) { 'PASS' } else { 'FAIL' })) (($shots -join ', '))

$log = Invoke-Adb @('-s', $serial, 'logcat', '-d', '-t', '800')
[IO.File]::WriteAllText([IO.Path]::Combine($runDir, 'logcat.txt'), $log)
$fatal = @($log -split '\r?\n' | Where-Object { $_ -match 'FATAL EXCEPTION|ANR in ' + [regex]::Escape($pkg) })
Add-Result '无崩溃/ANR' ($(if ($fatal.Count -eq 0) { 'PASS' } else { 'FAIL' })) ('FATAL/ANR=' + $fatal.Count)

$failed = @($results | Where-Object { $_.Status -eq 'FAIL' })
$skipped = @($results | Where-Object { $_.Status -eq 'SKIP' })
$lines.Add('')
$lines.Add('- 汇总: ' + ($results.Count - $failed.Count - $skipped.Count) + ' PASS / ' + $failed.Count + ' FAIL / ' + $skipped.Count + ' SKIP')
[IO.File]::WriteAllLines($report, $lines, (New-Object System.Text.UTF8Encoding($false)))
$results | ConvertTo-Json | Set-Content -LiteralPath ([IO.Path]::Combine($runDir, 'results.json')) -Encoding utf8
Write-Output ('DEVICE=1 SERIAL=' + $serial)
Write-Output ('REPORT=' + $report)
if ($failed.Count -gt 0) { exit 1 }
exit 0
