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
    [string]$LockPath
)

$ErrorActionPreference = "Stop"

$RepoPath = (Resolve-Path $Repo).Path
$Uploader = Join-Path $PSScriptRoot "maintenance_uploader.py"
if (-not (Test-Path $Uploader)) {
    throw "未找到脚本: $Uploader"
}
$ScriptTranscribing = $false

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

function Get-RunLock {
    param([string]$Path)

    try {
        $fileStream = [System.IO.File]::Open(
            $Path,
            [System.IO.FileMode]::OpenOrCreate,
            [System.IO.FileAccess]::ReadWrite,
            [System.IO.FileShare]::None
        )
        $writer = New-Object System.IO.StreamWriter($fileStream)
        $writer.WriteLine([System.Diagnostics.Process]::GetCurrentProcess().Id)
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
