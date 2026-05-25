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
# MODE PATH RESOLUTION
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
# PACK FUNCTION
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
        -c Release `
        -r win-x64 `
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
        --runtime win-x64
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

Write-Host "[VERSION] $version"
Write-Host "[MODE] $Mode"
Write-Host "[AVALONIA] $($paths.Avalonia)"
Write-Host "[WINDOWS] $($paths.Windows)"

# -----------------------------
# RELEASE NOTES
# -----------------------------
$notesDir = Join-Path $repoRoot "artifacts\release-notes"
New-Item $notesDir -ItemType Directory -Force | Out-Null

$notesFile = Join-Path $notesDir "latest.md"

if (-not $ReleaseNotes) {
    $ReleaseNotes = $notesFile
    @"
# Release $version
- $DemoMessage
"@ | Set-Content $notesFile -Encoding UTF8
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

Save-Version $version

Write-Section "BUILD DONE"
Write-Host "Version: $version"