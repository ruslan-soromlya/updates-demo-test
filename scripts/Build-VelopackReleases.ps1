[CmdletBinding()]
param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",

    [Parameter(Mandatory)]
    [string]$Version,

    [Parameter(Mandatory)]
    [string]$AppName,          # "Avalonia" or "Windows"

    [Parameter(Mandatory)]
    [string]$ProjectPath,      # relative to repo root, e.g. "DemoApp.Aval\DemoApp.Aval.csproj"

    [Parameter(Mandatory)]
    [string]$PackId,           # e.g. "DemoApp.Aval"

    [Parameter(Mandatory)]
    [string]$MainExe,          # e.g. "DemoApp.Aval.exe"

    [Parameter(Mandatory)]
    [string]$ReleaseDir,       # where vpk writes its output

    [string]$HomeMessage,
    [string]$UpdateSource      # Velopack feed URL baked into the app at build time
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

Write-Section "PACK $AppName"

if (-not $HomeMessage) { $HomeMessage = "Demo $Version" }

$publishDir = Join-Path $repoRoot "artifacts\publish\$AppName"
$project    = Join-Path $repoRoot $ProjectPath

Write-Host "[PUBLISH] $project -> $publishDir"

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

if ($LASTEXITCODE -ne 0) { throw "dotnet publish failed for $AppName" }

Write-Host "[VPK] Packing -> $ReleaseDir"

& vpk pack `
    --packId      $PackId `
    --packVersion $Version `
    --packDir     $publishDir `
    --mainExe     $MainExe `
    --outputDir   $ReleaseDir `
    --runtime     $Runtime

if ($LASTEXITCODE -ne 0) { throw "vpk pack failed for $AppName" }

Write-Section "PACK $AppName DONE"