param(
    [Parameter(Mandatory = $true)]
    [string]$Slug,

    [string]$SourcePath = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot '_lib\Eol.ps1')

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

function Read-JsonFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing JSON file: $Path"
    }

    return Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json
}

function Get-RelativePath {
    param(
        [string]$BasePath,
        [string]$FullPath
    )

    $base = [System.IO.Path]::GetFullPath($BasePath).TrimEnd('\')
    $full = [System.IO.Path]::GetFullPath($FullPath)

    if ($full.StartsWith($base, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $full.Substring($base.Length + 1)
    }

    return $FullPath
}

function Get-UnityVersion {
    param([string]$UnityRoot)

    $versionPath = Join-Path $UnityRoot "ProjectSettings\ProjectVersion.txt"
    if (-not (Test-Path -LiteralPath $versionPath)) {
        return $null
    }

    $version = $null
    $revision = $null

    foreach ($line in Get-Content -LiteralPath $versionPath) {
        if ($line -match "^m_EditorVersion:\s*(.+)$") {
            $version = $Matches[1].Trim()
        }
        elseif ($line -match "^m_EditorVersionWithRevision:\s*(.+)$") {
            $revision = $Matches[1].Trim()
        }
    }

    return [pscustomobject]@{
        version = $version
        revision = $revision
        path = "ProjectSettings/ProjectVersion.txt"
    }
}

function Get-PackageSummary {
    param([string]$UnityRoot)

    $manifestPath = Join-Path $UnityRoot "Packages\manifest.json"
    if (-not (Test-Path -LiteralPath $manifestPath)) {
        return [pscustomobject]@{ path = $null; count = 0; dependencies = @() }
    }

    $manifest = Get-Content -Raw -LiteralPath $manifestPath | ConvertFrom-Json
    $dependencies = @()

    if ($manifest.dependencies) {
        foreach ($property in $manifest.dependencies.PSObject.Properties) {
            $dependencies += [pscustomobject]@{
                name = $property.Name
                version = [string]$property.Value
            }
        }
    }

    return [pscustomobject]@{
        path = "Packages/manifest.json"
        count = $dependencies.Count
        dependencies = @($dependencies | Sort-Object name)
    }
}

function Get-PackageLockSummary {
    param([string]$UnityRoot)

    $lockPath = Join-Path $UnityRoot "Packages\packages-lock.json"
    if (-not (Test-Path -LiteralPath $lockPath)) {
        return [pscustomobject]@{ path = $null; count = 0; dependencies = @() }
    }

    $lock = Get-Content -Raw -LiteralPath $lockPath | ConvertFrom-Json
    $dependencies = @()

    if ($lock.dependencies) {
        foreach ($property in $lock.dependencies.PSObject.Properties) {
            $value = $property.Value
            $dependencies += [pscustomobject]@{
                name = $property.Name
                version = [string]$value.version
                depth = [int]$value.depth
                source = [string]$value.source
            }
        }
    }

    return [pscustomobject]@{
        path = "Packages/packages-lock.json"
        count = $dependencies.Count
        dependencies = @($dependencies | Sort-Object name)
    }
}

function Get-BuildScenes {
    param([string]$UnityRoot)

    $settingsPath = Join-Path $UnityRoot "ProjectSettings\EditorBuildSettings.asset"
    if (-not (Test-Path -LiteralPath $settingsPath)) {
        return @()
    }

    $scenes = @()
    $enabled = $null

    foreach ($line in Get-Content -LiteralPath $settingsPath) {
        if ($line -match "enabled:\s*(\d+)") {
            $enabled = [int]$Matches[1]
        }
        elseif ($line -match "path:\s*(.+)$") {
            $path = $Matches[1].Trim()
            if (-not [string]::IsNullOrWhiteSpace($path)) {
                $scenes += [pscustomobject]@{
                    path = $path
                    enabled = ($enabled -eq 1)
                }
            }
            $enabled = $null
        }
    }

    return @($scenes)
}

function Get-TagManagerSummary {
    param([string]$UnityRoot)

    $tagManagerPath = Join-Path $UnityRoot "ProjectSettings\TagManager.asset"
    $tags = @()
    $layers = @()
    $sortingLayers = @()

    if (-not (Test-Path -LiteralPath $tagManagerPath)) {
        return [pscustomobject]@{ tags = @(); layers = @(); sorting_layers = @() }
    }

    $state = ""
    foreach ($line in Get-Content -LiteralPath $tagManagerPath) {
        if ($line -match "^\s*tags:") {
            $state = "tags"
            continue
        }
        if ($line -match "^\s*layers:") {
            $state = "layers"
            continue
        }
        if ($line -match "^\s*m_SortingLayers:") {
            $state = "sorting"
            continue
        }
        if ($line -match "^\s*m_RenderingLayers:") {
            $state = "rendering"
            continue
        }

        if (($state -eq "tags") -and ($line -match "^\s*-\s*(.*)$")) {
            $value = $Matches[1].Trim()
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $tags += $value
            }
        }
        elseif (($state -eq "layers") -and ($line -match "^\s*-\s*(.*)$")) {
            $value = $Matches[1].Trim()
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $layers += $value
            }
        }
        elseif (($state -eq "sorting") -and ($line -match "^\s*-\s*name:\s*(.*)$")) {
            $value = $Matches[1].Trim()
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                $sortingLayers += $value
            }
        }
    }

    return [pscustomobject]@{
        tags = @($tags)
        layers = @($layers)
        sorting_layers = @($sortingLayers)
    }
}

