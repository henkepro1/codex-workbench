param(
    [Parameter(Mandatory = $true)]
    [string]$Title,

    [string]$Slug = "",

    [string]$SourcePath = "",

    [ValidateSet("general", "unity")]
    [string]$Kind = "general",

    [string]$DefaultSourceRoot = "D:\GameProjects",

    [string]$Status = "active",

    [switch]$Force
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot '_lib\Eol.ps1')

$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function ConvertTo-Slug {
    param([string]$Value)

    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")

    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw "Could not derive a slug from: $Value"
    }

    return $slug
}

function Write-ProjectFile {
    param(
        [string]$Path,
        [string]$Content
    )

    if ((Test-Path -LiteralPath $Path) -and -not $Force) {
        return
    }

    Write-Utf8Lf -Path $Path -Content $Content
}

if ([string]::IsNullOrWhiteSpace($Slug)) {
    $Slug = ConvertTo-Slug -Value $Title
}
else {
    $Slug = ConvertTo-Slug -Value $Slug
}

$now = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
$projectRoot = Join-Path (Join-Path $root "projects") $Slug
$projectAi = Join-Path $projectRoot ".ai"

if ((Test-Path -LiteralPath $projectRoot) -and -not $Force) {
    throw "Project dossier already exists: $projectRoot. Use -Force to refresh templates."
}

$directories = @(
    $projectRoot,
    (Join-Path $projectRoot "map"),
    (Join-Path $projectRoot "rules"),
    (Join-Path $projectRoot "assets"),
    $projectAi,
    (Join-Path $projectAi "assets"),
    (Join-Path $projectAi "attempts"),
    (Join-Path $projectAi "generations"),
    (Join-Path $projectAi "prompts"),
    (Join-Path $projectAi "sessions"),
    (Join-Path $projectAi "summaries"),
    (Join-Path $projectAi "feedback"),
    (Join-Path $projectAi "handoffs")
)

foreach ($directory in $directories) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

$sourceDisplay = if ([string]::IsNullOrWhiteSpace($SourcePath)) { "Not linked yet." } else { $SourcePath }
$sourceJson = if ([string]::IsNullOrWhiteSpace($SourcePath)) { $null } else { $SourcePath }
$kindDisplay = if ($Kind -eq "unity") { "Unity" } else { "General" }

Write-ProjectFile -Path (Join-Path $projectRoot "README.md") -Content @"
# $Title

Project dossier for $Slug.

Kind: $kindDisplay

## Start Here

- Human map: map/overview.md
- Source map: map/source.md
- Workflow map: map/workflow.md
- Asset map: map/assets.md
- Project rules: rules/project-rules.md
- AI context: .ai/index.json

## Source

$sourceDisplay
"@

Write-ProjectFile -Path (Join-Path $projectRoot "map\overview.md") -Content @"
# Overview

Project: $Title

## Purpose

Describe what this project is for.

## Current State

Describe the current state in a few lines.

## Important Links

- AI index: ../.ai/index.json
"@

Write-ProjectFile -Path (Join-Path $projectRoot "map\source.md") -Content @"
# Source

Source path: $sourceDisplay

Use this file to explain where code lives and what should be inspected first.
"@

Write-ProjectFile -Path (Join-Path $projectRoot "map\workflow.md") -Content @"
# Workflow

Use this file for project-specific commands, test steps, build steps, and release notes.
"@

Write-ProjectFile -Path (Join-Path $projectRoot "map\assets.md") -Content @"
# Assets

Human-facing assets for this project live in ../assets/.

AI-facing asset metadata lives in ../.ai/assets/index.json.
"@

Write-ProjectFile -Path (Join-Path $projectRoot "rules\project-rules.md") -Content @"
# $Title Project Rules

These rules apply before changing the linked live project.

## Required Rule Sources

- Global live-project policy: rules/live-project-code-rules.md
- Token-friendly rules index: .ai/rules/index.json
- Project context: projects/$Slug/.ai/index.json

## Project-Specific Overlay

- No separate source-side rules file has been registered yet.
- Use the global live-project policy as the active coding standard.
- Do not change gameplay or product behavior unless the user explicitly requests that behavior change.
- Record every external edit with scripts/record-project-change.ps1.
"@

