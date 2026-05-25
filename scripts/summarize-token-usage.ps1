param(
    [ValidateSet("workspace", "project")]
    [string]$Scope = "workspace",

    [string]$Slug = ""
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
    }
}

function Get-CountValue {
    param(
        [object]$Record,
        [string]$Name
    )

    if ($null -eq $Record.counts) {
        return 0L
    }

    if (-not ($Record.counts.PSObject.Properties.Name -contains $Name)) {
        return 0L
    }

    return [long]$Record.counts.$Name
}

$paths = Get-TokenUsagePaths -RequestedScope $Scope -RequestedSlug $Slug
New-Item -ItemType Directory -Force -Path $paths.Root | Out-Null

if (-not (Test-Path -LiteralPath $paths.Index)) {
    throw "Missing token usage index: $($paths.Index)"
}

$index = Read-JsonFile -Path $paths.Index

$records = @()
if (Test-Path -LiteralPath $paths.Ledger) {
    foreach ($line in Get-Content -LiteralPath $paths.Ledger -ErrorAction SilentlyContinue) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }

        try {
            $records += ($line | ConvertFrom-Json)
        }
        catch {
            throw "Invalid JSONL record in $($paths.Ledger): $($_.Exception.Message)"
        }
    }
}
else {
    New-Item -ItemType File -Path $paths.Ledger | Out-Null
}

$inputTotal = 0L
$outputTotal = 0L
$toolOutputTotal = 0L
$total = 0L
$exactCount = 0
$estimatedCount = 0
$culpritTotals = @{}

foreach ($record in $records) {
    $recordInput = Get-CountValue -Record $record -Name "input_tokens"
    $recordOutput = Get-CountValue -Record $record -Name "output_tokens"
    $recordToolOutput = Get-CountValue -Record $record -Name "tool_output_tokens"
    $recordTotal = Get-CountValue -Record $record -Name "total_tokens"

    if ($recordTotal -eq 0) {
        $recordTotal = $recordInput + $recordOutput + $recordToolOutput
    }

    $inputTotal += $recordInput
    $outputTotal += $recordOutput
    $toolOutputTotal += $recordToolOutput
    $total += $recordTotal

    if ($record.measurement -eq "exact") {
        $exactCount += 1
    }
    elseif ($record.measurement -eq "estimated") {
        $estimatedCount += 1
    }

    $culprits = @($record.culprits)
    if ($culprits.Count -eq 0) {
        continue
    }

    $share = [long][Math]::Ceiling($recordTotal / [double]$culprits.Count)
    foreach ($culprit in $culprits) {
        if ([string]::IsNullOrWhiteSpace($culprit)) {
            continue
        }

        $key = $culprit.Trim()
        if (-not $culpritTotals.ContainsKey($key)) {
            $culpritTotals[$key] = 0L
        }

        $culpritTotals[$key] += $share
    }
}

$topCulprits = @(
    foreach ($key in $culpritTotals.Keys) {
        [pscustomobject]@{
            culprit = $key
            attributed_tokens = [long]$culpritTotals[$key]
        }
    }
) | Sort-Object -Property attributed_tokens -Descending

$summary = [pscustomobject]@{
    schema_version = 1
    scope = $Scope
    slug = if ($Scope -eq "project") { ConvertTo-Slug -Value $Slug } else { $null }
    generated_at = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
    records = $records.Count
    totals = [pscustomobject]@{
        exact_records = $exactCount
        estimated_records = $estimatedCount
        input_tokens = $inputTotal
        output_tokens = $outputTotal
        tool_output_tokens = $toolOutputTotal
        total_tokens = $total
    }
    top_culprits = @($topCulprits | Select-Object -First 12)
}

Write-Utf8Lf -Path $paths.Summary -Content ($summary | ConvertTo-Json -Depth 10)

if (-not ($index.PSObject.Properties.Name -contains "totals")) {
    $index | Add-Member -NotePropertyName "totals" -NotePropertyValue ([pscustomobject]@{})
}
if (-not ($index.PSObject.Properties.Name -contains "top_culprits")) {
    $index | Add-Member -NotePropertyName "top_culprits" -NotePropertyValue @()
}

$index.last_updated = $summary.generated_at
$index.totals = [pscustomobject]@{
    records = $records.Count
    exact_records = $exactCount
    estimated_records = $estimatedCount
    input_tokens = $inputTotal
    output_tokens = $outputTotal
    tool_output_tokens = $toolOutputTotal
    total_tokens = $total
}
$index.top_culprits = @($summary.top_culprits)
Write-Utf8Lf -Path $paths.Index -Content ($index | ConvertTo-Json -Depth 10)

Write-Output "Token usage records: $($records.Count)"
Write-Output "Total tokens: $total"
if ($topCulprits.Count -gt 0) {
    Write-Output "Top culprits:"
    foreach ($entry in @($topCulprits | Select-Object -First 5)) {
        Write-Output "- $($entry.culprit): $($entry.attributed_tokens)"
    }
}
