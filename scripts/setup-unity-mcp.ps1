param(
    [string[]]$Slug = @("tower-heroes", "brawl-survivors"),

    [string]$PackageUrl = "https://github.com/CoplayDev/unity-mcp.git?path=/MCPForUnity#main",

    [string]$ConfigPath = "$env:USERPROFILE\.codex\config.toml",

    [switch]$SkipCodexConfig,

    [switch]$SkipUnityProjects
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot '_lib\Eol.ps1')

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$packageName = "com.coplaydev.unity-mcp"

function ConvertTo-Slug {
    param([string]$Value)

    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")

    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw "Invalid project slug."
    }

    return $slug
}

function Read-JsonFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing JSON file: $Path"
    }

    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Ensure-Mcp-Config {
    param(
        [string]$Path,
        [string]$UvxPath
    )

    $configDir = Split-Path -Parent $Path
    New-Item -ItemType Directory -Force -Path $configDir | Out-Null

    if (-not (Test-Path -LiteralPath $Path)) {
        Write-Utf8Lf -Path $Path -Content ""
    }

    $content = Get-Content -Raw -LiteralPath $Path

    if ($content -match "(?m)^\[mcp_servers\.unity\]") {
        return "Codex MCP unity entry already exists."
    }

    $block = @"

[mcp_servers.unity]
command = '$UvxPath'
args = ["--from", "mcpforunityserver", "mcp-for-unity", "--transport", "stdio"]
startup_timeout_sec = 120.0

[mcp_servers.unity.env]
DO_NOT_TRACK = "1"
UNITY_MCP_TELEMETRY_DISABLED = "1"
"@

    Add-Utf8Lf -Path $Path -Content $block
    return "Added Codex MCP unity entry."
}

function Find-Uvx {
    $command = Get-Command uvx -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $packagesRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
    $candidate = @(Get-ChildItem -LiteralPath $packagesRoot -Recurse -Filter "uvx.exe" -File -ErrorAction SilentlyContinue | Select-Object -First 1)
    if ($candidate.Count -gt 0) {
        return $candidate[0].FullName
    }

    return "uvx"
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

$changedProjects = @()
$now = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"

if (-not $SkipUnityProjects) {
    foreach ($slugValue in $Slug) {
        $projectSlug = ConvertTo-Slug -Value $slugValue
        $projectIndexPath = Join-Path (Join-Path (Join-Path $root "projects") $projectSlug) ".ai\index.json"
        $projectIndex = Read-JsonFile -Path $projectIndexPath
        $sourcePath = $projectIndex.source_path

        if ([string]::IsNullOrWhiteSpace($sourcePath) -or -not (Test-Path -LiteralPath $sourcePath)) {
            throw "Source path not found for $projectSlug`: $sourcePath"
        }

        $manifestPath = Join-Path $sourcePath "Packages\manifest.json"
        $manifest = Read-JsonFile -Path $manifestPath

        if (-not $manifest.dependencies) {
            $manifest | Add-Member -NotePropertyName "dependencies" -NotePropertyValue ([pscustomobject]@{})
        }

        $hadPackage = $manifest.dependencies.PSObject.Properties.Name -contains $packageName

        if ($hadPackage) {
            $manifest.dependencies.$packageName = $PackageUrl
            Write-Output "${projectSlug}: refreshed $packageName package URL."
        }
        else {
            $manifest.dependencies | Add-Member -NotePropertyName $packageName -NotePropertyValue $PackageUrl
            Write-Output "${projectSlug}: added $packageName."
        }

        $manifestJson = $manifest | ConvertTo-Json -Depth 20
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        [System.IO.File]::WriteAllText($manifestPath, $manifestJson, $utf8NoBom)
        $changedProjects += $projectSlug

        & (Join-Path $PSScriptRoot "record-project-change.ps1") `
            -Slug $projectSlug `
            -Category settings `
            -Summary "Configured Unity MCP package dependency" `
            -ChangedPath $manifestPath `
            -Verification "manifest.json parsed and dependency written; Unity package restore still needs Editor/package manager validation." `
            -RulesChecked "rules/live-project-code-rules.md", "projects/$projectSlug/rules/project-rules.md" `
            -MechanicsPreserved "No gameplay code or serialized gameplay assets changed." `
            -EditorChangesRequired "Open Unity to allow Package Manager to restore/update packages-lock.json and confirm MCP bridge connection." | Out-Null
    }
}

$uvxPath = Find-Uvx
$configStatus = "Skipped Codex config."
if (-not $SkipCodexConfig) {
    $configStatus = Ensure-Mcp-Config -Path $ConfigPath -UvxPath $uvxPath
}

$integrationPath = Join-Path $root ".ai\integrations\unity-mcp.json"
if (Test-Path -LiteralPath $integrationPath) {
    $integration = Read-JsonFile -Path $integrationPath
}
else {
    $integration = [pscustomobject]@{
        schema_version = 1
        id = "unity-mcp"
        name = "MCP for Unity"
        status = "planned"
        projects = @()
    }
}

Set-JsonProperty -Object $integration -Name "last_updated" -Value $now
Set-JsonProperty -Object $integration -Name "status" -Value "configured"
Set-JsonProperty -Object $integration -Name "server_command" -Value $uvxPath
Set-JsonProperty -Object $integration -Name "codex_config" -Value $ConfigPath
Set-JsonProperty -Object $integration -Name "config_status" -Value $configStatus

$projectEntries = @()
foreach ($project in @($integration.projects)) {
    if ($changedProjects -contains $project.slug) {
        Set-JsonProperty -Object $project -Name "status" -Value "configured"
        Set-JsonProperty -Object $project -Name "package" -Value $packageName
        Set-JsonProperty -Object $project -Name "package_url" -Value $PackageUrl
        Set-JsonProperty -Object $project -Name "updated_at" -Value $now
    }
    $projectEntries += $project
}

foreach ($projectSlug in $changedProjects) {
    if (@($projectEntries | Where-Object { $_.slug -eq $projectSlug }).Count -eq 0) {
        $projectEntries += [pscustomobject]@{
            slug = $projectSlug
            status = "configured"
            package = $packageName
            package_url = $PackageUrl
            updated_at = $now
        }
    }
}

$integration.projects = @($projectEntries | Sort-Object slug)
Write-Utf8Lf -Path $integrationPath -Content ($integration | ConvertTo-Json -Depth 12)

& (Join-Path $PSScriptRoot "update-ai-index.ps1") | Out-Null

Write-Output $configStatus
Write-Output "Updated Unity MCP integration record: .ai/integrations/unity-mcp.json"
