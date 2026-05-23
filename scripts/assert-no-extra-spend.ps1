param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("local", "claude-subscription", "codex-subscription")]
    [string]$Provider,

    [string]$Model = "",

    [switch]$RequireClaudeAiLogin
)

$ErrorActionPreference = "Stop"

function Test-BlockedEnvVar {
    param(
        [string]$Name,
        [string]$Reason
    )

    $value = [Environment]::GetEnvironmentVariable($Name, "Process")
    if ([string]::IsNullOrWhiteSpace($value)) {
        $value = [Environment]::GetEnvironmentVariable($Name, "User")
    }
    if ([string]::IsNullOrWhiteSpace($value)) {
        $value = [Environment]::GetEnvironmentVariable($Name, "Machine")
    }

    if (-not [string]::IsNullOrWhiteSpace($value)) {
        throw "Blocked no-extra-spend guard: environment variable $Name is set. $Reason"
    }
}

function Read-JsonIfExists {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    try {
        return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
    }
    catch {
        throw "Invalid JSON in $Path`: $($_.Exception.Message)"
    }
}

if ($Model -match "(?i)(^|[-_:])cloud($|[-_:])") {
    throw "Blocked no-extra-spend guard: model '$Model' looks like a hosted cloud model."
}

Test-BlockedEnvVar -Name "ANTHROPIC_API_KEY" -Reason "Claude Code must use the existing Claude.ai subscription login, not Anthropic Console/API billing."
Test-BlockedEnvVar -Name "OPENAI_API_KEY" -Reason "Codex local/subscription workflows must not route through OpenAI API key billing."
Test-BlockedEnvVar -Name "AZURE_OPENAI_API_KEY" -Reason "Azure OpenAI API key billing is outside the allowed provider policy."
Test-BlockedEnvVar -Name "OLLAMA_API_KEY" -Reason "Ollama workflows must use local models, not Ollama cloud/API billing."
Test-BlockedEnvVar -Name "CLAUDE_CODE_USE_BEDROCK" -Reason "Bedrock-backed Claude Code is outside the existing Claude.ai subscription lane."
Test-BlockedEnvVar -Name "CLAUDE_CODE_USE_VERTEX" -Reason "Vertex-backed Claude Code is outside the existing Claude.ai subscription lane."

$ollamaHost = [Environment]::GetEnvironmentVariable("OLLAMA_HOST", "Process")
if ([string]::IsNullOrWhiteSpace($ollamaHost)) {
    $ollamaHost = [Environment]::GetEnvironmentVariable("OLLAMA_HOST", "User")
}
if (-not [string]::IsNullOrWhiteSpace($ollamaHost)) {
    $allowedHosts = @(
        "http://localhost",
        "https://localhost",
        "http://127.0.0.1",
        "https://127.0.0.1",
        "http://[::1]",
        "https://[::1]"
    )

    $isLocal = $false
    foreach ($allowedHost in $allowedHosts) {
        if ($ollamaHost.StartsWith($allowedHost, [System.StringComparison]::OrdinalIgnoreCase)) {
            $isLocal = $true
            break
        }
    }

    if (-not $isLocal) {
        throw "Blocked no-extra-spend guard: OLLAMA_HOST points to '$ollamaHost'. Use a local Ollama endpoint only."
    }
}

if ($Provider -eq "claude-subscription" -or $RequireClaudeAiLogin) {
    $claudeSettingsPath = Join-Path $env:USERPROFILE ".claude\settings.json"
    $claudeSettings = Read-JsonIfExists -Path $claudeSettingsPath

    if ($null -eq $claudeSettings) {
        throw "Blocked no-extra-spend guard: missing $claudeSettingsPath. Add `{ `"forceLoginMethod`": `"claudeai`" `} before using Claude Code from this workbench."
    }

    if (-not ($claudeSettings.PSObject.Properties.Name -contains "forceLoginMethod")) {
        throw "Blocked no-extra-spend guard: $claudeSettingsPath must set forceLoginMethod to claudeai."
    }

    if ($claudeSettings.forceLoginMethod -ne "claudeai") {
        throw "Blocked no-extra-spend guard: Claude Code forceLoginMethod is '$($claudeSettings.forceLoginMethod)'. It must be 'claudeai' for existing subscription use."
    }
}

Write-Output "OK: no-extra-spend guard passed for $Provider."
