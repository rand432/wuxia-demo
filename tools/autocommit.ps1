# ============================================================
# 自动存档（autocommit）—— 由 Windows 计划任务「wuxia-autocommit」每 30 分钟调用
# 有改动就提交，然后推送到【所有】远端（backup=E: 裸仓库 + origin=Gitee）；
# 没改动就静默退出（不产生空提交）。
#
# 手动跑一次：
#   powershell -NoProfile -ExecutionPolicy Bypass -File D:\1\wuxia-demo\tools\autocommit.ps1
# 日志：D:\1\wuxia-demo\.git\autocommit.log（放在 .git 里，不会弄脏工作区）
#
# v2（2026-11-09）：**推送失败不再静默**
#   背景：远端历史被重写后，这个脚本连续失败了一个月，但只在日志里写一行、没人看，
#         发现时异地备份已经停摆 30 天。
#   现在：
#     · 失败 → 弹 Windows 气泡提示（第 1 次立刻提示，之后每小时提示一次）
#     · 状态写进 .git\autocommit-status.txt；恢复时也提示一次并清掉计数
#     · 没改动的那一轮，如果上次是失败状态，会顺手 ls-remote 探一下远端恢复没有
#     · 支持 -Repo 参数指向别的仓库（测试用；计划任务不传参，行为不变）
#
# ⚠ 本文件必须存成 **UTF-8 带 BOM**（或 UTF-16）：计划任务用的是 powershell.exe 5.1，
#   它读不带 BOM 的文件会按 ANSI/GBK 解，中文字符串直接变成乱码、整个脚本编译失败。
#
# 两个坑（都踩过，别改回去）：
#   1) PS 5.1 里原生 exe 的 stderr 在 ErrorActionPreference=Stop 下会被当成终止错误
#      —— 所以用 Continue，并且每个原生命令后面立刻查 $LASTEXITCODE。
#   2) $LASTEXITCODE 有作用域：一旦把原生命令包进函数，退出码就写在函数局部作用域里。
#      —— 所以这里坚持「同一个作用域里调用 + 立刻取退出码」，不封装成函数。
# ============================================================

param(
    [string]$Repo = 'D:\1\wuxia-demo'
)

$ErrorActionPreference = 'Continue'
$GitBin     = 'C:\Program Files\Git\cmd\git.exe'
$Log        = Join-Path $Repo '.git\autocommit.log'
$StatusFile = Join-Path $Repo '.git\autocommit-status.txt'
$FailFile   = Join-Path $Repo '.git\autocommit-failcount'
$AlertEvery = 2      # 连续失败时，每 2 次（约 1 小时）再提醒

# 远端不可达时别卡住计划任务：10 秒连接超时 + 禁止任何交互式提问
$env:GIT_SSH_COMMAND     = 'ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new'
$env:GIT_TERMINAL_PROMPT = '0'

function Write-Log([string]$m) {
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
    Add-Content -LiteralPath $Log -Value $line -Encoding UTF8
}

function Get-FailCount {
    if (Test-Path -LiteralPath $FailFile) {
        $v = Get-Content -LiteralPath $FailFile -ErrorAction SilentlyContinue | Select-Object -First 1
        if ("$v" -match '^\d+$') { return [int]$v }
    }
    return 0
}

function Set-FailCount([int]$n) {
    Set-Content -LiteralPath $FailFile -Value "$n" -Encoding UTF8
}

function Set-Status([string]$s) {
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $s
    Set-Content -LiteralPath $StatusFile -Value $line -Encoding UTF8
}

# 托盘气泡提示；计划任务跑在没有桌面的上下文里会失败，所以整段吞异常
function Show-Balloon([string]$title, [string]$body, [string]$kind) {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        $ni = New-Object System.Windows.Forms.NotifyIcon
        if ($kind -eq 'info') { $ni.Icon = [System.Drawing.SystemIcons]::Information }
        else { $ni.Icon = [System.Drawing.SystemIcons]::Warning }
        $ni.Visible = $true
        $ni.BalloonTipTitle = $title
        $ni.BalloonTipText  = $body
        $iconKind = 'Warning'
        if ($kind -eq 'info') { $iconKind = 'Info' }
        $ni.ShowBalloonTip(10000, $title, $body, $iconKind)
        Start-Sleep -Milliseconds 1500
        $ni.Dispose()
    } catch { }
}

