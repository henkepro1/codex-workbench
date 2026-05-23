param(
    [Parameter(Mandatory = $true)]
    [string]$Slug,

    [Parameter(Mandatory = $true)]
    [ValidateSet("input", "progress", "result")]
    [string]$Kind,

    [Parameter(Mandatory = $true)]
    [string]$Text,

    [string]$Title = "",

    [string]$Session = ""
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function ConvertTo-Slug {
    param([string]$Value)

    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")

    if ([string]::IsNullOrWhiteSpace($slug)) {
        return "note"
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
        throw "No active session for projects/$Slug. Start one with scripts/start-project-session.ps1."
    }

    $Session = Split-Path (Split-Path $projectIndex.active_session -Parent) -Leaf
}

$folderName = switch ($Kind) {
    "input" { "inputs" }
    "progress" { "progress" }
    "result" { "results" }
}

$sessionRoot = Join-Path $projectRoot ".ai\sessions\$Session"
$sessionIndexPath = Join-Path $sessionRoot "session.json"

if (-not (Test-Path -LiteralPath $sessionIndexPath)) {
    throw "Session not found: projects/$Slug/.ai/sessions/$Session"
}

$now = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
$stamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
$noteTitle = if ([string]::IsNullOrWhiteSpace($Title)) { "$Kind note" } else { $Title }
$noteSlug = ConvertTo-Slug -Value $noteTitle
$noteName = "$stamp-$Kind-$noteSlug.md"
$notePath = Join-Path (Join-Path $sessionRoot $folderName) $noteName
$relativeNotePath = "projects/$Slug/.ai/sessions/$Session/$folderName/$noteName"
$counter = 2

while (Test-Path -LiteralPath $notePath) {
    $noteName = "$stamp-$Kind-$noteSlug-$counter.md"
    $notePath = Join-Path (Join-Path $sessionRoot $folderName) $noteName
    $relativeNotePath = "projects/$Slug/.ai/sessions/$Session/$folderName/$noteName"
    $counter++
}

$content = @"
# $noteTitle

Date: $now
Kind: $Kind
Project: $Slug
Session: $Session

## Note

$Text
"@

Set-Content -LiteralPath $notePath -Value $content -Encoding UTF8

$sessionIndex = Get-Content -Raw -LiteralPath $sessionIndexPath | ConvertFrom-Json

if (-not ($sessionIndex.PSObject.Properties.Name -contains "last_updated")) {
    $sessionIndex | Add-Member -NotePropertyName "last_updated" -NotePropertyValue $now
}

if (-not ($sessionIndex.PSObject.Properties.Name -contains "recent_notes")) {
    $sessionIndex | Add-Member -NotePropertyName "recent_notes" -NotePropertyValue @()
}

$sessionIndex.last_updated = $now
$sessionIndex.note_counts.inputs = @(Get-ChildItem -LiteralPath (Join-Path $sessionRoot "inputs") -Filter "*.md" -File -ErrorAction SilentlyContinue).Count
$sessionIndex.note_counts.progress = @(Get-ChildItem -LiteralPath (Join-Path $sessionRoot "progress") -Filter "*.md" -File -ErrorAction SilentlyContinue).Count
$sessionIndex.note_counts.results = @(Get-ChildItem -LiteralPath (Join-Path $sessionRoot "results") -Filter "*.md" -File -ErrorAction SilentlyContinue).Count

$recent = @()
$noteFolders = @(
    [pscustomobject]@{ kind = "input"; folder = "inputs" },
    [pscustomobject]@{ kind = "progress"; folder = "progress" },
    [pscustomobject]@{ kind = "result"; folder = "results" }
)

foreach ($noteFolder in $noteFolders) {
    $folderPath = Join-Path $sessionRoot $noteFolder.folder
    $files = @(Get-ChildItem -LiteralPath $folderPath -Filter "*.md" -File -ErrorAction SilentlyContinue)

    foreach ($file in $files) {
        $firstLine = Get-Content -LiteralPath $file.FullName -TotalCount 1
        $titleFromFile = if ($firstLine -match "^#\s+(.+)$") { $Matches[1] } else { $file.BaseName }
        $recent += [pscustomobject]@{
            kind = $noteFolder.kind
            title = $titleFromFile
            path = "projects/$Slug/.ai/sessions/$Session/$($noteFolder.folder)/$($file.Name)"
            created_at = $file.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ssK")
        }
    }
}

$sessionIndex.recent_notes = @($recent | Sort-Object created_at | Select-Object -Last 10)
$sessionIndex | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $sessionIndexPath -Encoding UTF8

& (Join-Path $PSScriptRoot "update-project-index.ps1") -Slug $Slug | Out-Null

Write-Output "Added session note: $relativeNotePath"
