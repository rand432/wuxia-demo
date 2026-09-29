# 计划任务版：试 N 轮就退（给 Windows 计划任务每小时调用）
param([int]$Rounds = 6, [int]$IntervalMin = 8)
$cli = 'C:\Users\zq300\.libtv\libtv.exe'
$WS  = 'D:\1\wuxia-demo'
$K   = Join-Path $WS 'assets\gen\keyframes'
$O   = Join-Path $WS 'assets\gen\aivideo'
$LOG = Join-Path $WS '.git\retry.log'
Set-Location $WS
function L($m) { $s = "[" + (Get-Date -Format "MM-dd HH:mm:ss") + "] " + $m; [System.IO.File]::AppendAllText($LOG, $s + [char]10, (New-Object System.Text.UTF8Encoding $false)) }

function Try-Video([string]$name, [string]$kf, [string]$prompt, [int]$dur) {
  & $cli upload ($name + "_kf") --resource (Join-Path $K $kf) --x (Get-Random -Max 900) --y (Get-Random -Max 900) 2>&1 | Out-Null
  & $cli node delete $name 2>&1 | Out-Null
  & $cli node create $name -t video -s "model=Wan 3.0" -s "modeType=frames2video" -s ("duration=" + $dur) --left-add ($name + "_kf") --prompt $prompt 2>&1 | Out-Null
  $r = & $cli node $name --run 2>&1 | Out-String
  # 用错误码判断（1200000136 = 算力不足），避免中文在计划任务里编码不同导致误判
  if ($r -match "1200000136" -or $r -match "算力不足") { return "busy" }
  if ($r -notmatch "taskId") {
    $code = ([regex]::Match($r, 'code:\s*(\d+)')).Groups[1].Value
    return ("fail:" + $code)
  }
  & $cli download -n $name --without-ai-watermark --vip -o $O 2>&1 | Out-Null
  if (Test-Path (Join-Path $O ($name + ".mp4"))) { return "ok" } else { return "nodl" }
}

$p03 = "中国水墨画风格。二维水墨绘画，宣纸上作画，墨色浓淡干湿，不是照片不是3D渲染。画面正中两只中国古代的陶制酒盏从左右倾斜着举起来相碰，宽口浅腹的陶器，盏身厚实，底下只有很短的圈足。盏里鲜红的酒在相碰的一刻从盏沿炸开溅出，酒液顺桌沿往下滴。案上一叠残破的书和一只倒下的陶壶。画面中没有玻璃器皿，没有细长的高脚。镜头固定，相碰瞬间轻微一颤，之后极缓推近那滩酒渍。"
$p02 = "中国水墨画风格。二维水墨绘画，宣纸上作画，墨色浓淡干湿，不是照片不是3D渲染。荒原上一眼望不到头的逃难人流正在缓缓前行，衣衫褴褛、身形枯瘦，有人拄杖、有人背着孩子、有人已经倒下。旗帜与破布被风吹得猎猎翻动，地上的尘土与烟尘一阵阵卷起流动，枯树在风里摇晃。血红的残阳挂在天边。镜头缓慢横移跟拍人流，画面里的人持续在走动。"

for ($i = 1; $i -le $Rounds; $i++) {
  $r = Try-Video "03_纸醉金迷" "03_宫殿纸醉金迷.png" $p03 8
  L ("第 " + $i + "/" + $Rounds + " 轮  03=" + $r)
  if ($r -eq "ok") {
    L "03 出片成功"
    $r2 = Try-Video "02_荒原流民" "02_荒原流民.png" $p02 8
    L ("02=" + $r2)
    L "下一步：改 edl.json 里 03 那条从「03_陶盏缓推.mp4」换回「03_纸醉金迷.mp4」（type 改 ai、去掉 speed），再跑 tools\build_film.ps1"
    exit 0
  }
  if ($r -notlike "busy*") { L ("非算力问题（" + $r + "），本轮停止"); exit 1 }
  if ($i -lt $Rounds) { Start-Sleep -Seconds ($IntervalMin * 60) }
}
L "本轮无算力，等下次计划任务"