param(
    [Parameter(Mandatory = $true)]
    [string]$Slug,

    [string]$Session = "",

    [string]$Summary = "Session concluded.",

    [string]$Status = "done"
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
$projectRoot = Join-Path (Join-Path $root "projects") $Slug
$projectIndexPath = Join-Path $projectRoot ".ai\index.json"

if (-not (Test-Path -LiteralPath $projectIndexPath)) {
    throw "Project dossier not found: projects/$Slug"
}

$projectIndex = Get-Content -Raw -LiteralPath $projectIndexPath | ConvertFrom-Json

if ([string]::IsNullOrWhiteSpace($Session)) {
    if ([string]::IsNullOrWhiteSpace($projectIndex.active_session)) {
        throw "No active session for projects/$Slug."
    }

    $Session = Split-Path (Split-Path $projectIndex.active_session -Parent) -Leaf
}

& (Join-Path $PSScriptRoot "add-project-session-note.ps1") -Slug $Slug -Session $Session -Kind result -Title "Session conclusion" -Text $Summary | Out-Null

$sessionRoot = Join-Path $projectRoot ".ai\sessions\$Session"
$sessionIndexPath = Join-Path $sessionRoot "session.json"
$sessionIndex = Get-Content -Raw -LiteralPath $sessionIndexPath | ConvertFrom-Json
$now = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"

$sessionIndex.status = $Status
$sessionIndex.ended_at = $now
$sessionIndex.last_updated = $now
$sessionIndex | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sessionIndexPath -Encoding UTF8

if ($projectIndex.active_session -eq "projects/$Slug/.ai/sessions/$Session/session.json") {
    $projectIndex.active_session = $null
}

$projectIndex.last_updated = $now
$projectIndex | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $projectIndexPath -Encoding UTF8

& (Join-Path $PSScriptRoot "update-project-index.ps1") -Slug $Slug | Out-Null

Write-Output "Concluded project session: projects/$Slug/.ai/sessions/$Session"
