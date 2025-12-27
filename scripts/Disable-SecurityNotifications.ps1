# 禁用安全中心通知
# 永久禁用 Windows 安全中心发送的各类托盘通知和警告

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "正在请求管理员权限..." -ForegroundColor Yellow
    Start-Process -FilePath pwsh.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -ErrorAction SilentlyContinue
    if ($?) { exit }
    Start-Process -FilePath powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  禁用 Windows 安全中心通知" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/3] 正在修改组策略注册表项..." -ForegroundColor White
$path1 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications"
if (-not (Test-Path $path1)) { New-Item -Path $path1 -Force | Out-Null }
Set-ItemProperty -Path $path1 -Name "DisableNotifications" -Value 1 -Type DWord

Write-Host "[2/3] 正在禁用系统级别通知设置..." -ForegroundColor White
$path2 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance"
if (-not (Test-Path $path2)) { New-Item -Path $path2 -Force | Out-Null }
Set-ItemProperty -Path $path2 -Name "Enabled" -Value 0 -Type DWord

$path3 = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Reporting"
if (Test-Path $path3) {
    Set-ItemProperty -Path $path3 -Name "DisableEnhancedNotifications" -Value 1 -Type DWord -ErrorAction SilentlyContinue
}

Write-Host "[3/3] 正在刷新系统设置..." -ForegroundColor White
Stop-Process -Name "ShellExperienceHost" -Force -ErrorAction SilentlyContinue
Stop-Process -Name "StartMenuExperienceHost" -Force -ErrorAction SilentlyContinue

Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  操作成功！安全中心通知已永久禁用。" -ForegroundColor Green
Write-Host "  提示: 设置可能需要重启计算机或重新登录后完全生效。" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Green
Write-Host ""

if ($env:TOOLBOX_TMP_DIR) { Start-Sleep -Seconds 3 } else { pause }
