# ============================================================
# 自动存档（autocommit）—— 由 Windows 计划任务「wuxia-autocommit」定时调用
# 默认每 30 分钟跑一次：有改动就提交并推送到 E: 盘裸仓库备份；没改动就静默退出。
# 手动跑一次：powershell -NoProfile -ExecutionPolicy Bypass -File D:\1\wuxia-demo\tools\autocommit.ps1
# 日志：D:\1\wuxia-demo\.git\autocommit.log（放在 .git 里，不会弄脏工作区）
# ============================================================

$ErrorActionPreference = 'Stop'
$Repo = 'D:\1\wuxia-demo'
$Git  = 'C:\Program Files\Git\cmd\git.exe'
$Log  = Join-Path $Repo '.git\autocommit.log'

function Write-Log([string]$m) {
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
    Add-Content -LiteralPath $Log -Value $line -Encoding UTF8
}

if (-not (Test-Path -LiteralPath $Git)) { exit 1 }
Set-Location -LiteralPath $Repo

# 没改动就别打扰
$status = & $Git status --porcelain
if (-not $status) { exit 0 }

try {
    & $Git add -A 2>&1 | Out-Null
    $msg = '[auto] 自动存档 ' + (Get-Date -Format 'yyyy-MM-dd HH:mm')
    & $Git commit -q -m $msg 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) { Write-Log ('提交失败 exit=' + $LASTEXITCODE); exit 1 }

    $hash = (& $Git rev-parse --short HEAD).Trim()
    $n    = ($status | Measure-Object).Count
    Write-Log ('已提交 ' + $hash + '（' + $n + ' 项改动）')

    # 推送到异地裸仓库备份；推送失败不影响本地提交
    & $Git push -q backup main 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Log '已推送到 backup' }
    else { Write-Log ('推送失败 exit=' + $LASTEXITCODE + '（本地提交已保留）') }
} catch {
    Write-Log ('异常：' + $_.Exception.Message)
    exit 1
}
