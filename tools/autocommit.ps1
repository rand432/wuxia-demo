# ============================================================
# 自动存档（autocommit）—— 由 Windows 计划任务「wuxia-autocommit」每 30 分钟调用
# 有改动就提交，然后推送到【所有】远端（backup=E: 裸仓库，origin=Gitee/GitHub）；
# 没改动就静默退出（不产生空提交）。
# 手动跑一次：
#   powershell -NoProfile -ExecutionPolicy Bypass -File D:\1\wuxia-demo\tools\autocommit.ps1
# 日志：D:\1\wuxia-demo\.git\autocommit.log（放在 .git 里，不会弄脏工作区）
# 注：故意用 ErrorActionPreference=Continue + 逐个查 $LASTEXITCODE——
#     PS 5.1 里原生 exe 的 stderr 在 Stop 模式下会被当成终止错误。
# ============================================================

$ErrorActionPreference = 'Continue'
$Repo = 'D:\1\wuxia-demo'
$Git  = 'C:\Program Files\Git\cmd\git.exe'
$Log  = Join-Path $Repo '.git\autocommit.log'

# 远端不可达时别卡住计划任务：10 秒连接超时 + 禁止任何交互式提问
$env:GIT_SSH_COMMAND = 'ssh -o ConnectTimeout=10 -o BatchMode=yes -o StrictHostKeyChecking=accept-new'
$env:GIT_TERMINAL_PROMPT = '0'

function Write-Log([string]$m) {
    $line = '[{0}] {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $m
    Add-Content -LiteralPath $Log -Value $line -Encoding UTF8
}
function Git([string[]]$a) { & $Git -C $Repo @a 2>&1 }

if (-not (Test-Path -LiteralPath $Git)) { exit 1 }

# 没改动就别打扰
$status = Git @('status', '--porcelain')
if ($LASTEXITCODE -ne 0) { Write-Log ('git status 失败 exit=' + $LASTEXITCODE); exit 1 }
if (-not $status) { exit 0 }

Git @('add', '-A') | Out-Null
$msg = '[auto] 自动存档 ' + (Get-Date -Format 'yyyy-MM-dd HH:mm')
$commit = Git @('commit', '-q', '-m', $msg)
if ($LASTEXITCODE -ne 0) { Write-Log ('提交失败 exit=' + $LASTEXITCODE + ' :: ' + ($commit -join ' ')); exit 1 }

$hash = (Git @('rev-parse', '--short', 'HEAD') | Select-Object -First 1)
$n    = ($status | Measure-Object).Count
Write-Log ('已提交 ' + $hash + '（' + $n + ' 项改动）')

# 逐个远端推送；任何一个失败都不影响本地提交
$remotes = Git @('remote')
foreach ($r in $remotes) {
    $name = "$r".Trim()
    if (-not $name) { continue }
    $push = Git @('push', '-q', $name, 'main')
    if ($LASTEXITCODE -eq 0) { Write-Log ('已推送到 ' + $name) }
    else { Write-Log ('推送到 ' + $name + ' 失败 exit=' + $LASTEXITCODE + ' :: ' + (($push | Select-Object -Last 1) -join ' ')) }
}
