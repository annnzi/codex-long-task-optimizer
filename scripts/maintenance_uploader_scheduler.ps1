param(
    [string]$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [int]$IntervalSeconds = 60,
    [switch]$Execute,
    [switch]$AutoRound,
    [switch]$AutoExecute,
    [switch]$AllowSensitive,
    [switch]$TagOnUpload,
    [string]$TagPrefix = "v",
    [string]$PythonCmd = "python",
    [int]$VersionStep = 2,
    [int]$SmallIntervalSeconds = 25 * 60,
    [int]$MajorIntervalSeconds = 120 * 60,
    [switch]$AdaptiveLoop,
    [string]$AuditCsv = "",
    [string]$LogPath,
    [switch]$Loop,
    [int]$MaxRound = 100,
    [int]$MaxBackups = 10,
    [long]$MaxLogBytes = 5242880,
    [string]$LockPath,
    [int]$MaxLockAgeSeconds = 20 * 60
)

$ErrorActionPreference = "Stop"

$RepoPath = (Resolve-Path $Repo).Path
$Uploader = Join-Path $PSScriptRoot "maintenance_uploader.py"
if (-not (Test-Path $Uploader)) {
    throw "未找到脚本: $Uploader"
}

function Resolve-PythonCommand {
    param([string]$Preferred)

    $localCandidates = @(
        (Join-Path $RepoPath ".venv\Scripts\python.exe"),
        (Join-Path $RepoPath "venv\Scripts\python.exe")
    )
    foreach ($localCandidate in $localCandidates) {
        if (Test-Path -LiteralPath $localCandidate -PathType Leaf) {
            return (Resolve-Path -LiteralPath $localCandidate).Path
        }
    }

    $candidates = New-Object System.Collections.Generic.List[string]
    if (-not [string]::IsNullOrWhiteSpace($Preferred)) {
        $candidates.Add($Preferred.Trim())
    }
    $candidates.AddRange(@("python", "python3", "py"))

    foreach ($candidate in $candidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }
        if (Get-Command $candidate -ErrorAction SilentlyContinue) {
            return $candidate
        }
    }

    throw "未找到可执行 Python：已检查仓库 .venv/venv 与系统 python / python3 / py"
}

$PythonCmd = Resolve-PythonCommand -Preferred $PythonCmd

$ScriptTranscribing = $false
$RunId = [System.Guid]::NewGuid().ToString("N")

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Join-Path $RepoPath ".maintenance\\logs\\maintenance_uploader.log"
}
if (-not [System.IO.Path]::IsPathRooted($LogPath)) {
    $LogPath = Join-Path $RepoPath $LogPath
}
if (-not [string]::IsNullOrWhiteSpace($AuditCsv) -and -not [System.IO.Path]::IsPathRooted($AuditCsv)) {
    $AuditCsv = Join-Path $RepoPath $AuditCsv
}
$LogDir = Split-Path $LogPath
if (-not (Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir | Out-Null
}

if ($MaxLogBytes -le 1024) {
    $MaxLogBytes = 1024
}
if ($VersionStep -lt 1) {
    throw "VersionStep 必须 >= 1"
}
if ($SmallIntervalSeconds -lt 60) {
    throw "SmallIntervalSeconds 必须 >= 60"
}
if ($MajorIntervalSeconds -lt 60) {
    throw "MajorIntervalSeconds 必须 >= 60"
}
if ($MaxRound -lt 1) {
    throw "MaxRound 必须 >= 1"
}
if ($MaxBackups -lt 1) {
    throw "MaxBackups 必须 >= 1"
}
if ($MaxLockAgeSeconds -lt 1) {
    throw "MaxLockAgeSeconds 必须 >= 1"
}

if ([string]::IsNullOrWhiteSpace($LockPath)) {
    $LockPath = Join-Path $RepoPath ".maintenance\\maintenance_uploader.lock"
}
$LockDir = Split-Path $LockPath
if (-not (Test-Path $LockDir)) {
    New-Item -ItemType Directory -Path $LockDir | Out-Null
}

$maintenanceDir = Join-Path $RepoPath ".maintenance"
if (-not (Test-Path $maintenanceDir)) {
    New-Item -ItemType Directory -Path $maintenanceDir | Out-Null
}

function Rotate-TranscriptLog {
    if (-not (Test-Path $LogPath)) {
        return
    }
    $logInfo = Get-Item $LogPath
    if ($logInfo.Length -le $MaxLogBytes) {
        return
    }
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $rolledPath = "$LogPath.$timestamp"
    Move-Item -Path $LogPath -Destination $rolledPath
}

function Get-LockFileInfo {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        return $null
    }

    try {
        $raw = Get-Content -Path $Path -ErrorAction SilentlyContinue
    }
    catch {
        return $null
    }

    if ($raw.Count -lt 1) {
        return $null
    }

    $pid = 0
    [void][int]::TryParse($raw[0], [ref]$pid)

    $createdAt = $null
    if ($raw.Count -ge 2) {
        $parsed = $null
        if ([datetime]::TryParse($raw[1], [ref]$parsed)) {
            $createdAt = $parsed
        }
    }

    if ($null -eq $createdAt) {
        $createdAt = (Get-Item $Path).LastWriteTime
    }

    $ageSeconds = [math]::Max(0, [int]((Get-Date) - $createdAt).TotalSeconds)

    return [PSCustomObject]@{
        Pid = $pid
        CreatedAt = $createdAt
        AgeSeconds = $ageSeconds
        Raw = $raw
    }
}

