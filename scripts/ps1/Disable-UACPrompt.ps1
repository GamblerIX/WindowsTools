# 禁用 UAC 提升提示
# 禁用管理员操作的 UAC 弹窗提示，适用于服务器自动化管理场景

[CmdletBinding()]
param(
    [switch]$Headless,     # 无头模式，禁用交互式提示
    [switch]$Silent,       # 静默模式，减少输出
    [switch]$NoAdmin,      # 跳过管理员权限检查
    [switch]$DisableUAC    # 完全禁用 UAC (需要重启)
)

# 退出码定义: 0=成功, 1=一般错误, 3=权限错误

#region Helper Functions
function Write-Status {
    param([string]$Message, [string]$Color = 'White')
    if (-not $Silent) {
        Write-Host $Message -ForegroundColor $Color
    }
}

function Write-ErrorAndExit {
    param([string]$Message, [int]$ExitCode = 1)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    if (-not $Headless -and -not $env:TOOLBOX_TMP_DIR) { pause }
    exit $ExitCode
}

function Wait-OrPause {
    if ($env:TOOLBOX_TMP_DIR) {
        Start-Sleep -Seconds 3
    } elseif (-not $Headless) {
        pause
    }
}
#endregion

#region Admin Check
if (-not $NoAdmin) {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Status "正在请求管理员权限..." -Color Yellow
        $arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
        if ($Headless) { $arguments += "-Headless" }
        if ($Silent) { $arguments += "-Silent" }
        if ($DisableUAC) { $arguments += "-DisableUAC" }
        $arguments += "-NoAdmin"
        
        Start-Process -FilePath pwsh.exe -ArgumentList $arguments -Verb RunAs -ErrorAction SilentlyContinue
        if ($?) { exit 0 }
        Start-Process -FilePath powershell.exe -ArgumentList $arguments -Verb RunAs -ErrorAction SilentlyContinue
        if ($?) { exit 0 }
        Write-ErrorAndExit "无法获取管理员权限" 3
    }
}
#endregion

#region Main Script
try {
    if (-not $Silent) {
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host "  禁用 UAC 提升提示" -ForegroundColor Cyan
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host ""
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
        # ConsentPromptBehaviorAdmin = 0: 不提示直接提升
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
        # PromptOnSecureDesktop = 0: 不切换到安全桌面
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
            # EnableLUA = 0: 完全禁用 UAC
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
    
    if ($successCount -eq $totalSteps) {
        exit 0
    } elseif ($successCount -gt 0) {
        exit 0  # 部分成功也返回 0
    } else {
        exit 1
    }
}
catch {
    Write-ErrorAndExit "操作过程中发生错误: $($_.Exception.Message)" 1
}
#endregion
