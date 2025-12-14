$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "============================================"
Write-Host "Windows Terminal Installation Script"
Write-Host "============================================"
Write-Host ""

# Detect Windows version
$build = [System.Environment]::OSVersion.Version.Build
$isWin11 = $build -ge 22000
Write-Host "Windows Build: $build"
if ($isWin11) { Write-Host "Detected: Windows 11" } else { Write-Host "Detected: Windows 10" }
Write-Host ""

# Get latest stable release from GitHub
Write-Host "[1/3] Getting latest stable version..."
$api = "https://api.github.com/repos/microsoft/terminal/releases/latest"
$release = Invoke-RestMethod -Uri $api -UseBasicParsing
$version = $release.tag_name
Write-Host "Latest version: $version"
Write-Host ""

# Find correct asset
Write-Host "[2/3] Downloading..."
if ($isWin11) {
    $asset = $release.assets | Where-Object { $_.name -match '\.msixbundle$' -and $_.name -notmatch 'PreinstallKit' } | Select-Object -First 1
} else {
    $asset = $release.assets | Where-Object { $_.name -match 'Win10.*\.msixbundle$' } | Select-Object -First 1
    if (-not $asset) {
        $asset = $release.assets | Where-Object { $_.name -match '\.msixbundle$' -and $_.name -notmatch 'PreinstallKit' } | Select-Object -First 1
    }
}

if (-not $asset) {
    Write-Host "[Error] Could not find installer package." -ForegroundColor Red
    exit 1
}

$url = $asset.browser_download_url
$fileName = $asset.name
$outFile = "$env:TEMP\$fileName"
Write-Host "Package: $fileName"

Invoke-WebRequest -Uri $url -OutFile $outFile -UseBasicParsing
Write-Host "Download complete."
Write-Host ""

# Install
Write-Host "[3/3] Installing..."
Add-AppxPackage -Path $outFile
Write-Host ""
Write-Host "Installation complete!" -ForegroundColor Green

# Cleanup
Remove-Item $outFile -Force -ErrorAction SilentlyContinue
