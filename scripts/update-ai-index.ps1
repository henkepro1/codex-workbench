param(
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$aiRoot = Join-Path $root ".ai"
$indexPath = Join-Path $aiRoot "index.json"
$assetIndexPath = Join-Path $aiRoot "assets\index.json"
$projectsIndexPath = Join-Path $aiRoot "projects\index.json"

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

function Ensure-Property {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Value
    )

    if (-not ($Object.PSObject.Properties.Name -contains $Name)) {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

$index = Read-JsonFile -Path $indexPath
$assets = Read-JsonFile -Path $assetIndexPath
$projectsIndex = Read-JsonFile -Path $projectsIndexPath

$requiredSections = @(
    "workspace",
    "projects",
    "assets",
    "active_tasks",
    "recent_attempts",
    "important_docs",
    "last_updated"
)

foreach ($section in $requiredSections) {
    if (-not ($index.PSObject.Properties.Name -contains $section)) {
        throw ".ai/index.json is missing required section: $section"
    }
}

if (-not ($assets.PSObject.Properties.Name -contains "assets")) {
    throw ".ai/assets/index.json is missing required section: assets"
}

Ensure-Property -Object $index -Name "file_counts" -Value ([pscustomobject]@{})
Ensure-Property -Object $index -Name "paths" -Value ([pscustomobject]@{})

if (($index.projects -is [array]) -or ($null -eq $index.projects)) {
    $index.projects = [pscustomobject]@{
        registry = ".ai/projects/index.json"
        root = "projects"
        count = 0
    }
}

Ensure-Property -Object $index.projects -Name "registry" -Value ".ai/projects/index.json"
Ensure-Property -Object $index.projects -Name "root" -Value "projects"
Ensure-Property -Object $index.projects -Name "count" -Value 0
Ensure-Property -Object $index.assets -Name "counts" -Value ([pscustomobject]@{})
Ensure-Property -Object $index.paths -Name "projects_registry" -Value ".ai/projects/index.json"
Ensure-Property -Object $index.paths -Name "project_dossiers" -Value "projects"

if (-not ($index.workspace.PSObject.Properties.Name -contains "default_external_source_roots")) {
    $index.workspace | Add-Member -NotePropertyName "default_external_source_roots" -NotePropertyValue @("D:\GameProjects")
}

$importantDocs = @($index.important_docs)
foreach ($docPath in @(".env.example", "rules/README.md", "rules/live-project-code-rules.md", ".ai/rules/index.json", ".ai/workflows/index.json", ".ai/recommendations/index.json", ".ai/retrieval/index.json", ".ai/models/index.json", ".ai/feedback/index.json", ".ai/decisions/index.json", ".ai/integrations/unity-mcp.json", "cheatsheets/README.md", "cheatsheets/skills.md", "cheatsheets/workflows.md", "cheatsheets/workflow-codes.md", "cheatsheets/recommendations.md", "cheatsheets/retrieval-strategies.md", "cheatsheets/model-providers.md", "cheatsheets/reviewer.md", "cheatsheets/impact-guide.md", "docs/ideas.md")) {
    if ($importantDocs -notcontains $docPath) {
        $importantDocs += $docPath
    }
}
$index.important_docs = @($importantDocs)

Ensure-Property -Object $index.paths -Name "rules_index" -Value ".ai/rules/index.json"
Ensure-Property -Object $index.paths -Name "workflows_index" -Value ".ai/workflows/index.json"
Ensure-Property -Object $index.paths -Name "recommendations_index" -Value ".ai/recommendations/index.json"
Ensure-Property -Object $index.paths -Name "retrieval_index" -Value ".ai/retrieval/index.json"
Ensure-Property -Object $index.paths -Name "models_index" -Value ".ai/models/index.json"
Ensure-Property -Object $index.paths -Name "feedback_index" -Value ".ai/feedback/index.json"
Ensure-Property -Object $index.paths -Name "decisions_index" -Value ".ai/decisions/index.json"
Ensure-Property -Object $index.paths -Name "integrations_index" -Value ".ai/integrations/index.json"
Ensure-Property -Object $index.paths -Name "handoffs_index" -Value ".ai/handoffs/index.json"
Ensure-Property -Object $index.paths -Name "live_project_rules" -Value "rules/live-project-code-rules.md"

$assetCount = @($assets.assets).Count
$generationCount = @(Get-ChildItem -LiteralPath (Join-Path $aiRoot "generations") -Filter "*.json" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "_template.json" }).Count
$promptCount = @(Get-ChildItem -LiteralPath (Join-Path $aiRoot "prompts") -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "_template.md" }).Count
$attemptCount = @(Get-ChildItem -LiteralPath (Join-Path $aiRoot "attempts") -Filter "*.md" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "_template.md" }).Count
$taskCount = @(Get-ChildItem -LiteralPath (Join-Path $aiRoot "tasks") -Filter "*.md" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "_template.md" }).Count
$summaryCount = @(Get-ChildItem -LiteralPath (Join-Path $aiRoot "summaries") -Filter "*.md" -File -ErrorAction SilentlyContinue).Count
$feedbackCount = @(Get-ChildItem -LiteralPath (Join-Path $aiRoot "feedback") -Filter "*.md" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "_template.md" }).Count
$decisionCount = @(Get-ChildItem -LiteralPath (Join-Path $aiRoot "decisions") -Filter "*.md" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne "_template.md" }).Count
$handoffCount = @(Get-ChildItem -LiteralPath (Join-Path $aiRoot "handoffs") -Filter "*.md" -File -ErrorAction SilentlyContinue).Count
$recommendationIndexPath = Join-Path $aiRoot "recommendations\index.json"
$recommendationCount = 0
if (Test-Path -LiteralPath $recommendationIndexPath) {
    $recommendationIndex = Read-JsonFile -Path $recommendationIndexPath
    if ($recommendationIndex.PSObject.Properties.Name -contains "categories") {
        $recommendationCount = @($recommendationIndex.categories).Count
    }
}
$retrievalIndexPath = Join-Path $aiRoot "retrieval\index.json"
$retrievalStrategyCount = 0
if (Test-Path -LiteralPath $retrievalIndexPath) {
    $retrievalIndex = Read-JsonFile -Path $retrievalIndexPath
    if ($retrievalIndex.PSObject.Properties.Name -contains "strategies") {
        $retrievalStrategyCount = @($retrievalIndex.strategies).Count
    }
}
$humanAssetCount = @(Get-ChildItem -LiteralPath (Join-Path $root "assets") -File -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne ".gitkeep" }).Count
$projectCount = @($projectsIndex.projects).Count

