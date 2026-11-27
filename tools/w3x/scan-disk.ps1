$ErrorActionPreference = 'SilentlyContinue'
$dirs = @('D:\game','D:\360安全浏览器下载','D:\腾讯应用宝文件管理','D:\Program','C:\Users\zq300\Desktop','C:\Users\zq300\Downloads','C:\Users\zq300\Documents')
foreach ($d in $dirs) { if (Test-Path -LiteralPath $d) { Get-ChildItem -LiteralPath $d -Recurse -Force -Include *.w3x,*.w3m,*.w3n -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName } }
'--- D:\1 subdirs ---'
Get-ChildItem -LiteralPath 'D:\1' -Directory -Force | Where-Object { $_.Name -ne 'wuxia-demo' } | ForEach-Object { Get-ChildItem -LiteralPath $_.FullName -Recurse -Force -Include *.w3x,*.w3m -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notlike '*魔兽争霸3冰封王座*' } | Select-Object -ExpandProperty FullName }