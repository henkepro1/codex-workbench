param(
    [Parameter(Mandatory = $true)]
    [string]$Id,

    [Parameter(Mandatory = $true)]
    [string]$Type,

    [Parameter(Mandatory = $true)]
    [string]$Path,

    [string]$Source = "generated",

    [string]$PromptRef = "",

    [string]$Status = "draft",

    [string]$Notes = "",

    [switch]$Preview,

    [switch]$RequireFile
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$manifestPath = Join-Path $root ".ai\assets\index.json"
$repoPath = Join-Path $root $Path

if ($RequireFile -and -not (Test-Path -LiteralPath $repoPath)) {
    throw "Asset file does not exist: $Path"
}

try {
    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
}
catch {
    throw "Invalid asset manifest JSON: $($_.Exception.Message)"
}

if (-not ($manifest.PSObject.Properties.Name -contains "assets")) {
    $manifest | Add-Member -NotePropertyName "assets" -NotePropertyValue @()
}

$now = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
$entries = @($manifest.assets)
$existing = $entries | Where-Object { $_.id -eq $Id } | Select-Object -First 1

$previewEntry = [pscustomobject]@{
    id = $Id
    type = $Type
    path = $Path
    source = $Source
    prompt_ref = $PromptRef
    created_at = $now
    status = $Status
    notes = $Notes
}

if ($Preview) {
    Write-Output "Preview asset record:"
    $previewEntry | ConvertTo-Json -Depth 5
    return
}

if ($existing) {
    $existing.type = $Type
    $existing.path = $Path
    $existing.source = $Source
    $existing.prompt_ref = $PromptRef
    $existing.status = $Status
    $existing.notes = $Notes
}
else {
    $entries += $previewEntry
    $manifest.assets = $entries
}

$manifest.last_updated = $now
$manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

Write-Output "Registered asset: $Id -> $Path"
