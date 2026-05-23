param(
    [Parameter(Mandatory = $true)]
    [string]$Slug,

    [string]$Scope = "uncommitted",

    [ValidateSet("code", "architecture", "unity", "performance", "all")]
    [string]$Focus = "all",

    [string]$Model = "qwen2.5-coder:7b",

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function ConvertTo-Slug {
    param([string]$Value)

    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")

    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw "Invalid slug."
    }

    return $slug
}

function Read-JsonFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing JSON file: $Path"
    }

    try {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    }
    catch {
        throw "Invalid JSON in $Path`: $($_.Exception.Message)"
    }
}

function Ensure-ReviewIndex {
    param(
        [string]$Path,
        [string]$Project
    )

    if (Test-Path -LiteralPath $Path) {
        return Read-JsonFile -Path $Path
    }

    $index = [pscustomobject]@{
        schema_version = 1
        last_updated = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
        purpose = "Findings-only review notes for this project."
        project = $Project
        reviews = @()
    }

    New-Item -ItemType Directory -Force -Path (Split-Path $Path) | Out-Null
    $index | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding UTF8

    return $index
}

function New-ReviewPrompt {
    param(
        [string]$Project,
        [string]$ReviewScope,
        [string]$ReviewFocus
    )

    @"
You are running a fresh findings-only review for project '$Project'.

Follow these rules:
- Report findings only. Do not patch, edit, rewrite, or create files.
- Prioritize bugs, live-project rule violations, behavior regressions, hidden fallbacks, broad Unity lookups, unnecessary allocations/hot-path costs, and missing verification.
- Use severity sections: CRITICAL, WARNING, NOTE.
- Include file paths and line references when available.
- Say "No findings" if nothing material is found.

Required context to read before reviewing:
- AGENTS.md
- rules/live-project-code-rules.md
- projects/$Project/rules/project-rules.md
- projects/$Project/.ai/index.json
- projects/$Project/.ai/engine/unity/index.json when present
- cheatsheets/reviewer.md

Scope: $ReviewScope
Focus: $ReviewFocus

If Scope is:
- uncommitted: review staged, unstaged, and untracked changes.
- base:<branch>: review the diff from that base branch.
- commit:<sha>: review only that commit.
- files:<paths>: review only those files.
"@
}

$Slug = ConvertTo-Slug -Value $Slug
$projectRoot = Join-Path (Join-Path $root "projects") $Slug
$projectIndexPath = Join-Path $projectRoot ".ai\index.json"
$projectIndex = Read-JsonFile -Path $projectIndexPath

if ([string]::IsNullOrWhiteSpace($projectIndex.source_path)) {
    throw "Project $Slug does not define source_path."
}

$sourcePath = $projectIndex.source_path
if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Project source path does not exist: $sourcePath"
}

& (Join-Path $PSScriptRoot "assert-no-extra-spend.ps1") -Provider local -Model $Model | Out-Null
if (-not $DryRun) {
    & (Join-Path $PSScriptRoot "check-local-model.ps1") -Model $Model | Out-Null
}

$reviewPrompt = New-ReviewPrompt -Project $Slug -ReviewScope $Scope -ReviewFocus $Focus
$stamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
$safeScope = ConvertTo-Slug -Value $Scope
$reviewId = "$stamp-local-$safeScope"
$reviewsRoot = Join-Path $projectRoot ".ai\reviews"
$reviewIndexPath = Join-Path $reviewsRoot "index.json"
$relativeReviewPath = "projects/$Slug/.ai/reviews/$reviewId.md"
$reviewPath = Join-Path $reviewsRoot "$reviewId.md"

$codexArgs = @(
    "exec",
    "--oss",
    "--local-provider", "ollama",
    "-m", $Model,
    "-C", $sourcePath,
    "-s", "read-only",
    "-a", "never",
    $reviewPrompt
)

if ($DryRun) {
    Write-Output "DRY RUN: would run local findings-only review."
    Write-Output "Project: $Slug"
    Write-Output "Source: $sourcePath"
    Write-Output "Scope: $Scope"
    Write-Output "Focus: $Focus"
    Write-Output "Command: codex $($codexArgs[0..($codexArgs.Count - 2)] -join ' ') <review prompt>"
    Write-Output "Output: $relativeReviewPath"
    return
}

New-Item -ItemType Directory -Force -Path $reviewsRoot | Out-Null
$reviewOutput = & codex @codexArgs 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Local review failed: $($reviewOutput | Out-String)"
}

$reviewText = ($reviewOutput | Out-String).Trim()
$criticalCount = ([regex]::Matches($reviewText, "(?im)^\s*(#+\s*)?CRITICAL\b")).Count
$warningCount = ([regex]::Matches($reviewText, "(?im)^\s*(#+\s*)?WARNING\b")).Count
$noteCount = ([regex]::Matches($reviewText, "(?im)^\s*(#+\s*)?NOTE\b")).Count
$now = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"

$content = @"
# Review: $Slug / $Scope

Created: $now
Provider: local_free
Model: $Model
Focus: $Focus
Source: $sourcePath

## Findings

$reviewText
"@

Set-Content -LiteralPath $reviewPath -Value $content -Encoding UTF8

$index = Ensure-ReviewIndex -Path $reviewIndexPath -Project $Slug
$reviews = @($index.reviews)
$reviews += [pscustomobject]@{
    id = $reviewId
    project = $Slug
    provider = "local_free"
    model = $Model
    scope = $Scope
    focus = $Focus
    status = "open"
    critical_count = $criticalCount
    warning_count = $warningCount
    note_count = $noteCount
    path = $relativeReviewPath
    created_at = $now
}
$index.reviews = @($reviews | Sort-Object created_at -Descending)
$index.last_updated = $now
$index | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reviewIndexPath -Encoding UTF8

& (Join-Path $PSScriptRoot "update-project-index.ps1") -Slug $Slug | Out-Null

Write-Output "Created review: $relativeReviewPath"
