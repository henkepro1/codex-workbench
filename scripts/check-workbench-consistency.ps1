#requires -Version 5.1
<#
.SYNOPSIS
    Check workbench consistency: AGENTS.md <-> workflow macros <-> cheatsheets, stale timestamps, empty .ai dirs.

.DESCRIPTION
    Read-only audit. Reports drift but does not fix.
    Exit code 0 = clean. Exit 1 = errors found (or warnings if -Strict).

.PARAMETER Strict
    When set, exit 1 on warnings too (stale timestamps, template-only dirs, missing skill cross-refs).
    Default is to exit 1 only on hard drift (a macro referenced from one place but missing from another).

.EXAMPLE
    .\scripts\check-workbench-consistency.ps1
    .\scripts\check-workbench-consistency.ps1 -Strict
#>
[CmdletBinding()]
param(
    [switch]$Strict
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot

$errors = [System.Collections.Generic.List[string]]::new()
$warnings = [System.Collections.Generic.List[string]]::new()

function Add-Error([string]$msg) { $errors.Add($msg) | Out-Null }
function Add-Warning([string]$msg) { $warnings.Add($msg) | Out-Null }

# --- 1. Workflow macro cross-check (AGENTS.md <-> workflows/index.json <-> cheatsheet) ---
Write-Host 'Checking @wb: macro alignment...' -ForegroundColor Cyan

$workflowsPath = Join-Path $root '.ai/workflows/index.json'
if (-not (Test-Path $workflowsPath)) {
    Add-Error "workflows/index.json not found at $workflowsPath"
}
else {
    $workflowsJson = Get-Content $workflowsPath -Raw | ConvertFrom-Json
    $workflowCodes = @($workflowsJson.codes | ForEach-Object { $_.code }) | Sort-Object -Unique

    $agentsPath = Join-Path $root 'AGENTS.md'
    $agentsContent = if (Test-Path $agentsPath) { Get-Content $agentsPath -Raw } else { '' }
    $agentsCodes = @([regex]::Matches($agentsContent, '@wb:[a-z][a-z0-9-]*') |
        ForEach-Object { $_.Value }) | Sort-Object -Unique

    $cheatsheetPath = Join-Path $root 'cheatsheets/workflow-codes.md'
    $cheatsheetContent = if (Test-Path $cheatsheetPath) { Get-Content $cheatsheetPath -Raw } else { '' }
    $cheatsheetCodes = @([regex]::Matches($cheatsheetContent, '@wb:[a-z][a-z0-9-]*') |
        ForEach-Object { $_.Value }) | Sort-Object -Unique

    foreach ($code in $workflowCodes) {
        if ($cheatsheetCodes -notcontains $code) {
            Add-Error "Workflow code '$code' is in workflows/index.json but not in cheatsheets/workflow-codes.md"
        }
    }
    foreach ($code in $agentsCodes) {
        if ($workflowCodes -notcontains $code) {
            Add-Error "AGENTS.md references '$code' but it is not in workflows/index.json"
        }
    }
    foreach ($code in $cheatsheetCodes) {
        if ($workflowCodes -notcontains $code) {
            Add-Error "cheatsheets/workflow-codes.md references '$code' but it is not in workflows/index.json"
        }
    }
}

# --- 2. Stale last_updated timestamps ---
Write-Host 'Checking last_updated timestamps...' -ForegroundColor Cyan

$staleThresholdDays = 30
$now = Get-Date
$indexFiles = @()
$indexFiles += Get-ChildItem -Path (Join-Path $root '.ai') -Recurse -Filter 'index.json' -ErrorAction SilentlyContinue
$indexFiles += Get-ChildItem -Path (Join-Path $root 'projects') -Recurse -Filter 'index.json' -ErrorAction SilentlyContinue

foreach ($f in $indexFiles) {
    try {
        $j = Get-Content $f.FullName -Raw | ConvertFrom-Json
        if ($j.PSObject.Properties.Name -contains 'last_updated' -and $j.last_updated) {
            $lu = [DateTime]::Parse($j.last_updated)
            $ageDays = ($now - $lu).TotalDays
            if ($ageDays -gt $staleThresholdDays) {
                $relPath = $f.FullName.Substring($root.Length + 1)
                Add-Warning "$relPath last_updated is $([int]$ageDays) days old ($($j.last_updated))"
            }
        }
    }
    catch {
        # File isn't JSON or has no last_updated — skip silently
    }
}

# --- 3. Template-only directories ---
Write-Host 'Checking for template-only directories...' -ForegroundColor Cyan

$templateCandidates = @(
    '.ai/attempts',
    '.ai/generations',
    '.ai/prompts'
)
foreach ($dir in $templateCandidates) {
    $fullDir = Join-Path $root $dir
    if (Test-Path $fullDir) {
        $files = Get-ChildItem $fullDir -File -ErrorAction SilentlyContinue
        $nonTemplate = @($files | Where-Object { $_.Name -notmatch '^_template' -and $_.Name -ne 'index.json' })
        if ($files.Count -gt 0 -and $nonTemplate.Count -eq 0) {
            Add-Warning "$dir contains only template/index files (no real entries yet)"
        }
    }
}

# --- 4. Skill reference cross-check ---
Write-Host 'Checking skill references...' -ForegroundColor Cyan

if ($agentsContent) {
    $skillRefs = @([regex]::Matches($agentsContent, '\$([a-z][a-z0-9-]+)\b') |
        ForEach-Object { $_.Value }) | Sort-Object -Unique

    $skillsCheatsheetPath = Join-Path $root 'cheatsheets/skills.md'
    if (Test-Path $skillsCheatsheetPath) {
        $skillsContent = Get-Content $skillsCheatsheetPath -Raw
        foreach ($s in $skillRefs) {
            if ($skillsContent -notmatch [regex]::Escape($s)) {
                Add-Warning "AGENTS.md references skill '$s' but cheatsheets/skills.md does not mention it"
            }
        }
    }
    else {
        Add-Warning 'cheatsheets/skills.md does not exist; cannot cross-check skill references'
    }
}

# --- Report ---
Write-Host ''
if ($errors.Count -eq 0 -and $warnings.Count -eq 0) {
    Write-Host 'Workbench consistency: CLEAN' -ForegroundColor Green
    exit 0
}

if ($errors.Count -gt 0) {
    Write-Host "ERRORS ($($errors.Count)):" -ForegroundColor Red
    $errors | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
}

if ($warnings.Count -gt 0) {
    Write-Host "WARNINGS ($($warnings.Count)):" -ForegroundColor Yellow
    $warnings | ForEach-Object { Write-Host "  - $_" -ForegroundColor Yellow }
}

if ($errors.Count -gt 0) {
    exit 1
}

if ($Strict -and $warnings.Count -gt 0) {
    exit 1
}

exit 0
