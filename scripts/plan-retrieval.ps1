param(
    [Parameter(Mandatory = $true)]
    [string]$Slug,

    [Parameter(Mandatory = $true)]
    [string]$Task,

    [ValidateSet("", "grep_and_index", "rag_semantic", "hybrid")]
    [string]$ForceStrategy = ""
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

function Get-StrategyStatus {
    param(
        [object]$RetrievalIndex,
        [string]$Strategy
    )

    foreach ($strategyEntry in @($RetrievalIndex.strategies)) {
        if ($strategyEntry.id -eq $Strategy) {
            return $strategyEntry.status
        }
    }

    return "unknown"
}

$Slug = ConvertTo-Slug -Value $Slug
$projectRoot = Join-Path (Join-Path $root "projects") $Slug
$projectIndex = Read-JsonIfExists -Path (Join-Path $projectRoot ".ai\index.json")
if ($null -eq $projectIndex) {
    throw "Project not found: $Slug"
}

$retrievalIndex = Read-JsonIfExists -Path (Join-Path $root ".ai\retrieval\index.json")
if ($null -eq $retrievalIndex) {
    throw "Missing retrieval policy: .ai/retrieval/index.json"
}

$scope = Read-JsonIfExists -Path (Join-Path $projectRoot ".ai\scope.json")
$taskLower = $Task.ToLowerInvariant()

$hasFilePath = $Task -match "([A-Za-z]:\\|/|\\|\.(cs|json|md|unity|prefab|asset|shader|txt)\b)"
$hasExactSymbol = $Task -match "\b[A-Z][A-Za-z0-9_]{3,}\b"
$hasCompileSignal = $taskLower -match "compile|compiler|stack trace|exception|error cs\d+|nullreference|missing reference"
$hasHistorySignal = $taskLower -match "have we|did we|tried|try before|previous|before|attempt|decision|handoff|remember|discussed|what went wrong"
$hasBroadSignal = $taskLower -match "refactor|redesign|rework|architecture|architectural|multi-system|multiple systems|cross-cutting|large|hard task|unclear|investigate|understand|overview"
$hasFuzzySignal = $taskLower -match "anything about|what about|concept|idea|notes about|find notes|history"
$hasSourceSignal = $taskLower -match "code|script|class|method|function|component|system|source"
$wordCount = @($Task -split "\s+" | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count

$recommended = "grep_and_index"
$confidence = "high"
$gate = $false
$reason = "Default tie-breaker: grep/index is lowest cost and best for source-code retrieval."
$expectedScan = "Load project index, then use focused rg/file reads."
$cost = "low"
$sideEffects = "Read-only."
$fallback = "none"

if (-not [string]::IsNullOrWhiteSpace($ForceStrategy)) {
    $recommended = $ForceStrategy
    $confidence = "high"
    $gate = $true
    $reason = "Forced by ForceStrategy."
}
elseif ($hasFilePath -or $hasCompileSignal) {
    $recommended = "grep_and_index"
    $confidence = "high"
    $gate = $false
    $reason = "Task names a file/path or compile/runtime error signal."
}
elseif ($wordCount -le 5 -and -not $hasBroadSignal -and -not $hasHistorySignal -and -not $hasFuzzySignal) {
    $recommended = "grep_and_index"
    $confidence = "high"
    $gate = $false
    $reason = "Task appears trivial or narrow."
}
elseif ($hasHistorySignal -and -not $hasSourceSignal) {
    $recommended = "rag_semantic"
    $confidence = "medium"
    $gate = $true
    $reason = "Task asks about prior attempts, decisions, handoffs, or remembered context."
}
elseif ($hasBroadSignal) {
    $recommended = "hybrid"
    $confidence = "medium"
    $gate = $true
    $reason = "Task appears broad, architectural, or cross-cutting."
}
elseif ($hasFuzzySignal) {
    $recommended = "rag_semantic"
    $confidence = "medium"
    $gate = $true
    $reason = "Task is a fuzzy natural-language lookup over notes or concepts."
}
elseif ($hasExactSymbol) {
    $recommended = "grep_and_index"
    $confidence = "medium"
    $gate = $false
    $reason = "Task includes an exact-looking identifier; grep/index should find source entry points."
}

$strategyStatus = Get-StrategyStatus -RetrievalIndex $retrievalIndex -Strategy $recommended
$ragAvailable = (Get-StrategyStatus -RetrievalIndex $retrievalIndex -Strategy "rag_semantic") -eq "available"
$effectiveStrategy = $recommended

if ($recommended -eq "rag_semantic") {
    $cost = "medium"
    $expectedScan = "Search AI/workbench memory corpus: attempts, decisions, feedback, handoffs, sessions, changes, summaries, and maps."
    if (-not $ragAvailable) {
        $effectiveStrategy = "grep_and_index"
        $fallback = "RAG is not configured; use rg over .ai and project maps unless @wb:rag-setup is invoked."
        $sideEffects = "Read-only fallback. No vector index exists yet."
    }
    else {
        $sideEffects = "Read-only semantic lookup over configured notes corpus."
    }
}
elseif ($recommended -eq "hybrid") {
    $cost = "medium-high"
    $expectedScan = "Start with project scope/index/maps, use RAG for memory only if configured, then rg for source details."
    if (-not $ragAvailable) {
        $fallback = "Hybrid degrades to grep/index plus structured .ai context because RAG is not configured."
    }
    $sideEffects = "Read-only planning/retrieval. Later edit workflows may have separate side effects."
}

$scopeSummary = "scope unavailable"
if ($scope) {
    $scopeSummary = "$($scope.authored_source.size_class), $($scope.authored_source.csharp_loc) C# LOC, $($scope.authored_source.file_count) authored files, $($scope.notes_corpus.total_records) notes records"
}

$machine = [pscustomobject]@{
    project = $Slug
    task = $Task
    recommended_strategy = $recommended
    effective_strategy = $effectiveStrategy
    confidence = $confidence
    gate_required = $gate
    reason = $reason
    expected_scan = $expectedScan
    cost = $cost
    side_effects = $sideEffects
    rag_available = $ragAvailable
    strategy_status = $strategyStatus
    fallback = $fallback
    scope = $scopeSummary
}

Write-Output "# Retrieval Plan"
Write-Output ""
Write-Output "- Project: $Slug"
Write-Output "- Task: $Task"
Write-Output "- Recommended strategy: $recommended"
Write-Output "- Effective strategy: $effectiveStrategy"
Write-Output "- Confidence: $confidence"
Write-Output "- Gate required: $gate"
Write-Output "- Reason: $reason"
Write-Output "- Expected scan: $expectedScan"
Write-Output "- Cost: $cost"
Write-Output "- Side effects: $sideEffects"
Write-Output "- RAG available: $ragAvailable"
if ($fallback -ne "none") {
    Write-Output "- Fallback: $fallback"
}
Write-Output "- Scope: $scopeSummary"
Write-Output ""
Write-Output '```json'
$machine | ConvertTo-Json -Depth 8
Write-Output '```'
