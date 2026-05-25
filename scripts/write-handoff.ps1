param(
    [Parameter(Mandatory = $true)]
    [string]$Summary,

    [string]$Slug = "",

    [string]$Title = "Handoff",

    [string]$Blocked = "None.",

    [string]$Next = "",

    [string[]]$ChangedPath = @()
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
        return "handoff"
    }

    return $slug
}

function Ensure-Handoff-Index {
    param(
        [string]$Path,
        [string]$Purpose,
        [string]$Project = ""
    )

    if (Test-Path -LiteralPath $Path) {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    }

    $index = [pscustomobject]@{
        schema_version = 1
        last_updated = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
        purpose = $Purpose
        handoffs = @()
    }

    if (-not [string]::IsNullOrWhiteSpace($Project)) {
        $index | Add-Member -NotePropertyName "project" -NotePropertyValue $Project
    }

    New-Item -ItemType Directory -Force -Path (Split-Path $Path) | Out-Null
    Write-Utf8Lf -Path $Path -Content ($index | ConvertTo-Json -Depth 10)

    return $index
}

if ([string]::IsNullOrWhiteSpace($Slug)) {
    $scope = "global"
    $handoffRoot = Join-Path $root ".ai\handoffs"
    $relativeRoot = ".ai/handoffs"
    $indexPath = Join-Path $handoffRoot "index.json"
    $index = Ensure-Handoff-Index -Path $indexPath -Purpose "Manual lightweight handoff notes."
}
else {
    $Slug = ConvertTo-Slug -Value $Slug
    $scope = "project"
    $projectRoot = Join-Path (Join-Path $root "projects") $Slug
    $projectIndexPath = Join-Path $projectRoot ".ai\index.json"

    if (-not (Test-Path -LiteralPath $projectIndexPath)) {
        throw "Project dossier not found: projects/$Slug"
    }

    $handoffRoot = Join-Path $projectRoot ".ai\handoffs"
    $relativeRoot = "projects/$Slug/.ai/handoffs"
    $indexPath = Join-Path $handoffRoot "index.json"
    $index = Ensure-Handoff-Index -Path $indexPath -Purpose "Manual lightweight project handoff notes." -Project $Slug
}

New-Item -ItemType Directory -Force -Path $handoffRoot | Out-Null

$now = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
$stamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
$id = ConvertTo-Slug -Value $Title
$fileName = "$stamp-$id.md"
$handoffPath = Join-Path $handoffRoot $fileName
$relativePath = "$relativeRoot/$fileName"

$changedText = if ($ChangedPath.Count -eq 0) { "None listed." } else { ($ChangedPath | ForEach-Object { "- $_" }) -join "`r`n" }

$content = @"
# $Title

Created: $now
Scope: $scope

## What Was Done

$Summary

## Blocked

$Blocked

## Start Here Next Time

$Next

## Changed Paths

$changedText
"@

Write-Utf8Lf -Path $handoffPath -Content $content

$handoffs = @($index.handoffs)
$handoffs += [pscustomobject]@{
    id = $fileName.Replace(".md", "")
    title = $Title
    scope = $scope
    path = $relativePath
    created_at = $now
    summary = $Summary
}
$index.handoffs = @($handoffs | Sort-Object created_at -Descending)
$index.last_updated = $now
Write-Utf8Lf -Path $indexPath -Content ($index | ConvertTo-Json -Depth 10)

if ($scope -eq "project") {
    & (Join-Path $PSScriptRoot "update-project-index.ps1") -Slug $Slug | Out-Null
}
else {
    & (Join-Path $PSScriptRoot "update-ai-index.ps1") | Out-Null
}

Write-Output "Created handoff: $relativePath"
