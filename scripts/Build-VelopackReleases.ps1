[CmdletBinding()]
param(
    [string]$Configuration = "Release",
    [string]$Runtime = "win-x64",
    [string]$AvaloniaReleaseDir,
    [string]$WindowsReleaseDir,
    [string]$VersionFile = ".release-version.json",
    [string]$Version,
    [switch]$NoIncrement,
    [string]$ReleaseNotes,
    [string]$DemoMessage,
    [string]$AvaloniaUpdateSource,
    [string]$WindowsUpdateSource
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$releaseRoot = Join-Path ([Environment]::GetFolderPath("LocalApplicationData")) "DemoApp\Releases"

if (-not $AvaloniaReleaseDir) {
    $AvaloniaReleaseDir = Join-Path $releaseRoot "demoaval"
}

if (-not $WindowsReleaseDir) {
    $WindowsReleaseDir = Join-Path $releaseRoot "demowindows"
}

$versionFilePath = if ([System.IO.Path]::IsPathRooted($VersionFile)) {
    $VersionFile
} else {
    Join-Path $repoRoot $VersionFile
}

function Assert-CommandExists {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$InstallHint
    )

    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) {
        throw "'$Name' was not found. $InstallHint"
    }
}

function Convert-ToFileVersion {
    param([Parameter(Mandatory = $true)][version]$SemanticVersion)

    return "{0}.{1}.{2}.0" -f $SemanticVersion.Major, $SemanticVersion.Minor, $SemanticVersion.Build
}

function Get-NextVersion {
    if ($Version) {
        return [version]$Version
    }

    if (-not (Test-Path $versionFilePath)) {
        return [version]"1.0.0"
    }

    $state = Get-Content $versionFilePath -Raw | ConvertFrom-Json
    $lastVersion = [version]$state.LastVersion

    if ($NoIncrement) {
        return $lastVersion
    }

    return [version]::new($lastVersion.Major, $lastVersion.Minor, $lastVersion.Build + 1)
}

function Save-Version {
    param([Parameter(Mandatory = $true)][version]$ReleaseVersion)

    $state = [ordered]@{
        LastVersion = $ReleaseVersion.ToString()
        UpdatedAt = (Get-Date).ToUniversalTime().ToString("o")
    }

    $state | ConvertTo-Json | Set-Content -Path $versionFilePath -Encoding UTF8
}

function New-DefaultReleaseNotes {
    param(
        [Parameter(Mandatory = $true)]
        [version]$ReleaseVersion,
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $releaseNotesDir = Join-Path $repoRoot "artifacts\release-notes"
    $releaseNotesPath = Join-Path $releaseNotesDir "$ReleaseVersion.md"

    New-Item -ItemType Directory -Path $releaseNotesDir -Force | Out-Null

    @(
        "# DemoApp $ReleaseVersion",
        "",
        "- Demo message changed to: $Message",
        "- Avalonia checks `$AvaloniaReleaseDir` for updates.",
        "- Windows checks `$WindowsReleaseDir` for updates.",
        "- Release packages include installer, portable, full, and delta artifacts when possible."
    ) | Set-Content -Path $releaseNotesPath -Encoding UTF8

    return $releaseNotesPath
}

function Publish-And-Pack {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $true)]
        [string]$ProjectPath,
        [Parameter(Mandatory = $true)]
        [string]$PackId,
        [Parameter(Mandatory = $true)]
        [string]$PackTitle,
        [Parameter(Mandatory = $true)]
        [string]$MainExe,
        [Parameter(Mandatory = $true)]
        [string]$ReleaseDir,
        [Parameter(Mandatory = $true)]
        [version]$ReleaseVersion,
        [Parameter(Mandatory = $true)]
        [string]$Message,
        [string]$UpdateSource,
        [string]$IconPath
    )

    $publishDir = Join-Path $repoRoot "artifacts\publish\$Name"
    $projectFullPath = Join-Path $repoRoot $ProjectPath
    $fileVersion = Convert-ToFileVersion $ReleaseVersion

    if (Test-Path $publishDir) {
        Remove-Item -LiteralPath $publishDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $publishDir -Force | Out-Null
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

    Write-Host "Publishing $Name $ReleaseVersion..."
    dotnet publish $projectFullPath `
        -c $Configuration `
        -r $Runtime `
        --self-contained true `
        -o $publishDir `
        -p:Version=$ReleaseVersion `
        -p:AssemblyVersion=$fileVersion `
        -p:FileVersion=$fileVersion `
        -p:InformationalVersion=$ReleaseVersion `
        -p:DemoMessage=$Message `
        -p:DemoUpdateSource=$UpdateSource

    $packArgs = @(
        "pack",
        "--packId", $PackId,
        "--packVersion", $ReleaseVersion.ToString(),
        "--packDir", $publishDir,
        "--mainExe", $MainExe,
        "--outputDir", $ReleaseDir,
        "--runtime", $Runtime,
        "--packTitle", $PackTitle
    )

    if ($IconPath) {
        $packArgs += @("--icon", (Join-Path $repoRoot $IconPath))
    }

    if ($ReleaseNotes) {
        $releaseNotesPath = if ([System.IO.Path]::IsPathRooted($ReleaseNotes)) {
            $ReleaseNotes
        } else {
            Join-Path $repoRoot $ReleaseNotes
        }

        $packArgs += @("--releaseNotes", $releaseNotesPath)
    }

    Write-Host "Packing $Name to $ReleaseDir..."
    & vpk @packArgs
}

Assert-CommandExists "dotnet" "Install the .NET SDK."
Assert-CommandExists "vpk" "Install Velopack CLI with: dotnet tool install -g vpk"

$releaseVersion = Get-NextVersion

if (-not $DemoMessage) {
    $DemoMessage = "Demo release $releaseVersion is now installed."
}

if (-not $ReleaseNotes) {
    $ReleaseNotes = New-DefaultReleaseNotes -ReleaseVersion $releaseVersion -Message $DemoMessage
}

Publish-And-Pack `
    -Name "DemoApp.Aval" `
    -ProjectPath "DemoApp.Aval\DemoApp.Aval.csproj" `
    -PackId "DemoApp.Aval" `
    -PackTitle "DemoApp Avalonia" `
    -MainExe "DemoApp.Aval.exe" `
    -ReleaseDir $AvaloniaReleaseDir `
    -ReleaseVersion $releaseVersion `
    -Message $DemoMessage `
    -UpdateSource $AvaloniaUpdateSource `
    -IconPath "DemoApp.Aval\Assets\avalonia-logo.ico"

Publish-And-Pack `
    -Name "DemoApp.Windows" `
    -ProjectPath "DemoApp.Windows\DemoApp.Windows.csproj" `
    -PackId "DemoApp.Windows" `
    -PackTitle "DemoApp Windows" `
    -MainExe "DemoApp.Windows.exe" `
    -ReleaseDir $WindowsReleaseDir `
    -ReleaseVersion $releaseVersion `
    -Message $DemoMessage `
    -UpdateSource $WindowsUpdateSource `
    -IconPath "DemoApp.Windows\wpfui-icon.ico"

Save-Version $releaseVersion

Write-Host ""
Write-Host "Created release $releaseVersion"
Write-Host "Demo message:      $DemoMessage"
Write-Host "Avalonia releases: $AvaloniaReleaseDir"
Write-Host "Windows releases:  $WindowsReleaseDir"
