param(
    [ValidateSet("init", "status", "run", "run-loop", "health", "stop", "help")]
    [string]$Mode = "init",
    [string]$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [string]$TaskName = "CodexMaintenanceUploader",
    [int]$TaskIntervalMinutes = 1,
    [int]$SmallIntervalMinutes = 25,
    [int]$MajorIntervalMinutes = 120,
    [int]$MaxRound = 100,
    [int]$MaxBackups = 10,
    [int]$VersionStep = 2,
    [int]$TailLines = 200,
    [int]$AlertNoUploadWindow = 5,
    [string]$LogPath = ".\\.maintenance\\logs\\maintenance_uploader.log",
    [string]$AuditPath = ".\\.maintenance\\logs\\maintenance_uploader_audit.csv",
    [string]$AuditCsv = ".\\.maintenance\\logs\\maintenance_uploader_audit.csv",
    [string]$PythonCmd = "python",
    [switch]$AutoCommit,
    [switch]$AllowSensitive,
    [switch]$TagOnUpload,
    [string]$TagPrefix = "v",
    [switch]$AdaptiveLoop,
    [switch]$ReplaceIfExists
)

$ErrorActionPreference = "Stop"
$script:CadenceExitCode = 0

function Set-ChildExitCode {
    if ($LASTEXITCODE -ne $null -and $LASTEXITCODE -ne 0) {
        $script:CadenceExitCode = [Math]::Max([int]$script:CadenceExitCode, [int]$LASTEXITCODE)
    }
}

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = ".\\.maintenance\\logs\\maintenance_uploader.log"
}
if ([string]::IsNullOrWhiteSpace($AuditPath)) {
    $AuditPath = ".\\.maintenance\\logs\\maintenance_uploader_audit.csv"
}
if ([string]::IsNullOrWhiteSpace($AuditCsv)) {
    $AuditCsv = ".\\.maintenance\\logs\\maintenance_uploader_audit.csv"
}
if (-not [System.IO.Path]::IsPathRooted($LogPath)) {
    $LogPath = Join-Path $Repo $LogPath
}
if (-not [System.IO.Path]::IsPathRooted($AuditPath)) {
    $AuditPath = Join-Path $Repo $AuditPath
}
if (-not [System.IO.Path]::IsPathRooted($AuditCsv)) {
    $AuditCsv = Join-Path $Repo $AuditCsv
}

$OpsScript = Join-Path $PSScriptRoot "maintenance_uploader_ops.ps1"
if (-not (Test-Path $OpsScript)) {
    throw "Ops script not found: $OpsScript"
}

function Invoke-Init {
    $modeArgs = @(
        "-Mode", "start",
        "-TaskName", $TaskName,
        "-Repo", $Repo,
        "-TaskIntervalMinutes", $TaskIntervalMinutes.ToString(),
        "-IntervalSeconds", "60",
        "-SmallIntervalSeconds", ($SmallIntervalMinutes * 60).ToString(),
        "-MajorIntervalSeconds", ($MajorIntervalMinutes * 60).ToString(),
        "-AutoRound",
        "-VersionStep", $VersionStep.ToString(),
        "-MaxRound", $MaxRound.ToString(),
        "-MaxBackups", $MaxBackups.ToString(),
        "-PythonCmd", $PythonCmd,
        "-LogPath", $LogPath,
        "-AuditCsv", $AuditCsv,
        "-TagPrefix", $TagPrefix
    )
    if ($AutoCommit) {
        $modeArgs += "-AutoExecute"
        $modeArgs += "-Execute"
    }
    if ($AllowSensitive) {
        $modeArgs += "-AllowSensitive"
    }
    if ($AdaptiveLoop) {
        $modeArgs += "-AdaptiveLoop"
    }
    if ($ReplaceIfExists) {
        $modeArgs += "-ReplaceIfExists"
    }
    if ($TagOnUpload) {
        $modeArgs += "-TagOnUpload"
    }

    & $OpsScript @modeArgs
    Set-ChildExitCode

    if ($AutoCommit) {
        Write-Host "Init done: auto-upload enabled."
    }
    else {
        Write-Host "Init done: dry-run mode. Use -AutoCommit to enable auto upload."
    }
    Write-Host "Health log: $LogPath"
    Write-Host "Health summary: $AuditPath"
}

