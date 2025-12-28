# 安装 Microsoft Store
# 为系统安装或修复微软商店组件

[CmdletBinding()]
param(
    [switch]$Headless,    # 无头模式，禁用交互式提示
    [switch]$Silent,      # 静默模式，减少输出
    [switch]$NoAdmin,     # 跳过管理员权限检查
    [switch]$Force        # 强制重新安装
)

# 退出码定义: 0=成功, 1=一般错误, 2=网络错误, 3=权限错误

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
        Start-Sleep -Seconds 2
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
        if ($Force) { $arguments += "-Force" }
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
        Write-Host "  Microsoft Store 安装/修复脚本" -ForegroundColor Cyan
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host ""
    }

    # 检查现有安装
    $existingStore = Get-AppxPackage -Name "Microsoft.WindowsStore" -ErrorAction SilentlyContinue
    if ($existingStore -and -not $Force) {
        Write-Status "检测到系统已安装 Microsoft Store (版本: $($existingStore.Version))。" -Color Green
        Write-Status "提示: 如需强制重新安装，请使用 -Force 参数或在管理员终端手动执行: wsreset -i" -Color Cyan
        Write-Status "任务已标记为完成。" -Color Green
        Wait-OrPause
        exit 0
    }

    # 停止相关进程
    Get-Process -Name "WinStore.App" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

    # 启动系统安装程序
    Write-Status "正在启动系统安装程序 (wsreset -i)..." -Color White
    $wsreset = Start-Process "wsreset.exe" -ArgumentList "-i" -Wait -PassThru -ErrorAction SilentlyContinue

    # 等待安装完成
    $found = $false
    $maxAttempts = 8
    for ($i = 0; $i -lt $maxAttempts; $i++) {
        Write-Status "正在搜索商店组件 (尝试 $($i+1)/$maxAttempts)..." -Color Gray
        $store = Get-AppxPackage -Name "Microsoft.WindowsStore" -AllUsers -ErrorAction SilentlyContinue
        if ($store) {
            $found = $true
            break
        }
        Start-Sleep -Seconds 10
    }

    if ($found) {
        $manifest = Join-Path $store.InstallLocation "AppxManifest.xml"
        if (Test-Path $manifest) {
            Add-AppxPackage -DisableDevelopmentMode -Register $manifest -ErrorAction SilentlyContinue
        }
        Write-Status "Microsoft Store 注册成功!" -Color Green
    } else {
        Write-Status "尝试强制在线获取..." -Color Yellow
        try {
            Add-AppxPackage -RegisterByFamilyName -MainPackage "Microsoft.WindowsStore_8wekyb3d8bbwe" -ErrorAction Stop
            Write-Status "Microsoft Store 安装成功!" -Color Green
        }
        catch {
            Write-Status "在线获取失败: $($_.Exception.Message)" -Color Red
            Write-Status "请确保系统已连接到互联网并重试。" -Color Yellow
        }
    }

    Wait-OrPause
    exit 0
}
catch {
    Write-ErrorAndExit "安装过程中发生错误: $($_.Exception.Message)" 1
}
#endregion
