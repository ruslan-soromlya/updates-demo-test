name: Build Demo Updates

on:
  workflow_dispatch:
    inputs:
      version:
        description: "Optional version override (default: 1.0.{run_number})"
        required: false
        type: string

      home_message:
        description: "Message shown on the app Home page after update"
        required: true
        type: string

      update_notes:
        description: "Shown in the update screen when a new version is available"
        required: true
        type: string

permissions:
  contents: write   # needed to push the version tag
  pages: write
  id-token: write

jobs:
  build:
    runs-on: windows-latest

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0   # full history so we can read/push tags

      - uses: actions/setup-dotnet@v4
        with:
          dotnet-version: 10.0.x

      - name: Install Velopack
        shell: pwsh
        run: |
          dotnet tool install -g vpk
          "$env:USERPROFILE\.dotnet\tools" | Out-File $env:GITHUB_PATH -Append

      # ── VERSION ────────────────────────────────────────────────────────────
      # Priority: manual input → latest git tag + 1 → 1.0.{run_number}
      - name: Resolve version
        shell: pwsh
        run: |
          $manual = "${{ inputs.version }}".Trim()

          if ($manual -ne "") {
            $version = $manual
            Write-Host "[VERSION] Using manual override: $version"
          } else {
            $latestTag = git tag --list "v*" |
              ForEach-Object { $_.Trim() } |
              Where-Object { $_ -match '^v(\d+)\.(\d+)\.(\d+)$' } |
              Select-Object @{ N='Raw'; E={ $_ } },
                            @{ N='Sort'; E={
                                $m = [regex]::Match($_, '^v(\d+)\.(\d+)\.(\d+)$')
                                [int]$m.Groups[1].Value * 1000000 +
                                [int]$m.Groups[2].Value * 1000 +
                                [int]$m.Groups[3].Value
                            }} |
              Sort-Object Sort -Descending |
              Select-Object -First 1 -ExpandProperty Raw

            if ($latestTag) {
              $m = [regex]::Match($latestTag, '^v(\d+)\.(\d+)\.(\d+)$')
              $version = "$($m.Groups[1].Value).$($m.Groups[2].Value).$([int]$m.Groups[3].Value + 1)"
              Write-Host "[VERSION] Incremented from tag ${latestTag}: $version"
            } else {
              $version = "1.0.${{ github.run_number }}"
              Write-Host "[VERSION] No tags found, using run_number: $version"
            }
          }

          "RELEASE_VERSION=$version" | Out-File $env:GITHUB_ENV -Append

      # ── FEEDS ──────────────────────────────────────────────────────────────
      - name: Set feed URLs
        shell: pwsh
        run: |
          $base = "https://${{ github.repository_owner }}.github.io/${{ github.event.repository.name }}"
          "AVALONIA_FEED=$base/demoaval"    | Out-File $env:GITHUB_ENV -Append
          "WINDOWS_FEED=$base/demowindows"  | Out-File $env:GITHUB_ENV -Append

      # ── RELEASE NOTES ──────────────────────────────────────────────────────
      - name: Write release notes file
        shell: pwsh
        run: |
          New-Item artifacts\release-notes -ItemType Directory -Force | Out-Null
          Set-Content artifacts\release-notes\latest.md @"
          ${{ inputs.update_notes }}
          "@ -Encoding UTF8

      # ── BUILD ──────────────────────────────────────────────────────────────
      - name: Build
        shell: pwsh
        run: |
          .\scripts\Build-VelopackReleases.ps1 `
            -Mode              CI `
            -Version           $env:RELEASE_VERSION `
            -HomeMessage       "${{ inputs.home_message }}" `
            -ReleaseNotes      "artifacts\release-notes\latest.md" `
            -AvaloniaUpdateSource $env:AVALONIA_FEED `
            -WindowsUpdateSource  $env:WINDOWS_FEED

      # ── TAG ────────────────────────────────────────────────────────────────
      # Push the version tag AFTER a successful build so it's only recorded
      # when the artifacts are actually going to be deployed.
      - name: Tag release
        shell: pwsh
        run: |
          git config user.name  "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git tag "v$env:RELEASE_VERSION"
          git push origin "v$env:RELEASE_VERSION"

      # ── PAGES UI ───────────────────────────────────────────────────────────
      - name: Copy GitHub Pages UI
        shell: pwsh
        run: |
          New-Item artifacts/pages -ItemType Directory -Force | Out-Null
          Copy-Item pages/index.html artifacts/pages/index.html -Force
          Write-Host "[OK] index.html copied"

      # ── DEBUG ──────────────────────────────────────────────────────────────
      - name: Debug artifacts
        shell: pwsh
        run: |
          Write-Host "=== ARTIFACTS TREE ==="
          Get-ChildItem artifacts -Recurse -ErrorAction SilentlyContinue

      # ── DEPLOY ─────────────────────────────────────────────────────────────
      - name: Upload Pages artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: artifacts/pages

      - name: Deploy to GitHub Pages
        uses: actions/deploy-pages@v4