# 安装 WSL2
# 一键安装并配置 Windows Subsystem for Linux 2
# ---------------------------------------------------------
# 相关文件:
# - scripts/ps1/Common.ps1 (通用函数库)
# - docs/wsl2.md (相关文档)
# - main.py (主入口)
# ---------------------------------------------------------

[CmdletBinding()]
param(
    [switch]$Headless,    # 无头模式
    [switch]$Silent,      # 静默模式
    [switch]$NoAdmin,     # 跳过提权
    [switch]$NoDistro     # 不安装默认发行版
)

# 可配置变量定义
$WSLGitHubApiUrl = "https://api.github.com/repos/microsoft/WSL/releases/latest"
# 微软官方备选方案 (WSL2 内核更新包): https://learn.microsoft.com/zh-cn/windows/wsl/install-manual
$FallbackWSLUrl = "https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi"
$DefaultDistro = "Debian"  # 默认安装 Debian 12
$MinimumBuildForWSL2 = 18362
$MinimumBuildForWSLInstall = 19041 # wsl --install 支持的最低版本

# 导入通用函数库
. $PSScriptRoot\Common.ps1

#region Admin Check
if (-not $NoAdmin) {
    if (-not (Test-IsAdmin)) {
        $extraArgs = @()
        if ($Headless) { $extraArgs += "-Headless" }
        if ($Silent) { $extraArgs += "-Silent" }
        if ($NoDistro) { $extraArgs += "-NoDistro" }
        Request-AdminPrivilege -ScriptPath $PSCommandPath -Arguments $extraArgs
    }
}
#endregion

