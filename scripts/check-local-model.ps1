param(
    [string]$Model = "qwen2.5-coder:7b",

    [ValidateSet("ollama")]
    [string]$Provider = "ollama",

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

& (Join-Path $PSScriptRoot "assert-no-extra-spend.ps1") -Provider local -Model $Model | Out-Null

if ($Model -match "(?i)cloud") {
    throw "Local model '$Model' is blocked because it looks like a cloud-hosted model."
}

if ($Provider -ne "ollama") {
    throw "Unsupported local provider: $Provider"
}

function Resolve-OllamaCommand {
    $command = Get-Command ollama -ErrorAction SilentlyContinue
    if ($null -ne $command) {
        return $command.Source
    }

    $candidates = @(
        (Join-Path $env:LOCALAPPDATA "Programs\Ollama\ollama.exe"),
        (Join-Path $env:ProgramFiles "Ollama\ollama.exe")
    )

    foreach ($candidate in $candidates) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    return $null
}

if ($DryRun) {
    Write-Output "DRY RUN: would verify local Ollama model '$Model'."
    Write-Output "Command: ollama list"
    return
}

$ollamaCommand = Resolve-OllamaCommand
if ($null -eq $ollamaCommand) {
    throw "Ollama is not available on PATH. Install/start Ollama manually, then run: ollama pull $Model"
}

$listOutput = & $ollamaCommand list 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Could not query local Ollama. Start Ollama manually, then retry. Output: $($listOutput | Out-String)"
}

$models = @($listOutput | Select-Object -Skip 1)
$found = $false
foreach ($line in $models) {
    if ($line -match "^\s*$([regex]::Escape($Model))\s") {
        $found = $true
        break
    }
}

if (-not $found) {
    throw "Local Ollama model '$Model' is not installed. Pull it manually with: ollama pull $Model"
}

Write-Output "OK: local Ollama model '$Model' is available."