function Invoke-Run {
    $runArgs = @(
        "-Mode", "run",
        "-Repo", $Repo,
        "-TaskName", $TaskName,
        "-SmallIntervalSeconds", ($SmallIntervalMinutes * 60).ToString(),
        "-MajorIntervalSeconds", ($MajorIntervalMinutes * 60).ToString(),
        "-VersionStep", $VersionStep.ToString(),
        "-MaxRound", $MaxRound.ToString(),
        "-MaxBackups", $MaxBackups.ToString(),
        "-AutoRound",
        "-LogPath", $LogPath,
        "-AuditCsv", $AuditCsv,
        "-PythonCmd", $PythonCmd,
        "-TagPrefix", $TagPrefix
    )
    if ($AutoCommit) {
        $runArgs += "-AutoExecute"
        $runArgs += "-Execute"
    }
    if ($AllowSensitive) {
        $runArgs += "-AllowSensitive"
    }
    if ($AdaptiveLoop) {
        $runArgs += "-AdaptiveLoop"
    }
    if ($TagOnUpload) {
        $runArgs += "-TagOnUpload"
    }

    & $OpsScript @runArgs
    Set-ChildExitCode

    if ($AutoCommit) {
        Write-Host "Tip: pair init -AutoCommit with scheduler for steady long-run." 
    }
}

function Invoke-RunLoop {
    $loopArgs = @(
        "-Mode", "run-loop",
        "-Repo", $Repo,
        "-TaskName", $TaskName,
        "-SmallIntervalSeconds", ($SmallIntervalMinutes * 60).ToString(),
        "-MajorIntervalSeconds", ($MajorIntervalMinutes * 60).ToString(),
        "-VersionStep", $VersionStep.ToString(),
        "-MaxRound", $MaxRound.ToString(),
        "-MaxBackups", $MaxBackups.ToString(),
        "-AutoRound",
        "-LogPath", $LogPath,
        "-AuditCsv", $AuditCsv,
        "-PythonCmd", $PythonCmd,
        "-TagPrefix", $TagPrefix
    )
    if ($AdaptiveLoop) {
        $loopArgs += "-AdaptiveLoop"
    }
    if ($TagOnUpload) {
        $loopArgs += "-TagOnUpload"
    }
    if ($AutoCommit) {
        $loopArgs += "-AutoExecute"
        $loopArgs += "-Execute"
    }
    if ($AllowSensitive) {
        $loopArgs += "-AllowSensitive"
    }

    & $OpsScript @loopArgs
    Set-ChildExitCode
}

function Invoke-Status {
    & $OpsScript -Mode status -Repo $Repo -TaskName $TaskName -TailLines $TailLines
    Set-ChildExitCode
}

function Invoke-Health {
    & $OpsScript `
        -Mode health `
        -Repo $Repo `
        -TaskName $TaskName `
        -AuditPath $AuditPath `
        -TailLines $TailLines `
        -AlertNoUploadWindow $AlertNoUploadWindow
    Set-ChildExitCode
}

function Invoke-Stop {
    & $OpsScript -Mode stop -TaskName $TaskName
    Set-ChildExitCode
}

function Write-Help {
    Write-Host "Usage: .\scripts\maintenance_uploader_cadence.ps1 -Mode <init|status|run|run-loop|health|stop|help>"
    Write-Host "  init      : create/update task (minute trigger; cadence handles 25/120 min upload windows)"
    Write-Host "  status    : show running state and latest health tail"
    Write-Host "  run       : manual single execution for local check"
    Write-Host "  run-loop  : run local daemon loop, trigger every $TaskIntervalMinutes minute(s)"
    Write-Host "  health    : write/update audit CSV at $AuditPath"
    Write-Host "  stop      : remove scheduled task"
    Write-Host "  help      : show this usage"
    Write-Host "Suggested: -AutoCommit -SmallIntervalMinutes 25 -MajorIntervalMinutes 120 -VersionStep 2 -MaxRound 100 -MaxBackups 10"
}

try {
    switch ($Mode) {
        "init" { Invoke-Init }
        "status" { Invoke-Status }
        "run" { Invoke-Run }
        "run-loop" { Invoke-RunLoop }
        "health" { Invoke-Health }
        "stop" { Invoke-Stop }
        "help" { Write-Help }
        default {
            Write-Host ("Unknown mode: " + $Mode)
            Write-Help
            throw "Unknown mode"
        }
    }
}
catch {
    Write-Host $_.Exception.Message
    $script:CadenceExitCode = 2
}

if ($script:CadenceExitCode -ne 0) {
    exit $script:CadenceExitCode
}
exit 0
