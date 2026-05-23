param(
    [Parameter(Mandatory = $true)]
    [string]$Slug,

    [Parameter(Mandatory = $true)]
    [ValidateSet("code", "scene", "prefab", "scriptable-object", "shader", "settings", "asset", "docs", "other")]
    [string]$Category,

    [Parameter(Mandatory = $true)]
    [string]$Summary,

    [string[]]$ChangedPath = @(),

    [string]$Verification = "Not run",

    [string[]]$RulesChecked = @(),

    [string]$MechanicsPreserved = "Not documented",

    [string]$EditorChangesRequired = "Not documented",

    [string[]]$FollowUpFixes = @(),

    [string]$ChangeId = ""
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function ConvertTo-Slug {
    param([string]$Value)

    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")

    if ([string]::IsNullOrWhiteSpace($slug)) {
        return "change"
    }

    return $slug
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

$Slug = ConvertTo-Slug -Value $Slug
$projectRoot = Join-Path (Join-Path $root "projects") $Slug
$projectIndexPath = Join-Path $projectRoot ".ai\index.json"

if (-not (Test-Path -LiteralPath $projectIndexPath)) {
    throw "Project dossier not found: projects/$Slug"
}

$projectIndex = Get-Content -Raw -LiteralPath $projectIndexPath | ConvertFrom-Json
$changesRoot = Join-Path $projectRoot ".ai\changes"
New-Item -ItemType Directory -Force -Path $changesRoot | Out-Null

$ChangedPath = Normalize-StringList -Values $ChangedPath
$RulesChecked = Normalize-StringList -Values $RulesChecked
$FollowUpFixes = Normalize-StringList -Values $FollowUpFixes

$now = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
$stamp = Get-Date -Format "yyyy-MM-dd-HHmmss"

if ([string]::IsNullOrWhiteSpace($ChangeId)) {
    $ChangeId = ConvertTo-Slug -Value $Summary
}
else {
    $ChangeId = ConvertTo-Slug -Value $ChangeId
}

$fileName = "$stamp-$ChangeId.json"
$changePath = Join-Path $changesRoot $fileName
$counter = 2

while (Test-Path -LiteralPath $changePath) {
    $fileName = "$stamp-$ChangeId-$counter.json"
    $changePath = Join-Path $changesRoot $fileName
    $counter++
}

$record = [pscustomobject]@{
    schema_version = 1
    id = $fileName.Replace(".json", "")
    project = $Slug
    category = $Category
    summary = $Summary
    source_path = $projectIndex.source_path
    changed_paths = @($ChangedPath)
    verification = $Verification
    audit = [pscustomobject]@{
        rules_checked = @($RulesChecked)
        mechanics_preserved = $MechanicsPreserved
        editor_changes_required = $EditorChangesRequired
        follow_up_fixes = @($FollowUpFixes)
    }
    created_at = $now
    notes = "External project changes should be paired with refreshed project and engine context when relevant."
}

$record | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $changePath -Encoding UTF8

& (Join-Path $PSScriptRoot "update-project-index.ps1") -Slug $Slug | Out-Null

Write-Output "Recorded project change: projects/$Slug/.ai/changes/$fileName"