#region Main Script
try {
    $ErrorActionPreference = 'Stop'
    
    Show-Banner "WSL2 一键安装工具"

    # 1. 检测系统版本
    $build = [System.Environment]::OSVersion.Version.Build
    Write-Status "当前系统 Build: $build" -Color Gray

    if ($build -lt 17763) {
        Write-ErrorAndExit "WSL 需要 Windows 10 Build 17763 或更高版本。您的系统暂不支持。"
    }

    $isWSL2Supported = $build -ge $MinimumBuildForWSL2
    if (-not $isWSL2Supported) {
        Write-Status "提示: 您的系统版本 ($build) 仅支持 WSL1，无法开启 WSL2。" -Color Yellow
    }

    # 2. 检查并开启特性
    Write-Status "正在检查系统特性..." -Color White
    
    $featuresNeeded = @("Microsoft-Windows-Subsystem-Linux")
    if ($isWSL2Supported) {
        $featuresNeeded += "VirtualMachinePlatform"
    }

    $rebootRequired = $false
    foreach ($feature in $featuresNeeded) {
        $state = Get-WindowsOptionalFeature -Online -FeatureName $feature
        if ($state.State -ne 'Enabled') {
            Write-Status "正在启用特性: $feature..." -Color Yellow
            Enable-WindowsOptionalFeature -Online -FeatureName $feature -NoRestart -All | Out-Null
            $rebootRequired = $true
        } else {
            Write-Status "特性已启用: $feature" -Color Gray
        }
    }

    if ($rebootRequired) {
        Write-Status ""
        Write-Status "====================================================" -Color Yellow
        Write-Status "  必须重启计算机才能完成特性开启！" -Color Yellow
        Write-Status "  请重启后再次运行此逻辑以完成后续安装。" -Color Yellow
        Write-Status "====================================================" -Color Yellow
        Write-Status ""
        # 工具箱模式下不进行交互式提示
        if (-not $Headless -and -not $env:TOOLBOX_TMP_DIR) {
            $resp = Read-Host "是否立即重启? (Y/N)"
            if ($resp -eq 'y' -or $resp -eq 'Y') {
                Restart-Computer
            }
        }
        exit 0
    }

    # 3. 如果支持 WSL2，从 GitHub Releases 下载并安装
    if ($isWSL2Supported) {
        Write-Status "正在配置 WSL2..." -Color White
        
        $tmpDir = if ($env:TOOLBOX_TMP_DIR) { $env:TOOLBOX_TMP_DIR } else { $env:TEMP }
        $downloadUrl = $null
        $outFileName = $null
        
        # 尝试从 GitHub API 获取最新版本
        Write-Status "从 GitHub Releases 获取最新版本信息..." -Color Gray
        $release = Get-GitHubLatestRelease -Owner "microsoft" -Repo "WSL"
        
        if ($release) {
            $latestVersion = $release.tag_name
            Write-Status "最新 WSL 版本: $latestVersion" -Color Cyan
            
            # 查找 x64 MSI 安装包
            $asset = $release.assets | Where-Object { $_.name -match 'wsl.*\.x64\.msi$' -or $_.name -match 'x64\.msi$' } | Select-Object -First 1
            
            if (-not $asset) {
                $asset = $release.assets | Where-Object { $_.name -match '\.msi$' -and $_.name -match 'x64' } | Select-Object -First 1
            }
            
            if ($asset) {
                $downloadUrl = $asset.browser_download_url
                $outFileName = $asset.name
                $sizeMB = [math]::Round($asset.size / 1MB, 2)
                Write-Status "安装包: $outFileName ($sizeMB MB)" -Color Gray
            }
        }
        
        # 如果 GitHub API 失败，使用备选 URL
        if (-not $downloadUrl) {
            Write-Status "GitHub API 不可用，使用备选下载地址..." -Color Yellow
            $downloadUrl = $FallbackWSLUrl
            $outFileName = [System.IO.Path]::GetFileName($FallbackWSLUrl)
            Write-Status "备选安装包: $outFileName" -Color Gray
        }
        
        # 下载并安装
        $outFile = Join-Path $tmpDir $outFileName
        Write-Status "正在下载..." -Color Yellow
        
        if (Invoke-DownloadWithRetry -Url $downloadUrl -OutFile $outFile) {
            Write-Status "正在安装 WSL..." -Color Gray
            Start-Process msiexec.exe -ArgumentList "/i `"$outFile`" /quiet /norestart" -Wait
            Write-Status "WSL 安装成功。" -Color Green
        } else {
            Write-ErrorAndExit "下载 WSL 安装包失败，请检查网络连接。"
        }
        
        # 设置 WSL2 为默认版本
        try {
            wsl.exe --set-default-version 2 | Out-Null
            Write-Status "WSL2 已成功设置为默认版本。" -Color Green
        }
        catch {
            Write-Status "设置默认版本失败，请手动运行: wsl --set-default-version 2" -Color Yellow
        }
    }

    # 4. 安装发行版 (Debian 12)
    if (-not $NoDistro -and $build -ge $MinimumBuildForWSLInstall) {
        Write-Status "正在安装默认发行版: $DefaultDistro..." -Color Cyan
        Write-Status "这可能需要几分钟，请不要关闭窗口。" -Color Gray
        Start-Process wsl.exe -ArgumentList "--install -d $DefaultDistro --no-launch" -Wait | Out-Null
        Write-Status "$DefaultDistro 安装请求已发送。" -Color Green
    }

    Write-Status ""
    Write-Status "========================================" -Color Green
    Write-Status "  ✅ WSL 安装/配置任务完成!" -Color Green
    Write-Status "========================================" -Color Green
    Write-Status ""
    Write-Status "后续步骤:" -Color White
    Write-Status "1. 如果这是您第一次安装，请在开始菜单找到 '$DefaultDistro' 并启动它以完成初始化。" -Color Gray
    Write-Status "2. 您可以使用 'wsl --status' 查看当前状态。" -Color Gray
    Write-Status ""

    Wait-OrPause
    exit 0

}
catch {
    Write-ErrorAndExit "执行过程中出错: $($_.Exception.Message)" 1
}
#endregion
