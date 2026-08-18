param(
    [string]$Repo = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [int]$IntervalSeconds = 60,
    [int]$TaskIntervalMinutes = 1,
    [ValidateSet("install", "uninstall", "status")]
    [string]$Mode = "install",
    [switch]$Execute,
    [switch]$Loop,
    [switch]$AutoRound,
    [switch]$AutoExecute,
    [switch]$TagOnUpload,
    [string]$TagPrefix = "v",
    [string]$TaskName = "CodexMaintenanceUploader",
    [string]$PythonCmd = "python",
    [int]$VersionStep = 2,
    [string]$LogPath = "",
    [int]$MaxLockAgeSeconds = 20 * 60
)

$ErrorActionPreference = "Stop"

function Get-TaskCommand {
    param(
        [bool]$isExecute,
        [bool]$withLoop,
        [bool]$withAutoRound,
        [bool]$withAutoExecute,
        [bool]$withVersionStep,
        [bool]$withTagOnUpload,
        [string]$withTagPrefix
    )

    $schedulerScript = Join-Path $PSScriptRoot "maintenance_uploader_scheduler.ps1"
    if (-not (Test-Path $schedulerScript)) {
        throw "未找到脚本: $schedulerScript"
    }

    if (-not (Test-Path $Repo)) {
        throw "仓库不存在: $Repo"
    }

    if (-not (Get-Command $PythonCmd -ErrorAction SilentlyContinue)) {
        throw "未找到可执行命令: $PythonCmd"
    }

    $arguments = @(
        "-NoProfile",
        "-WindowStyle", "Hidden",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$schedulerScript`"",
        "-Repo", "`"$Repo`"",
        "-IntervalSeconds", $IntervalSeconds.ToString(),
        "-PythonCmd", "`"$PythonCmd`""
    )

    if ($withLoop) {
        $arguments += "-Loop"
    }

    if ($withAutoRound) {
        $arguments += "-AutoRound"
    }

    if ($isExecute) {
        $arguments += "-Execute"
    }
    if ($withAutoExecute) {
        $arguments += "-AutoExecute"
    }
    if ($withTagOnUpload) {
        $arguments += "-TagOnUpload"
    }
    if (-not [string]::IsNullOrWhiteSpace($withTagPrefix)) {
        $arguments += "-TagPrefix"
        $arguments += "`"$withTagPrefix`""
    }
    if ($withVersionStep) {
        $arguments += "-VersionStep"
        $arguments += "`"$VersionStep`""
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
    schtasks /Query /TN "$TaskName" 2>$null | Out-Null
    return $LASTEXITCODE -eq 0
}

function Ensure-Environment {
    if (-not (Get-Command schtasks -ErrorAction SilentlyContinue)) {
        throw "未找到 schtasks 命令，无法创建任务计划。"
    }
}

function Install-Task {
    if ($TaskIntervalMinutes -lt 1) {
        throw "TaskIntervalMinutes 必须 >= 1"
    }
    if ($VersionStep -lt 1) {
        throw "VersionStep 必须 >= 1"
    }
    if ($Loop) {
        throw "任务计划模式请不要加 -Loop，已内置按分钟调度。若需常驻执行，请直接运行 scripts\\maintenance_uploader_scheduler.ps1 -Loop。"
    }

    if (Get-TaskExists) {
        throw "任务 ${TaskName} 已存在。请先执行 -Mode uninstall，或更换任务名。"
    }

    $taskCommand = Get-TaskCommand `
        -isExecute $Execute.IsPresent `
        -withLoop $Loop.IsPresent `
        -withAutoRound $AutoRound.IsPresent `
        -withAutoExecute $AutoExecute.IsPresent `
        -withVersionStep ($VersionStep -ne 2) `
        -withTagOnUpload $TagOnUpload.IsPresent `
        -withTagPrefix $TagPrefix
    $quotedTaskCommand = '"' + $taskCommand.Replace('"', '\"') + '"'
    Write-Host "正在创建任务计划: $TaskName"
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
    Write-Host "正在移除任务计划: $TaskName"
    if (-not (Get-TaskExists)) {
        throw "任务 ${TaskName} 不存在，无需移除。"
    }
    & schtasks /Delete /TN "$TaskName" /F
}

function Show-Task {
    Write-Host "查看任务计划: $TaskName"
    if (-not (Get-TaskExists)) {
        Write-Host "任务不存在：$TaskName"
        Write-Host "提示：先执行 -Mode install 创建任务。"
        return
    }
    & schtasks /Query /TN "$TaskName" /V /FO LIST
}

switch ($Mode) {
    "install" { Ensure-Environment; Install-Task }
    "uninstall" { Ensure-Environment; Remove-Task }
    "status" { Ensure-Environment; Show-Task }
}
