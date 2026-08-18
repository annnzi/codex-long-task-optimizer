param(
    [string]$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [int]$IntervalSeconds = 60,
    [switch]$Execute,
    [switch]$AutoRound,
    [switch]$AutoExecute,
    [switch]$TagOnUpload,
    [string]$TagPrefix = "v",
    [string]$PythonCmd = "python",
    [int]$VersionStep = 2,
    [string]$LogPath,
    [switch]$Loop,
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
$ScriptTranscribing = $false
$RunId = [System.Guid]::NewGuid().ToString("N")

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Join-Path $RepoPath ".maintenance\\logs\\maintenance_uploader.log"
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

function Get-RunLock {
    param([string]$Path)

    $lockInfo = Get-LockFileInfo -Path $Path
    if ($null -ne $lockInfo -and $lockInfo.AgeSeconds -gt $MaxLockAgeSeconds) {
        $stale = $true
        if ($lockInfo.Pid -gt 0) {
            $proc = Get-Process -Id $lockInfo.Pid -ErrorAction SilentlyContinue
            if ($null -ne $proc) {
                $stale = $false
                Write-Host "检测到锁文件存在且对应进程仍在运行：pid=$($lockInfo.Pid)，年龄=$($lockInfo.AgeSeconds)s，本次执行跳过。"
            }
        }
        if ($stale) {
            Write-Host "检测到过期锁文件，执行清理：$Path，年龄=$($lockInfo.AgeSeconds)s。"
            Remove-Item -Path $Path -Force -ErrorAction SilentlyContinue
            $lockInfo = $null
        }
    }

    try {
        $fileStream = [System.IO.File]::Open(
            $Path,
            [System.IO.FileMode]::OpenOrCreate,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )
        $writer = New-Object System.IO.StreamWriter($fileStream)
        $writer.WriteLine([System.Diagnostics.Process]::GetCurrentProcess().Id)
        $writer.WriteLine((Get-Date).ToUniversalTime().ToString("o"))
        $writer.WriteLine($RunId)
        $writer.Flush()
        return @($fileStream, $writer)
    }
    catch {
        return $null
    }
}

function Release-RunLock {
    param([array]$LockHandle)

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
    if ($TagOnUpload) {
        $args += "--tag-on-upload"
    }
    if (-not [string]::IsNullOrWhiteSpace($TagPrefix)) {
        $args += "--tag-prefix"
        $args += $TagPrefix
    }

    & $PythonCmd @args
}
catch {
    Write-Error $_
    throw
}
finally {
    Release-RunLock -LockHandle $runLock
    if ($ScriptTranscribing) {
        Stop-Transcript | Out-Null
        $ScriptTranscribing = $false
    }
    Pop-Location
}
