param(
    [string]$LogPath = ".\.maintenance\logs\maintenance_uploader.log",
    [int]$TailLines = 120,
    [int]$AlertNoUploadWindow = 5,
    [switch]$AsReport
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $LogPath)) {
    throw "未找到日志文件: $LogPath"
}

if ($TailLines -lt 1) {
    $TailLines = 1
}

Write-Host "健康检查读取前 $TailLines 条日志..."
$lines = Get-Content $LogPath
if ($lines.Count -gt $TailLines) {
    $lines = $lines[($lines.Count - $TailLines)..($lines.Count - 1)]
}

$records = @()
foreach ($line in $lines) {
    if ($line -notmatch "状态：(\{.*\})") {
        continue
    }
    $jsonText = $matches[1]
    try {
        $obj = $jsonText | ConvertFrom-Json
        $records += [PSCustomObject]@{
            ts = if ($obj.ts) { [double]$obj.ts } else { 0 }
            round = if ($obj.round -ne $null) { [int]$obj.round } else { 0 }
            mode = if ($obj.mode) { [string]$obj.mode } else { "unknown" }
            uploaded = [bool]($obj.uploaded)
            backup_done = [bool]($obj.backup_done)
            parse_error = if ($obj.parse_error) { [string]$obj.parse_error } else { "" }
            message = if ($obj.message) { [string]$obj.message } else { "" }
        }
    }
    catch {
        continue
    }
}

if ($records.Count -eq 0) {
    Write-Host "本次日志范围内未发现结构化状态行。请先确认脚本正在输出 `状态：{...}`。"
    exit 1
}

$summary = @{
    total = $records.Count
    uploaded = ($records | Where-Object uploaded | Measure-Object).Count
    skipped_upload = ($records | Where-Object { -not $_.uploaded -and $_.mode -ne "idle" }).Count
    error_mode = ($records | Where-Object { $_.mode -eq "error" }).Count
    idle = ($records | Where-Object { $_.mode -eq "idle" }).Count
    parse_error = ($records | Where-Object { -not [string]::IsNullOrWhiteSpace($_.parse_error) }).Count
    last_round = ($records | Select-Object -ExpandProperty round -Last 1)
}

Write-Host "最近 $TailLines 行状态统计"
Write-Host "总记录: $($summary.total)"
Write-Host "已上传: $($summary.uploaded)"
Write-Host "未上传触发窗口: $($summary.skipped_upload)"
Write-Host "error 模式: $($summary.error_mode)"
Write-Host "idle: $($summary.idle)"
Write-Host "解析异常: $($summary.parse_error)"
Write-Host "最近轮次: $($summary.last_round)"

if ($summary.parse_error -gt 0) {
    Write-Host "注意：发现解析异常，建议检查 docs/context/PROJECT_STATE.md 轮次字段。"
}

if ($summary.uploaded -eq 0 -and $summary.total -ge 20) {
    Write-Host "预警：最近检测无任何上传执行。请确认轮次与时间窗口是否到达，或任务是否只在预览模式运行。"
}

$streak = 0
$maxIdleStreak = 0
foreach ($record in $records) {
    if (-not $record.uploaded -and $record.mode -ne "idle") {
        $streak += 1
        if ($streak -gt $maxIdleStreak) {
            $maxIdleStreak = $streak
        }
    }
    else {
        $streak = 0
    }
}
if ($maxIdleStreak -ge $AlertNoUploadWindow) {
    Write-Host "告警：存在连续未上传非 idle 的窗口，最大连续段=$maxIdleStreak。建议核查 `--execute` 使用与时间窗口配置。"
}

if ($summary.error_mode -gt 0) {
    Write-Host "告警：存在 error 模式记录，需检查 PROJECT_STATE.md 轮次是否可解析。"
}

Write-Host "最近 10 条模式序列:"
$records | Select-Object -Last 10 | ForEach-Object {
    Write-Host ("  round=$($_.round), mode=$($_.mode), uploaded=$($_.uploaded), backup=$($_.backup_done), err=$($_.parse_error)")
}

if ($AsReport) {
    $tsNow = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $uploadRate = if ($summary.total -eq 0) { 0 } else { [math]::Round(($summary.uploaded * 100.0 / $summary.total), 2) }
    $idleRate = if ($summary.total -eq 0) { 0 } else { [math]::Round(($summary.idle * 100.0 / $summary.total), 2) }
    $nonUploadRate = if ($summary.total -eq 0) { 0 } else { [math]::Round((($summary.total - $summary.uploaded) * 100.0 / $summary.total), 2) }
    $reasons = @()
    if ($summary.parse_error -gt 0) { $reasons += "parse_error" }
    if ($maxIdleStreak -ge $AlertNoUploadWindow) { $reasons += "upload_streak" }
    if ($summary.error_mode -gt 0) { $reasons += "mode_error" }
    $rows = @()
    $rows += [PSCustomObject]@{
        time = $tsNow
        log_path = $LogPath
        tail_lines = $TailLines
        total_records = $summary.total
        uploaded = $summary.uploaded
        skipped_upload = $summary.skipped_upload
        error_mode = $summary.error_mode
        idle = $summary.idle
        parse_error = $summary.parse_error
        max_streak_no_upload_non_idle = $maxIdleStreak
        upload_rate = $uploadRate
        idle_rate = $idleRate
        non_upload_rate = $nonUploadRate
        last_round = $summary.last_round
        risk_flag = if ($reasons.Count -gt 0) { "warn" } else { "ok" }
        risk_reasons = ($reasons -join ",")
    }
    $rows | ConvertTo-Csv -NoTypeInformation
}
