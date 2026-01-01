# 启用 UTF-8 支持
# 为 Windows 所有终端自动开启 UTF-8 编码支持
# ---------------------------------------------------------
# 相关文件:
# - scripts/ps1/Common.ps1 (通用函数库)
# - docs/utf8-support.md (相关文档)
# - main.py (主入口)
# ---------------------------------------------------------

[CmdletBinding()]
param(
    [switch]$Headless,    # 无头模式，禁用交互式提示
    [switch]$Silent,      # 静默模式，减少输出
    [switch]$NoAdmin,     # 跳过管理员权限检查
    [switch]$Force        # 强制配置（跳过已配置检查）
)

# 退出码定义: 0=成功, 1=一般错误, 3=权限错误, 4=系统不支持

# 导入通用函数库
. $PSScriptRoot\Common.ps1

#region 本地辅助函数
function Test-UTF8SystemSupport {
    # Windows 10 1903 (Build 18362) 及以上版本支持系统级 UTF-8
    $build = [System.Environment]::OSVersion.Version.Build
    return $build -ge 18362
}

function Get-CurrentUTF8Status {
    $status = @{
        SystemCodePage = $null
        ConsoleOutputCP = $null
        PowerShellEncoding = $null
        IsConfigured = $false
    }
    
    try {
        $codePage = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage" -ErrorAction SilentlyContinue
        $status.SystemCodePage = $codePage.ACP
        $status.ConsoleOutputCP = [Console]::OutputEncoding.CodePage
        $status.PowerShellEncoding = $OutputEncoding.CodePage
        $status.IsConfigured = ($status.SystemCodePage -eq "65001")
    }
    catch {}
    
    return $status
}
#endregion

#region Admin Check
if (-not $NoAdmin) {
    if (-not (Test-IsAdmin)) {
        $extraArgs = @()
        if ($Headless) { $extraArgs += "-Headless" }
        if ($Silent) { $extraArgs += "-Silent" }
        if ($Force) { $extraArgs += "-Force" }
        Request-AdminPrivilege -ScriptPath $PSCommandPath -Arguments $extraArgs
    }
}
#endregion