function Get-ScriptableObjectTypes {
    param([string]$UnityRoot)

    $assetsRoot = Join-Path $UnityRoot "Assets"
    $types = @()

    if (-not (Test-Path -LiteralPath $assetsRoot)) {
        return @()
    }

    $files = @(Get-ChildItem -LiteralPath $assetsRoot -Recurse -File -Filter "*.cs" -ErrorAction SilentlyContinue)

    foreach ($file in $files) {
        $lines = @(Get-Content -LiteralPath $file.FullName -ErrorAction SilentlyContinue)

        for ($index = 0; $index -lt $lines.Count; $index++) {
            $line = $lines[$index]
            if ($line -match "class\s+([A-Za-z_][A-Za-z0-9_]*)\s*(:|where|$).*ScriptableObject") {
                $className = $Matches[1]
                $windowStart = [Math]::Max(0, $index - 6)
                $attributeText = ($lines[$windowStart..$index] -join " ")
                $menuName = $null
                $fileName = $null

                if ($attributeText -match "menuName\s*=\s*""([^""]+)""") {
                    $menuName = $Matches[1]
                }
                if ($attributeText -match "fileName\s*=\s*""([^""]+)""") {
                    $fileName = $Matches[1]
                }

                $types += [pscustomobject]@{
                    class = $className
                    script = (Get-RelativePath -BasePath $UnityRoot -FullPath $file.FullName).Replace('\', '/')
                    menu_name = $menuName
                    file_name = $fileName
                }
            }
        }
    }

    return @($types | Sort-Object class, script)
}

function Get-AssetList {
    param(
        [string]$UnityRoot,
        [string[]]$Extensions
    )

    $assetsRoot = Join-Path $UnityRoot "Assets"
    if (-not (Test-Path -LiteralPath $assetsRoot)) {
        return @()
    }

    return @(Get-ChildItem -LiteralPath $assetsRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $Extensions -contains $_.Extension.ToLowerInvariant() } |
        Sort-Object FullName |
        ForEach-Object {
            [pscustomobject]@{
                path = (Get-RelativePath -BasePath $UnityRoot -FullPath $_.FullName).Replace('\', '/')
                bytes = $_.Length
                modified = $_.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ssK")
            }
        })
}

function Get-HierarchySources {
    param([string]$UnityRoot)

    $roots = @($UnityRoot)
    $parent = Split-Path -Parent $UnityRoot
    if (-not [string]::IsNullOrWhiteSpace($parent)) {
        $roots += $parent
    }

    $sources = @()
    foreach ($candidateRoot in $roots | Select-Object -Unique) {
        if (-not (Test-Path -LiteralPath $candidateRoot)) {
            continue
        }

        $files = @(Get-ChildItem -LiteralPath $candidateRoot -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match "(?i)(editor)?hierarchy|handoff" -and $_.Extension -in @(".md", ".txt") })

        foreach ($file in $files) {
            $sources += [pscustomobject]@{
                path = $file.FullName
                bytes = $file.Length
                modified = $file.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ssK")
            }
        }
    }

    return @($sources | Sort-Object path)
}