if (-not (Test-Path -LiteralPath $GitBin)) { exit 1 }
if (-not (Test-Path -LiteralPath (Join-Path $Repo '.git'))) { exit 1 }

# ---- 没改动就别打扰；但上次失败过的话，顺手探一下远端恢复没有 ----
$status = & $GitBin -C $Repo status --porcelain 2>&1
$code = $LASTEXITCODE
if ($code -ne 0) { Write-Log ('git status 失败 exit=' + $code); exit 1 }

if (-not $status) {
    $prev = Get-FailCount
    if ($prev -gt 0) {
        $bad = @()
        $remotes = & $GitBin -C $Repo remote 2>&1
        foreach ($r in $remotes) {
            $name = "$r".Trim()
            if (-not $name) { continue }
            $null = & $GitBin -C $Repo ls-remote --heads $name 2>&1
            if ($LASTEXITCODE -ne 0) { $bad += $name }
        }
        if ($bad.Count -eq 0) {
            Write-Log ('远端已恢复（此前连续失败 ' + $prev + ' 次）')
            Set-FailCount 0
            Set-Status 'OK（探测：所有远端可读）'
            Show-Balloon '备份已恢复' ('所有远端都能访问了（此前连续失败 ' + $prev + ' 次）') 'info'
        }
    }
    exit 0
}

# ---- 提交 ----
& $GitBin -C $Repo add -A 2>&1 | Out-Null
$msg    = '[auto] 自动存档 ' + (Get-Date -Format 'yyyy-MM-dd HH:mm')
$commit = & $GitBin -C $Repo commit -q -m $msg 2>&1
$code   = $LASTEXITCODE
if ($code -ne 0) { Write-Log ('提交失败 exit=' + $code + ' :: ' + ($commit -join ' ')); exit 1 }

$hash = (& $GitBin -C $Repo rev-parse --short HEAD 2>&1 | Select-Object -First 1)
$n    = ($status | Measure-Object).Count
Write-Log ('已提交 ' + $hash + '（' + $n + ' 项改动）')

# ---- 逐个远端推送；任何一个失败都不影响本地提交 ----
$remotes = & $GitBin -C $Repo remote 2>&1
$failed  = @()
$okCount = 0
foreach ($r in $remotes) {
    $name = "$r".Trim()
    if (-not $name) { continue }
    $push = & $GitBin -C $Repo push -q $name main 2>&1
    $code = $LASTEXITCODE
    if ($code -eq 0) {
        $okCount++
        Write-Log ('已推送到 ' + $name)
    } else {
        $last = (($push | Select-Object -Last 1) -join ' ').Trim()
        $failed += ($name + '（' + $last + '）')
        Write-Log ('推送到 ' + $name + ' 失败 exit=' + $code + ' :: ' + $last)
    }
}

# ---- 结果：失败要吵，恢复也要说一声 ----
if ($failed.Count -gt 0) {
    $failCount = (Get-FailCount) + 1
    Set-FailCount $failCount
    $detail = ($failed -join '；')
    Set-Status ('失败（连续第 ' + $failCount + ' 次）：' + $detail)
    if (($failCount -eq 1) -or (($failCount % $AlertEvery) -eq 0)) {
        $body = '连续失败 ' + $failCount + ' 次：' + $detail + [Environment]::NewLine + '日志：' + $Log
        Show-Balloon '备份推送失败' $body 'warn'
    }
} else {
    $prev = Get-FailCount
    Set-FailCount 0
    Set-Status ('OK：' + $okCount + ' 个远端已推送')
    if ($prev -gt 0) {
        Write-Log ('推送已恢复（此前连续失败 ' + $prev + ' 次）')
        Show-Balloon '备份推送已恢复' ('全部 ' + $okCount + ' 个远端可推送') 'info'
    }
}
