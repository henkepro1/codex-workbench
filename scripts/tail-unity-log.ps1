param(
    [string]$LogPath = "",

    [ValidateSet("error", "warning", "all")]
    [string]$Severity = "error",

    [int]$Tail = 2000,

    [int]$MaxEvents = 30,

    [string]$Pattern = ""
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($LogPath)) {
    $LogPath = Join-Path $env:LOCALAPPDATA "Unity\Editor\Editor.log"
}

if (-not (Test-Path -LiteralPath $LogPath)) {
    throw "Unity Editor log not found: $LogPath"
}

$lines = @(Get-Content -LiteralPath $LogPath -Tail $Tail -ErrorAction Stop)
$events = @()

foreach ($line in $lines) {
    $isWarning = $line -match "(?i)\bwarning\b"
    $isError = $line -match "(?i)(\berror\b|exception|failed|assertion|NullReferenceException|MissingReferenceException|InvalidOperationException)"

    if ($Severity -eq "error" -and -not $isError) {
        continue
    }
    if ($Severity -eq "warning" -and -not ($isWarning -or $isError)) {
        continue
    }
    if (-not [string]::IsNullOrWhiteSpace($Pattern) -and $line -notmatch $Pattern) {
        continue
    }

    $clean = ($line -replace "\s+", " ").Trim()
    if ([string]::IsNullOrWhiteSpace($clean)) {
        continue
    }

    $events += $clean
}

$deduped = @()
$seen = @{}

foreach ($event in $events) {
    if (-not $seen.ContainsKey($event)) {
        $seen[$event] = $true
        $deduped += $event
    }
}

Write-Output "Unity log: $LogPath"
Write-Output "Severity: $Severity"
Write-Output "Scanned lines: $($lines.Count)"
Write-Output "Matched events: $($deduped.Count)"
Write-Output ""

if ($deduped.Count -eq 0) {
    Write-Output "No matching Unity log events found."
    return
}

$deduped | Select-Object -First $MaxEvents | ForEach-Object {
    Write-Output "- $_"
}

if ($deduped.Count -gt $MaxEvents) {
    Write-Output ""
    Write-Output "Truncated: $($deduped.Count - $MaxEvents) more matching events."
}
