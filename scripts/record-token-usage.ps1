param(
    [ValidateSet("workspace", "project")]
    [string]$Scope = "workspace",

    [string]$Slug = "",

    [switch]$Enable,

    [switch]$Disable,

    [switch]$Force,

    [string]$Title = "",

    [string]$Summary = "",

    [ValidateSet("exact", "estimated", "mixed")]
    [string]$Measurement = "estimated",

    [long]$InputTokens = 0,

    [long]$OutputTokens = 0,

    [long]$ToolOutputTokens = 0,

    [long]$CachedInputTokens = 0,

    [string[]]$Culprit = @(),

    [string[]]$Mitigation = @(),

    [string]$Notes = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot '_lib\Eol.ps1')

$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function ConvertTo-Slug {
    param([string]$Value)

    $slugValue = $Value.ToLowerInvariant() -replace "[^a-z0-9]+", "-"
    $slugValue = $slugValue.Trim("-")

    if ([string]::IsNullOrWhiteSpace($slugValue)) {
        throw "Project scope requires -Slug."
    }

    return $slugValue
}

function Read-JsonOrDefault {
    param(
        [string]$Path,
        [object]$DefaultValue
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        return $DefaultValue
    }

    try {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    }
    catch {
        throw "Invalid JSON in $Path`: $($_.Exception.Message)"
    }
}

function Normalize-StringList {
    param([string[]]$Values)

    $items = @()
    foreach ($value in @($Values)) {
        if ([string]::IsNullOrWhiteSpace($value)) {
            continue
        }

        foreach ($part in ($value -split ",")) {
            $trimmed = $part.Trim()
            if (-not [string]::IsNullOrWhiteSpace($trimmed)) {
                $items += $trimmed
            }
        }
    }

    return @($items)
}

function Get-TokenUsagePaths {
    param(
        [string]$RequestedScope,
        [string]$RequestedSlug
    )

    if ($RequestedScope -eq "workspace") {
        $usageRoot = Join-Path $root ".ai\token-usage"
        return [pscustomobject]@{
            Root = $usageRoot
            Index = Join-Path $usageRoot "index.json"
            Ledger = Join-Path $usageRoot "ledger.jsonl"
            Summary = Join-Path $usageRoot "summary.json"
            RelativeLedger = ".ai/token-usage/ledger.jsonl"
            RelativeSummary = ".ai/token-usage/summary.json"
        }
    }

    $normalizedSlug = ConvertTo-Slug -Value $RequestedSlug
    $projectRoot = Join-Path (Join-Path $root "projects") $normalizedSlug
    if (-not (Test-Path -LiteralPath $projectRoot)) {
        throw "Project dossier not found: projects/$normalizedSlug"
    }

    $usageRoot = Join-Path $projectRoot ".ai\token-usage"
    return [pscustomobject]@{
        Root = $usageRoot
        Index = Join-Path $usageRoot "index.json"
        Ledger = Join-Path $usageRoot "ledger.jsonl"
        Summary = Join-Path $usageRoot "summary.json"
        RelativeLedger = "projects/$normalizedSlug/.ai/token-usage/ledger.jsonl"
        RelativeSummary = "projects/$normalizedSlug/.ai/token-usage/summary.json"
    }
}

function New-DefaultIndex {
    param(
        [string]$RequestedScope,
        [string]$RequestedSlug,
        [string]$RelativeLedger,
        [string]$RelativeSummary
    )

    $defaultIndex = [pscustomobject]@{
        schema_version = 1
        enabled = $false
        scope = $RequestedScope
        last_updated = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
        ledger = $RelativeLedger
        summary = $RelativeSummary
        tracking_policy = [pscustomobject]@{
            default = "off"
            record_full_transcripts = $false
            record_tool_outputs = $false
            exact_counts_only_when_reported_by_runtime = $true
            estimated_counts_allowed = $true
            notes = @(
                "This workbench cannot read hidden platform limit accounting unless the runtime exposes token usage.",
                "Keep records compact and do not store raw transcripts or tool output."
            )
        }
        totals = [pscustomobject]@{
            records = 0
            exact_records = 0
            estimated_records = 0
            input_tokens = 0
            output_tokens = 0
            tool_output_tokens = 0
            total_tokens = 0
        }
        top_culprits = @()
    }

    if ($RequestedScope -eq "project") {
        $defaultIndex | Add-Member -NotePropertyName "slug" -NotePropertyValue (ConvertTo-Slug -Value $RequestedSlug)
    }

    return $defaultIndex
}

$paths = Get-TokenUsagePaths -RequestedScope $Scope -RequestedSlug $Slug
New-Item -ItemType Directory -Force -Path $paths.Root | Out-Null

$index = Read-JsonOrDefault -Path $paths.Index -DefaultValue (New-DefaultIndex -RequestedScope $Scope -RequestedSlug $Slug -RelativeLedger $paths.RelativeLedger -RelativeSummary $paths.RelativeSummary)

if ($Enable -and $Disable) {
    throw "Use only one of -Enable or -Disable."
}

if ($Enable) {
    $index.enabled = $true
    $index.last_updated = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
    Write-Utf8Lf -Path $paths.Index -Content ($index | ConvertTo-Json -Depth 10)
    if (-not (Test-Path -LiteralPath $paths.Ledger)) {
        New-Item -ItemType File -Path $paths.Ledger | Out-Null
    }
    Write-Output "Token usage tracking enabled for $Scope."
    return
}

if ($Disable) {
    $index.enabled = $false
    $index.last_updated = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
    Write-Utf8Lf -Path $paths.Index -Content ($index | ConvertTo-Json -Depth 10)
    Write-Output "Token usage tracking disabled for $Scope."
    return
}

if (-not $index.enabled -and -not $Force) {
    Write-Output "Token usage tracking is disabled for $Scope. Use -Enable first, or pass -Force for a one-off record."
    return
}

if ([string]::IsNullOrWhiteSpace($Title)) {
    throw "Recording token usage requires -Title."
}

foreach ($count in @($InputTokens, $OutputTokens, $ToolOutputTokens, $CachedInputTokens)) {
    if ($count -lt 0) {
        throw "Token counts must not be negative."
    }
}

$normalizedCulprits = Normalize-StringList -Values $Culprit
$normalizedMitigations = Normalize-StringList -Values $Mitigation
$totalTokens = $InputTokens + $OutputTokens + $ToolOutputTokens

$record = [pscustomobject]@{
    schema_version = 1
    id = (Get-Date -Format "yyyy-MM-dd-HHmmss")
    created_at = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
    scope = $Scope
    slug = if ($Scope -eq "project") { ConvertTo-Slug -Value $Slug } else { $null }
    title = $Title.Trim()
    summary = $Summary.Trim()
    measurement = $Measurement
    counts = [pscustomobject]@{
        input_tokens = $InputTokens
        output_tokens = $OutputTokens
        tool_output_tokens = $ToolOutputTokens
        cached_input_tokens = $CachedInputTokens
        total_tokens = $totalTokens
    }
    culprits = @($normalizedCulprits)
    mitigations = @($normalizedMitigations)
    notes = $Notes.Trim()
}

Add-Utf8Lf -Path $paths.Ledger -Content ($record | ConvertTo-Json -Depth 10 -Compress)

& (Join-Path $PSScriptRoot "summarize-token-usage.ps1") -Scope $Scope -Slug $Slug | Out-Null

Write-Output "Recorded token usage: $($record.id)"
