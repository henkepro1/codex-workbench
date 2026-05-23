param(
    [Parameter(Mandatory = $true)]
    [string]$Slug,

    [Parameter(Mandatory = $true)]
    [string]$Topic,

    [string]$InitialNote = "",

    [switch]$AllowParallel
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function ConvertTo-Slug {
    param([string]$Value)

    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")

    if ([string]::IsNullOrWhiteSpace($slug)) {
        return "session"
    }

    return $slug
}

$Slug = ConvertTo-Slug -Value $Slug
$topicSlug = ConvertTo-Slug -Value $Topic
$projectRoot = Join-Path (Join-Path $root "projects") $Slug
$projectIndexPath = Join-Path $projectRoot ".ai\index.json"

if (-not (Test-Path -LiteralPath $projectIndexPath)) {
    throw "Project dossier not found: projects/$Slug"
}

$projectIndex = Get-Content -Raw -LiteralPath $projectIndexPath | ConvertFrom-Json

if ((-not $AllowParallel) -and (-not [string]::IsNullOrWhiteSpace($projectIndex.active_session))) {
    throw "Project already has an active session: $($projectIndex.active_session). Conclude it first or use -AllowParallel."
}

$timestamp = Get-Date -Format "yyyy-MM-dd-HHmm"
$sessionId = "$timestamp-$topicSlug"
$sessionsRoot = Join-Path $projectRoot ".ai\sessions"
$sessionRoot = Join-Path $sessionsRoot $sessionId
$counter = 2

while (Test-Path -LiteralPath $sessionRoot) {
    $sessionId = "$timestamp-$topicSlug-$counter"
    $sessionRoot = Join-Path $sessionsRoot $sessionId
    $counter++
}

$directories = @(
    $sessionRoot,
    (Join-Path $sessionRoot "inputs"),
    (Join-Path $sessionRoot "progress"),
    (Join-Path $sessionRoot "results"),
    (Join-Path $sessionRoot "artifacts")
)

foreach ($directory in $directories) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$now = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
$relativeSessionPath = "projects/$Slug/.ai/sessions/$sessionId"

$sessionIndex = [pscustomobject]@{
    schema_version = 1
    id = $sessionId
    project = $Slug
    topic = $Topic
    status = "active"
    started_at = $now
    last_updated = $now
    ended_at = $null
    paths = [pscustomobject]@{
        root = $relativeSessionPath
        inputs = "$relativeSessionPath/inputs"
        progress = "$relativeSessionPath/progress"
        results = "$relativeSessionPath/results"
        artifacts = "$relativeSessionPath/artifacts"
    }
    note_counts = [pscustomobject]@{
        inputs = 0
        progress = 0
        results = 0
    }
    recent_notes = @()
}

$sessionIndex | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $sessionRoot "session.json") -Encoding UTF8

$projectIndex.active_session = "$relativeSessionPath/session.json"
$projectIndex.last_updated = $now
$projectIndex | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $projectIndexPath -Encoding UTF8

if (-not [string]::IsNullOrWhiteSpace($InitialNote)) {
    & (Join-Path $PSScriptRoot "add-project-session-note.ps1") -Slug $Slug -Kind input -Text $InitialNote -Title "Initial request" -Session $sessionId | Out-Null
}

& (Join-Path $PSScriptRoot "update-project-index.ps1") -Slug $Slug | Out-Null

Write-Output "Started project session: $relativeSessionPath"
