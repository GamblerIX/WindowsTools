# 安装 Microsoft Store
# 为系统安装或修复微软商店组件
# ---------------------------------------------------------
# 相关文件:
# - scripts/ps1/Common.ps1 (通用函数库)
# - docs/microsoft-store.md (相关文档)
# - main.py (主入口)
# ---------------------------------------------------------

[CmdletBinding()]
param(
    [switch]$Headless,    # 无头模式，禁用交互式提示
    [switch]$Silent,      # 静默模式，减少输出
    [switch]$NoAdmin,     # 跳过管理员权限检查
    [switch]$Force        # 强制重新安装
)

# 退出码定义: 0=成功, 1=一般错误, 2=网络错误, 3=权限错误

# 导入通用函数库
. $PSScriptRoot\Common.ps1

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
    Show-Banner "Microsoft Store 安装/修复脚本"

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
