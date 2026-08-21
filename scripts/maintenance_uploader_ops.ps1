param(
    [ValidateSet("status", "start", "stop", "run", "run-loop", "health", "help")]
    [string]$Mode = "status",
    [string]$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [int]$TaskIntervalMinutes = 1,
    [int]$IntervalSeconds = 60,
    [string]$TaskName = "CodexMaintenanceUploader",
    [string]$LogPath = ".maintenance\\logs\\maintenance_uploader.log",
    [switch]$Execute,
    [switch]$AutoRound,
    [switch]$AutoExecute,
    [switch]$AllowSensitive,
    [switch]$TagOnUpload,
    [string]$TagPrefix = "v",
    [int]$VersionStep = 2,
    [int]$SmallIntervalSeconds = 25 * 60,
    [int]$MajorIntervalSeconds = 120 * 60,
    [int]$MaxLockAgeSeconds = 20 * 60,
    [int]$TailLines = 200,
    [int]$AlertNoUploadWindow = 5,
    [string]$AuditPath = '.\\.maintenance\\logs\\maintenance_uploader_audit.csv',
    [switch]$AdaptiveLoop,
    [string]$AuditCsv = '.\\.maintenance\\logs\\maintenance_uploader_audit.csv',
    [string]$PythonCmd = "python",
    [int]$MaxRound = 100,
    [int]$MaxBackups = 10,
    [switch]$ReplaceIfExists
)

$ErrorActionPreference = "Stop"
$script:OpsExitCode = 0

$RepoPath = (Resolve-Path $Repo).Path
$OpsScript = $PSScriptRoot
$SchedulerScript = Join-Path $OpsScript "maintenance_uploader_scheduler.ps1"
$ScheduleTaskScript = Join-Path $OpsScript "maintenance_uploader_schedule_task.ps1"
$HealthScript = Join-Path $OpsScript "maintenance_uploader_health.ps1"
$UploaderScript = Join-Path $OpsScript "maintenance_uploader.py"

if (-not (Test-Path $UploaderScript)) {
    throw "Uploader script not found: $UploaderScript"
}
if (-not (Test-Path $SchedulerScript)) {
    throw "Scheduler script not found: $SchedulerScript"
}
if (-not (Test-Path $ScheduleTaskScript)) {
    throw "Task scheduler wrapper not found: $ScheduleTaskScript"
}
if (-not (Test-Path $HealthScript)) {
    throw "Health script not found: $HealthScript"
}

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = ".maintenance\\logs\\maintenance_uploader.log"
}
if (-not [System.IO.Path]::IsPathRooted($LogPath)) {
    $LogPath = Join-Path $RepoPath $LogPath
}
if (-not [string]::IsNullOrWhiteSpace($AuditPath)) {
    if (-not [System.IO.Path]::IsPathRooted($AuditPath)) {
        $AuditPath = Join-Path $RepoPath $AuditPath
    }
}
if (-not [string]::IsNullOrWhiteSpace($AuditCsv)) {
    if (-not [System.IO.Path]::IsPathRooted($AuditCsv)) {
        $AuditCsv = Join-Path $RepoPath $AuditCsv
    }
}

function Resolve-Interval {
    param([int]$Interval)
    if ($Interval -lt 1) {
        return 1
    }
    return $Interval
}

$TaskIntervalMinutes = Resolve-Interval -Interval $TaskIntervalMinutes
$IntervalSeconds = Resolve-Interval -Interval $IntervalSeconds
$SmallIntervalSeconds = Resolve-Interval -Interval $SmallIntervalSeconds
$MajorIntervalSeconds = Resolve-Interval -Interval $MajorIntervalSeconds
$MaxLockAgeSeconds = Resolve-Interval -Interval $MaxLockAgeSeconds

if ($TailLines -lt 10) {
    $TailLines = 10
}
if ($AlertNoUploadWindow -lt 1) {
    $AlertNoUploadWindow = 1
}

