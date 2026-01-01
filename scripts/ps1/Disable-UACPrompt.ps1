# 禁用 UAC 提升提示
# 禁用管理员操作的 UAC 弹窗提示，适用于服务器自动化管理场景
# ---------------------------------------------------------
# 相关文件:
# - scripts/ps1/Common.ps1 (通用函数库)
# - docs/uac-prompt.md (相关文档)
# - main.py (主入口)
# ---------------------------------------------------------

[CmdletBinding()]
param(
    [switch]$Headless,     # 无头模式，禁用交互式提示
    [switch]$Silent,       # 静默模式，减少输出
    [switch]$NoAdmin,      # 跳过管理员权限检查
    [switch]$DisableUAC    # 完全禁用 UAC (需要重启)
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
        if ($DisableUAC) { $extraArgs += "-DisableUAC" }
        Request-AdminPrivilege -ScriptPath $PSCommandPath -Arguments $extraArgs
    }
}
#endregion

#region Main Script
try {
    Show-Banner "禁用 UAC 提升提示"
    
    if (-not $Silent) {
        Write-Host "⚠ 安全提示: 此操作会降低系统安全性，" -ForegroundColor Yellow
        Write-Host "  仅建议在受信任的服务器环境中使用。" -ForegroundColor Yellow
        Write-Host ""
    }

    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    $successCount = 0
    $totalSteps = if ($DisableUAC) { 3 } else { 2 }

    # 步骤 1: 禁用 UAC 提升提示 (管理员无需确认)
    Write-Status "[1/$totalSteps] 正在禁用 UAC 提升提示..." -Color White
    try {
        Set-ItemProperty -Path $regPath -Name "ConsentPromptBehaviorAdmin" -Value 0 -Type DWord -ErrorAction Stop
        Write-Status "  ✓ UAC 提升提示已禁用 (ConsentPromptBehaviorAdmin=0)" -Color Green
        $successCount++
    }
    catch {
        Write-Status "  ✗ 禁用 UAC 提升提示失败: $($_.Exception.Message)" -Color Red
    }

    # 步骤 2: 禁用安全桌面提示
    Write-Status "[2/$totalSteps] 正在禁用安全桌面提示..." -Color White
    try {
        Set-ItemProperty -Path $regPath -Name "PromptOnSecureDesktop" -Value 0 -Type DWord -ErrorAction Stop
        Write-Status "  ✓ 安全桌面提示已禁用 (PromptOnSecureDesktop=0)" -Color Green
        $successCount++
    }
    catch {
        Write-Status "  ✗ 禁用安全桌面提示失败: $($_.Exception.Message)" -Color Red
    }

    # 步骤 3 (可选): 完全禁用 UAC
    if ($DisableUAC) {
        Write-Status "[3/$totalSteps] 正在完全禁用 UAC..." -Color White
        try {
            Set-ItemProperty -Path $regPath -Name "EnableLUA" -Value 0 -Type DWord -ErrorAction Stop
            Write-Status "  ✓ UAC 已完全禁用 (EnableLUA=0)" -Color Green
            Write-Status "  ⚠ 需要重启计算机才能生效" -Color Yellow
            $successCount++
        }
        catch {
            Write-Status "  ✗ 完全禁用 UAC 失败: $($_.Exception.Message)" -Color Red
        }
    }

    # 输出结果
    if (-not $Silent) {
        Write-Host ""
        if ($successCount -eq $totalSteps) {
            Write-Host "============================================" -ForegroundColor Green
            Write-Host "  操作成功！UAC 提示已禁用。" -ForegroundColor Green
            Write-Host "============================================" -ForegroundColor Green
        } elseif ($successCount -gt 0) {
            Write-Host "============================================" -ForegroundColor Yellow
            Write-Host "  部分操作完成！($successCount/$totalSteps)" -ForegroundColor Yellow
            Write-Host "============================================" -ForegroundColor Yellow
        } else {
            Write-Host "============================================" -ForegroundColor Red
            Write-Host "  操作失败！请检查上述错误信息。" -ForegroundColor Red
            Write-Host "============================================" -ForegroundColor Red
        }
        Write-Host ""
        if ($DisableUAC) {
            Write-Host "提示: 完全禁用 UAC 需要重启计算机后生效。" -ForegroundColor Cyan
        } else {
            Write-Host "提示: UAC 提示设置已即时生效。" -ForegroundColor Cyan
        }
        Write-Host ""
    }

    Wait-OrPause
    
    if ($successCount -gt 0) {
        exit 0
    } else {
        exit 1
    }
}
catch {
    Write-ErrorAndExit "操作过程中发生错误: $($_.Exception.Message)" 1
}
#endregion