function Get-SettingsFiles {
    param([string]$UnityRoot)

    $settingsRoot = Join-Path $UnityRoot "ProjectSettings"
    if (-not (Test-Path -LiteralPath $settingsRoot)) {
        return @()
    }

    $importantPattern = "Graphics|Quality|Input|Physics|TagManager|EditorBuild|ProjectSettings|Render|URP"
    return @(Get-ChildItem -LiteralPath $settingsRoot -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match $importantPattern } |
        Sort-Object Name |
        ForEach-Object {
            [pscustomobject]@{
                path = "ProjectSettings/$($_.Name)"
                bytes = $_.Length
                modified = $_.LastWriteTime.ToString("yyyy-MM-ddTHH:mm:ssK")
            }
        })
}

$Slug = ConvertTo-Slug -Value $Slug
$projectRoot = Join-Path (Join-Path $root "projects") $Slug
$projectIndexPath = Join-Path $projectRoot ".ai\index.json"

if (-not (Test-Path -LiteralPath $projectIndexPath)) {
    throw "Project dossier not found: projects/$Slug"
}

$projectIndex = Read-JsonFile -Path $projectIndexPath

if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    $SourcePath = $projectIndex.source_path
}

if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    throw "No Unity source path provided and projects/$Slug/.ai/index.json has no source_path."
}

$unityRoot = Resolve-Path -LiteralPath $SourcePath
$required = @("Assets", "Packages", "ProjectSettings")
foreach ($directoryName in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $unityRoot $directoryName))) {
        throw "Source path does not look like a Unity project root. Missing: $directoryName"
    }
}

$unityContextRoot = Join-Path $projectRoot ".ai\engine\unity"
New-Item -ItemType Directory -Force -Path $unityContextRoot | Out-Null

$now = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
$unityVersion = Get-UnityVersion -UnityRoot $unityRoot
$packages = Get-PackageSummary -UnityRoot $unityRoot
$packageLock = Get-PackageLockSummary -UnityRoot $unityRoot
$buildScenes = @(Get-BuildScenes -UnityRoot $unityRoot)
$tagManager = Get-TagManagerSummary -UnityRoot $unityRoot
$scenes = @(Get-AssetList -UnityRoot $unityRoot -Extensions @(".unity"))
$prefabs = @(Get-AssetList -UnityRoot $unityRoot -Extensions @(".prefab"))
$shaders = @(Get-AssetList -UnityRoot $unityRoot -Extensions @(".shader", ".shadergraph"))
$scriptableTypes = @(Get-ScriptableObjectTypes -UnityRoot $unityRoot)
$settingsFiles = @(Get-SettingsFiles -UnityRoot $unityRoot)
$hierarchySources = @(Get-HierarchySources -UnityRoot $unityRoot)

$assetExtensions = @(Get-ChildItem -LiteralPath (Join-Path $unityRoot "Assets") -Recurse -File -ErrorAction SilentlyContinue |
    Group-Object Extension |
    Sort-Object Name |
    ForEach-Object {
        [pscustomobject]@{
            extension = if ([string]::IsNullOrWhiteSpace($_.Name)) { "(none)" } else { $_.Name }
            count = $_.Count
        }
    })

$settings = [pscustomobject]@{
    schema_version = 1
    generated_at = $now
    unity_version = $unityVersion
    packages = $packages
    package_lock = $packageLock
    build_scenes = @($buildScenes)
    tags = @($tagManager.tags)
    layers = @($tagManager.layers)
    sorting_layers = @($tagManager.sorting_layers)
    important_settings_files = @($settingsFiles)
}

$sceneData = [pscustomobject]@{
    schema_version = 1
    generated_at = $now
    count = $scenes.Count
    build_scenes = @($buildScenes)
    scenes = @($scenes)
}

$prefabData = [pscustomobject]@{
    schema_version = 1
    generated_at = $now
    count = $prefabs.Count
    prefabs = @($prefabs)
}

