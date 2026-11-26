param(
  [string]$Godot = 'C:/Users/zq300/Desktop/Godot_v4.7.2-stable_win64.exe',
  [string]$AndroidSdk = 'D:/Android',
  [string]$OutApk = '',
  [string]$RunId = '',
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
$publishApk = 'D:/1/wuxia-export/wuxia.apk'
$qaRoot = Join-Path $projectRoot '.shots/qa'
$qaRootFull = [IO.Path]::GetFullPath($qaRoot).TrimEnd('\') + '\'
if (-not $RunId) { $RunId = [Guid]::NewGuid().ToString('N') }
if ($RunId -notmatch '^[A-Za-z0-9._-]+$') { Write-Output "ERROR: 非法运行编号: $RunId"; exit 5 }
$runDir = Join-Path $qaRoot $RunId
if (-not $OutApk) { $OutApk = Join-Path $runDir 'wuxia_qa_android.apk' }

# ---------- 前置检查（任何写文件之前） ----------
if (-not [IO.File]::Exists($Godot)) { Write-Output "ERROR: Godot 不存在: $Godot"; exit 2 }
$btRoot = [IO.Path]::Combine($AndroidSdk, 'build-tools')
if (-not [IO.Directory]::Exists($btRoot)) { Write-Output "ERROR: Android build-tools 不存在: $btRoot"; exit 2 }
$bt = Get-ChildItem $btRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1
$apksigner = [IO.Path]::Combine($bt.FullName, 'apksigner.bat')
$aapt2 = [IO.Path]::Combine($bt.FullName, 'aapt2.exe')
if (-not [IO.File]::Exists($apksigner) -or -not [IO.File]::Exists($aapt2)) { Write-Output "ERROR: build-tools 不完整: $($bt.FullName)"; exit 2 }

# 输出路径规范化与限制：必须在 QA 目录内，且任何现存父级都不能是联接/符号链接
if (-not [IO.Path]::IsPathRooted($OutApk)) { $OutApk = Join-Path $projectRoot $OutApk }
$outFull = [IO.Path]::GetFullPath($OutApk)
if (-not $outFull.StartsWith($qaRootFull, [StringComparison]::OrdinalIgnoreCase)) {
    Write-Output "ERROR: 输出路径不在 QA 目录内: $outFull"; exit 5
}
if ($outFull.Equals([IO.Path]::GetFullPath($publishApk), [StringComparison]::OrdinalIgnoreCase)) {
    Write-Output "ERROR: 拒绝覆盖正式发布包: $outFull"; exit 5
}
$probe = Split-Path $outFull -Parent
while ($probe) {
    if (Test-Path $probe) {
        $it = Get-Item $probe -Force
        if ($it.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            Write-Output "ERROR: 路径含联接或符号链接: $probe"; exit 5
        }
    }
    $parent = Split-Path $probe -Parent
    if ($parent -eq $probe -or [string]::IsNullOrEmpty($parent)) { break }
    $probe = $parent
}
if (Test-Path $outFull) {
    $it = Get-Item $outFull -Force
    if ($it.PSIsContainer) { Write-Output "ERROR: 输出路径是目录: $outFull"; exit 5 }
    if ($it.Attributes -band [IO.FileAttributes]::ReparsePoint) { Write-Output "ERROR: 输出文件是链接: $outFull"; exit 5 }
}
# 已有 QA 包的基线（失败时必须保持不变）
$oldQaHash = if (Test-Path $outFull) { (Get-FileHash $outFull -Algorithm SHA256).Hash } else { $null }
$pubHashBefore = if (Test-Path $publishApk) { (Get-FileHash $publishApk -Algorithm SHA256).Hash } else { $null }
$pubTimeBefore = if (Test-Path $publishApk) { (Get-Item $publishApk).LastWriteTimeUtc } else { $null }

# ---------- 独立 QA 临时工程 ----------
New-Item -ItemType Directory -Path $runDir -Force | Out-Null
$qaProject = Join-Path $runDir 'qa_project'
New-Item -ItemType Directory -Path $qaProject -Force | Out-Null
foreach ($part in @('menu','shared','kushou','tools','assets','fonts','.godot')) {
    $target = Join-Path $qaProject $part
    if (-not (Test-Path $target)) { New-Item -ItemType Junction -Path $target -Target (Join-Path $projectRoot $part) | Out-Null }
}
Copy-Item -LiteralPath (Join-Path $projectRoot 'icon.svg') -Destination (Join-Path $qaProject 'icon.svg') -Force
$config = [IO.File]::ReadAllText((Join-Path $projectRoot 'project.godot'))
$config = $config.Replace('config/name="江湖游历"', 'config/name="江湖游历 QA"')
[IO.File]::WriteAllText((Join-Path $qaProject 'project.godot'), $config)
$preset = [IO.File]::ReadAllText((Join-Path $projectRoot 'export_presets.cfg'))
$preset = $preset.Replace('package/unique_name="com.wuxia.demo"', 'package/unique_name="com.wuxia.demo.qa"')
$preset = $preset.Replace('export_path="../wuxia-export/wuxia.apk"', ('export_path="' + ($outFull -replace '\\','/') + '"'))
$preset = $preset.Replace('exclude_filter="', 'exclude_filter="tools/audit_*, tools/_probe*, tools/qa_*, tools/playthrough*, tools/perf_*, .qa/*, ')
[IO.File]::WriteAllText((Join-Path $qaProject 'export_presets.cfg'), $preset)
Write-Output "QA_RUN_ID=$RunId"
Write-Output "QA_PROJECT=$qaProject"
Write-Output "QA_OUT=$outFull"

$outTemp = Join-Path $runDir ('_export_' + [Guid]::NewGuid().ToString('N') + '.apk')
if (-not $SkipExport) {
    $log = Invoke-Native $Godot @('--headless','--path',$qaProject,'--export-debug','Android',$outTemp)
    $code = $nativeExit
    if ($log.Trim().Length -gt 0) { Write-Output $log.Trim() }
    if ($code -ne 0 -or -not (Test-Path $outTemp)) {
        if (Test-Path $outTemp) { Remove-Item $outTemp -Force }
        Write-Output "ERROR: 导出失败（exit=$code），已有 QA 包保持原样"; exit 3
    }
} else {
    if (-not (Test-Path $outTemp)) { Write-Output "ERROR: -SkipExport 需要现有临时包: $outTemp"; exit 3 }
}

# ---------- 校验（在临时文件上） ----------
$sha = (Get-FileHash $outTemp -Algorithm SHA256).Hash
$signerOut = Invoke-Native $apksigner @('verify','--print-certs',$outTemp)
if ($signerOut -match 'DOES NOT VERIFY' -or $signerOut -notmatch 'Signer #1') { Write-Output 'ERROR: 签名校验失败'; if (Test-Path $outTemp) { Remove-Item $outTemp -Force }; exit 4 }
$cert = [regex]::Match($signerOut, 'certificate SHA-256 digest: ([0-9a-f]+)').Groups[1].Value
$badging = Invoke-Native $aapt2 @('dump','badging',$outTemp)
$pkg = [regex]::Match($badging, "package: name='([^']+)'").Groups[1].Value
$label = [regex]::Match($badging, "application-label:'([^']+)'").Groups[1].Value
$minSdk = [regex]::Match($badging, "minSdkVersion:'([^']+)'").Groups[1].Value
$native = [regex]::Match($badging, "native-code: '([^']*)'").Groups[1].Value
if ($pkg -ne 'com.wuxia.demo.qa') { Write-Output "ERROR: 包名不符: $pkg"; Remove-Item $outTemp -Force; exit 4 }
if ($label -notmatch '江湖游历 QA') { Write-Output "ERROR: 应用名不符: $label"; Remove-Item $outTemp -Force; exit 4 }
if ($native -notmatch 'arm64-v8a') { Write-Output "ERROR: ABI 不符: $native"; Remove-Item $outTemp -Force; exit 4 }

Add-Type -AssemblyName System.IO.Compression.FileSystem
$zip = [IO.Compression.ZipFile]::OpenRead($outTemp)
$names = @($zip.Entries | ForEach-Object { $_.FullName })
$zip.Dispose()
$required = @(
    'assets/kushou/result_view.gdc',
    'assets/kushou/card_frame.gdc',
    'assets/ui/panel_win.png.import',
    'assets/char/player_q.png.import',
    'assets/gen/qingshen/portrait_zhujue_ink_v3.webp.import',
    'assets/char/player_battle_frames.png.import',
    'assets/char/player_skill_poses_v2.png.import',
    'assets/gen/enemies/frames/crowd_brute_v1.png.import',
    'assets/gen/enemies/frames/crowd_shield_v1.png.import',
    'assets/audio/sfx/enemy_warning.ogg.import',
    'assets/audio/sfx/fall_down.ogg.import'
)
$imported = @(
    'portrait_zhujue_ink_v3.webp',
    'player_battle_frames.png',
    'player_skill_poses_v2.png',
    'crowd_brute_v1.png',
    'crowd_shield_v1.png',
    'enemy_warning.ogg',
    'fall_down.ogg'
)
$missing = @()
foreach ($needle in $required) { if (-not ($names | Where-Object { $_ -like "*$needle*" })) { $missing += $needle } }
foreach ($needle in $imported) { if (-not ($names | Where-Object { $_ -like "*imported/$needle-*" })) { $missing += "imported/$needle" } }
$forbidden = @($names | Where-Object { $_ -like '*/tools/audit_*' -or $_ -like '*/tools/playthrough*' -or $_ -like '*tools/_probe*' -or $_ -like '*docs/*' })
if ($missing.Count -gt 0) { Write-Output ('ERROR: APK 缺少资源: ' + ($missing -join ', ')); Remove-Item $outTemp -Force; exit 4 }
if ($forbidden.Count -gt 0) { Write-Output ('ERROR: APK 含应排除内容: ' + (($forbidden | Select-Object -First 5) -join ', ')); Remove-Item $outTemp -Force; exit 4 }

# ---------- 发布：校验全部通过后才替换旧 QA 包 ----------
Move-Item -LiteralPath $outTemp -Destination $outFull -Force
$pubHashAfter = if (Test-Path $publishApk) { (Get-FileHash $publishApk -Algorithm SHA256).Hash } else { $null }
$pubTimeAfter = if (Test-Path $publishApk) { (Get-Item $publishApk).LastWriteTimeUtc } else { $null }
if ($pubHashBefore -ne $pubHashAfter -or $pubTimeBefore -ne $pubTimeAfter) { Write-Output 'ERROR: 正式发布包被改动'; exit 4 }
if ($oldQaHash -and -not (Test-Path $outFull)) { Write-Output 'ERROR: 旧 QA 包丢失'; exit 4 }
$adbOut = Invoke-Native (Join-Path $AndroidSdk 'platform-tools/adb.exe') @('devices')
$deviceCount = @($adbOut -split '\r?\n' | Where-Object { $_ -match '\sdevice$' }).Count
Write-Output ('QA_EXPORT_PASS package=' + $pkg + ' label=' + $label + ' minSdk=' + $minSdk + ' abi=' + $native)
Write-Output ('SHA256=' + $sha)
Write-Output ('CERT_SHA256=' + $cert)
Write-Output ('SIZE=' + (Get-Item $outFull).Length)
Write-Output ('DEVICE=' + $deviceCount)
exit 0
