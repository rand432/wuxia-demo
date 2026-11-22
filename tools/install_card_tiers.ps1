# 用法：把生成的源图按 <series>_<tier> 命名考进 tmp-cards-tier，然后运行本脚本
# 输入名建议：atk_0.png / atk_1.png ...（series_key + tier）
# 输出：assets/art/cards/gen/<series>_<tier>.png（透明底）
param(
    [string]$Stage = 'C:\Users\zq300\.dsh\dsh-imagegen\tmp-cards-tier',
    [string]$Out = 'D:\1\wuxia-demo\assets\art\cards\gen'
)
$ErrorActionPreference = 'Stop'
if (-not (Test-Path $Stage)) { throw "stage not found: $Stage" }
New-Item -ItemType Directory -Force -Path $Out | Out-Null
Push-Location 'D:\1\wuxia-demo\tools\ai-cutout'
try {
    $env:FFMPEG = 'C:\Users\zq300\ffmpeg\bin\ffmpeg.exe'
    $env:FFPROBE = 'C:\Users\zq300\ffmpeg\bin\ffprobe.exe'
    $files = Get-ChildItem $Stage -File | Where-Object { $_.Extension -in '.png', '.jpg', '.jpeg' } | ForEach-Object { $_.FullName }
    if ($files.Count -eq 0) { throw "no source images in $Stage" }
    node ai_cutout.mjs @files --out $Stage --suffix _cut
    Get-ChildItem $Stage -Filter '*_cut.png' | ForEach-Object {
        # 输出名形如 atk_0.png_cut.png → 还原成 atk_0.png
        $base = $_.Name -replace '\.(png|jpg|jpeg)_cut\.png$', ''
        $base = $base -replace '_cut\.png$', ''
        $target = Join-Path $Out ($base + '.png')
        Move-Item $_.FullName $target -Force
        "installed " + (Split-Path $target -Leaf)
    }
} finally {
    Pop-Location
}
