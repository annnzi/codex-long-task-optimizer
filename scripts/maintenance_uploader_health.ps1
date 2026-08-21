param(
    [string]$LogPath = '.\.maintenance\logs\maintenance_uploader.log',
    [int]$TailLines = 120,
    [int]$AlertNoUploadWindow = 5,
    [string]$AuditPath = '',
    [switch]$AsReport
)

$ErrorActionPreference = 'Stop'

$cnStatus = "$([char]0x72b6)$([char]0x6001)"
$cnStatusWide = $cnStatus + "$([char]0xFF1A)"
$cnStatusColon = $cnStatus + ':'
$logPathResolved = (Resolve-Path -Path $LogPath).Path
$logDirectory = Split-Path -Path $logPathResolved -Parent

$statusPatterns = @(
    '(?i)(?:status|STATUS|Status|状态)\s*[:：]\s*(\{.*\})$',
    '(?i)(?:status|STATUS|Status|状态)\s*(?:=>|=)\s*(\{.*\})$'
)

function Get-StatusTextFromLine {
    param([string]$line)

    foreach ($prefix in @(
        ($cnStatus + ':'),    # 状态:
        $cnStatusWide,        # 状态：
        $cnStatusColon,       # 状态:
        'status:',
        'STATUS:',
        'Status:',
        'status =>',
        'status =',
        'STATUS =>',
        'STATUS =',
        'Status =>',
        'Status ='
    )) {
        $index = $line.IndexOf($prefix)
        if ($index -ge 0) {
            return $line.Substring($index + $prefix.Length).Trim()
        }
    }

    foreach ($pattern in $statusPatterns) {
        $match = [regex]::Match($line, $pattern)
        if ($match.Success -and $match.Groups.Count -gt 1) {
            return $match.Groups[1].Value.Trim()
        }
    }

    if ($line -match '(?i)(?:status|STATUS|Status|状态)') {
        $start = $line.IndexOf('{')
        if ($start -ge 0) {
            $candidate = $line.Substring($start).Trim()
            if ($candidate.StartsWith('{') -and $candidate.Contains('}')) {
                return $candidate
            }
        }
    }

    return $null
}

function Resolve-BackupPath {
    param([string]$PathValue)

    if ([string]::IsNullOrWhiteSpace($PathValue)) {
        return $null
    }
    if ([System.IO.Path]::IsPathRooted($PathValue)) {
        return $PathValue
    }
    if ([string]::IsNullOrWhiteSpace($logDirectory)) {
        return $PathValue
    }
    return Join-Path $logDirectory $PathValue
}

if (-not (Test-Path -Path $LogPath -PathType Leaf)) {
    throw ("Log not found: {0}" -f $LogPath)
}

if ($TailLines -lt 1) {
    $TailLines = 1
}

Write-Host ("Read last {0} log lines..." -f $TailLines)
$lines = Get-Content -Path $LogPath -Tail $TailLines