#region Main Script
try {
    Show-Banner "Windows 终端 UTF-8 支持配置工具"

    # 检查系统是否支持 UTF-8
    $build = [System.Environment]::OSVersion.Version.Build
    Write-Status "当前系统版本: Windows Build $build" -Color Gray

    if (-not (Test-UTF8SystemSupport)) {
        Write-Host "[WARNING] 当前系统版本 (Build $build) 不完全支持系统级 UTF-8 设置。" -ForegroundColor Yellow
        Write-Host "[WARNING] 系统级 UTF-8 支持需要 Windows 10 1903 (Build 18362) 或更高版本。" -ForegroundColor Yellow
        Write-Host "[WARNING] 将仅配置控制台和 PowerShell 的 UTF-8 设置。" -ForegroundColor Yellow
        Write-Host ""
    }

    # 检查当前状态
    $currentStatus = Get-CurrentUTF8Status
    Write-Status "当前系统代码页: $($currentStatus.SystemCodePage)" -Color Gray
    Write-Status "当前控制台代码页: $($currentStatus.ConsoleOutputCP)" -Color Gray

    if ($currentStatus.IsConfigured -and -not $Force) {
        Write-Status ""
        Write-Status "系统已配置 UTF-8 支持，无需重复配置。" -Color Green
        Write-Status "如需强制重新配置，请使用 -Force 参数。" -Color Cyan
        Wait-OrPause
        exit 0
    }

    $changesApplied = 0

    # 步骤 1: 配置系统区域设置（需要 Windows 10 1903+）
    if (Test-UTF8SystemSupport) {
        Write-Status ""
        Write-Status "[1/4] 正在配置系统区域设置 (Beta: UTF-8)..." -Color White
        
        $nlsPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage"
        try {
            Set-ItemProperty -Path $nlsPath -Name "ACP" -Value "65001" -ErrorAction Stop
            Set-ItemProperty -Path $nlsPath -Name "OEMCP" -Value "65001" -ErrorAction Stop
            Set-ItemProperty -Path $nlsPath -Name "MACCP" -Value "65001" -ErrorAction Stop
            $changesApplied++
            Write-Status "  ✓ 系统代码页已设置为 UTF-8 (65001)" -Color Green
        }
        catch {
            Write-Status "  ✗ 无法修改系统代码页: $($_.Exception.Message)" -Color Red
        }
    } else {
        Write-Status ""
        Write-Status "[1/4] 跳过系统区域设置 (系统版本不支持)..." -Color Yellow
    }

    # 步骤 2: 配置控制台默认代码页
    Write-Status ""
    Write-Status "[2/4] 正在配置控制台默认代码页..." -Color White
    
    $consolePath = "HKLM:\SOFTWARE\Microsoft\Command Processor"
    try {
        $autoRun = "chcp 65001 >nul"
        Set-ItemProperty -Path $consolePath -Name "AutoRun" -Value $autoRun -ErrorAction Stop
        $changesApplied++
        Write-Status "  ✓ CMD 自动设置 UTF-8 代码页" -Color Green
    }
    catch {
        Write-Status "  ✗ 无法配置 CMD: $($_.Exception.Message)" -Color Red
    }

    # 步骤 3: 配置 PowerShell 默认编码
    Write-Status ""
    Write-Status "[3/4] 正在配置 PowerShell 默认编码..." -Color White
    
    $psProfileDir = Split-Path $PROFILE.AllUsersAllHosts -Parent
    $psProfilePath = $PROFILE.AllUsersAllHosts
    $pwshProfileDir = Join-Path $env:ProgramData "PowerShell"
    $pwshProfilePath = Join-Path $pwshProfileDir "profile.ps1"
    
    $utf8Config = @"

# UTF-8 Encoding Configuration (Added by WindowsTools)
`$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
"@

    # 配置 Windows PowerShell
    try {
        if (-not (Test-Path $psProfileDir)) {
            New-Item -Path $psProfileDir -ItemType Directory -Force | Out-Null
        }
        
        $existingContent = ""
        if (Test-Path $psProfilePath) {
            $existingContent = Get-Content $psProfilePath -Raw -ErrorAction SilentlyContinue
        }
        
        if ($existingContent -notmatch "UTF-8 Encoding Configuration") {
            Add-Content -Path $psProfilePath -Value $utf8Config -ErrorAction Stop
            Write-Status "  ✓ Windows PowerShell 已配置 UTF-8 编码" -Color Green
            $changesApplied++
        } else {
            Write-Status "  - Windows PowerShell 已有配置" -Color Gray
        }
    }
    catch {
        Write-Status "  ✗ 无法配置 Windows PowerShell: $($_.Exception.Message)" -Color Red
    }

    # 配置 PowerShell 7
    try {
        if (-not (Test-Path $pwshProfileDir)) {
            New-Item -Path $pwshProfileDir -ItemType Directory -Force | Out-Null
        }
        
        $existingContent = ""
        if (Test-Path $pwshProfilePath) {
            $existingContent = Get-Content $pwshProfilePath -Raw -ErrorAction SilentlyContinue
        }
        
        if ($existingContent -notmatch "UTF-8 Encoding Configuration") {
            Add-Content -Path $pwshProfilePath -Value $utf8Config -ErrorAction Stop
            Write-Status "  ✓ PowerShell 7 已配置 UTF-8 编码" -Color Green
            $changesApplied++
        } else {
            Write-Status "  - PowerShell 7 已有配置" -Color Gray
        }
    }
    catch {
        Write-Status "  ✗ 无法配置 PowerShell 7: $($_.Exception.Message)" -Color Red
    }

    # 步骤 4: 配置 Windows Terminal (如果存在)
    Write-Status ""
    Write-Status "[4/4] 正在检查 Windows Terminal 配置..." -Color White
    
    $wtSettingsPath = Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    
    if (Test-Path $wtSettingsPath) {
        Write-Status "  - Windows Terminal 检测到，其默认已支持 UTF-8" -Color Gray
    } else {
        Write-Status "  - 未检测到 Windows Terminal" -Color Gray
    }

    # 完成
    Write-Status ""
    if ($changesApplied -gt 0) {
        Write-Host "============================================" -ForegroundColor Green
        Write-Host "  配置完成！已应用 $changesApplied 项更改。" -ForegroundColor Green
        Write-Host "============================================" -ForegroundColor Green
        Write-Status ""
        Write-Status "注意事项:" -Color Cyan
        Write-Status "1. 系统代码页更改需要重启计算机才能完全生效" -Color Yellow
        Write-Status "2. 新打开的终端窗口将自动使用 UTF-8 编码" -Color Yellow
        Write-Status "3. 某些旧程序可能在 UTF-8 模式下显示乱码" -Color Yellow
    } else {
        Write-Status "未应用任何更改，系统已完全配置。" -Color Green
    }

    Wait-OrPause
    exit 0
}
catch {
    Write-ErrorAndExit "配置过程中发生错误: $($_.Exception.Message)" 1
}
#endregion
