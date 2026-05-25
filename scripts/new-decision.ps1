param(
    [Parameter(Mandatory = $true)]
    [string]$Title,

    [Parameter(Mandatory = $true)]
    [string]$Decision,

    [string]$Alternatives = "",

    [string]$Why = "",

    [string]$Scope = "workbench",

    [string[]]$Linked = @(),

    [string]$Status = "accepted",

    [string]$Id = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot '_lib\Eol.ps1')

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$decisionsRoot = Join-Path $root ".ai\decisions"
$indexPath = Join-Path $decisionsRoot "index.json"

function ConvertTo-Slug {
    param([string]$Value)

    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")

    if ([string]::IsNullOrWhiteSpace($slug)) {
        return "decision"
    }

    return $slug
}

New-Item -ItemType Directory -Force -Path $decisionsRoot | Out-Null

if (-not (Test-Path -LiteralPath $indexPath)) {
    [pscustomobject]@{
        schema_version = 1
        last_updated = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
        purpose = "Compact registry of architecture and workflow decisions made for the workbench."
        decisions = @()
    } | ConvertTo-Json -Depth 10 | ForEach-Object { Write-Utf8Lf -Path $indexPath -Content $_ }
}

if ([string]::IsNullOrWhiteSpace($Id)) {
    $Id = ConvertTo-Slug -Value $Title
}
else {
    $Id = ConvertTo-Slug -Value $Id
}

$date = Get-Date -Format "yyyy-MM-dd"
$now = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
$fileName = "$date-$Id.md"
$decisionPath = Join-Path $decisionsRoot $fileName
$counter = 2

while (Test-Path -LiteralPath $decisionPath) {
    $fileName = "$date-$Id-$counter.md"
    $decisionPath = Join-Path $decisionsRoot $fileName
    $counter++
}

$linkedText = if ($Linked.Count -eq 0) { "None." } else { ($Linked | ForEach-Object { "- $_" }) -join "`r`n" }

$content = @"
---
id: $($fileName.Replace(".md", ""))
created_at: $now
status: $Status
---

# Decision: $Title

## Decision Made

$Decision

## Alternatives Considered

$Alternatives

## Why This Won

$Why

## Scope

$Scope

## Linked Tasks Or Sessions

$linkedText
"@

Write-Utf8Lf -Path $decisionPath -Content $content

$index = Get-Content -Raw -LiteralPath $indexPath | ConvertFrom-Json
$decisions = @($index.decisions)
$decisions += [pscustomobject]@{
    id = $fileName.Replace(".md", "")
    title = $Title
    status = $Status
    scope = $Scope
    path = ".ai/decisions/$fileName"
    created_at = $now
    summary = $Decision
}
$index.decisions = @($decisions | Sort-Object created_at -Descending)
$index.last_updated = $now
Write-Utf8Lf -Path $indexPath -Content ($index | ConvertTo-Json -Depth 10)

& (Join-Path $PSScriptRoot "update-ai-index.ps1") | Out-Null

Write-Output "Created decision: .ai/decisions/$fileName"
