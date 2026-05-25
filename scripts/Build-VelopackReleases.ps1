[CmdletBinding()]
param(
    [ValidateSet("CI", "Local")]
    [string]$Mode = "CI",

    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",

    [Parameter(Mandatory)]
    [string]$Version,

    [string]$ReleaseNotes,
    [string]$HomeMessage,

    [string]$AvaloniaUpdateSource,
    [string]$WindowsUpdateSource
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot

function Write-Section($text) {
    Write-Host ""
    Write-Host "==============================="
    Write-Host $text
    Write-Host "==============================="
    Write-Host ""
}

function Resolve-Paths {
    if ($Mode -eq "CI") {
        $pages = Join-Path $repoRoot "artifacts\pages"
        return @{
            PagesDir = $pages
            Avalonia = Join-Path $pages "demoaval\releases"
            Windows  = Join-Path $pages "demowindows\releases"
        }
    }

    $root = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "DemoApp\Releases"
    return @{
        PagesDir = $null
        Avalonia = Join-Path $root "demoaval"
        Windows  = Join-Path $root "demowindows"
    }
}

function Publish-And-Pack {
    param(
        [string]$Name,
        [string]$ProjectPath,
        [string]$PackId,
        [string]$MainExe,
        [string]$ReleaseDir,
        [string]$Version,
        [string]$HomeMessage,
        [string]$UpdateSource
    )

    $publishDir = Join-Path $repoRoot "artifacts\publish\$Name"
    $project    = Join-Path $repoRoot $ProjectPath

    Write-Host "[PACK] $Name -> $ReleaseDir"

    if (Test-Path $publishDir) { Remove-Item $publishDir -Recurse -Force }
    New-Item $publishDir -ItemType Directory -Force | Out-Null
    New-Item $ReleaseDir -ItemType Directory -Force | Out-Null

    dotnet publish $project `
        -c $Configuration `
        -r $Runtime `
        --self-contained true `
        -o $publishDir `
        -p:Version=$Version `
        -p:HomeMessage=$HomeMessage `
        -p:DemoUpdateSource=$UpdateSource

    & vpk pack `
        --packId      $PackId `
        --packVersion $Version `
        --packDir     $publishDir `
        --mainExe     $MainExe `
        --outputDir   $ReleaseDir `
        --runtime     $Runtime
}

function Write-Manifest {
    param(
        [string]$PagesDir,
        [string]$Version,
        [string]$HomeMessage,
        [string]$BaseUrl,
        [string]$ReleaseNotesContent
    )

    Write-Host "[MANIFEST] Generating index.json..."

    $releaseDir   = Join-Path $PagesDir "releases"
    $manifestPath = Join-Path $releaseDir "index.json"
    $notesDir     = Join-Path $releaseDir $Version
    $notesPath    = Join-Path $notesDir "notes.md"

    New-Item $releaseDir -ItemType Directory -Force | Out-Null
    New-Item $notesDir   -ItemType Directory -Force | Out-Null

    # Write release notes next to the manifest so the URL resolves
    Set-Content $notesPath $ReleaseNotesContent -Encoding UTF8
    Write-Host "[MANIFEST] notes.md written -> $notesPath"

    $existing = @()
    if (Test-Path $manifestPath) {
        try {
            $existing = Get-Content $manifestPath -Raw | ConvertFrom-Json
            Write-Host "[MANIFEST] Existing entries: $($existing.Count)"
        } catch {
            Write-Host "[WARN] Could not parse existing index.json — resetting"
        }
    }

    $entry = [ordered]@{
        version     = $Version
        homeMessage = $HomeMessage
        builtAt     = (Get-Date).ToUniversalTime().ToString("o")
        notesUrl    = "$BaseUrl/releases/$Version/notes.md"
        avaloniaUrl = "$BaseUrl/demoaval/Setup.exe"
        windowsUrl  = "$BaseUrl/demowindows/Setup.exe"
    }

    $manifest = @($entry) + @($existing)
    $manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath -Encoding UTF8
    Write-Host "[MANIFEST] index.json written -> $manifestPath"
}

# ── START ────────────────────────────────────────────────────────────────────

Write-Section "BUILD START"

$paths = Resolve-Paths

$repo = $env:GITHUB_REPOSITORY
$baseUrl = if ($repo) {
    "https://$($repo.Split('/')[0]).github.io/$($repo.Split('/')[1])"
} else {
    "http://localhost"
}

if (-not $HomeMessage) { $HomeMessage = "Demo $Version" }

$notesContent = if ($ReleaseNotes -and (Test-Path $ReleaseNotes)) {
    Get-Content $ReleaseNotes -Raw
} else {
    "# Release $Version`n- $HomeMessage"
}

Write-Host "[VERSION]  $Version"
Write-Host "[MODE]     $Mode"
Write-Host "[BASE_URL] $baseUrl"
Write-Host "[AVALONIA] $($paths.Avalonia)"
Write-Host "[WINDOWS]  $($paths.Windows)"

# ── BUILD ────────────────────────────────────────────────────────────────────

Publish-And-Pack `
    -Name             "Avalonia" `
    -ProjectPath      "DemoApp.Aval\DemoApp.Aval.csproj" `
    -PackId           "DemoApp.Aval" `
    -MainExe          "DemoApp.Aval.exe" `
    -ReleaseDir       $paths.Avalonia `
    -Version          $Version `
    -HomeMessage      $HomeMessage `
    -UpdateSource     $AvaloniaUpdateSource

Publish-And-Pack `
    -Name             "Windows" `
    -ProjectPath      "DemoApp.Windows\DemoApp.Windows.csproj" `
    -PackId           "DemoApp.Windows" `
    -MainExe          "DemoApp.Windows.exe" `
    -ReleaseDir       $paths.Windows `
    -Version          $Version `
    -HomeMessage      $HomeMessage `
    -UpdateSource     $WindowsUpdateSource

# ── MANIFEST (CI only) ───────────────────────────────────────────────────────

if ($Mode -eq "CI") {
    Write-Manifest `
        -PagesDir            (Join-Path $repoRoot "artifacts\pages") `
        -Version             $Version `
        -HomeMessage         $HomeMessage `
        -BaseUrl             $baseUrl `
        -ReleaseNotesContent $notesContent
}

Write-Section "BUILD DONE"
Write-Host "Version: $Version"