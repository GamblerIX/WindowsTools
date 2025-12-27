# 安装 Windows Terminal
# 一键安装或更新至最新稳定版 Windows Terminal 

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "正在请求管理员权限..." -ForegroundColor Yellow
    Start-Process -FilePath pwsh.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -ErrorAction SilentlyContinue
    if ($?) { exit }
    Start-Process -FilePath powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Windows Terminal 安装/更新工具" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$current = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue
$currentVersion = if ($current) { $current.Version } else { $null }
if ($currentVersion) { Write-Host "当前版本: $currentVersion" -ForegroundColor Gray }

$api = "https://api.github.com/repos/microsoft/terminal/releases/latest"
$release = Invoke-RestMethod -Uri $api -UseBasicParsing
$latestVersion = $release.tag_name -replace '^v',''
Write-Host "最新版本: $latestVersion"

if ($currentVersion -and ([System.Version]::new($currentVersion) -ge [System.Version]::new($latestVersion))) {
    Write-Host "已是最新版本，无需更新。" -ForegroundColor Green
    exit 0
}

$build = [System.Environment]::OSVersion.Version.Build
$isWin11 = $build -ge 22000
$asset = if ($isWin11) {
    $release.assets | Where-Object { $_.name -match '\.msixbundle$' -and $_.name -notmatch 'PreinstallKit' } | Select-Object -First 1
} else {
    $release.assets | Where-Object { $_.name -match 'Win10.*\.msixbundle$' } | Select-Object -First 1
}

$tmpDir = if ($env:TOOLBOX_TMP_DIR) { $env:TOOLBOX_TMP_DIR } else { $env:TEMP }
if (-not (Test-Path $tmpDir)) { New-Item -ItemType Directory -Path $tmpDir -Force }
$outFile = Join-Path $tmpDir $asset.name

if ((Test-Path $outFile) -and ((Get-Item $outFile).Length -eq $asset.size)) {
    Write-Host "使用缓存文件。" -ForegroundColor Green
} else {
    Write-Host "正在下载 ($([math]::Round($asset.size/1MB, 2)) MB)..." -ForegroundColor White
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $outFile -UseBasicParsing
}

Write-Host "正在关闭 Terminal 进程并安装..." -ForegroundColor White
Get-Process -Name "WindowsTerminal" -ErrorAction SilentlyContinue | Stop-Process -Force
Add-AppxPackage -Path $outFile -ForceApplicationShutdown

if (-not $env:TOOLBOX_TMP_DIR) { Remove-Item $outFile -Force -ErrorAction SilentlyContinue }
Write-Host "安装成功!" -ForegroundColor Green
pause
