param(
    [switch]$Json,

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot '_lib\Eol.ps1')

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$envPath = Join-Path $root ".env"

function ConvertTo-Slug {
    param([string]$Value)

    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")

    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw "Invalid active project slug."
    }

    return $slug
}

function Read-DotEnv {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No active project is configured. Create .env from .env.example or pass -Slug explicitly."
    }

    $values = @{}
    foreach ($line in Get-Content -LiteralPath $Path) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
            continue
        }

        $parts = $trimmed.Split("=", 2)
        if ($parts.Count -ne 2) {
            continue
        }

        $key = $parts[0].Trim()
        $value = $parts[1].Trim()
        if (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'"))) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        $values[$key] = $value
    }

    return $values
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

function Set-JsonProperty {
    param(
        [object]$Object,
        [string]$Name,
        [object]$Value
    )

    if ($Object.PSObject.Properties.Name -contains $Name) {
        $Object.$Name = $Value
    }
    else {
        $Object | Add-Member -NotePropertyName $Name -NotePropertyValue $Value
    }
}

function Set-ProjectSourceText {
    param(
        [string]$Slug,
        [string]$Title,
        [string]$Kind,
        [string]$SourcePath
    )

    $projectRoot = Join-Path (Join-Path $root "projects") $Slug
    $kindDisplay = if ($Kind -eq "unity") { "Unity" } else { "General" }

    $readmePath = Join-Path $projectRoot "README.md"
    if (Test-Path -LiteralPath $readmePath) {
        @"
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

$SourcePath
"@ | ForEach-Object { Write-Utf8Lf -Path $readmePath -Content $_ }
    }

    $sourceMapPath = Join-Path $projectRoot "map\source.md"
    if (Test-Path -LiteralPath $sourceMapPath) {
        @"
# Source

Source path: $SourcePath

Use this file to explain where code lives and what should be inspected first.
"@ | ForEach-Object { Write-Utf8Lf -Path $sourceMapPath -Content $_ }
    }

    $summaryPath = Join-Path $projectRoot ".ai\summary.md"
    if (Test-Path -LiteralPath $summaryPath) {
        @"
# $Title Summary

Slug: `$Slug`

Kind: $kindDisplay

Source: $SourcePath

Use projects/$Slug/.ai/index.json first, then inspect focused map files or engine context as needed.
"@ | ForEach-Object { Write-Utf8Lf -Path $summaryPath -Content $_ }
    }
}

$envValues = Read-DotEnv -Path $envPath

foreach ($requiredKey in @("WORKBENCH_ACTIVE_PROJECT", "WORKBENCH_ACTIVE_SOURCE_PATH")) {
    if (-not $envValues.ContainsKey($requiredKey) -or [string]::IsNullOrWhiteSpace($envValues[$requiredKey])) {
        throw ".env is missing $requiredKey. Create it from .env.example or pass -Slug explicitly."
    }
}

$slug = ConvertTo-Slug -Value $envValues["WORKBENCH_ACTIVE_PROJECT"]
$sourcePath = $envValues["WORKBENCH_ACTIVE_SOURCE_PATH"]
$title = if ($envValues.ContainsKey("WORKBENCH_ACTIVE_TITLE") -and -not [string]::IsNullOrWhiteSpace($envValues["WORKBENCH_ACTIVE_TITLE"])) { $envValues["WORKBENCH_ACTIVE_TITLE"] } else { $slug }
$kind = if ($envValues.ContainsKey("WORKBENCH_ACTIVE_KIND") -and -not [string]::IsNullOrWhiteSpace($envValues["WORKBENCH_ACTIVE_KIND"])) { $envValues["WORKBENCH_ACTIVE_KIND"].ToLowerInvariant() } else { "general" }

if ($kind -notin @("general", "unity")) {
    throw "WORKBENCH_ACTIVE_KIND must be general or unity."
}

if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Active project source path does not exist: $sourcePath"
}

$projectRoot = Join-Path (Join-Path $root "projects") $slug
$projectIndexPath = Join-Path $projectRoot ".ai\index.json"
$changed = $false

if (-not (Test-Path -LiteralPath $projectIndexPath)) {
    if ($DryRun) {
        $changed = $true
    }
    else {
        & (Join-Path $PSScriptRoot "new-project.ps1") -Title $title -Slug $slug -SourcePath $sourcePath -Kind $kind | Out-Null
        $changed = $true
    }
}
else {
    $projectIndex = Read-JsonFile -Path $projectIndexPath

    if ($projectIndex.source_path -ne $sourcePath -or $projectIndex.title -ne $title -or $projectIndex.kind -ne $kind) {
        $changed = $true
        if (-not $DryRun) {
            $now = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
            Set-JsonProperty -Object $projectIndex -Name "source_path" -Value $sourcePath
            Set-JsonProperty -Object $projectIndex -Name "title" -Value $title
            Set-JsonProperty -Object $projectIndex -Name "kind" -Value $kind
            Set-JsonProperty -Object $projectIndex -Name "last_updated" -Value $now
            Write-Utf8Lf -Path $projectIndexPath -Content ($projectIndex | ConvertTo-Json -Depth 10)

            Set-ProjectSourceText -Slug $slug -Title $title -Kind $kind -SourcePath $sourcePath
            & (Join-Path $PSScriptRoot "update-project-index.ps1") -Slug $slug | Out-Null
        }
    }
}

if (-not $DryRun) {
    $registryPath = Join-Path $root ".ai\projects\index.json"
    $registry = Read-JsonFile -Path $registryPath
    $existing = @($registry.projects | Where-Object { $_.slug -eq $slug })
    if ($existing.Count -eq 0) {
        & (Join-Path $PSScriptRoot "update-project-index.ps1") -Slug $slug | Out-Null
    }
}

$result = [pscustomobject]@{
    slug = $slug
    title = $title
    kind = $kind
    source_path = $sourcePath
    project_path = "projects/$slug"
    index = "projects/$slug/.ai/index.json"
    changed = $changed
    dry_run = [bool]$DryRun
}

if ($Json) {
    $result | ConvertTo-Json -Depth 5
}
else {
    Write-Output "Active project: $slug"
    Write-Output "Title: $title"
    Write-Output "Kind: $kind"
    Write-Output "Source: $sourcePath"
    if ($DryRun -and $changed) {
        Write-Output "Dry run: dossier/index would be created or updated from .env."
    }
    elseif ($changed) {
        Write-Output "Synced dossier/index from .env."
    }
}
