# 立即重启计算机
# 强制关闭所有应用程序并立即重启

[CmdletBinding()]
param(
    [int]$Delay = 0,      # 延迟秒数
    [switch]$Force        # 强制重启
)

try {
    if ($Delay -gt 0) {
        Write-Host "计算机将在 $Delay 秒后重启..." -ForegroundColor Yellow
        shutdown.exe /r /t $Delay /f /c "脚本触发：系统重启"
    } else {
        Write-Host "正在重启计算机..." -ForegroundColor Red
        Restart-Computer -Force -Confirm:$false
    }
}
catch {
    Write-Host "[ERROR] 无法启动重启进程: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