$scriptableData = [pscustomobject]@{
    schema_version = 1
    generated_at = $now
    type_count = $scriptableTypes.Count
    asset_file_count = (@(Get-ChildItem -LiteralPath (Join-Path $unityRoot "Assets") -Recurse -File -Filter "*.asset" -ErrorAction SilentlyContinue)).Count
    types = @($scriptableTypes)
}

$shaderData = [pscustomobject]@{
    schema_version = 1
    generated_at = $now
    count = $shaders.Count
    shaders = @($shaders)
}

$hierarchyData = [pscustomobject]@{
    schema_version = 1
    generated_at = $now
    note = "Hierarchy context is linked from known exported docs. Scene/prefab YAML is not deep-parsed by this lean scan."
    sources = @($hierarchySources)
}

$index = [pscustomobject]@{
    schema_version = 1
    generated_at = $now
    engine = "unity"
    source_path = [string]$unityRoot
    unity_version = $unityVersion.version
    unity_revision = $unityVersion.revision
    paths = [pscustomobject]@{
        settings = "projects/$Slug/.ai/engine/unity/settings.json"
        scenes = "projects/$Slug/.ai/engine/unity/scenes.json"
        prefabs = "projects/$Slug/.ai/engine/unity/prefabs.json"
        scriptable_objects = "projects/$Slug/.ai/engine/unity/scriptable-objects.json"
        shaders = "projects/$Slug/.ai/engine/unity/shaders.json"
        hierarchy_sources = "projects/$Slug/.ai/engine/unity/hierarchy-sources.json"
    }
    counts = [pscustomobject]@{
        packages = $packages.count
        package_lock_entries = $packageLock.count
        scenes = $scenes.Count
        build_scenes = @($buildScenes | Where-Object { $_.enabled }).Count
        prefabs = $prefabs.Count
        scriptable_object_types = $scriptableTypes.Count
        shaders = $shaders.Count
        hierarchy_sources = $hierarchySources.Count
    }
    asset_extension_counts = @($assetExtensions)
    refresh_policy = "Refresh after Unity-relevant code, scene, prefab, ScriptableObject, shader, layer, or settings changes."
}

Write-Utf8Lf -Path (Join-Path $unityContextRoot "settings.json") -Content ($settings | ConvertTo-Json -Depth 12)
Write-Utf8Lf -Path (Join-Path $unityContextRoot "scenes.json") -Content ($sceneData | ConvertTo-Json -Depth 12)
Write-Utf8Lf -Path (Join-Path $unityContextRoot "prefabs.json") -Content ($prefabData | ConvertTo-Json -Depth 12)
Write-Utf8Lf -Path (Join-Path $unityContextRoot "scriptable-objects.json") -Content ($scriptableData | ConvertTo-Json -Depth 12)
Write-Utf8Lf -Path (Join-Path $unityContextRoot "shaders.json") -Content ($shaderData | ConvertTo-Json -Depth 12)
Write-Utf8Lf -Path (Join-Path $unityContextRoot "hierarchy-sources.json") -Content ($hierarchyData | ConvertTo-Json -Depth 12)
Write-Utf8Lf -Path (Join-Path $unityContextRoot "index.json") -Content ($index | ConvertTo-Json -Depth 12)

if (-not ($projectIndex.PSObject.Properties.Name -contains "kind")) {
    $projectIndex | Add-Member -NotePropertyName "kind" -NotePropertyValue "unity"
}
else {
    $projectIndex.kind = "unity"
}

if (-not ($projectIndex.ai_paths.PSObject.Properties.Name -contains "engine")) {
    $projectIndex.ai_paths | Add-Member -NotePropertyName "engine" -NotePropertyValue "projects/$Slug/.ai/engine"
}
if (-not ($projectIndex.ai_paths.PSObject.Properties.Name -contains "unity_context")) {
    $projectIndex.ai_paths | Add-Member -NotePropertyName "unity_context" -NotePropertyValue "projects/$Slug/.ai/engine/unity/index.json"
}

$projectIndex.source_path = [string]$unityRoot
$projectIndex.last_updated = $now
Write-Utf8Lf -Path $projectIndexPath -Content ($projectIndex | ConvertTo-Json -Depth 12)

& (Join-Path $PSScriptRoot "update-project-index.ps1") -Slug $Slug | Out-Null

Write-Output "Updated Unity context: projects/$Slug/.ai/engine/unity/index.json"
