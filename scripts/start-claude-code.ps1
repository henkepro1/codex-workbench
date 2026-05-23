param(
    [ValidateSet("sonnet", "opus", "haiku")]
    [string]$Model = "sonnet",

    [string]$Slug = "",

    [string]$Prompt = "",

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

function Resolve-ClaudeCommand {
    $command = Get-Command claude -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Links\claude.exe"),
        (Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages\Anthropic.ClaudeCode_Microsoft.Winget.Source_8wekyb3d8bbwe\claude.exe")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

function Resolve-ProjectSlug {
    param([string]$Value)

    if (-not [string]::IsNullOrWhiteSpace($Value)) {
        return ConvertTo-Slug -Value $Value
    }

    $activeProject = & (Join-Path $PSScriptRoot "resolve-active-project.ps1") -Json | ConvertFrom-Json
    return $activeProject.slug
}

& (Join-Path $PSScriptRoot "assert-no-extra-spend.ps1") -Provider claude-subscription -Model $Model -RequireClaudeAiLogin | Out-Null

$claudeCommand = Resolve-ClaudeCommand
if ($null -eq $claudeCommand -and -not $DryRun) {
    throw "Claude Code is not available on PATH. Install/login manually with the existing Claude subscription before using this launcher."
}

$initialPromptParts = @(
    "Use the existing Claude.ai subscription only. Do not use Anthropic Console/API billing, API keys, cloud model billing, upgrades, or new subscriptions."
)

$Slug = Resolve-ProjectSlug -Value $Slug

$projectIndexPath = Join-Path $root "projects\$Slug\.ai\index.json"
if (-not (Test-Path -LiteralPath $projectIndexPath)) {
    throw "Project dossier not found: projects/$Slug"
}

$bootstrap = & (Join-Path $PSScriptRoot "snapshot-context.ps1") -Bootstrap -Slug $Slug
$initialPromptParts += "<bootstrap_context>`r`n$($bootstrap -join "`r`n")`r`n</bootstrap_context>"

if (-not [string]::IsNullOrWhiteSpace($Prompt)) {
    $initialPromptParts += $Prompt
}

$initialPrompt = ($initialPromptParts -join "`r`n`r`n")
$claudeArgs = @("--model", $Model)

if ($DryRun) {
    Write-Output "DRY RUN: would launch Claude Code through the existing Claude.ai subscription."
    Write-Output "Command: claude $($claudeArgs -join ' ')"
    Write-Output "Required setting: ~/.claude/settings.json forceLoginMethod=claudeai"
    Write-Output "Bootstrap: scripts/snapshot-context.ps1 -Bootstrap -Slug $Slug"
    Write-Output "Provider: subscription_covered"
    Write-Output "Model: $Model"
    return
}

if ([string]::IsNullOrWhiteSpace($initialPrompt)) {
    & $claudeCommand @claudeArgs
}
else {
    & $claudeCommand @claudeArgs $initialPrompt
}