$records = New-Object System.Collections.Generic.List[PSObject]
$parseFailureSamples = New-Object System.Collections.Generic.List[string]
foreach ($line in $lines) {
    $statusText = Get-StatusTextFromLine -line $line
    if ([string]::IsNullOrWhiteSpace($statusText)) {
        continue
    }
    if (-not $statusText.TrimStart().StartsWith('{')) {
        continue
    }

    try {
        $obj = $statusText | ConvertFrom-Json
    }
    catch {
        $parseFailureSamples.Add(($line.Trim() -replace "`r|`n", ''))
        continue
    }

    $records.Add([PSCustomObject]@{
        ts = if ($null -ne $obj.ts) { [double]$obj.ts } else { 0 }
        round = if ($null -ne $obj.round) { [int]$obj.round } else { 0 }
        mode = if ($obj.mode) { [string]$obj.mode } else { 'unknown' }
        uploaded = [bool]($obj.uploaded)
        backup_done = [bool]($obj.backup_done)
        backup_file = if ($obj.backup_file) { [string]$obj.backup_file } else { '' }
        parse_error = if ($obj.parse_error) { [string]$obj.parse_error } else { '' }
        message = if ($obj.message) { [string]$obj.message } else { '' }
        cycle_version = if ($obj.cycle_version) { [string]$obj.cycle_version } else { '' }
        cycles_completed = if ($null -ne $obj.cycles_completed) { [int]$obj.cycles_completed } else { 0 }
        round_cycle_completed = if ($null -ne $obj.round_cycle_completed) { [bool]$obj.round_cycle_completed } else { $false }
        cycle_boundary_round = if ($null -ne $obj.cycle_boundary_round) { [int]$obj.cycle_boundary_round } else { 0 }
        cycle_boundary_ts = if ($null -ne $obj.cycle_boundary_ts) { [double]$obj.cycle_boundary_ts } else { 0 }
        next_small_upload_due_seconds = if ($null -ne $obj.next_small_upload_due_seconds) { [int]$obj.next_small_upload_due_seconds } else { 0 }
        next_major_upload_due_seconds = if ($null -ne $obj.next_major_upload_due_seconds) { [int]$obj.next_major_upload_due_seconds } else { 0 }
        project_version = if ($obj.project_version) { [string]$obj.project_version } else { '' }
        cycle_tag = if ($obj.cycle_tag) { [string]$obj.cycle_tag } else { '' }
        version_step = if ($null -ne $obj.version_step) { [int]$obj.version_step } else { 0 }
        round_max = if ($null -ne $obj.round_max) { [int]$obj.round_max } else { 0 }
        round_action = if ($obj.round_action) { [string]$obj.round_action } else { '' }
        state_source = if ($obj.state_source) { [string]$obj.state_source } else { '' }
    })
}

if ($records.Count -eq 0) {
    Write-Host 'No structured status found in selected lines. Ensure maintenance_uploader writes status JSON lines with "status:" prefix.'
    if ($parseFailureSamples.Count -gt 0) {
        Write-Host 'Parse failed sample:'
        $parseFailureSamples | Select-Object -First 3 | ForEach-Object {
            Write-Host ("  {0}" -f $_)
        }
    }
    exit 1
}

    $latestBackupFile = ($records | Where-Object { -not [string]::IsNullOrWhiteSpace($_.backup_file) } | Select-Object -ExpandProperty backup_file -Last 1)
    $resolvedLatestBackupFile = Resolve-BackupPath -PathValue $latestBackupFile

    $summary = @{
        total = $records.Count
        uploaded = ($records | Where-Object uploaded | Measure-Object).Count
        skipped_upload = ($records | Where-Object { -not $_.uploaded -and $_.mode -ne 'idle' } | Measure-Object).Count
        error_mode = ($records | Where-Object { $_.mode -eq 'error' } | Measure-Object).Count
        idle = ($records | Where-Object { $_.mode -eq 'idle' } | Measure-Object).Count
        parse_error = ($records | Where-Object { -not [string]::IsNullOrWhiteSpace($_.parse_error) } | Measure-Object).Count
        last_round = ($records | Select-Object -ExpandProperty round -Last 1)
        last_cycle_version = ($records | Select-Object -ExpandProperty cycle_version -Last 1)
        last_project_version = ($records | Select-Object -ExpandProperty project_version -Last 1)
        last_cycle_tag = ($records | Select-Object -ExpandProperty cycle_tag -Last 1)
        last_round_action = ($records | Select-Object -ExpandProperty round_action -Last 1)
        last_state_source = ($records | Select-Object -ExpandProperty state_source -Last 1)
        last_cycles_completed = ($records | Select-Object -ExpandProperty cycles_completed -Last 1)
        total_round_cycle_completed = ($records | Where-Object { $_.round_cycle_completed } | Measure-Object).Count
        last_round_max = ($records | Select-Object -ExpandProperty round_max -Last 1)
        last_cycle_boundary_round = ($records | Select-Object -ExpandProperty cycle_boundary_round -Last 1)
        last_cycle_boundary_ts = ($records | Select-Object -ExpandProperty cycle_boundary_ts -Last 1)
        backup_events = ($records | Where-Object { $_.backup_done } | Measure-Object).Count
        last_backup_file = $latestBackupFile
        latest_backup_exists = if ([string]::IsNullOrWhiteSpace($resolvedLatestBackupFile)) { $false } else { Test-Path -Path $resolvedLatestBackupFile }
        max_small_due = ($records | Measure-Object -Property next_small_upload_due_seconds -Maximum).Maximum
        max_major_due = ($records | Measure-Object -Property next_major_upload_due_seconds -Maximum).Maximum
        nearest_small_due = ($records | Measure-Object -Property next_small_upload_due_seconds -Minimum).Minimum
        nearest_major_due = ($records | Measure-Object -Property next_major_upload_due_seconds -Minimum).Minimum
    }

