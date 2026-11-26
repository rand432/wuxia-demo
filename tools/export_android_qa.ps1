param(
  [string]$Godot = 'C:/Users/zq300/Desktop/Godot_v4.7.2-stable_win64.exe',
  [string]$AndroidSdk = 'D:/Android',
  [string]$OutApk = '',
  [switch]$SkipExport
)
$ErrorActionPreference = 'Stop'
function Invoke-Native {
    param([string]$Exe, [string[]]$Arguments)
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $out = & $Exe @Arguments 2>&1 | Out-String
    $script:nativeExit = $LASTEXITCODE
    $ErrorActionPreference = $prev
    return $out
}
$projectRoot = Split-Path $PSScriptRoot -Parent
if (-not $OutApk) { $OutApk = Join-Path $projectRoot '.shots/wuxia_qa_android.apk' }

# ---------- 前置检查 ----------
if (-not (Test-Path $Godot)) { Write-Output "ERROR: Godot 不存在: $Godot"; exit 2 }
$btRoot = Join-Path $AndroidSdk 'build-tools'
if (-not (Test-Path $btRoot)) { Write-Output "ERROR: Android build-tools 不存在: $btRoot"; exit 2 }
$bt = Get-ChildItem $btRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1
$apksigner = Join-Path $bt.FullName 'apksigner.bat'
$aapt2 = Join-Path $bt.FullName 'aapt2.exe'
if (-not (Test-Path $apksigner) -or -not (Test-Path $aapt2)) { Write-Output "ERROR: build-tools 不完整: $($bt.FullName)"; exit 2 }

$publishApk = 'D:/1/wuxia-export/wuxia.apk'
$pubBefore = if (Test-Path $publishApk) { (Get-Item $publishApk).LastWriteTimeUtc } else { $null }

# ---------- 构造 QA 测试工程（不改正式 project.godot / 发布包） ----------
$qaRoot = Join-Path $projectRoot '.shots/qa/qa_project'
New-Item -ItemType Directory -Path $qaRoot -Force | Out-Null
foreach ($part in @('menu','shared','kushou','tools','assets','fonts','.godot')) {
    $target = Join-Path $qaRoot $part
    if (-not (Test-Path $target)) { New-Item -ItemType Junction -Path $target -Target (Join-Path $projectRoot $part) | Out-Null }
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'icon.svg') -Destination (Join-Path $qaRoot 'icon.svg') -Force
$config = [IO.File]::ReadAllText((Join-Path $projectRoot 'project.godot'))
$config = $config.Replace('config/name="江湖游历"', 'config/name="江湖游历 QA"')
[IO.File]::WriteAllText((Join-Path $qaRoot 'project.godot'), $config)
$preset = [IO.File]::ReadAllText((Join-Path $projectRoot 'export_presets.cfg'))
$preset = $preset.Replace('package/unique_name="com.wuxia.demo"', 'package/unique_name="com.wuxia.demo.qa"')
$preset = $preset.Replace('export_path="../wuxia-export/wuxia.apk"', ('export_path="' + ($OutApk -replace '\\\\','/') + '"'))
$preset = $preset.Replace('exclude_filter="', 'exclude_filter="tools/audit_*, tools/_probe*, tools/qa_*, tools/playthrough*, .qa/*, ')
[IO.File]::WriteAllText((Join-Path $qaRoot 'export_presets.cfg'), $preset)
Write-Output "QA_PROJECT=$qaRoot"
Write-Output "QA_OUT=$OutApk"

# ---------- 导出 ----------
if (-not $SkipExport) {
    if (Test-Path $OutApk) { Remove-Item $OutApk -Force }
    $log = Invoke-Native $Godot @('--headless','--path',$qaRoot,'--export-debug','Android',$OutApk)
    $code = $nativeExit
    if ($log.Trim().Length -gt 0) { Write-Output $log.Trim() }
    if ($code -ne 0 -or -not (Test-Path $OutApk)) { Write-Output "ERROR: 导出失败（exit=$code）: $OutApk"; exit 3 }
}
if (-not (Test-Path $OutApk)) { Write-Output "ERROR: APK 不存在: $OutApk"; exit 3 }

# ---------- 校验 ----------
$sha = (Get-FileHash $OutApk -Algorithm SHA256).Hash
$signerOut = Invoke-Native $apksigner @('verify','--print-certs',$OutApk)
if ($signerOut -match 'DOES NOT VERIFY' -or $signerOut -notmatch 'Signer #1') { Write-Output 'ERROR: 签名校验失败'; exit 4 }
$cert = [regex]::Match($signerOut, 'certificate SHA-256 digest: ([0-9a-f]+)').Groups[1].Value
$badging = Invoke-Native $aapt2 @('dump','badging',$OutApk)
$pkg = [regex]::Match($badging, "package: name='([^']+)'").Groups[1].Value
$minSdk = [regex]::Match($badging, "minSdkVersion:'([^']+)'").Groups[1].Value
$label = [regex]::Match($badging, "application-label:'([^']+)'").Groups[1].Value
$native = [regex]::Match($badging, "native-code: '([^']*)'").Groups[1].Value
if ($pkg -ne 'com.wuxia.demo.qa') { Write-Output "ERROR: 包名不符: $pkg"; exit 4 }
if ($label -notmatch '江湖游历 QA') { Write-Output "ERROR: 应用名不符: $label"; exit 4 }
if ($native -notmatch 'arm64-v8a') { Write-Output "ERROR: ABI 不符: $native"; exit 4 }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($OutApk)
$names = @($zip.Entries | ForEach-Object { $_.FullName })
$required = @(
    'assets/kushou/result_view.gdc',
    'assets/assets/ui/panel_win.png.import',
    'assets/assets/char/player_q.png.import',
    'assets/assets/gen/enemies/frames/kunshou_zhu_v1.png.import',
    'foe_kunshou_zhu.png',
    'boss_impact_',
    'enemy_warning',
    'assets/kushou/card_frame.gdc'
)
$missing = @()
foreach ($needle in $required) {
    if (-not ($names | Where-Object { $_ -like "*$needle*" })) { $missing += $needle }
}
$forbidden = @($names | Where-Object { $_ -like '*tools/_probe*' -or $_ -like '*audit_project*' -or $_ -like '*docs/*' -or $_ -like '*.apk' })
$zip.Dispose()
if ($missing.Count -gt 0) { Write-Output ('ERROR: APK 缺少资源: ' + ($missing -join ', ')); exit 4 }
if ($forbidden.Count -gt 0) { Write-Output ('ERROR: APK 含应排除内容: ' + (($forbidden | Select-Object -First 5) -join ', ')); exit 4 }
if ($pubBefore -and (Test-Path $publishApk)) {
    $pubAfter = (Get-Item $publishApk).LastWriteTimeUtc
    if ($pubAfter -ne $pubBefore) { Write-Output 'ERROR: 正式发布包被改动'; exit 4 }
}
Write-Output ('QA_EXPORT_PASS package=' + $pkg + ' label=' + $label + ' minSdk=' + $minSdk + ' abi=' + $native)
Write-Output ('SHA256=' + $sha)
Write-Output ('CERT_SHA256=' + $cert)
Write-Output ('SIZE=' + (Get-Item $OutApk).Length)
$adbOut = Invoke-Native (Join-Path $AndroidSdk 'platform-tools/adb.exe') @('devices')
$deviceCount = @($adbOut -split '\r?\n' | Where-Object { $_ -match '\sdevice$' }).Count
Write-Output ('DEVICE=' + $deviceCount)
exit 0
