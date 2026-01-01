# 安装 PowerShell 7
# 一键安装或更新至最新稳定版 PowerShell 7
# ---------------------------------------------------------
# 相关文件:
# - scripts/ps1/Common.ps1 (通用函数库)
# - docs/powershell7.md (相关文档)
# - main.py (主入口)
# ---------------------------------------------------------

[CmdletBinding()]
param(
    [switch]$Headless,    # 无头模式，禁用交互式提示
    [switch]$Silent,      # 静默模式，减少输出
    [switch]$NoAdmin,     # 跳过管理员权限检查
    [switch]$Force        # 强制安装（跳过版本检查）
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
    $ErrorActionPreference = 'Stop'

    Show-Banner "PowerShell 7 安装/更新工具"

    # 检查当前版本
    $currentVersion = $null
    if (Get-Command pwsh -ErrorAction SilentlyContinue) {
        try {
            $currentVersion = (pwsh --version).Replace('PowerShell ', '').Trim()
            Write-Status "当前版本: $currentVersion" -Color Gray
        }
        catch {
            Write-Status "无法获取当前版本信息" -Color Yellow
        }
    }

    # 获取最新版本信息
    Write-Status "正在获取最新版本信息..." -Color White
    $release = Get-GitHubLatestRelease -Owner "PowerShell" -Repo "PowerShell"
    
    if (-not $release) {
        Write-ErrorAndExit "无法连接到 GitHub API" 2
    }

    $latestVersion = $release.tag_name -replace '^v',''
    Write-Status "最新版本: $latestVersion"

    # 版本比较
    if (-not $Force -and $currentVersion) {
        try {
            $currentClean = $currentVersion.Split('-')[0]
            $latestClean = $latestVersion.Split('-')[0]
            if ([System.Version]::new($currentClean) -ge [System.Version]::new($latestClean)) {
                Write-Status "已是最新版本，无需更新。" -Color Green
                Wait-OrPause
                exit 0
            }
        }
        catch {
            Write-Status "版本比较失败，继续安装..." -Color Yellow
        }
    }

    # 选择正确的安装包
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
    $asset = $release.assets | Where-Object { $_.name -match "PowerShell-$latestVersion-win-$arch.msi" } | Select-Object -First 1

    if (-not $asset) {
        Write-ErrorAndExit "无法找到适合当前系统的安装包 (架构: $arch)" 1
    }

    # 准备下载目录
    $tmpDir = if ($env:TOOLBOX_TMP_DIR) { $env:TOOLBOX_TMP_DIR } else { $env:TEMP }
    if (-not (Test-Path $tmpDir)) { 
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null 
    }
    $outFile = Join-Path $tmpDir $asset.name

    # 检查缓存
    if ((Test-Path $outFile) -and ((Get-Item $outFile).Length -eq $asset.size)) {
        Write-Status "使用缓存文件。" -Color Green
    } else {
        $sizeMB = [math]::Round($asset.size / 1MB, 2)
        Write-Status "正在下载 ($sizeMB MB)..." -Color White
        
        if (-not (Invoke-DownloadWithRetry -Url $asset.browser_download_url -OutFile $outFile)) {
            Write-ErrorAndExit "下载失败，请检查网络连接" 2
        }
        
        # 验证文件完整性
        if ((Get-Item $outFile).Length -ne $asset.size) {
            Remove-Item $outFile -Force -ErrorAction SilentlyContinue
            Write-ErrorAndExit "下载的文件大小不正确，可能下载不完整" 2
        }
    }

    # 安装
    Write-Status "正在安装，请稍候..." -Color White
    $msiArgs = "/package `"$outFile`" /quiet /norestart ADD_PATH=1"
    $process = Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -PassThru

    if ($process.ExitCode -eq 0) {
        Write-Status "安装成功!" -Color Green
    } elseif ($process.ExitCode -eq 3010) {
        Write-Status "安装成功! 需要重启计算机以完成安装。" -Color Yellow
    } else {
        Write-ErrorAndExit "安装程序返回错误代码: $($process.ExitCode)" 1
    }

    # 清理非工具箱缓存
    if (-not $env:TOOLBOX_TMP_DIR) { 
        Remove-Item $outFile -Force -ErrorAction SilentlyContinue 
    }

    Wait-OrPause
    exit 0
}
catch {
    Write-ErrorAndExit "安装过程中发生错误: $($_.Exception.Message)" 1
}
#endregion
