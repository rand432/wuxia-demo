<#
  开场动画 · 本地 2.5D 运镜生成器（v1）
  ------------------------------------------------------------
  用途：把 assets/gen/keyframes/ 里的静态关键帧，按每镜的情绪配一种镜头运动
        （推 / 拉 / 摇 / 移），用 ffmpeg 的 zoompan 生成 1280x720 / 25fps 的片段。
  为什么：水墨片的"动"本来就不靠人物演，靠镜头的呼吸。
          参考片《剑意》"一笔墨路"那 4 秒就是几乎不动的缓推。
  日期：2026-09-27
#>
param(
  [string]$Only = '',          # 只跑某一镜（前缀匹配）
  [switch]$Dry
)
$ErrorActionPreference = 'Stop'
$ff  = 'C:\Users\zq300\ffmpeg\bin\ffmpeg.exe'
$KDIR = 'D:\1\wuxia-demo\assets\gen\keyframes'
$ODIR = 'D:\1\wuxia-demo\assets\gen\motion'
New-Item -ItemType Directory -Force -Path $ODIR | Out-Null

# ---- 每镜的运镜表 ----------------------------------------------------------
# name        秒  z0    z1    聚焦X 聚焦Y  平移X  平移Y   情绪说明
$SHOTS = @(
  @{n='01_墨入水';      t=5;  z0=1.00; z1=1.18; fx=0.50; fy=0.55; px=0;    py=0;    note='极缓推近墨滴'},
  @{n='02_荒原流民';    t=7;  z0=1.08; z1=1.02; fx=0.50; fy=0.55; px=-70;  py=0;    note='极缓横移跟流民 + 略拉远'},
  @{n='03_宫殿纸醉金迷';t=8;  z0=1.00; z1=1.16; fx=0.50; fy=0.45; px=0;    py=18;   note='起幅静 → 缓推近碰杯处'},
  @{n='04_刀在膝上_B擦刀';t=8;z0=1.12; z1=1.05; fx=0.42; fy=0.52; px=40;   py=0;    note='从刀身缓摇向手'},
  @{n='05_红烛婚礼';    t=8;  z0=1.10; z1=1.03; fx=0.32; fy=0.50; px=48;   py=0;    note='从门框推向婚房深处'},
  @{n='06_门外护卫';    t=10; z0=1.00; z1=1.06; fx=0.50; fy=0.50; px=0;    py=0;    note='几乎不动，只有光影'},
  @{n='07a_翻杯围拢';   t=6;  z0=1.00; z1=1.17; fx=0.52; fy=0.44; px=0;    py=0;    note='缓推近翻倒的杯'},
  @{n='07b_混战中刀';   t=4;  z0=1.00; z1=1.22; fx=0.50; fy=0.48; px=0;    py=0;    note='快速推近（激烈）'},
  @{n='07c_师傅的话';   t=3;  z0=1.00; z1=1.13; fx=0.50; fy=0.42; px=0;    py=0;    note='极缓推近老者'},
  @{n='07d_宗门焚毁';   t=4;  z0=1.00; z1=1.20; fx=0.50; fy=0.40; px=0;    py=0;    note='缓推近匾额'},
  @{n='07e_被逼崖边';   t=4;  z0=1.10; z1=1.04; fx=0.42; fy=0.52; px=-52;  py=0;    note='极缓横移（压迫）'},
  @{n='07b2_一刀光';    t=2;  z0=1.00; z1=1.22; fx=0.52; fy=0.48; px=0;    py=0;    note='推近光心（就一下）'},
  @{n='07b3_雨空镜';    t=3;  z0=1.00; z1=1.05; fx=0.50; fy=0.55; px=0;    py=0;    note='几乎完全不动'},
  @{n='08_坠崖';        t=8;  z0=1.00; z1=1.16; fx=0.50; fy=0.42; px=0;    py=62;   note='缓推近 + 下移跟坠'},
  @{n='09_没死';        t=10; z0=1.00; z1=1.14; fx=0.50; fy=0.46; px=0;    py=0;    note='极缓推近那只手'},
  @{n='10_五问';        t=10; z0=1.12; z1=1.04; fx=0.46; fy=0.44; px=34;   py=0;    note='缓摇（环绕感）'},
  @{n='11_江湖新客';    t=10; z0=1.16; z1=1.00; fx=0.50; fy=0.50; px=0;    py=0;    note='极缓拉远（雾合拢）'}
)

$made = 0
foreach ($s in $SHOTS) {
  if ($Only -ne '' -and $s.n -notlike "$Only*") { continue }
  $src = Join-Path $KDIR ($s.n + '.png')
  if (-not (Test-Path $src)) { Write-Output ("  ✗ 缺关键帧: " + $s.n); continue }
  $dst = Join-Path $ODIR ($s.n + '.mp4')
  $D   = [int]($s.t * 25)                     # 总帧数
  $z0  = $s.z0; $z1 = $s.z1
  $fx  = $s.fx; $fy = $s.fy
  $px  = $s.px; $py = $s.py
  $vf = "zoompan=z='$z0+($z1-$z0)*on/$D'" +
        ":x='max(0,min(iw-iw/zoom,$fx*iw-iw/zoom/2+$px*on/$D))'" +
        ":y='max(0,min(ih-ih/zoom,$fy*ih-ih/zoom/2+$py*on/$D))'" +
        ":d=${D}:s=1280x720:fps=25,format=yuv420p"
  if ($Dry) { Write-Output ("  [dry] " + $s.n + "  " + $s.t + "s  " + $s.note); continue }
  & $ff -y -v error -loop 1 -i $src -vf $vf -t $s.t -c:v libx264 -crf 18 -preset medium $dst 2>&1 | Out-Null
  if (Test-Path $dst) {
    $kb = [math]::Round((Get-Item $dst).Length / 1KB)
    Write-Output ("  ✓ " + $s.n.PadRight(22) + " " + $s.t.ToString().PadLeft(2) + "s  " + $kb.ToString().PadLeft(4) + "KB   " + $s.note)
    $made++
  } else { Write-Output ("  ✗ 失败: " + $s.n) }
}
Write-Output ""
Write-Output ("共生成 " + $made + " 段 → " + $ODIR)