function Invoke-TaskInstall {
    & $ScheduleTaskScript `
        -Mode install `
        -IntervalSeconds $IntervalSeconds `
        -TaskIntervalMinutes $TaskIntervalMinutes `
        -TaskName $TaskName `
        -Repo $RepoPath `
        -PythonCmd $PythonCmd `
        -VersionStep $VersionStep `
        -SmallIntervalSeconds $SmallIntervalSeconds `
        -MajorIntervalSeconds $MajorIntervalSeconds `
        -MaxRound $MaxRound `
        -MaxBackups $MaxBackups `
        -MaxLockAgeSeconds $MaxLockAgeSeconds `
        -LogPath $LogPath `
        -AutoRound:$AutoRound `
        -AutoExecute:$AutoExecute `
        -AllowSensitive:$AllowSensitive `
        -AdaptiveLoop:$AdaptiveLoop `
        -AuditCsv $AuditCsv `
        -ReplaceIfExists:$ReplaceIfExists `
        -TagOnUpload:$TagOnUpload `
        -TagPrefix $TagPrefix
    $script:OpsExitCode = if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) { 0 } else { $LASTEXITCODE }
}

function Invoke-TaskStatus {
    & $ScheduleTaskScript `
        -Mode status `
        -TaskName $TaskName
    $script:OpsExitCode = if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) { 0 } else { $LASTEXITCODE }

    if (Test-Path $LogPath) {
        & $HealthScript -LogPath $LogPath -TailLines $TailLines -AlertNoUploadWindow $AlertNoUploadWindow
        if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
            $script:OpsExitCode = [Math]::Max([int]$script:OpsExitCode, [int]$LASTEXITCODE)
        }
    }
    else {
        Write-Host "No readable log file: $LogPath"
        $script:OpsExitCode = [Math]::Max([int]$script:OpsExitCode, 1)
    }
}

function Invoke-RunOnce {
    & $SchedulerScript `
        -Repo $RepoPath `
        -IntervalSeconds $IntervalSeconds `
        -PythonCmd $PythonCmd `
        -VersionStep $VersionStep `
        -SmallIntervalSeconds $SmallIntervalSeconds `
        -MajorIntervalSeconds $MajorIntervalSeconds `
        -MaxRound $MaxRound `
        -MaxBackups $MaxBackups `
        -MaxLockAgeSeconds $MaxLockAgeSeconds `
        -LogPath $LogPath `
        -Execute:$Execute `
        -AutoRound:$AutoRound `
        -AutoExecute:$AutoExecute `
        -AllowSensitive:$AllowSensitive `
        -AdaptiveLoop:$AdaptiveLoop `
        -AuditCsv $AuditCsv `
        -TagOnUpload:$TagOnUpload `
        -TagPrefix $TagPrefix
    $script:OpsExitCode = if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) { 0 } else { $LASTEXITCODE }
}

function Invoke-RunLoop {
    & $SchedulerScript `
        -Repo $RepoPath `
        -IntervalSeconds $IntervalSeconds `
        -PythonCmd $PythonCmd `
        -VersionStep $VersionStep `
        -SmallIntervalSeconds $SmallIntervalSeconds `
        -MajorIntervalSeconds $MajorIntervalSeconds `
        -MaxRound $MaxRound `
        -MaxBackups $MaxBackups `
        -MaxLockAgeSeconds $MaxLockAgeSeconds `
        -LogPath $LogPath `
        -Execute:$Execute `
        -AutoRound:$AutoRound `
        -AutoExecute:$AutoExecute `
        -AllowSensitive:$AllowSensitive `
        -AdaptiveLoop:$AdaptiveLoop `
        -AuditCsv $AuditCsv `
        -TagOnUpload:$TagOnUpload `
        -TagPrefix $TagPrefix `
        -Loop
    $script:OpsExitCode = if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) { 0 } else { $LASTEXITCODE }
}

function Invoke-Health {
    & $HealthScript -LogPath $LogPath -TailLines $TailLines -AlertNoUploadWindow $AlertNoUploadWindow -AuditPath $AuditPath -AsReport
    $script:OpsExitCode = if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) { 0 } else { $LASTEXITCODE }
}

function Write-Help {
    Write-Host "Usage: .\scripts\maintenance_uploader_ops.ps1 -Mode <status|start|stop|run|run-loop|health>"
    Write-Host "  status    : Show task state and health tail"
    Write-Host "  start     : Install task plan (minute trigger)"
    Write-Host "  stop      : Uninstall task plan"
    Write-Host "  run       : Execute once and generate logs"
    Write-Host "  run-loop  : Run scheduler in foreground"
    Write-Host ("  start replace mode: " + $ReplaceIfExists.IsPresent)
    Write-Host ("  maxRound: " + $MaxRound)
    Write-Host ("  adaptive loop: " + $AdaptiveLoop.IsPresent)
    Write-Host "  health    : Export health report (CSV)"
    Write-Host ("  audit csv: " + $AuditPath)
    Write-Host "  help      : Show this help"
}

try {
    switch ($Mode) {
        "status" { Invoke-TaskStatus }
        "start" { Invoke-TaskInstall }
        "stop" {
            & $ScheduleTaskScript -Mode uninstall -TaskName $TaskName
            $script:OpsExitCode = if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq $null) { 0 } else { $LASTEXITCODE }
        }
        "run" { Invoke-RunOnce }
        "run-loop" { Invoke-RunLoop }
        "health" { Invoke-Health }
        "help" { Write-Help; $script:OpsExitCode = 0 }
        default {
            Write-Host ("Unknown mode: {0}" -f $Mode)
            Write-Help
            $script:OpsExitCode = 2
        }
    }
}
catch {
    Write-Host $_.Exception.Message
    $script:OpsExitCode = 2
}

if ($script:OpsExitCode -ne 0) {
    exit $script:OpsExitCode
}
exit 0
