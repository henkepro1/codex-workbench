param(
    [string]$Slug = "",

    [int]$MaxLinesPerFile = 120,

    [switch]$Bootstrap,

    [int]$RecentCount = 3
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function ConvertTo-Slug {
    param([string]$Value)

    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")

    return $slug
}

function Read-JsonIfExists {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Write-RecentMarkdown {
    param(
        [string]$Title,
        [string]$Path,
        [int]$Count
    )

    Write-Output "## $Title"

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Output "None."
        Write-Output ""
        return
    }

    $files = @(Get-ChildItem -LiteralPath $Path -Filter "*.md" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -ne "_template.md" } |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First $Count)

    if ($files.Count -eq 0) {
        Write-Output "None."
        Write-Output ""
        return
    }

    foreach ($file in $files) {
        $firstHeading = (Get-Content -LiteralPath $file.FullName -TotalCount 20 | Where-Object { $_ -match "^#\s+" } | Select-Object -First 1)
        if ([string]::IsNullOrWhiteSpace($firstHeading)) {
            $firstHeading = $file.BaseName
        }
        Write-Output "- $($file.Name): $($firstHeading -replace '^#\s+', '')"
    }

    Write-Output ""
}

function Write-RecentJsonEntries {
    param(
        [string]$Title,
        [string]$Path,
        [string]$Property,
        [int]$Count
    )

    Write-Output "## $Title"

    $index = Read-JsonIfExists -Path $Path
    if ($null -eq $index -or -not ($index.PSObject.Properties.Name -contains $Property)) {
        Write-Output "None."
        Write-Output ""
        return
    }

    $entries = @($index.$Property | Select-Object -First $Count)
    if ($entries.Count -eq 0) {
        Write-Output "None."
        Write-Output ""
        return
    }

    foreach ($entry in $entries) {
        $titleText = if ($entry.title) { $entry.title } elseif ($entry.summary) { $entry.summary } else { $entry.id }
        $pathText = if ($entry.path) { " ($($entry.path))" } else { "" }
        Write-Output "- $titleText$pathText"
    }

    Write-Output ""
}

if ($Bootstrap) {
    $projectSlug = ""
    if (-not [string]::IsNullOrWhiteSpace($Slug)) {
        $projectSlug = ConvertTo-Slug -Value $Slug
    }

    $workspaceIndex = Read-JsonIfExists -Path (Join-Path $root ".ai\index.json")
    $projectsIndex = Read-JsonIfExists -Path (Join-Path $root ".ai\projects\index.json")
    $workflowIndex = Read-JsonIfExists -Path (Join-Path $root ".ai\workflows\index.json")
    $recommendationIndex = Read-JsonIfExists -Path (Join-Path $root ".ai\recommendations\index.json")

    Write-Output "# Codex Workbench Bootstrap"
    Write-Output ""
    Write-Output "Generated: $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"
    Write-Output "Root: $root"
    if (-not [string]::IsNullOrWhiteSpace($projectSlug)) {
        Write-Output "Project: $projectSlug"
    }
    Write-Output ""

    Write-Output "## Load Order"
    Write-Output "- AGENTS.md"
    Write-Output "- .ai/index.json"
    Write-Output "- .ai/projects/index.json"
    Write-Output "- .ai/workflows/index.json when using @wb macros"
    Write-Output "- .ai/recommendations/index.json for optional workflow suggestions"
    Write-Output "- .ai/rules/index.json before external project edits"
    Write-Output "- projects/<slug>/.ai/index.json before project work"
    Write-Output ""

    Write-Output "## Workspace"
    if ($workspaceIndex) {
        Write-Output "- Purpose: $($workspaceIndex.workspace.purpose)"
        Write-Output "- Projects: $($workspaceIndex.projects.count)"
        Write-Output "- Default source roots: $(@($workspaceIndex.workspace.default_external_source_roots) -join ', ')"
    }
    Write-Output ""

    Write-Output "## Projects"
    if ($projectsIndex) {
        foreach ($project in @($projectsIndex.projects)) {
            Write-Output "- $($project.slug): $($project.title) [$($project.kind)] -> $($project.source_path)"
        }
    }
    Write-Output ""

    Write-Output "## Workflow Codes"
    if ($workflowIndex) {
        foreach ($code in @($workflowIndex.codes)) {
            Write-Output "- $($code.code): requires $(@($code.requires) -join ', ')"
        }
    }
    Write-Output ""

    Write-Output "## Recommendations"
    if ($recommendationIndex) {
        Write-Output "- Mode: $($recommendationIndex.mode)"
        foreach ($category in @($recommendationIndex.categories)) {
            Write-Output "- $($category.id): $($category.mode) -> $($category.suggest)"
        }
    }
    else {
        Write-Output "None."
    }
    Write-Output ""

    Write-RecentJsonEntries -Title "Global Feedback" -Path (Join-Path $root ".ai\feedback\index.json") -Property "entries" -Count $RecentCount
    Write-RecentJsonEntries -Title "Decisions" -Path (Join-Path $root ".ai\decisions\index.json") -Property "decisions" -Count $RecentCount
    Write-RecentMarkdown -Title "Recent Root Attempts" -Path (Join-Path $root ".ai\attempts") -Count $RecentCount
    Write-RecentJsonEntries -Title "Global Handoffs" -Path (Join-Path $root ".ai\handoffs\index.json") -Property "handoffs" -Count $RecentCount

    if (-not [string]::IsNullOrWhiteSpace($projectSlug)) {
        $projectRoot = Join-Path (Join-Path $root "projects") $projectSlug
        $projectIndex = Read-JsonIfExists -Path (Join-Path $projectRoot ".ai\index.json")

        Write-Output "## Project Summary"
        $summaryPath = Join-Path $projectRoot ".ai\summary.md"
        if (Test-Path -LiteralPath $summaryPath) {
            Get-Content -LiteralPath $summaryPath -TotalCount 40
        }
        elseif ($projectIndex) {
            Write-Output "- Title: $($projectIndex.title)"
            Write-Output "- Source: $($projectIndex.source_path)"
            Write-Output "- Kind: $($projectIndex.kind)"
        }
        else {
            Write-Output "Missing project index for $projectSlug."
        }
        Write-Output ""

        Write-Output "## Unity Context"
        $unityIndex = Read-JsonIfExists -Path (Join-Path $projectRoot ".ai\engine\unity\index.json")
        if ($unityIndex) {
            Write-Output "- Unity: $($unityIndex.unity_version)"
            Write-Output "- Scenes: $($unityIndex.counts.scenes), build scenes: $($unityIndex.counts.build_scenes)"
            Write-Output "- Prefabs: $($unityIndex.counts.prefabs)"
            Write-Output "- ScriptableObject types: $($unityIndex.counts.scriptable_object_types)"
            Write-Output "- Packages: $($unityIndex.counts.packages)"
            if ($unityIndex.counts.PSObject.Properties.Name -contains "package_lock_entries") {
                Write-Output "- Package lock entries: $($unityIndex.counts.package_lock_entries)"
            }
        }
        else {
            Write-Output "No Unity context found."
        }
        Write-Output ""

        Write-RecentJsonEntries -Title "Project Feedback" -Path (Join-Path $projectRoot ".ai\feedback\index.json") -Property "entries" -Count $RecentCount
        Write-RecentMarkdown -Title "Project Attempts" -Path (Join-Path $projectRoot ".ai\attempts") -Count $RecentCount

        Write-Output "## Recent Project Changes"
        $changesPath = Join-Path $projectRoot ".ai\changes"
        $changes = @(Get-ChildItem -LiteralPath $changesPath -Filter "*.json" -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First $RecentCount)
        if ($changes.Count -eq 0) {
            Write-Output "None."
        }
        else {
            foreach ($change in $changes) {
                $changeJson = Get-Content -Raw -LiteralPath $change.FullName | ConvertFrom-Json
                Write-Output "- $($changeJson.created_at): $($changeJson.summary)"
            }
        }
        Write-Output ""

        Write-RecentJsonEntries -Title "Project Handoffs" -Path (Join-Path $projectRoot ".ai\handoffs\index.json") -Property "handoffs" -Count $RecentCount
    }

    return
}

