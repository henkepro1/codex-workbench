param(
    [Parameter(Mandatory = $true)]
    [string]$Title,

    [Parameter(Mandatory = $true)]
    [string]$Rule,

    [string]$Why = "",

    [string]$WhenToApply = "",

    [string]$AppliesTo = "workbench",

    [string]$Slug = "",

    [string]$Source = "user feedback",

    [string]$Id = ""
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
        return "feedback"
    }

    return $slug
}

function Read-Or-Create-Index {
    param(
        [string]$Path,
        [string]$Purpose,
        [string]$Project = ""
    )

    if (Test-Path -LiteralPath $Path) {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    }

    New-Item -ItemType Directory -Force -Path (Split-Path $Path) | Out-Null

    $index = [pscustomobject]@{
        schema_version = 1
        last_updated = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
        purpose = $Purpose
        entries = @()
    }

    if (-not [string]::IsNullOrWhiteSpace($Project)) {
        $index | Add-Member -NotePropertyName "project" -NotePropertyValue $Project
    }

    return $index
}

if ([string]::IsNullOrWhiteSpace($Id)) {
    $Id = ConvertTo-Slug -Value $Title
}
else {
    $Id = ConvertTo-Slug -Value $Id
}

$now = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
$stamp = Get-Date -Format "yyyy-MM-dd-HHmmss"

if ([string]::IsNullOrWhiteSpace($Slug)) {
    $scope = "global"
    $feedbackRoot = Join-Path $root ".ai\feedback"
    $relativeRoot = ".ai/feedback"
    $indexPath = Join-Path $feedbackRoot "index.json"
    $index = Read-Or-Create-Index -Path $indexPath -Purpose "Workbench-level persistent feedback memory."
}
else {
    $Slug = ConvertTo-Slug -Value $Slug
    $scope = "project"
    $projectRoot = Join-Path (Join-Path $root "projects") $Slug
    $projectIndexPath = Join-Path $projectRoot ".ai\index.json"

    if (-not (Test-Path -LiteralPath $projectIndexPath)) {
        throw "Project dossier not found: projects/$Slug"
    }

    $feedbackRoot = Join-Path $projectRoot ".ai\feedback"
    $relativeRoot = "projects/$Slug/.ai/feedback"
    $indexPath = Join-Path $feedbackRoot "index.json"
    $index = Read-Or-Create-Index -Path $indexPath -Purpose "Project-specific persistent feedback memory." -Project $Slug

    if ($AppliesTo -eq "workbench") {
        $AppliesTo = $Slug
    }
}

New-Item -ItemType Directory -Force -Path $feedbackRoot | Out-Null

$fileName = "$stamp-$Id.md"
$feedbackPath = Join-Path $feedbackRoot $fileName
$counter = 2

while (Test-Path -LiteralPath $feedbackPath) {
    $fileName = "$stamp-$Id-$counter.md"
    $feedbackPath = Join-Path $feedbackRoot $fileName
    $counter++
}

$relativePath = "$relativeRoot/$fileName"

$content = @"
---
id: $($fileName.Replace(".md", ""))
created_at: $now
scope: $scope
applies_to: $AppliesTo
---

# Feedback: $Title

## Rule

$Rule

## Why

$Why

## When To Apply

$WhenToApply

## Source

$Source
"@

Write-Utf8Lf -Path $feedbackPath -Content $content

$entries = @($index.entries)
$entries += [pscustomobject]@{
    id = $fileName.Replace(".md", "")
    title = $Title
    scope = $scope
    applies_to = $AppliesTo
    path = $relativePath
    created_at = $now
    rule = $Rule
}

$index.entries = @($entries | Sort-Object created_at -Descending)
$index.last_updated = $now
Write-Utf8Lf -Path $indexPath -Content ($index | ConvertTo-Json -Depth 10)

if ($scope -eq "project") {
    & (Join-Path $PSScriptRoot "update-project-index.ps1") -Slug $Slug | Out-Null
}
else {
    & (Join-Path $PSScriptRoot "update-ai-index.ps1") | Out-Null
}

Write-Output "Remembered feedback: $relativePath"