$projectIndex = [pscustomobject]@{
    schema_version = 1
    slug = $Slug
    title = $Title
    status = $Status
    source_path = $sourceJson
    created_at = $now
    last_updated = $now
    human_map = [pscustomobject]@{
        readme = "projects/$Slug/README.md"
        overview = "projects/$Slug/map/overview.md"
        source = "projects/$Slug/map/source.md"
        workflow = "projects/$Slug/map/workflow.md"
        assets = "projects/$Slug/map/assets.md"
        rules = "projects/$Slug/rules/project-rules.md"
    }
    ai_paths = [pscustomobject]@{
        assets_manifest = "projects/$Slug/.ai/assets/index.json"
        sessions = "projects/$Slug/.ai/sessions"
        attempts = "projects/$Slug/.ai/attempts"
        generations = "projects/$Slug/.ai/generations"
        prompts = "projects/$Slug/.ai/prompts"
        summaries = "projects/$Slug/.ai/summaries"
        changes = "projects/$Slug/.ai/changes"
        feedback = "projects/$Slug/.ai/feedback/index.json"
        handoffs = "projects/$Slug/.ai/handoffs/index.json"
        summary = "projects/$Slug/.ai/summary.md"
        scope = "projects/$Slug/.ai/scope.json"
    }
    active_session = $null
    kind = $Kind
    default_source_root = $DefaultSourceRoot
    rules = [pscustomobject]@{
        global_index = ".ai/rules/index.json"
        global_policy = "rules/live-project-code-rules.md"
        project_overlay = "projects/$Slug/rules/project-rules.md"
        source_rules = @()
        must_read_before_external_edits = $true
    }
    counts = [pscustomobject]@{
        assets = 0
        sessions = 0
        attempts = 0
        generations = 0
        prompts = 0
        summaries = 0
        changes = 0
        engine_context_files = 0
        feedback = 0
        handoffs = 0
    }
    notes = @(
        "Read this file before scanning the project dossier or linked source path.",
        "Keep detailed session documentation in timestamped session files only when explicitly requested."
    )
}

$extraDirectories = @(
    (Join-Path $projectAi "changes")
)

if ($Kind -eq "unity") {
    $extraDirectories += @(
        (Join-Path $projectAi "engine"),
        (Join-Path $projectAi "engine\unity")
    )

    $projectIndex.ai_paths | Add-Member -NotePropertyName "engine" -NotePropertyValue "projects/$Slug/.ai/engine"
    $projectIndex.ai_paths | Add-Member -NotePropertyName "unity_context" -NotePropertyValue "projects/$Slug/.ai/engine/unity/index.json"
    $projectIndex.notes += "Unity engine context lives under projects/$Slug/.ai/engine/unity/."
}

foreach ($directory in $extraDirectories) {
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
}

Write-Utf8Lf -Path (Join-Path $projectAi "index.json") -Content ($projectIndex | ConvertTo-Json -Depth 10)

[pscustomobject]@{
    schema_version = 1
    last_updated = $now
    project = $Slug
    source_path = $sourceJson
    source_exists = $false
    authored_source = [pscustomobject]@{
        file_count = 0
        csharp_files = 0
        csharp_loc = 0
        size_class = "small"
        extension_counts = @()
        excluded_dirs = @("Library", "Temp", "Logs", "obj", "bin", "Build", "Builds", "PackageCache", ".git", ".vs")
    }
    engine_assets = [pscustomobject]@{
        engine = $Kind
        scenes = 0
        prefabs = 0
        scriptable_objects = 0
        shaders = 0
        packages = 0
    }
    notes_corpus = [pscustomobject]@{
        total_records = 0
        counts = [pscustomobject]@{
            attempts = 0
            decisions = 0
            feedback = 0
            sessions = 0
            handoffs = 0
            changes = 0
            summaries = 0
            maps = 0
        }
        rag_candidate = $false
    }
    retrieval = [pscustomobject]@{
        default_strategy = "grep_and_index"
        source_code_strategy = "grep_and_index"
        memory_strategy = "grep_and_index_until_rag_setup"
        rag_status = "setup_required"
    }
} | ConvertTo-Json -Depth 12 | ForEach-Object { Write-Utf8Lf -Path (Join-Path $projectAi "scope.json") -Content $_ }

$assetIndex = [pscustomobject]@{
    schema_version = 1
    last_updated = $now
    assets_root = "projects/$Slug/assets"
    assets = @()
}

Write-Utf8Lf -Path (Join-Path $projectAi "assets\index.json") -Content ($assetIndex | ConvertTo-Json -Depth 10)

Write-ProjectFile -Path (Join-Path $projectAi "attempts\_template.md") -Content @"
# Attempt: {{TASK_TITLE}}

Date: {{DATE}}
Status: failed | stalled | abandoned | superseded

## Goal

## Context

## Attempted Steps

## Failure Or Error

