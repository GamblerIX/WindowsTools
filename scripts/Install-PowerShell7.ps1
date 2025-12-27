# 安装 PowerShell 7
# 一键安装或更新至最新稳定版 PowerShell 7

# 自提权逻辑
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
Write-Host "  PowerShell 7 安装/更新工具" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$currentVersion = $null
if (Get-Command pwsh -ErrorAction SilentlyContinue) {
    $currentVersion = (pwsh --version).Replace('PowerShell ', '').Trim()
    Write-Host "当前版本: $currentVersion" -ForegroundColor Gray
}

$release = Invoke-RestMethod -Uri "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
$latestVersion = $release.tag_name -replace '^v',''
Write-Host "最新版本: $latestVersion"

if ($currentVersion -and ([System.Version]::new($currentVersion.Split('-')[0]) -ge [System.Version]::new($latestVersion.Split('-')[0]))) {
    Write-Host "已是最新版本，无需更新。" -ForegroundColor Green
    exit 0
}

$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
$asset = $release.assets | Where-Object { $_.name -match "PowerShell-$latestVersion-win-$arch.msi" } | Select-Object -First 1

$tmpDir = if ($env:TOOLBOX_TMP_DIR) { $env:TOOLBOX_TMP_DIR } else { $env:TEMP }
$outFile = Join-Path $tmpDir $asset.name

if ((Test-Path $outFile) -and ((Get-Item $outFile).Length -eq $asset.size)) {
    Write-Host "使用缓存文件。" -ForegroundColor Green
} else {
    Write-Host "正在下载 ($([math]::Round($asset.size/1MB, 2)) MB)..." -ForegroundColor White
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $outFile -UseBasicParsing
}

Write-Host "正在安装，请稍候..." -ForegroundColor White
$process = Start-Process msiexec.exe -ArgumentList "/package `"$outFile`" /quiet /norestart ADD_PATH=1" -Wait -PassThru

if ($process.ExitCode -eq 0) {
    Write-Host "安装成功!" -ForegroundColor Green
} else {
    Write-Host "安装程序返回错误代码: $($process.ExitCode)" -ForegroundColor Red
}

if (-not $env:TOOLBOX_TMP_DIR) { Remove-Item $outFile -Force -ErrorAction SilentlyContinue }
pause
