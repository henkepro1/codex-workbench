param(
    [Parameter(Mandatory = $true)]
    [string]$Slug,

    [ValidateSet("EditMode", "PlayMode", "All")]
    [string]$TestMode = "EditMode",

    [string]$UnityPath = "",

    [int]$TimeoutSeconds = 1800,

    [switch]$CommandOnly
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")

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

function Find-Unity {
    param(
        [string]$RequestedPath,
        [string]$UnityVersion
    )

    if (-not [string]::IsNullOrWhiteSpace($RequestedPath)) {
        if (-not (Test-Path -LiteralPath $RequestedPath)) {
            throw "Unity executable not found: $RequestedPath"
        }
        return (Resolve-Path -LiteralPath $RequestedPath).Path
    }

    $versionRoot = Join-Path "D:\Unity" $UnityVersion
    $candidate = Join-Path $versionRoot "Editor\Unity.exe"
    if (Test-Path -LiteralPath $candidate) {
        return (Resolve-Path -LiteralPath $candidate).Path
    }

    $fallbacks = @(Get-ChildItem -LiteralPath "D:\Unity" -Recurse -Filter "Unity.exe" -File -ErrorAction SilentlyContinue | Sort-Object FullName)
    if ($fallbacks.Count -eq 1) {
        return $fallbacks[0].FullName
    }

    throw "Could not locate Unity $UnityVersion under D:\Unity. Pass -UnityPath explicitly."
}

function Get-Unity-Version {
    param([string]$ProjectPath)

    $versionPath = Join-Path $ProjectPath "ProjectSettings\ProjectVersion.txt"
    if (-not (Test-Path -LiteralPath $versionPath)) {
        throw "Missing Unity project version file: $versionPath"
    }

    foreach ($line in Get-Content -LiteralPath $versionPath) {
        if ($line -match "^m_EditorVersion:\s*(.+)$") {
            return $Matches[1].Trim()
        }
    }

    throw "Could not parse Unity version from $versionPath"
}

function Get-Test-Summary {
    param([string]$ResultPath)

    if (-not (Test-Path -LiteralPath $ResultPath)) {
        return [pscustomobject]@{
            total = 0
            passed = 0
            failed = 0
            skipped = 0
            failures = @("Unity did not produce a test result XML file.")
        }
    }

    [xml]$xml = Get-Content -Raw -LiteralPath $ResultPath
    $rootNode = $xml.DocumentElement

    $total = 0
    $passed = 0
    $failed = 0
    $skipped = 0

    if ($rootNode.HasAttribute("total")) { $total = [int]$rootNode.GetAttribute("total") }
    if ($rootNode.HasAttribute("passed")) { $passed = [int]$rootNode.GetAttribute("passed") }
    if ($rootNode.HasAttribute("failed")) { $failed = [int]$rootNode.GetAttribute("failed") }
    if ($rootNode.HasAttribute("skipped")) { $skipped = [int]$rootNode.GetAttribute("skipped") }

    $failures = @()
    $failedNodes = @($xml.SelectNodes("//*[@result='Failed' or @label='Error']"))

    foreach ($node in $failedNodes | Select-Object -First 20) {
        $name = $node.fullname
        if ([string]::IsNullOrWhiteSpace($name)) {
            $name = $node.name
        }
        $messageNode = $node.SelectSingleNode("failure/message")
        $message = if ($messageNode) { ($messageNode.InnerText -replace "\s+", " ").Trim() } else { "No failure message." }
        $failures += "$name - $message"
    }

    return [pscustomobject]@{
        total = $total
        passed = $passed
        failed = $failed
        skipped = $skipped
        failures = @($failures)
    }
}

$Slug = ConvertTo-Slug -Value $Slug
$projectIndexPath = Join-Path (Join-Path (Join-Path $root "projects") $Slug) ".ai\index.json"

if (-not (Test-Path -LiteralPath $projectIndexPath)) {
    throw "Project dossier not found: projects/$Slug"
}

$projectIndex = Get-Content -Raw -LiteralPath $projectIndexPath | ConvertFrom-Json
$projectPath = $projectIndex.source_path

if ([string]::IsNullOrWhiteSpace($projectPath) -or -not (Test-Path -LiteralPath $projectPath)) {
    throw "Unity project source path not found for $Slug`: $projectPath"
}

$projectPath = (Resolve-Path -LiteralPath $projectPath).Path
$unityVersion = Get-Unity-Version -ProjectPath $projectPath
$unityExe = Find-Unity -RequestedPath $UnityPath -UnityVersion $unityVersion

$outputRoot = Join-Path (Join-Path (Join-Path $root "projects") $Slug) ".ai\tmp\unity-tests"
New-Item -ItemType Directory -Force -Path $outputRoot | Out-Null

$stamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
$resultPath = Join-Path $outputRoot "$stamp-$TestMode-results.xml"
$logPath = Join-Path $outputRoot "$stamp-$TestMode-unity.log"

$arguments = @(
    "-batchmode",
    "-quit",
    "-projectPath", $projectPath,
    "-runTests",
    "-testResults", $resultPath,
    "-logFile", $logPath
)

if ($TestMode -ne "All") {
    $arguments += @("-testPlatform", $TestMode)
}

Write-Output "Unity: $unityExe"
Write-Output "Project: $projectPath"
Write-Output "Mode: $TestMode"
Write-Output "Results: $resultPath"
Write-Output "Log: $logPath"

if ($CommandOnly) {
    Write-Output ""
    Write-Output "Command:"
    Write-Output "`"$unityExe`" $($arguments -join ' ')"
    return
}

$process = Start-Process -FilePath $unityExe -ArgumentList $arguments -Wait -PassThru -WindowStyle Hidden
$summary = Get-Test-Summary -ResultPath $resultPath

Write-Output ""
Write-Output "PASS: $($summary.passed)   FAIL: $($summary.failed)   SKIP: $($summary.skipped)   TOTAL: $($summary.total)"

if ($summary.failures.Count -gt 0) {
    Write-Output "Failures:"
    foreach ($failure in $summary.failures) {
        Write-Output "  - $failure"
    }
}

if ($process.ExitCode -ne 0 -or $summary.failed -gt 0) {
    exit 1
}