$files = @(
    "AGENTS.md",
    ".ai/index.json",
    ".ai/projects/index.json",
    ".ai/assets/index.json",
    ".ai/rules/index.json",
    ".ai/workflows/index.json",
    ".ai/recommendations/index.json",
    ".ai/feedback/index.json",
    ".ai/decisions/index.json",
    ".ai/summaries/workspace-summary.md",
    "rules/README.md",
    "rules/live-project-code-rules.md",
    "cheatsheets/workflow-codes.md",
    "cheatsheets/recommendations.md",
    "README.md",
    "docs/workflow.md",
    "docs/ideas.md"
)

if (-not [string]::IsNullOrWhiteSpace($Slug)) {
    $projectSlug = ConvertTo-Slug -Value $Slug

    $files += @(
        "projects/$projectSlug/README.md",
        "projects/$projectSlug/map/overview.md",
        "projects/$projectSlug/map/source.md",
        "projects/$projectSlug/map/workflow.md",
        "projects/$projectSlug/map/assets.md",
        "projects/$projectSlug/perf-budget.md",
        "projects/$projectSlug/rules/project-rules.md",
        "projects/$projectSlug/.ai/summary.md",
        "projects/$projectSlug/.ai/index.json",
        "projects/$projectSlug/.ai/feedback/index.json",
        "projects/$projectSlug/.ai/assets/index.json",
        "projects/$projectSlug/.ai/engine/unity/index.json",
        "projects/$projectSlug/.ai/engine/unity/settings.json",
        "projects/$projectSlug/.ai/engine/unity/scenes.json",
        "projects/$projectSlug/.ai/engine/unity/hierarchy-sources.json"
    )
}

Write-Output "# Codex Workbench Context Snapshot"
Write-Output ""
Write-Output "Generated: $(Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")"
Write-Output "Root: $root"
if (-not [string]::IsNullOrWhiteSpace($Slug)) {
    Write-Output "Project: $projectSlug"
}
Write-Output ""

foreach ($relativePath in $files) {
    $path = Join-Path $root $relativePath

    if (-not (Test-Path -LiteralPath $path)) {
        continue
    }

    Write-Output "## $relativePath"
    Get-Content -LiteralPath $path -TotalCount $MaxLinesPerFile
    Write-Output ""
}

Write-Output "## First-Level Tree"
Get-ChildItem -Force -LiteralPath $root |
    Where-Object { $_.Name -notin @(".git", "node_modules", "dist", "build", ".venv", "venv") } |
    Sort-Object Name |
    ForEach-Object {
        if ($_.PSIsContainer) {
            Write-Output "dir  $($_.Name)"
        }
        else {
            Write-Output "file $($_.Name)"
        }
    }