$versionStepValues = $records | Where-Object { $_.version_step -gt 0 } | Select-Object -ExpandProperty version_step
if ($versionStepValues.Count -eq 0) {
    $summary.avg_version_step = 0
} else {
    $summary.avg_version_step = [math]::Round(($versionStepValues | Measure-Object -Average).Average, 2)
}

Write-Host ("Last {0} status lines summary" -f $TailLines)
Write-Host ("Total records: {0}" -f $summary.total)
Write-Host ("Uploaded: {0}" -f $summary.uploaded)
Write-Host ("Skipped by window: {0}" -f $summary.skipped_upload)
Write-Host ("Error mode: {0}" -f $summary.error_mode)
Write-Host ("Idle mode: {0}" -f $summary.idle)
Write-Host ("Parse errors: {0}" -f $summary.parse_error)
Write-Host ("Last round: {0}" -f $summary.last_round)
Write-Host ("Backup events in window: {0}" -f $summary.backup_events)
if ([bool]$summary.latest_backup_exists) {
    Write-Host ("Latest backup exists on disk: {0}" -f $summary.last_backup_file)
}

if (-not [string]::IsNullOrWhiteSpace($summary.last_cycle_version)) {
    Write-Host ("Last cycle version: {0}" -f $summary.last_cycle_version)
}
Write-Host ("Due window (nearest max/min seconds small/major): {0}/{1} / {2}/{3}" -f $summary.nearest_small_due, $summary.nearest_major_due, $summary.max_small_due, $summary.max_major_due)
if ($summary.last_cycles_completed -ge 0) {
    Write-Host ("Cycles completed: {0}" -f $summary.last_cycles_completed)
}
Write-Host ("Round cycle completed events in window: {0}" -f $summary.total_round_cycle_completed)
if ($summary.last_cycle_boundary_round -gt 0) {
    Write-Host ("Last cycle boundary: round={0}, ts={1}" -f $summary.last_cycle_boundary_round, $summary.last_cycle_boundary_ts)
}
if ($summary.total_round_cycle_completed -gt 0) {
    $milestoneWindow = if ($summary.last_round_max -gt 0) { $summary.last_round_max } else { 100 }
    Write-Host ("Milestone: detected {0}-round cycle completion event in observed window." -f $milestoneWindow)
}

if (-not [string]::IsNullOrWhiteSpace($summary.last_project_version)) {
    Write-Host ("Project version: {0}" -f $summary.last_project_version)
}
if (-not [string]::IsNullOrWhiteSpace($summary.last_cycle_tag)) {
    Write-Host ("Last cycle tag: {0}" -f $summary.last_cycle_tag)
}
if (-not [string]::IsNullOrWhiteSpace($summary.last_round_action)) {
    Write-Host ("Last round action: {0}" -f $summary.last_round_action)
}
if (-not [string]::IsNullOrWhiteSpace($summary.last_state_source)) {
    Write-Host ("Last state source: {0}" -f $summary.last_state_source)
}
if (-not [string]::IsNullOrWhiteSpace($summary.last_backup_file)) {
    Write-Host ("Latest backup: {0}" -f $summary.last_backup_file)
}

if ($summary.parse_error -gt 0) {
    Write-Host 'Warning: parse_error found, please check project state round fields.'
}
if ($summary.uploaded -eq 0 -and $summary.total -ge 20) {
    Write-Host 'Alert: no uploads observed in recent logs. Verify schedule windows and execute mode.'
}

$streak = 0
$maxIdleStreak = 0
foreach ($record in $records) {
    if (-not $record.uploaded -and $record.mode -ne 'idle') {
        $streak += 1
        if ($streak -gt $maxIdleStreak) {
            $maxIdleStreak = $streak
        }
    }
    else {
        $streak = 0
    }
}

$resultTier = 'ok'
if ($summary.error_mode -gt 0 -or $summary.parse_error -gt 0) {
    $resultTier = 'error'
}
elseif ($summary.uploaded -eq 0 -or $maxIdleStreak -ge $AlertNoUploadWindow) {
    $resultTier = 'warn'
}
Write-Host ("Result tier: {0}" -f $resultTier)

