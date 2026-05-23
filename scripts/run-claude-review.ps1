param(
    [string]$Slug = "",

    [string]$Scope = "uncommitted",

    [ValidateSet("code", "architecture", "unity", "performance", "all")]
    [string]$Focus = "all",

    [ValidateSet("sonnet", "opus", "haiku")]
    [string]$Model = "sonnet",

    [int]$MaxContextLines = 1200,

    [switch]$DryRun
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function ConvertTo-Slug {
    param([string]$Value)

    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")

    if ([string]::IsNullOrWhiteSpace($slug)) {
        throw "Invalid slug."
    }

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

function Resolve-ProjectSlug {
    param([string]$Value)

    if (-not [string]::IsNullOrWhiteSpace($Value)) {
        return ConvertTo-Slug -Value $Value
    }

    $activeProject = & (Join-Path $PSScriptRoot "resolve-active-project.ps1") -Json | ConvertFrom-Json
    return $activeProject.slug
}

function Ensure-ReviewIndex {
    param(
        [string]$Path,
        [string]$Project
    )

    if (Test-Path -LiteralPath $Path) {
        return Read-JsonFile -Path $Path
    }

    $index = [pscustomobject]@{
        schema_version = 1
        last_updated = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
        purpose = "Findings-only review notes for this project."
        project = $Project
        reviews = @()
    }

    New-Item -ItemType Directory -Force -Path (Split-Path $Path) | Out-Null
    $index | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $Path -Encoding UTF8

    return $index
}

function Invoke-GitText {
    param(
        [string]$Source,
        [string[]]$GitArgs
    )

    $output = & git -C $Source @GitArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        return "git $($GitArgs -join ' ') failed:`r`n$($output | Out-String)"
    }

    return ($output | Out-String)
}

function Get-UntrackedContext {
    param(
        [string]$Source,
        [int]$FileLimit = 20,
        [int]$LinesPerFile = 160
    )

    $files = & git -C $Source ls-files --others --exclude-standard 2>&1
    if ($LASTEXITCODE -ne 0 -or $files.Count -eq 0) {
        return ""
    }

    $sourceRoot = (Resolve-Path -LiteralPath $Source).Path
    $parts = @("## untracked files")
    foreach ($file in @($files | Select-Object -First $FileLimit)) {
        if ([string]::IsNullOrWhiteSpace($file)) {
            continue
        }

        $candidate = Join-Path $sourceRoot $file
        $resolved = Resolve-Path -LiteralPath $candidate -ErrorAction SilentlyContinue
        if ($null -eq $resolved -or -not $resolved.Path.StartsWith($sourceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            continue
        }

        if ((Get-Item -LiteralPath $resolved.Path).Length -gt 262144) {
            $parts += "### $file`r`nSkipped: file is larger than 256 KiB."
            continue
        }

        $content = Get-Content -LiteralPath $resolved.Path -TotalCount $LinesPerFile
        $joinedContent = $content -join "`r`n"
        $parts += "### $file`r`n--- file content start ---`r`n$joinedContent`r`n--- file content end ---"
    }

    return $parts -join "`r`n`r`n"
}

function Get-ScopeContext {
    param(
        [string]$Source,
        [string]$ReviewScope,
        [int]$LineLimit
    )

    if ($ReviewScope -eq "uncommitted") {
        $parts = @(
            "## git status --short`r`n$(Invoke-GitText -Source $Source -GitArgs @('status', '--short'))",
            "## git diff --stat`r`n$(Invoke-GitText -Source $Source -GitArgs @('diff', '--stat'))",
            "## git diff --cached`r`n$(Invoke-GitText -Source $Source -GitArgs @('diff', '--cached'))",
            "## git diff`r`n$(Invoke-GitText -Source $Source -GitArgs @('diff'))",
            "$(Get-UntrackedContext -Source $Source)"
        )
        return (($parts -join "`r`n`r`n") -split "`r?`n" | Select-Object -First $LineLimit) -join "`r`n"
    }

    if ($ReviewScope.StartsWith("base:", [System.StringComparison]::OrdinalIgnoreCase)) {
        $base = $ReviewScope.Substring(5).Trim()
        if ([string]::IsNullOrWhiteSpace($base)) {
            throw "Scope base:<branch> requires a branch or ref."
        }
        $parts = @(
            "## git diff $base --stat`r`n$(Invoke-GitText -Source $Source -GitArgs @('diff', $base, '--stat'))",
            "## git diff $base`r`n$(Invoke-GitText -Source $Source -GitArgs @('diff', $base))"
        )
        return (($parts -join "`r`n`r`n") -split "`r?`n" | Select-Object -First $LineLimit) -join "`r`n"
    }

    if ($ReviewScope.StartsWith("commit:", [System.StringComparison]::OrdinalIgnoreCase)) {
        $commit = $ReviewScope.Substring(7).Trim()
        if ([string]::IsNullOrWhiteSpace($commit)) {
            throw "Scope commit:<sha> requires a commit SHA."
        }
        $parts = @(
            "## git show $commit --stat`r`n$(Invoke-GitText -Source $Source -GitArgs @('show', '--stat', $commit))",
            "## git show $commit`r`n$(Invoke-GitText -Source $Source -GitArgs @('show', '--find-renames', '--find-copies', $commit))"
        )
        return (($parts -join "`r`n`r`n") -split "`r?`n" | Select-Object -First $LineLimit) -join "`r`n"
    }

    if ($ReviewScope.StartsWith("files:", [System.StringComparison]::OrdinalIgnoreCase)) {
        $files = @($ReviewScope.Substring(6).Split(",") | ForEach-Object { $_.Trim() } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
        if ($files.Count -eq 0) {
            throw "Scope files:<paths> requires at least one path."
        }

        $sourceRoot = (Resolve-Path -LiteralPath $Source).Path
        $parts = @()
        foreach ($file in $files) {
            $candidate = Join-Path $sourceRoot $file
            $resolved = Resolve-Path -LiteralPath $candidate -ErrorAction Stop
            if (-not $resolved.Path.StartsWith($sourceRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                throw "File is outside project source: $file"
            }
            $content = Get-Content -LiteralPath $resolved.Path -TotalCount 300
            $joinedContent = $content -join "`r`n"
            $parts += "## $file`r`n--- file content start ---`r`n$joinedContent`r`n--- file content end ---"
        }
        return (($parts -join "`r`n`r`n") -split "`r?`n" | Select-Object -First $LineLimit) -join "`r`n"
    }

    throw "Unsupported scope '$ReviewScope'. Use uncommitted, base:<branch>, commit:<sha>, or files:<paths>."
}

$Slug = Resolve-ProjectSlug -Value $Slug
$projectRoot = Join-Path (Join-Path $root "projects") $Slug
$projectIndexPath = Join-Path $projectRoot ".ai\index.json"
$projectIndex = Read-JsonFile -Path $projectIndexPath

if ([string]::IsNullOrWhiteSpace($projectIndex.source_path)) {
    throw "Project $Slug does not define source_path."
}

$sourcePath = $projectIndex.source_path
if (-not (Test-Path -LiteralPath $sourcePath)) {
    throw "Project source path does not exist: $sourcePath"
}

& (Join-Path $PSScriptRoot "assert-no-extra-spend.ps1") -Provider claude-subscription -Model $Model -RequireClaudeAiLogin | Out-Null

$claudeCommand = Resolve-ClaudeCommand
if ($null -eq $claudeCommand -and -not $DryRun) {
    throw "Claude Code is not available on PATH. Install/login manually with the existing Claude subscription before using this script."
}

$stamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
$safeScope = ConvertTo-Slug -Value $Scope
$reviewId = "$stamp-claude-$safeScope"
$reviewsRoot = Join-Path $projectRoot ".ai\reviews"
$reviewIndexPath = Join-Path $reviewsRoot "index.json"
$relativeReviewPath = "projects/$Slug/.ai/reviews/$reviewId.md"
$reviewPath = Join-Path $reviewsRoot "$reviewId.md"

if ($DryRun) {
    Write-Output "DRY RUN: would run Claude Code findings-only review through the existing Claude.ai subscription."
    Write-Output "Project: $Slug"
    Write-Output "Source: $sourcePath"
    Write-Output "Scope: $Scope"
    Write-Output "Focus: $Focus"
    Write-Output "Required setting: ~/.claude/settings.json forceLoginMethod=claudeai"
    Write-Output "Command: claude -p <review prompt> --model $Model"
    Write-Output "Output: $relativeReviewPath"
    return
}

$scopeContext = Get-ScopeContext -Source $sourcePath -ReviewScope $Scope -LineLimit $MaxContextLines
$reviewPrompt = @"
You are running a fresh findings-only review for project '$Slug'.

No-extra-spend rule:
- Use the existing Claude.ai subscription only.
- Do not use Anthropic Console/API billing, API keys, provider credits, cloud model billing, upgrades, or new subscriptions.

Review rules:
- Report findings only. Do not patch, edit, rewrite, or create files.
- Prioritize bugs, live-project rule violations, behavior regressions, hidden fallbacks, broad Unity lookups, unnecessary allocations/hot-path costs, and missing verification.
- Use severity sections: CRITICAL, WARNING, NOTE.
- Include file paths and line references when available.
- Say "No findings" if nothing material is found.

Required policy references:
- AGENTS.md
- rules/live-project-code-rules.md
- projects/$Slug/rules/project-rules.md
- cheatsheets/reviewer.md

Scope: $Scope
Focus: $Focus
Source path: $sourcePath

Review context:
$scopeContext
"@

New-Item -ItemType Directory -Force -Path $reviewsRoot | Out-Null
$reviewOutput = & $claudeCommand -p $reviewPrompt --model $Model 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "Claude review failed: $($reviewOutput | Out-String)"
}

$reviewText = ($reviewOutput | Out-String).Trim()
$criticalCount = ([regex]::Matches($reviewText, "(?im)^\s*(#+\s*)?CRITICAL\b")).Count
$warningCount = ([regex]::Matches($reviewText, "(?im)^\s*(#+\s*)?WARNING\b")).Count
$noteCount = ([regex]::Matches($reviewText, "(?im)^\s*(#+\s*)?NOTE\b")).Count
$now = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"

$content = @"
# Review: $Slug / $Scope

Created: $now
Provider: subscription_covered
Model: claude-code/$Model
Focus: $Focus
Source: $sourcePath

## Findings

$reviewText
"@

Set-Content -LiteralPath $reviewPath -Value $content -Encoding UTF8

$index = Ensure-ReviewIndex -Path $reviewIndexPath -Project $Slug
$reviews = @($index.reviews)
$reviews += [pscustomobject]@{
    id = $reviewId
    project = $Slug
    provider = "subscription_covered"
    model = "claude-code/$Model"
    scope = $Scope
    focus = $Focus
    status = "open"
    critical_count = $criticalCount
    warning_count = $warningCount
    note_count = $noteCount
    path = $relativeReviewPath
    created_at = $now
}
$index.reviews = @($reviews | Sort-Object created_at -Descending)
$index.last_updated = $now
$index | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $reviewIndexPath -Encoding UTF8

& (Join-Path $PSScriptRoot "update-project-index.ps1") -Slug $Slug | Out-Null

Write-Output "Created review: $relativeReviewPath"