foreach ($countName in @("assets", "generation_records", "prompt_records", "attempt_notes", "task_notes", "summaries", "feedback_notes", "decisions", "handoffs", "recommendations", "retrieval_strategies", "project_dossiers")) {
    if (-not ($index.file_counts.PSObject.Properties.Name -contains $countName)) {
        $index.file_counts | Add-Member -NotePropertyName $countName -NotePropertyValue 0
    }
}

$index.assets.counts.registered = $assetCount
$index.projects.count = $projectCount
$index.file_counts.assets = $humanAssetCount
$index.file_counts.generation_records = $generationCount
$index.file_counts.prompt_records = $promptCount
$index.file_counts.attempt_notes = $attemptCount
$index.file_counts.task_notes = $taskCount
$index.file_counts.summaries = $summaryCount
$index.file_counts.feedback_notes = $feedbackCount
$index.file_counts.decisions = $decisionCount
$index.file_counts.handoffs = $handoffCount
$index.file_counts.recommendations = $recommendationCount
$index.file_counts.retrieval_strategies = $retrievalStrategyCount
$index.file_counts.project_dossiers = $projectCount

if ($CheckOnly) {
    Write-Output "OK: .ai/index.json, .ai/assets/index.json, and .ai/projects/index.json are valid."
    Write-Output "Registered assets: $assetCount"
    Write-Output "Human asset files: $humanAssetCount"
    Write-Output "Project dossiers: $projectCount"
    Write-Output "Generation records: $generationCount"
    Write-Output "Attempt notes: $attemptCount"
    return
}

$now = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
$index.last_updated = $now
$assets.last_updated = $now
$projectsIndex.last_updated = $now

$index | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $indexPath -Encoding UTF8
$assets | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $assetIndexPath -Encoding UTF8
$projectsIndex | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $projectsIndexPath -Encoding UTF8

Write-Output "Updated .ai/index.json"
Write-Output "Updated .ai/assets/index.json"
Write-Output "Updated .ai/projects/index.json"