if ($maxIdleStreak -ge $AlertNoUploadWindow) {
    Write-Host ("Alert: no-upload active streak={0}, check --execute and timing settings." -f $maxIdleStreak)
}
if ($summary.error_mode -gt 0) {
    Write-Host 'Alert: error mode exists; validate state parsing in PROJECT_STATE.md'
}

Write-Host 'Last 10 status sequence:'
$records | Select-Object -Last 10 | ForEach-Object {
    Write-Host ("  round={0}, mode={1}, uploaded={2}, backup={3}, err={4}" -f $_.round, $_.mode, $_.uploaded, $_.backup_done, $_.parse_error)
}

if ($AsReport) {
    $tsNow = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $uploadRate = if ($summary.total -eq 0) { 0 } else { [math]::Round(($summary.uploaded * 100.0 / $summary.total), 2) }
    $idleRate = if ($summary.total -eq 0) { 0 } else { [math]::Round(($summary.idle * 100.0 / $summary.total), 2) }
    $nonUploadRate = if ($summary.total -eq 0) { 0 } else { [math]::Round((($summary.total - $summary.uploaded) * 100.0 / $summary.total), 2) }

    $reasons = New-Object System.Collections.Generic.List[string]
    if ($summary.parse_error -gt 0) { $reasons.Add('parse_error') }
    if ($maxIdleStreak -ge $AlertNoUploadWindow) { $reasons.Add('upload_streak') }
    if ($summary.error_mode -gt 0) { $reasons.Add('mode_error') }

    $rows = @(
        [PSCustomObject]@{
            time = $tsNow
            log_path = $LogPath
            tail_lines = $TailLines
            total_records = $summary.total
            uploaded = $summary.uploaded
            skipped_upload = $summary.skipped_upload
            error_mode = $summary.error_mode
            idle = $summary.idle
            parse_error = $summary.parse_error
            last_cycle_version = $summary.last_cycle_version
            max_streak_no_upload_non_idle = $maxIdleStreak
            upload_rate = $uploadRate
            idle_rate = $idleRate
            non_upload_rate = $nonUploadRate
            last_round = $summary.last_round
            project_version = $summary.last_project_version
            cycle_tag = $summary.last_cycle_tag
            round_action = $summary.last_round_action
            state_source = $summary.last_state_source
            last_backup_file = $summary.last_backup_file
            backup_events = $summary.backup_events
            latest_backup_exists = [bool]$summary.latest_backup_exists
            result_tier = $resultTier
            avg_version_step = $summary.avg_version_step
            nearest_small_due = $summary.nearest_small_due
            nearest_major_due = $summary.nearest_major_due
            max_small_due = $summary.max_small_due
            max_major_due = $summary.max_major_due
            risk_flag = if ($reasons.Count -gt 0) { 'warn' } else { 'ok' }
            risk_reasons = ($reasons -join ',')
            avg_round = if ($records.Count -eq 0) { 0 } else { [math]::Round(($records | Select-Object -ExpandProperty round | Measure-Object -Average).Average, 2) }
            cycles_completed = $summary.last_cycles_completed
            round_cycle_completed = $summary.total_round_cycle_completed
            cycle_boundary_round = $summary.last_cycle_boundary_round
            cycle_boundary_ts = $summary.last_cycle_boundary_ts
            round_max = if ($summary.last_round_max -gt 0) { $summary.last_round_max } else { 100 }
            audit_time = $tsNow
        }
    )
    if (-not [string]::IsNullOrWhiteSpace($AuditPath)) {
        $auditDir = Split-Path -Path $AuditPath -Parent
        if (-not [string]::IsNullOrWhiteSpace($auditDir) -and -not (Test-Path -Path $auditDir)) {
            New-Item -ItemType Directory -Path $auditDir | Out-Null
        }
        if (Test-Path -Path $AuditPath) {
            $rows | Export-Csv -Path $AuditPath -NoTypeInformation -Append
        }
        else {
            $rows | Export-Csv -Path $AuditPath -NoTypeInformation
        }
        Write-Host ("Audit snapshot appended: {0}" -f $AuditPath)
    }
    $rows | ConvertTo-Csv -NoTypeInformation
}
