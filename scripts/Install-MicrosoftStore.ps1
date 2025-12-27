# 安装 Microsoft Store
# 为系统安装或修复微软商店组件

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "正在请求管理员权限..." -ForegroundColor Yellow
    Start-Process -FilePath pwsh.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs -ErrorAction SilentlyContinue
    if ($?) { exit }
    Start-Process -FilePath powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Microsoft Store 安装/修复脚本" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

$existingStore = Get-AppxPackage -Name "Microsoft.WindowsStore" -ErrorAction SilentlyContinue
if ($existingStore) {
    Write-Host "检测到系统已安装 Microsoft Store (版本: $($existingStore.Version))。" -ForegroundColor Green
    Write-Host "提示: 如需强制重新安装，请在管理员终端手动执行命令: wsreset -i" -ForegroundColor Cyan
    Write-Host "任务已标记为完成。" -ForegroundColor Green
    if ($env:TOOLBOX_TMP_DIR) { Start-Sleep -Seconds 2 } else { pause }
    exit 0
}

Get-Process -Name "WinStore.App" -ErrorAction SilentlyContinue | Stop-Process -Force

Write-Host "正在启动系统安装程序 (wsreset -i)..." -ForegroundColor White
Start-Process "wsreset.exe" -ArgumentList "-i" -Wait

$found = $false
for ($i = 0; $i -lt 8; $i++) {
    Write-Host "正在搜索商店组件 (尝试 $($i+1)/8)..." -ForegroundColor Gray
    $store = Get-AppxPackage -Name "Microsoft.WindowsStore" -AllUsers
    if ($store) {
        $found = $true
        break
    }
    Start-Sleep -Seconds 10
}

if ($found) {
    $manifest = Join-Path $store.InstallLocation "AppxManifest.xml"
    Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction SilentlyContinue
    Write-Host "Microsoft Store 注册成功!" -ForegroundColor Green
} else {
    Write-Host "尝试强制在线获取..." -ForegroundColor Yellow
    Add-AppxPackage -RegisterByFamilyName -MainPackage "Microsoft.WindowsStore_8wekyb3d8bbwe" -ErrorAction SilentlyContinue
}
pause