function Test-LockOwnerAlive {
    param([psobject]$LockInfo)

    if ($null -eq $LockInfo -or $LockInfo.Pid -le 0) {
        return $false
    }

    try {
        $proc = Get-Process -Id $LockInfo.Pid -ErrorAction SilentlyContinue
    }
    catch {
        return $false
    }
    if ($null -eq $proc) {
        return $false
    }

    try {
        $cmd = (Get-CimInstance Win32_Process -Filter ("ProcessId = {0}" -f $LockInfo.Pid) -ErrorAction SilentlyContinue).CommandLine
        if (-not [string]::IsNullOrWhiteSpace($cmd) -and $cmd -match 'maintenance_uploader(_scheduler)?\.ps1') {
            return $true
        }
    }
    catch {
        # 无法读取命令行时：保守处理为“仍在运行”。
        return $true
    }

    return $false
}

function Get-RunLock {
    param([string]$Path)

    $lockInfo = Get-LockFileInfo -Path $Path
    if ($null -ne $lockInfo -and $lockInfo.AgeSeconds -gt $MaxLockAgeSeconds) {
        if (Test-LockOwnerAlive -LockInfo $lockInfo) {
            Write-Host "检测到锁文件存在且对应进程仍被认定为活跃：pid=$($lockInfo.Pid)，年龄=$($lockInfo.AgeSeconds)s，本次执行跳过。"
        }
        else {
            Write-Host "检测到过期锁文件，执行清理：$Path，年龄=$($lockInfo.AgeSeconds)s。"
            Remove-Item -Path $Path -Force -ErrorAction SilentlyContinue
            $lockInfo = $null
        }
    }

    try {
        $fileStream = [System.IO.File]::Open(
            $Path,
            [System.IO.FileMode]::CreateNew,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )
        $writer = New-Object System.IO.StreamWriter($fileStream)
        $writer.WriteLine([System.Diagnostics.Process]::GetCurrentProcess().Id)
        $writer.WriteLine((Get-Date).ToUniversalTime().ToString("o"))
        $writer.WriteLine($RunId)
        $writer.Flush()
        $fileStream.Flush($true)
        return @($fileStream, $writer)
    }
    catch {
        return $null
    }
}

function Release-RunLock {
    param(
        [array]$LockHandle,
        [string]$Path
    )

    if ($null -eq $LockHandle) {
        return
    }
    if ($LockHandle.Count -ge 2) {
        if ($LockHandle[1]) {
            $LockHandle[1].Dispose()
        }
        if ($LockHandle[0]) {
            $LockHandle[0].Dispose()
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        Remove-Item -Path $Path -Force -ErrorAction SilentlyContinue
    }
}

Push-Location $RepoPath
$runLock = Get-RunLock -Path $LockPath
if ($null -eq $runLock) {
    Write-Host "检测到维护任务已在运行，已跳过本次调度。"
    Pop-Location
    exit 0
}

try {
    Rotate-TranscriptLog
    Start-Transcript -Path $LogPath -Append
    $ScriptTranscribing = $true
    Write-Host ("maintenance_uploader scheduler runId={0} repo={1} interval={2}s execute={3} autoRound={4} autoExecute={5} versionStep={6}" -f $RunId, $RepoPath, $IntervalSeconds, [bool]$Execute, [bool]$AutoRound, [bool]$AutoExecute, $VersionStep)

    $args = @(
        $Uploader,
        "--repo", $RepoPath,
        "--interval-seconds", $IntervalSeconds.ToString()
    )
    $args += "--small-interval-seconds"
    $args += $SmallIntervalSeconds.ToString()
    $args += "--major-interval-seconds"
    $args += $MajorIntervalSeconds.ToString()
    if ($Loop) {
        $args += "--loop"
    }

    if ($AutoRound.IsPresent) {
        $args += "--auto-round"
    }
    if ($VersionStep -ne 2) {
        $args += "--version-step"
        $args += $VersionStep.ToString()
    }

    if ($Execute) {
        $args += "--execute"
    }
    if ($AutoExecute) {
        $args += "--auto-execute"
    }
    if ($AllowSensitive) {
        $args += "--allow-sensitive"
    }
    if ($AdaptiveLoop) {
        $args += "--adaptive-loop"
    }
    $args += "--max-round"
    $args += $MaxRound.ToString()
    $args += "--max-backups"
    $args += $MaxBackups.ToString()
    if (-not [string]::IsNullOrWhiteSpace($AuditCsv)) {
        $args += "--audit-csv"
        $args += $AuditCsv
    }
    if ($TagOnUpload) {
        $args += "--tag-on-upload"
    }
    if (-not [string]::IsNullOrWhiteSpace($TagPrefix)) {
        $args += "--tag-prefix"
        $args += $TagPrefix
    }

    & $PythonCmd @args
    $childExitCode = $LASTEXITCODE
    if ($null -ne $childExitCode -and $childExitCode -ne 0) {
        throw "maintenance_uploader.py 退出码：$childExitCode"
    }
}
catch {
    Write-Error $_
    throw
}
finally {
    Release-RunLock -LockHandle $runLock -Path $LockPath
    if ($ScriptTranscribing) {
        Stop-Transcript | Out-Null
        $ScriptTranscribing = $false
    }
    Pop-Location
}
