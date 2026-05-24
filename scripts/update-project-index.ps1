param(
    [Parameter(Mandatory = $true)]
    [string]$Slug,

    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function ConvertTo-Slug {
    param([string]$Value)

    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")

    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw "Invalid project slug."
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

function Count-Files {
    param(
        [string]$Path,
        [string]$Filter = "*",
        [string[]]$ExcludeNames = @()
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return 0
    }

    return @(Get-ChildItem -LiteralPath $Path -Filter $Filter -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin $ExcludeNames }).Count
}

$Slug = ConvertTo-Slug -Value $Slug
$projectRoot = Join-Path (Join-Path $root "projects") $Slug
$projectAi = Join-Path $projectRoot ".ai"
$projectIndexPath = Join-Path $projectAi "index.json"
$assetIndexPath = Join-Path $projectAi "assets\index.json"
$registryPath = Join-Path $root ".ai\projects\index.json"

$projectIndex = Read-JsonFile -Path $projectIndexPath
$assetIndex = Read-JsonFile -Path $assetIndexPath

if (-not ($projectIndex.PSObject.Properties.Name -contains "counts")) {
    $projectIndex | Add-Member -NotePropertyName "counts" -NotePropertyValue ([pscustomobject]@{})
}

if (-not ($projectIndex.human_map.PSObject.Properties.Name -contains "rules")) {
    $projectIndex.human_map | Add-Member -NotePropertyName "rules" -NotePropertyValue "projects/$Slug/rules/project-rules.md"
}

if (-not ($projectIndex.PSObject.Properties.Name -contains "rules")) {
    $projectIndex | Add-Member -NotePropertyName "rules" -NotePropertyValue ([pscustomobject]@{
        global_index = ".ai/rules/index.json"
        global_policy = "rules/live-project-code-rules.md"
        project_overlay = "projects/$Slug/rules/project-rules.md"
        source_rules = @()
        must_read_before_external_edits = $true
    })
}

foreach ($countName in @("assets", "sessions", "attempts", "generations", "prompts", "summaries", "changes", "engine_context_files", "feedback", "handoffs", "reviews", "token_usage_records")) {
    if (-not ($projectIndex.counts.PSObject.Properties.Name -contains $countName)) {
        $projectIndex.counts | Add-Member -NotePropertyName $countName -NotePropertyValue 0
    }
}

$projectIndex.counts.assets = @($assetIndex.assets).Count
$projectIndex.counts.sessions = @(Get-ChildItem -LiteralPath (Join-Path $projectAi "sessions") -Directory -ErrorAction SilentlyContinue).Count
$projectIndex.counts.attempts = Count-Files -Path (Join-Path $projectAi "attempts") -Filter "*.md" -ExcludeNames @("_template.md")
$projectIndex.counts.generations = Count-Files -Path (Join-Path $projectAi "generations") -Filter "*.json" -ExcludeNames @("_template.json")
$projectIndex.counts.prompts = Count-Files -Path (Join-Path $projectAi "prompts") -ExcludeNames @("_template.md")
$projectIndex.counts.summaries = Count-Files -Path (Join-Path $projectAi "summaries") -Filter "*.md" -ExcludeNames @("README.md")
$projectIndex.counts.changes = Count-Files -Path (Join-Path $projectAi "changes") -Filter "*.json"
$projectIndex.counts.engine_context_files = Count-Files -Path (Join-Path $projectAi "engine\unity") -Filter "*.json"
$projectIndex.counts.feedback = Count-Files -Path (Join-Path $projectAi "feedback") -Filter "*.md" -ExcludeNames @("_template.md")
$projectIndex.counts.handoffs = Count-Files -Path (Join-Path $projectAi "handoffs") -Filter "*.md"
$projectIndex.counts.reviews = Count-Files -Path (Join-Path $projectAi "reviews") -Filter "*.md"
$projectTokenUsageLedgerPath = Join-Path $projectAi "token-usage\ledger.jsonl"
$projectIndex.counts.token_usage_records = 0
if (Test-Path -LiteralPath $projectTokenUsageLedgerPath) {
    $projectIndex.counts.token_usage_records = @(Get-Content -LiteralPath $projectTokenUsageLedgerPath -ErrorAction SilentlyContinue | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count
}

if ((Test-Path -LiteralPath (Join-Path $projectAi "engine\unity\index.json")) -and -not ($projectIndex.ai_paths.PSObject.Properties.Name -contains "unity_context")) {
    $projectIndex.ai_paths | Add-Member -NotePropertyName "unity_context" -NotePropertyValue "projects/$Slug/.ai/engine/unity/index.json"
}

if (-not ($projectIndex.ai_paths.PSObject.Properties.Name -contains "feedback")) {
    $projectIndex.ai_paths | Add-Member -NotePropertyName "feedback" -NotePropertyValue "projects/$Slug/.ai/feedback/index.json"
}

if (-not ($projectIndex.ai_paths.PSObject.Properties.Name -contains "handoffs")) {
    $projectIndex.ai_paths | Add-Member -NotePropertyName "handoffs" -NotePropertyValue "projects/$Slug/.ai/handoffs/index.json"
}

if (-not ($projectIndex.ai_paths.PSObject.Properties.Name -contains "reviews")) {
    $projectIndex.ai_paths | Add-Member -NotePropertyName "reviews" -NotePropertyValue "projects/$Slug/.ai/reviews/index.json"
}

if (-not ($projectIndex.ai_paths.PSObject.Properties.Name -contains "token_usage")) {
    $projectIndex.ai_paths | Add-Member -NotePropertyName "token_usage" -NotePropertyValue "projects/$Slug/.ai/token-usage/index.json"
}

if (-not ($projectIndex.ai_paths.PSObject.Properties.Name -contains "summary")) {
    $projectIndex.ai_paths | Add-Member -NotePropertyName "summary" -NotePropertyValue "projects/$Slug/.ai/summary.md"
}

if (-not ($projectIndex.ai_paths.PSObject.Properties.Name -contains "scope")) {
    $projectIndex.ai_paths | Add-Member -NotePropertyName "scope" -NotePropertyValue "projects/$Slug/.ai/scope.json"
}

if ($CheckOnly) {
    Write-Output "OK: project index is valid for $Slug"
    Write-Output "Assets: $($projectIndex.counts.assets)"
    Write-Output "Sessions: $($projectIndex.counts.sessions)"
    Write-Output "Attempts: $($projectIndex.counts.attempts)"
    return
}

$now = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
$projectIndex.last_updated = $now
$assetIndex.last_updated = $now

$projectIndex | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $projectIndexPath -Encoding UTF8
$assetIndex | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $assetIndexPath -Encoding UTF8

& (Join-Path $PSScriptRoot "update-project-scope.ps1") -Slug $Slug | Out-Null

if (Test-Path -LiteralPath $registryPath) {
    $registry = Read-JsonFile -Path $registryPath
    $projects = @($registry.projects)
    $updatedProjects = @()
    $found = $false

    foreach ($project in $projects) {
        if ($project.slug -eq $Slug) {
            $found = $true
            $updatedProjects += [pscustomobject]@{
                slug = $Slug
                title = $projectIndex.title
                status = $projectIndex.status
                kind = if ($projectIndex.PSObject.Properties.Name -contains "kind") { $projectIndex.kind } else { "general" }
                source_path = $projectIndex.source_path
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

    if ($found) {
        $registry.projects = @($updatedProjects | Sort-Object slug)
        $registry.last_updated = $now
        $registry | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $registryPath -Encoding UTF8
    }
}

& (Join-Path $PSScriptRoot "update-ai-index.ps1") | Out-Null

Write-Output "Updated project index: projects/$Slug/.ai/index.json"