## Suspected Cause

## Next Recommended Approach

## Things Not To Retry
"@

Write-ProjectFile -Path (Join-Path $projectAi "generations\_template.json") -Content @"
{
  "schema_version": 1,
  "id": "YYYY-MM-DD-generation-id",
  "created_at": "ISO 8601 timestamp",
  "tool": "image_gen | local-script | external | unknown",
  "prompt": "generation prompt or summary",
  "inputs": [],
  "outputs": [],
  "status": "draft | accepted | rejected | archived",
  "linked_asset_ids": [],
  "notes": ""
}
"@

Write-ProjectFile -Path (Join-Path $projectAi "prompts\_template.md") -Content @"
# Prompt Record: {{TITLE}}

Date: {{DATE}}
Status: draft | useful | superseded

## Prompt

## Result

## Reuse Notes
"@

Write-ProjectFile -Path (Join-Path $projectAi "summaries\README.md") -Content @"
# Summaries

Store compact project summaries here when they are useful for future sessions.
"@

Write-ProjectFile -Path (Join-Path $projectAi "summary.md") -Content @"
# $Title Summary

Slug: `$Slug`

Kind: $kindDisplay

Source: $sourceDisplay

Use projects/$Slug/.ai/index.json first, then inspect focused map files or engine context as needed.
"@

Write-ProjectFile -Path (Join-Path $projectRoot "perf-budget.md") -Content @"
# $Title Performance Budget

Use this file for project-specific performance targets and profiling notes.

## Current Defaults

- Assume high load for scalable gameplay or product systems.
- Avoid hidden per-frame allocations and broad repeated lookups.
- Respect existing pooling, prewarm, tick, and update-budget systems.

## Measured Budgets

- Frame time budget: TBD.
- Hot-path allocation budget: TBD.
- Scale targets: TBD.
"@

[pscustomobject]@{
    schema_version = 1
    last_updated = $now
    project = $Slug
    purpose = "Project-specific persistent feedback memory."
    entries = @()
} | ConvertTo-Json -Depth 10 | ForEach-Object { Write-Utf8Lf -Path (Join-Path $projectAi "feedback\index.json") -Content $_ }

[pscustomobject]@{
    schema_version = 1
    last_updated = $now
    project = $Slug
    purpose = "Manual lightweight project handoff notes."
    handoffs = @()
} | ConvertTo-Json -Depth 10 | ForEach-Object { Write-Utf8Lf -Path (Join-Path $projectAi "handoffs\index.json") -Content $_ }

$registryPath = Join-Path $root ".ai\projects\index.json"
if (-not (Test-Path -LiteralPath $registryPath)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $registryPath) | Out-Null
    [pscustomobject]@{
        schema_version = 1
        last_updated = $now
        projects_root = "projects"
        projects = @()
    } | ConvertTo-Json -Depth 10 | ForEach-Object { Write-Utf8Lf -Path $registryPath -Content $_ }
}

$registry = Get-Content -Raw -LiteralPath $registryPath | ConvertFrom-Json
$projects = @($registry.projects)
$found = $false
$updatedProjects = @()

foreach ($project in $projects) {
    if ($project.slug -eq $Slug) {
        $found = $true
        $updatedProjects += [pscustomobject]@{
            slug = $Slug
            title = $Title
            status = $Status
            kind = $Kind
            source_path = $sourceJson
            path = "projects/$Slug"
            index = "projects/$Slug/.ai/index.json"
            created_at = $project.created_at
            last_updated = $now
        }
    }
    else {
        $updatedProjects += $project
    }
}

if (-not $found) {
    $projects += [pscustomobject]@{
        slug = $Slug
        title = $Title
        status = $Status
        kind = $Kind
        source_path = $sourceJson
        path = "projects/$Slug"
        index = "projects/$Slug/.ai/index.json"
        created_at = $now
        last_updated = $now
    }
    $updatedProjects = $projects
}

$registry.projects = @($updatedProjects | Sort-Object slug)
$registry.last_updated = $now
Write-Utf8Lf -Path $registryPath -Content ($registry | ConvertTo-Json -Depth 10)

if (-not [string]::IsNullOrWhiteSpace($SourcePath) -and (Test-Path -LiteralPath $SourcePath)) {
    & (Join-Path $PSScriptRoot "update-project-scope.ps1") -Slug $Slug | Out-Null
}

& (Join-Path $PSScriptRoot "update-ai-index.ps1") | Out-Null

Write-Output "Created project dossier: projects/$Slug"
Write-Output "Project index: projects/$Slug/.ai/index.json"
