param(
    [Parameter(Mandatory = $true)]
    [string]$TaskName,

    [string]$Status = "failed",

    [switch]$Preview,

    [switch]$Force
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot '_lib\Eol.ps1')

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$attemptsRoot = Join-Path $root ".ai\attempts"
$templatePath = Join-Path $attemptsRoot "_template.md"

if (-not (Test-Path -LiteralPath $templatePath)) {
    throw "Missing attempt template: $templatePath"
}

function ConvertTo-Slug {
    param([string]$Value)

    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace "[^a-z0-9]+", "-"
    $slug = $slug.Trim("-")

    if ([string]::IsNullOrWhiteSpace($slug)) {
        return "attempt"
    }

    return $slug
}

$date = Get-Date -Format "yyyy-MM-dd"
$slug = ConvertTo-Slug -Value $TaskName
$fileName = "$date-$slug.md"
$targetPath = Join-Path $attemptsRoot $fileName

$content = Get-Content -Raw -LiteralPath $templatePath
$content = $content.Replace("{{TASK_TITLE}}", $TaskName)
$content = $content.Replace("{{DATE}}", $date)
$content = $content -replace "Status: failed \| stalled \| abandoned \| superseded", "Status: $Status"

if ($Preview) {
    Write-Output "Preview target: $targetPath"
    Write-Output $content
    return
}

if ((Test-Path -LiteralPath $targetPath) -and -not $Force) {
    throw "Attempt note already exists: $targetPath. Use -Force to overwrite."
}

New-Item -ItemType Directory -Force -Path $attemptsRoot | Out-Null
Write-Utf8Lf -Path $targetPath -Content $content

Write-Output "Created attempt note: $targetPath"
