param(
    [ValidateSet("bootstrap", "status", "run", "health", "stop", "help")]
    [string]$Mode = "bootstrap",
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
    [string]$PythonCmd = "python",
    [string]$LogPath = ".\.maintenance\\logs\\maintenance_uploader.log",
    [string]$AuditPath = ".\.maintenance\\logs\\maintenance_uploader_audit.csv",
    [string]$AuditCsv = ".\.maintenance\\logs\\maintenance_uploader_audit.csv",
    [switch]$AutoCommit,
    [switch]$AllowSensitive,
    [switch]$AdaptiveLoop,
    [switch]$ReplaceIfExists,
    [switch]$TagOnUpload,
    [string]$TagPrefix = "v"
)

$ErrorActionPreference = "Stop"
$script:TimerExitCode = 0

$CadenceScript = Join-Path $PSScriptRoot "maintenance_uploader_cadence.ps1"
if (-not (Test-Path $CadenceScript)) {
    throw "Cadence entry missing: $CadenceScript"
}

function Invoke-Bootstrap {
    $bootstrapArgs = @(
        "-Mode", "init",
        "-Repo", $Repo,
        "-TaskName", $TaskName,
        "-TaskIntervalMinutes", $TaskIntervalMinutes.ToString(),
        "-SmallIntervalMinutes", $SmallIntervalMinutes.ToString(),
        "-MajorIntervalMinutes", $MajorIntervalMinutes.ToString(),
        "-MaxRound", $MaxRound.ToString(),
        "-MaxBackups", $MaxBackups.ToString(),
        "-VersionStep", $VersionStep.ToString(),
        "-TailLines", $TailLines.ToString(),
        "-AlertNoUploadWindow", $AlertNoUploadWindow.ToString(),
        "-PythonCmd", $PythonCmd,
        "-LogPath", $LogPath,
        "-AuditPath", $AuditPath,
        "-AuditCsv", $AuditCsv,
        "-TagPrefix", $TagPrefix
    )

    if ($AdaptiveLoop) {
        $bootstrapArgs += "-AdaptiveLoop"
    }
    # Bootstrap 入口默认幂等：重复执行时直接更新任务配置。
    $bootstrapArgs += "-ReplaceIfExists"
    if ($TagOnUpload) {
        $bootstrapArgs += "-TagOnUpload"
    }
    if ($AutoCommit) {
        $bootstrapArgs += "-AutoCommit"
    }
    if ($AllowSensitive) {
        $bootstrapArgs += "-AllowSensitive"
    }

    & $CadenceScript @bootstrapArgs
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
        throw "Cadence bootstrap failed with exit code=$LASTEXITCODE"
    }

    & $CadenceScript -Mode status -Repo $Repo -TaskName $TaskName -TailLines $TailLines
}

function Invoke-Status {
    & $CadenceScript -Mode status -Repo $Repo -TaskName $TaskName -TailLines $TailLines
}

function Invoke-Run {
    & $CadenceScript -Mode run -Repo $Repo -TaskName $TaskName -TailLines $TailLines -SmallIntervalMinutes $SmallIntervalMinutes -MajorIntervalMinutes $MajorIntervalMinutes -MaxRound $MaxRound -MaxBackups $MaxBackups -VersionStep $VersionStep -AllowSensitive:$AllowSensitive -AdaptiveLoop:$AdaptiveLoop
}

function Invoke-Health {
    & $CadenceScript -Mode health -Repo $Repo -TaskName $TaskName -TailLines $TailLines -AlertNoUploadWindow $AlertNoUploadWindow -AuditPath $AuditPath
}

function Invoke-Stop {
    & $CadenceScript -Mode stop -Repo $Repo -TaskName $TaskName
}

function Write-Help {
    Write-Host "Usage: .\scripts\maintenance_uploader_timer.ps1 -Mode <bootstrap|status|run|health|stop>"
    Write-Host "  bootstrap : install/update scheduled task with 1-min trigger + 25/120 upload windows (idempotent)"
    Write-Host "  status    : show task and latest health summary"
    Write-Host "  run       : run one maintenance cycle"
    Write-Host "  health    : export one health report sample"
    Write-Host "  stop      : remove scheduled task"
    Write-Host "Params: -AutoCommit, -AllowSensitive, -AdaptiveLoop, -ReplaceIfExists, -VersionStep, -MaxBackups, -TagOnUpload"
}

try {
    switch ($Mode) {
        "help" { Write-Help }
        "bootstrap" { Invoke-Bootstrap }
        "status" { Invoke-Status }
        "run" { Invoke-Run }
        "health" { Invoke-Health }
        "stop" { Invoke-Stop }
        default {
            Write-Help
            throw "Unknown mode: $Mode"
        }
    }
}
catch {
    Write-Host $_.Exception.Message
    $script:TimerExitCode = 2
}

if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne $null) {
    $script:TimerExitCode = [Math]::Max([int]$script:TimerExitCode, [int]$LASTEXITCODE)
}

if ($script:TimerExitCode -ne 0) {
    exit $script:TimerExitCode
}
exit 0
