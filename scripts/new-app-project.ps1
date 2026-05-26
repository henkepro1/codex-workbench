param(
    [Parameter(Mandatory = $true)]
    [string]$Title,

    [string]$Slug = "",

    [string]$Description = "",

    [string]$TemplatePath = "D:\GameProjects\_template-app",

    [string]$SourceRoot = "D:\GameProjects",

    [switch]$SetActive,

    [switch]$Force
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot '_lib\Eol.ps1')

$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function ConvertTo-Slug {
    param([string]$Value)
    $s = $Value.ToLowerInvariant()
    $s = $s -replace "[^a-z0-9]+", "-"
    $s = $s.Trim("-")
    if ([string]::IsNullOrWhiteSpace($s)) { throw "Could not derive a slug from: $Value" }
    return $s
}

if ([string]::IsNullOrWhiteSpace($Slug)) { $Slug = ConvertTo-Slug -Value $Title } else { $Slug = ConvertTo-Slug -Value $Slug }
if ([string]::IsNullOrWhiteSpace($Description)) { $Description = "Mobile/web application generated from the workbench app template." }

if (-not (Test-Path -LiteralPath $TemplatePath)) {
    throw "Template not found at $TemplatePath. Create it first or pass -TemplatePath."
}

$destination = Join-Path $SourceRoot $Slug
if (Test-Path -LiteralPath $destination) {
    if (-not $Force) {
        throw "Destination already exists: $destination. Pass -Force to overwrite (DANGEROUS, will wipe directory)."
    }
    Write-Output "Force-removing existing $destination"
    Remove-Item -LiteralPath $destination -Recurse -Force
}

Write-Output "Cloning template $TemplatePath -> $destination"
$excludeDirs = @("node_modules", "dist", "build", ".next", ".expo", "logs", "coverage")
$excludeFiles = @(".env", ".env.local")

# Use robocopy for fast, robust copy with exclusions
$rcArgs = @(
    "`"$TemplatePath`"",
    "`"$destination`"",
    "/E", "/COPY:DAT", "/R:1", "/W:1", "/NFL", "/NDL", "/NJH", "/NJS", "/NP",
    "/XD"
)
$rcArgs += $excludeDirs
$rcArgs += "/XF"
$rcArgs += $excludeFiles

$rc = Start-Process -FilePath "robocopy.exe" -ArgumentList $rcArgs -Wait -PassThru -NoNewWindow
# robocopy exit codes 0-7 are success
if ($rc.ExitCode -ge 8) {
    throw "robocopy failed with exit code $($rc.ExitCode)"
}

# Token replacement across text files
Write-Output "Token-replacing {{APP_TITLE}}, {{APP_SLUG}}, {{APP_DESCRIPTION}}"
$textExtensions = @(".ts", ".tsx", ".js", ".jsx", ".json", ".md", ".yml", ".yaml", ".prisma", ".env.example", ".gitattributes", ".gitignore", ".editorconfig", ".html", ".css")
Get-ChildItem -LiteralPath $destination -Recurse -File | Where-Object {
    $textExtensions -contains $_.Extension -or $_.Name -in @(".env.example", "Dockerfile", "Procfile")
} | ForEach-Object {
    $path = $_.FullName
    try {
        $content = [System.IO.File]::ReadAllText($path)
        $needsReplace = ($content -like "*{{APP_TITLE}}*") -or ($content -like "*{{APP_SLUG}}*") -or ($content -like "*{{APP_DESCRIPTION}}*")
        if ($needsReplace) {
            $content = $content.Replace("{{APP_TITLE}}", $Title).Replace("{{APP_SLUG}}", $Slug).Replace("{{APP_DESCRIPTION}}", $Description)
            [System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
        }
    } catch {
        Write-Warning "Skipped (read error): $path"
    }
}

# Initialize a fresh git repo in the new project (separate from workbench)
$gitDir = Join-Path $destination ".git"
if (-not (Test-Path -LiteralPath $gitDir)) {
    Write-Output "Initializing git in $destination"
    Push-Location $destination
    try {
        git init -q | Out-Null
        git add . | Out-Null
        # Use --allow-empty-message? No — we want a real first commit. Some env may not have user configured;
        # set a fallback identity for the first commit only.
        $cfgEmail = git config user.email 2>$null
        if (-not $cfgEmail) {
            git config user.email "no-reply@local.invalid" | Out-Null
            git config user.name "Local" | Out-Null
        }
        git commit -q -m "Initial commit from template" | Out-Null
    } catch {
        Write-Warning "git init/commit failed (continuing): $($_.Exception.Message)"
    } finally {
        Pop-Location
    }
}

# Create the workbench dossier via the existing script (Kind=general)
Write-Output "Creating workbench dossier"
& (Join-Path $PSScriptRoot "new-project.ps1") -Title $Title -Slug $Slug -SourcePath $destination -Kind "general" | Out-Null

# Append run instructions to project workflow.md
$workflowPath = Join-Path $root ("projects\$Slug\map\workflow.md")
if (Test-Path -LiteralPath $workflowPath) {
    $current = [System.IO.File]::ReadAllText($workflowPath)
    $append = @"

## How to run

This project was generated from the workbench app template ($TemplatePath).

``````powershell
cd $destination
pnpm install
pnpm dev      # auto-runs env+db setup, migrations, and seed on first run
``````

That's it. API on <http://localhost:4000>, app on <http://localhost:8081>. In the Metro terminal: ``w`` opens Expo web, ``i``/``a`` open iOS/Android simulators.

### Other useful scripts

- ``pnpm setup``       force a full setup re-run (useful after ``pnpm db:reset``)
- ``pnpm db:reset``    wipe and re-migrate the database
- ``pnpm db:studio``   open Prisma Studio (visual DB inspector)
- ``pnpm db:down``     stop the Postgres container
- ``pnpm test``        run all suites

### Layout

- ``apps/api/``        Fastify + Prisma backend (TypeScript)
- ``apps/mobile/``     Expo (RN + web) frontend (TypeScript)
- ``packages/shared/`` zod DTOs shared between the two
- ``scripts/setup.mjs`` first-run bootstrap (env + docker + migrations + seed)

"@
    [System.IO.File]::WriteAllText($workflowPath, $current + $append, [System.Text.UTF8Encoding]::new($false))
}

# Optionally update workbench .env
if ($SetActive) {
    $envPath = Join-Path $root ".env"
    $envContent = @"
WORKBENCH_ACTIVE_PROJECT=$Slug
WORKBENCH_ACTIVE_SOURCE_PATH=$destination
WORKBENCH_ACTIVE_TITLE=$Title
WORKBENCH_ACTIVE_KIND=general
"@
    Write-Utf8Lf -Path $envPath -Content $envContent
    Write-Output "Set $Slug as active project in .env"
}

Write-Output ""
Write-Output "Done. Next steps:"
Write-Output "  1. cd `"$destination`""
Write-Output "  2. Copy-Item .env.example .env  (then fill secrets)"
Write-Output "  3. pnpm install"
Write-Output "  4. pnpm db:up && pnpm db:migrate"
Write-Output "  5. pnpm dev"
Write-Output ""
Write-Output "Workbench dossier:  projects/$Slug/"
Write-Output "Source code:        $destination"
