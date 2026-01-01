# 禁用安全中心通知
# 永久禁用 Windows 安全中心发送的各类托盘通知和警告
# ---------------------------------------------------------
# 相关文件:
# - scripts/ps1/Common.ps1 (通用函数库)
# - docs/security-notifications.md (相关文档)
# - main.py (主入口)
# ---------------------------------------------------------

[CmdletBinding()]
param(
    [switch]$Headless,    # 无头模式，禁用交互式提示
    [switch]$Silent,      # 静默模式，减少输出
    [switch]$NoAdmin      # 跳过管理员权限检查
)

# 退出码定义: 0=成功, 1=一般错误, 3=权限错误

# 导入通用函数库
. $PSScriptRoot\Common.ps1

#region Admin Check
if (-not $NoAdmin) {
    if (-not (Test-IsAdmin)) {
        $extraArgs = @()
        if ($Headless) { $extraArgs += "-Headless" }
        if ($Silent) { $extraArgs += "-Silent" }
        Request-AdminPrivilege -ScriptPath $PSCommandPath -Arguments $extraArgs
    }
}
#endregion

#region Main Script
try {
    Show-Banner "禁用 Windows 安全中心通知"

    # 步骤 1: 修改组策略注册表项
    Write-Status "[1/3] 正在修改组策略注册表项..." -Color White
    $path1 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications"
    if (-not (Test-Path $path1)) { 
        New-Item -Path $path1 -Force | Out-Null 
    }
    Set-ItemProperty -Path $path1 -Name "DisableNotifications" -Value 1 -Type DWord -ErrorAction Stop

    # 步骤 2: 禁用系统级别通知设置
    Write-Status "[2/3] 正在禁用系统级别通知设置..." -Color White
    $path2 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Notifications\Settings\Windows.SystemToast.SecurityAndMaintenance"
    if (-not (Test-Path $path2)) { 
        New-Item -Path $path2 -Force | Out-Null 
    }
    Set-ItemProperty -Path $path2 -Name "Enabled" -Value 0 -Type DWord -ErrorAction Stop

    $path3 = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Reporting"
    if (Test-Path $path3) {
        Set-ItemProperty -Path $path3 -Name "DisableEnhancedNotifications" -Value 1 -Type DWord -ErrorAction SilentlyContinue
    }

    # 步骤 3: 刷新系统设置
    Write-Status "[3/3] 正在刷新系统设置..." -Color White
    Stop-Process -Name "ShellExperienceHost" -Force -ErrorAction SilentlyContinue
    Stop-Process -Name "StartMenuExperienceHost" -Force -ErrorAction SilentlyContinue

    if (-not $Silent) {
        Write-Host ""
        Write-Host "============================================" -ForegroundColor Green
        Write-Host "  操作成功！安全中心通知已永久禁用。" -ForegroundColor Green
        Write-Host "  提示: 设置可能需要重启计算机或重新登录后完全生效。" -ForegroundColor Cyan
        Write-Host "============================================" -ForegroundColor Green
        Write-Host ""
    }

    Wait-OrPause
    exit 0
}
catch {
    Write-ErrorAndExit "操作过程中发生错误: $($_.Exception.Message)" 1
}
#endregion
