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

function Read-JsonIfExists {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Count-FilesRecursive {
    param(
        [string]$Path,
        [string]$Filter = "*",
        [string[]]$ExcludeNames = @()
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return 0
    }

    return @(Get-ChildItem -LiteralPath $Path -Filter $Filter -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notin $ExcludeNames }).Count
}

function Test-ExcludedPath {
    param([string]$Path)

    $excludedSegments = @(
        ".git",
        ".vs",
        ".idea",
        "Library",
        "Temp",
        "Logs",
        "Obj",
        "obj",
        "Bin",
        "bin",
        "Build",
        "Builds",
        "UserSettings",
        "MemoryCaptures",
        "Recordings",
        "node_modules",
        "dist",
        "build",
        "PackageCache"
    )

    foreach ($segment in $excludedSegments) {
        if ($Path -match "\\$([regex]::Escape($segment))(\\|$)") {
            return $true
        }
    }

    return $false
}

function Get-SizeClass {
    param([int]$Loc)

    if ($Loc -lt 10000) {
        return "small"
    }
    if ($Loc -lt 100000) {
        return "medium"
    }
    if ($Loc -lt 500000) {
        return "large"
    }
    return "huge"
}

$Slug = ConvertTo-Slug -Value $Slug
$projectRoot = Join-Path (Join-Path $root "projects") $Slug
$projectAi = Join-Path $projectRoot ".ai"
$projectIndexPath = Join-Path $projectAi "index.json"
$scopePath = Join-Path $projectAi "scope.json"

$projectIndex = Read-JsonIfExists -Path $projectIndexPath
if ($null -eq $projectIndex) {
    throw "Project index not found: projects/$Slug/.ai/index.json"
}

$sourcePath = $projectIndex.source_path
$sourceExists = -not [string]::IsNullOrWhiteSpace($sourcePath) -and (Test-Path -LiteralPath $sourcePath)

$authoredExtensions = @(
    ".cs",
    ".asmdef",
    ".asmref",
    ".shader",
    ".shadergraph",
    ".hlsl",
    ".cginc",
    ".compute",
    ".uxml",
    ".uss",
    ".unity",
    ".prefab",
    ".asset",
    ".mat",
    ".controller",
    ".anim",
    ".inputactions",
    ".json",
    ".yaml",
    ".yml",
    ".md",
    ".txt"
)

$authoredFiles = @()
if ($sourceExists) {
    $authoredFiles = @(Get-ChildItem -LiteralPath $sourcePath -File -Recurse -ErrorAction SilentlyContinue |
        Where-Object {
            -not (Test-ExcludedPath -Path $_.FullName) -and
            ($authoredExtensions -contains $_.Extension)
        })
}

$extensionCounts = @()
foreach ($group in ($authoredFiles | Group-Object Extension | Sort-Object Name)) {
    $extensionCounts += [pscustomobject]@{
        extension = if ([string]::IsNullOrWhiteSpace($group.Name)) { "[none]" } else { $group.Name }
        count = $group.Count
    }
}

$csharpFiles = @($authoredFiles | Where-Object { $_.Extension -eq ".cs" })
$csharpLoc = 0
foreach ($file in $csharpFiles) {
    try {
        $csharpLoc += @(Get-Content -LiteralPath $file.FullName -ErrorAction Stop).Count
    }
    catch {
        continue
    }
}

$unityIndex = Read-JsonIfExists -Path (Join-Path $projectAi "engine\unity\index.json")
$engineAssets = [pscustomobject]@{
    engine = if ($unityIndex) { "unity" } else { $projectIndex.kind }
    scenes = if ($unityIndex) { $unityIndex.counts.scenes } else { 0 }
    prefabs = if ($unityIndex) { $unityIndex.counts.prefabs } else { 0 }
    scriptable_objects = if ($unityIndex) { $unityIndex.counts.scriptable_object_types } else { 0 }
    shaders = if ($unityIndex) { $unityIndex.counts.shaders } else { 0 }
    packages = if ($unityIndex) { $unityIndex.counts.packages } else { 0 }
}

$notesCorpus = [pscustomobject]@{
    attempts = Count-FilesRecursive -Path (Join-Path $projectAi "attempts") -Filter "*.md" -ExcludeNames @("_template.md")
    decisions = Count-FilesRecursive -Path (Join-Path $root ".ai\decisions") -Filter "*.md" -ExcludeNames @("_template.md")
    feedback = Count-FilesRecursive -Path (Join-Path $projectAi "feedback") -Filter "*.md" -ExcludeNames @("_template.md")
    sessions = Count-FilesRecursive -Path (Join-Path $projectAi "sessions") -Filter "*.md"
    handoffs = Count-FilesRecursive -Path (Join-Path $projectAi "handoffs") -Filter "*.md"
    changes = Count-FilesRecursive -Path (Join-Path $projectAi "changes") -Filter "*.json"
    summaries = Count-FilesRecursive -Path (Join-Path $projectAi "summaries") -Filter "*.md" -ExcludeNames @("README.md")
    maps = Count-FilesRecursive -Path (Join-Path $projectRoot "map") -Filter "*.md"
}

$notesTotal = 0
foreach ($property in $notesCorpus.PSObject.Properties) {
    $notesTotal += [int]$property.Value
}

$scope = [pscustomobject]@{
    schema_version = 1
    last_updated = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
    project = $Slug
    source_path = $sourcePath
    source_exists = $sourceExists
    authored_source = [pscustomobject]@{
        file_count = @($authoredFiles).Count
        csharp_files = @($csharpFiles).Count
        csharp_loc = $csharpLoc
        size_class = Get-SizeClass -Loc $csharpLoc
        extension_counts = @($extensionCounts)
        excluded_dirs = @("Library", "Temp", "Logs", "obj", "bin", "Build", "Builds", "PackageCache", ".git", ".vs")
    }
    engine_assets = $engineAssets
    notes_corpus = [pscustomobject]@{
        total_records = $notesTotal
        counts = $notesCorpus
        rag_candidate = $notesTotal -ge 200
    }
    retrieval = [pscustomobject]@{
        default_strategy = "grep_and_index"
        source_code_strategy = "grep_and_index"
        memory_strategy = if ($notesTotal -ge 200) { "rag_semantic_candidate" } else { "grep_and_index_until_rag_setup" }
        rag_status = "setup_required"
    }
}

if ($CheckOnly) {
    Write-Output "Project: $Slug"
    Write-Output "Source exists: $sourceExists"
    Write-Output "Authored files: $($scope.authored_source.file_count)"
    Write-Output "C# LOC: $($scope.authored_source.csharp_loc)"
    Write-Output "Size class: $($scope.authored_source.size_class)"
    Write-Output "Notes records: $($scope.notes_corpus.total_records)"
    return
}

$scope | ConvertTo-Json -Depth 12 | Set-Content -LiteralPath $scopePath -Encoding UTF8

Write-Output "Updated project scope: projects/$Slug/.ai/scope.json"
