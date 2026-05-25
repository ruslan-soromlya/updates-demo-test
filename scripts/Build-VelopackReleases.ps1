[CmdletBinding()]
param(
    [ValidateSet("CI", "Local")]
    [string]$Mode = "CI",

    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",

    [string]$VersionFile = ".release-version.json",
    [string]$Version,
    [switch]$NoIncrement,

    [string]$ReleaseNotes,
    [string]$DemoMessage,

    [string]$AvaloniaUpdateSource,
    [string]$WindowsUpdateSource
)

$ErrorActionPreference = "Stop"

# -----------------------------
# ROOT
# -----------------------------
$repoRoot = Split-Path -Parent $PSScriptRoot

function Write-Section($text) {
    Write-Host ""
    Write-Host "==============================="
    Write-Host $text
    Write-Host "==============================="
    Write-Host ""
}

# -----------------------------
# VERSION
# -----------------------------
function Get-NextVersion {
    if ($Version) { return [version]$Version }

    $path = Join-Path $repoRoot $VersionFile

    if (-not (Test-Path $path)) {
        return [version]"1.0.0"
    }

    $state = Get-Content $path -Raw | ConvertFrom-Json
    $last = [version]$state.LastVersion

    if ($NoIncrement) { return $last }

    return [version]::new($last.Major, $last.Minor, $last.Build + 1)
}

function Save-Version($v) {
    $path = Join-Path $repoRoot $VersionFile

    @{
        LastVersion = $v.ToString()
        UpdatedAt   = (Get-Date).ToUniversalTime().ToString("o")
    } | ConvertTo-Json | Set-Content $path -Encoding UTF8
}

# -----------------------------
# PATH RESOLUTION
# -----------------------------
function Resolve-Paths {
    param($Mode)

    if ($Mode -eq "CI") {
        Write-Host "[MODE] CI"

        $pages = Join-Path $repoRoot "artifacts\pages"

        return @{
            PagesDir = $pages
            Avalonia = Join-Path $pages "demoaval\releases"
            Windows  = Join-Path $pages "demowindows\releases"
        }
    }

    Write-Host "[MODE] Local"

    $root = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "DemoApp\Releases"

    return @{
        PagesDir = $null
        Avalonia = Join-Path $root "demoaval"
        Windows  = Join-Path $root "demowindows"
    }
}

# -----------------------------
# PACK
# -----------------------------
function Publish-And-Pack {
    param(
        [string]$Name,
        [string]$ProjectPath,
        [string]$PackId,
        [string]$MainExe,
        [string]$ReleaseDir,
        [version]$Version,
        [string]$Message,
        [string]$UpdateSource
    )

    $publishDir = Join-Path $repoRoot "artifacts\publish\$Name"
    $project = Join-Path $repoRoot $ProjectPath

    Write-Host "[PACK] $Name -> $ReleaseDir"

    if (Test-Path $publishDir) {
        Remove-Item $publishDir -Recurse -Force
    }

    New-Item $publishDir -ItemType Directory -Force | Out-Null
    New-Item $ReleaseDir -ItemType Directory -Force | Out-Null

    dotnet publish $project `
        -c $Configuration `
        -r $Runtime `
        --self-contained true `
        -o $publishDir `
        -p:Version=$Version `
        -p:DemoMessage=$Message `
        -p:DemoUpdateSource=$UpdateSource

    & vpk pack `
        --packId $PackId `
        --packVersion $Version `
        --packDir $publishDir `
        --mainExe $MainExe `
        --outputDir $ReleaseDir `
        --runtime $Runtime
}


function Write-Manifest {
    param(
        [string]$PagesDir,
        [version]$Version,
        [string]$DemoMessage,
        [string]$BaseUrl
    )

    Write-Host "[MANIFEST] Generating index.json..."

    $releaseDir = Join-Path $PagesDir "releases"
    $manifestPath = Join-Path $releaseDir "index.json"

    New-Item $releaseDir -ItemType Directory -Force | Out-Null

    $existing = @()

    if (Test-Path $manifestPath) {
        try {
            $existing = Get-Content $manifestPath -Raw | ConvertFrom-Json
            Write-Host "[MANIFEST] Existing entries: $($existing.Count)"
        } catch {
            Write-Host "[WARN] Could not parse existing index.json - resetting"
        }
    }

    $entry = [ordered]@{
        version     = $Version.ToString()
        demoMessage = $DemoMessage
        builtAt     = (Get-Date).ToUniversalTime().ToString("o")
        notesUrl    = "$BaseUrl/releases/$Version/notes.md"
        avaloniaUrl = "$BaseUrl/demoaval/Setup.exe"
        windowsUrl  = "$BaseUrl/demowindows/Setup.exe"
    }

    $manifest = @($entry) + @($existing)

    $manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath -Encoding UTF8

    Write-Host "[MANIFEST] index.json written -> $manifestPath"
}

# -----------------------------
# START
# -----------------------------
Write-Section "BUILD START"

$version = Get-NextVersion
$paths = Resolve-Paths -Mode $Mode

if (-not $DemoMessage) {
    $DemoMessage = "Demo $version"
}

# FIXED BASE URL
$repo = $env:GITHUB_REPOSITORY
if ($repo) {
    $baseUrl = "https://$($repo.Split('/')[0]).github.io/$($repo.Split('/')[1])"
} else {
    $baseUrl = "http://localhost"
}

Write-Host "[VERSION] $version"
Write-Host "[MODE] $Mode"
Write-Host "[BASE_URL] $baseUrl"
Write-Host "[AVALONIA] $($paths.Avalonia)"
Write-Host "[WINDOWS] $($paths.Windows)"

# -----------------------------
# RELEASE NOTES
# -----------------------------
$notesDir = Join-Path $repoRoot "artifacts\release-notes"
New-Item $notesDir -ItemType Directory -Force | Out-Null

$notesFile = Join-Path $notesDir "latest.md"

if (-not $ReleaseNotes) {
    @"
# Release $version
- $DemoMessage
"@ | Set-Content $notesFile -Encoding UTF8

    $ReleaseNotes = $notesFile
}

# -----------------------------
# BUILD
# -----------------------------
Publish-And-Pack `
    -Name "Avalonia" `
    -ProjectPath "DemoApp.Aval\DemoApp.Aval.csproj" `
    -PackId "DemoApp.Aval" `
    -MainExe "DemoApp.Aval.exe" `
    -ReleaseDir $paths.Avalonia `
    -Version $version `
    -Message $DemoMessage `
    -UpdateSource $AvaloniaUpdateSource

Publish-And-Pack `
    -Name "Windows" `
    -ProjectPath "DemoApp.Windows\DemoApp.Windows.csproj" `
    -PackId "DemoApp.Windows" `
    -MainExe "DemoApp.Windows.exe" `
    -ReleaseDir $paths.Windows `
    -Version $version `
    -Message $DemoMessage `
    -UpdateSource $WindowsUpdateSource

# -----------------------------
# SAVE VERSION
# -----------------------------
Save-Version $version

# -----------------------------
# GENERATE MANIFEST (CI ONLY)
# -----------------------------
if ($Mode -eq "CI") {
    Write-Manifest `
        -PagesDir (Join-Path $repoRoot "artifacts\pages") `
        -Version $version `
        -DemoMessage $DemoMessage `
        -BaseUrl $baseUrl
}

Write-Section "BUILD DONE"
Write-Host "Version: $version"