$ErrorActionPreference = "Stop"

$repo = "AutoHotkey/Ahk2Exe"
$outDir = $PSScriptRoot + "\Ahk2Exe"
$zipPath = $PSScriptRoot + "\Ahk2Exe_download.zip"

try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Host "Fetching latest release from GitHub API..."
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/latest" -UseBasicParsing
    $asset = $release.assets | Where-Object { $_.name -match "Ahk2Exe.*\.zip$" } | Select-Object -First 1
    if (-not $asset) {
        Write-Error "Ahk2Exe.zip asset not found in latest release."
        exit 1
    }
    $url = $asset.browser_download_url
    Write-Host "Downloading from: $url"
    Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing

    if (Test-Path $outDir) {
        Remove-Item $outDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $outDir | Out-Null

    # Use Shell.Application for reliable extraction with non-ASCII paths
    $shell = New-Object -ComObject Shell.Application
    $zip = $shell.Namespace($zipPath)
    $dest = $shell.Namespace($outDir)
    $dest.CopyHere($zip.Items(), 16)

    Remove-Item $zipPath -Force
    Write-Host "Ahk2Exe installed successfully."
    exit 0
} catch {
    Write-Error "Download failed: $_"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force -ErrorAction SilentlyContinue }
    exit 1
}
