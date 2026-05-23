param(
    [string]$Model = "qwen2.5-coder:7b",

    [string]$Slug = "",

    [string]$Prompt = "",

    [switch]$Small,

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function ConvertTo-Slug {
    param([string]$Value)

    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")

    return $slug
}

if ($Small) {
    $Model = "qwen2.5-coder:3b"
}

& (Join-Path $PSScriptRoot "assert-no-extra-spend.ps1") -Provider local -Model $Model | Out-Null

$codexCommand = Get-Command codex -ErrorAction SilentlyContinue
if ($null -eq $codexCommand) {
    throw "Codex is not available on PATH."
}

if (-not $DryRun) {
    & (Join-Path $PSScriptRoot "check-local-model.ps1") -Model $Model | Out-Null
}

$initialPromptParts = @(
    "Use AGENTS.md and the workbench indexes. Stay within the no-extra-spend policy: local/free models only, no API keys, no cloud-hosted models."
)

if (-not [string]::IsNullOrWhiteSpace($Slug)) {
    $Slug = ConvertTo-Slug -Value $Slug
    $projectIndexPath = Join-Path $root "projects\$Slug\.ai\index.json"
    if (-not (Test-Path -LiteralPath $projectIndexPath)) {
        throw "Project dossier not found: projects/$Slug"
    }

    $bootstrap = & (Join-Path $PSScriptRoot "snapshot-context.ps1") -Bootstrap -Slug $Slug
    $initialPromptParts += "<bootstrap_context>`r`n$($bootstrap -join "`r`n")`r`n</bootstrap_context>"
}

if (-not [string]::IsNullOrWhiteSpace($Prompt)) {
    $initialPromptParts += $Prompt
}

$initialPrompt = ($initialPromptParts -join "`r`n`r`n")
$codexArgs = @(
    "--oss",
    "--local-provider", "ollama",
    "-m", $Model,
    "-C", $root.Path
)

if ($DryRun) {
    Write-Output "DRY RUN: would launch local Codex."
    Write-Output "Command: codex $($codexArgs -join ' ')"
    if (-not [string]::IsNullOrWhiteSpace($Slug)) {
        Write-Output "Bootstrap: scripts/snapshot-context.ps1 -Bootstrap -Slug $Slug"
    }
    Write-Output "Provider: local_free"
    Write-Output "Model: $Model"
    return
}

& codex @codexArgs $initialPrompt
