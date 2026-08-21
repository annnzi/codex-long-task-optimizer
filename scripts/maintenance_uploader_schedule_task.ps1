param(
    [string]$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [int]$IntervalSeconds = 60,
    [int]$TaskIntervalMinutes = 1,
    [string]$TaskName = "CodexMaintenanceUploader",
    [ValidateSet("install", "uninstall", "status")]
    [string]$Mode = "install",
    [switch]$Execute,
    [switch]$Loop,
    [switch]$AutoRound,
    [switch]$AutoExecute,
    [switch]$AllowSensitive,
    [switch]$TagOnUpload,
    [string]$TagPrefix = "v",
    [string]$PythonCmd = "python",
    [int]$VersionStep = 2,
    [int]$SmallIntervalSeconds = 25 * 60,
    [int]$MajorIntervalSeconds = 120 * 60,
    [int]$MaxRound = 100,
    [int]$MaxBackups = 10,
    [string]$LogPath = "",
    [switch]$AdaptiveLoop,
    [string]$AuditCsv = "",
    [int]$MaxLockAgeSeconds = 20 * 60,
    [switch]$ReplaceIfExists
)

$ErrorActionPreference = "Stop"

function Resolve-PythonCommand {
    param([string]$Preferred)

    $repoPath = (Resolve-Path -LiteralPath $Repo).Path
    $localCandidates = @(
        (Join-Path $repoPath ".venv\Scripts\python.exe"),
        (Join-Path $repoPath "venv\Scripts\python.exe")
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

    throw "Python executable not found: repository .venv/venv or python / python3 / py"
}

function Get-TaskCommand {
    param(
        [bool]$isExecute,
        [bool]$withLoop,
        [bool]$withAutoRound,
        [bool]$withAutoExecute,
        [bool]$withAllowSensitive,
        [bool]$withAdaptiveLoop,
        [bool]$withVersionStep,
        [int]$withSmallIntervalSeconds,
        [int]$withMajorIntervalSeconds,
        [int]$withMaxRound,
        [int]$withMaxBackups,
        [bool]$withTagOnUpload,
        [string]$withTagPrefix,
        [string]$withAuditCsv
    )

    $schedulerScript = Join-Path $PSScriptRoot "maintenance_uploader_scheduler.ps1"
    if (-not (Test-Path $schedulerScript)) {
        throw "scheduler script missing: $schedulerScript"
    }

    if (-not (Test-Path $Repo)) {
        throw "repo not found: $Repo"
    }

    $pythonCmdResolved = Resolve-PythonCommand -Preferred $PythonCmd

    $arguments = @(
        "-NoProfile",
        "-WindowStyle", "Hidden",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$schedulerScript`"",
        "-Repo", "`"$Repo`"",
        "-IntervalSeconds", $IntervalSeconds.ToString(),
        "-PythonCmd", "`"$pythonCmdResolved`""
    )

    if ($withLoop) { $arguments += "-Loop" }
    if ($withAutoRound) { $arguments += "-AutoRound" }
    if ($isExecute) { $arguments += "-Execute" }
    if ($withAutoExecute) { $arguments += "-AutoExecute" }
    if ($withAllowSensitive) { $arguments += "-AllowSensitive" }
    if ($withAdaptiveLoop) { $arguments += "-AdaptiveLoop" }
    if ($withTagOnUpload) { $arguments += "-TagOnUpload" }

    if (-not [string]::IsNullOrWhiteSpace($withAuditCsv)) {
        $arguments += "-AuditCsv"
        $arguments += "`"$withAuditCsv`""
    }
    if (-not [string]::IsNullOrWhiteSpace($withTagPrefix)) {
        $arguments += "-TagPrefix"
        $arguments += "`"$withTagPrefix`""
    }
    if ($withVersionStep) {
        $arguments += "-VersionStep"
        $arguments += "`"$VersionStep`""
    }
    if ($withSmallIntervalSeconds -ge 60) {
        $arguments += "-SmallIntervalSeconds"
        $arguments += "`"$withSmallIntervalSeconds`""
    }
    if ($withMajorIntervalSeconds -ge 60) {
        $arguments += "-MajorIntervalSeconds"
        $arguments += "`"$withMajorIntervalSeconds`""
    }
    if ($withMaxRound -ge 1) {
        $arguments += "-MaxRound"
        $arguments += "`"$withMaxRound`""
    }
    if ($withMaxBackups -ge 1) {
        $arguments += "-MaxBackups"
        $arguments += "`"$withMaxBackups`""
    }
    if ($MaxLockAgeSeconds -ge 60) {
        $arguments += "-MaxLockAgeSeconds"
        $arguments += "`"$MaxLockAgeSeconds`""
    }
    if (-not [string]::IsNullOrWhiteSpace($LogPath)) {
        $arguments += "-LogPath"
        $arguments += "`"$LogPath`""
    }

    return "powershell.exe " + ($arguments -join " ")
}

function Get-TaskExists {
    & cmd.exe /c "schtasks /Query /TN `"$TaskName`" >nul 2>nul"
    return ($LASTEXITCODE -eq 0)
}

function Ensure-Environment {
    if (-not (Get-Command schtasks -ErrorAction SilentlyContinue)) {
        throw "schtasks command not available."
    }
}

function Install-Task {
    if ($TaskIntervalMinutes -lt 1) {
        throw "TaskIntervalMinutes must be >= 1"
    }
    if ($VersionStep -lt 1) {
        throw "VersionStep must be >= 1"
    }
    if ($MaxBackups -lt 1) {
        throw "MaxBackups must be >= 1"
    }
    if ($Loop) {
        throw "For scheduled mode, do not pass -Loop. Use scheduler -Loop for foreground mode."
    }

    if (Get-TaskExists) {
        if ($ReplaceIfExists) {
            Write-Host "Task $TaskName already exists, replacing."
            & schtasks /Delete /TN "$TaskName" /F | Out-Null
        }
        else {
            throw "Task $TaskName already exists. Run -Mode uninstall or use a different task name."
        }
    }

    $taskCommand = Get-TaskCommand `
        -isExecute $Execute.IsPresent `
        -withLoop $Loop.IsPresent `
        -withAutoRound $AutoRound.IsPresent `
        -withAutoExecute $AutoExecute.IsPresent `
        -withAllowSensitive $AllowSensitive.IsPresent `
        -withAdaptiveLoop $AdaptiveLoop.IsPresent `
        -withVersionStep ($VersionStep -ne 2) `
        -withSmallIntervalSeconds $SmallIntervalSeconds `
        -withMajorIntervalSeconds $MajorIntervalSeconds `
        -withMaxRound $MaxRound `
        -withMaxBackups $MaxBackups `
        -withTagOnUpload $TagOnUpload.IsPresent `
        -withTagPrefix $TagPrefix `
        -withAuditCsv $AuditCsv

    $quotedTaskCommand = '"' + $taskCommand.Replace('"', '\"') + '"'

    Write-Host "Creating task: $TaskName"
    & schtasks /Create `
        /TN "$TaskName" `
        /SC MINUTE `
        /MO $TaskIntervalMinutes `
        /RU $env:USERNAME `
        /RL HIGHEST `
        /F `
        /TR $quotedTaskCommand
}

function Remove-Task {
    Write-Host "Removing task: $TaskName"
    if (-not (Get-TaskExists)) {
        throw "Task $TaskName does not exist."
    }
    & schtasks /Delete /TN "$TaskName" /F
}

function Show-Task {
    Write-Host "Task status: $TaskName"
    if (-not (Get-TaskExists)) {
        Write-Host "Task not found: $TaskName"
        Write-Host "Tip: run -Mode install first."
        return
    }
    & schtasks /Query /TN "$TaskName" /V /FO LIST
}

try {
    switch ($Mode) {
        "install" { Ensure-Environment; Install-Task }
        "uninstall" { Ensure-Environment; Remove-Task }
        "status" { Ensure-Environment; Show-Task }
        default {
            throw "Unknown mode: $Mode"
        }
    }
}
catch {
    Write-Host $_.Exception.Message
    exit 2
}
