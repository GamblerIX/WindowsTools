# 安装 Windows Terminal
# 一键安装或更新至最新稳定版 Windows Terminal

[CmdletBinding()]
param(
    [switch]$Headless,    # 无头模式，禁用交互式提示
    [switch]$Silent,      # 静默模式，减少输出
    [switch]$NoAdmin,     # 跳过管理员权限检查
    [switch]$Force        # 强制安装（跳过版本检查）
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

function Invoke-DownloadWithRetry {
    param(
        [string]$Url,
        [string]$OutFile,
        [int]$MaxRetries = 3
    )
    
    $headers = @{
        'User-Agent' = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
    }
    
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            Write-Status "下载尝试 $attempt/$MaxRetries..." -Color Gray
            
            # 优先使用 .NET WebClient（更稳定）
            $webClient = New-Object System.Net.WebClient
            $webClient.Headers.Add('User-Agent', $headers['User-Agent'])
            $webClient.DownloadFile($Url, $OutFile)
            
            if (Test-Path $OutFile) {
                return $true
            }
        }
        catch {
            Write-Status "尝试 $attempt 失败: $($_.Exception.Message)" -Color Yellow
            
            if ($attempt -eq $MaxRetries) {
                # 最后一次尝试使用 Invoke-WebRequest
                try {
                    Write-Status "使用备用方法下载..." -Color Yellow
                    $ProgressPreference = 'SilentlyContinue'
                    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing -Headers $headers -TimeoutSec 300
                    if (Test-Path $OutFile) {
                        return $true
                    }
                }
                catch {
                    return $false
                }
            }
            
            Start-Sleep -Seconds (2 * $attempt)
        }
    }
    return $false
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
    $ErrorActionPreference = 'Stop'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    if (-not $Silent) {
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host "  Windows Terminal 安装/更新工具" -ForegroundColor Cyan
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host ""
    }

    # 检查当前版本
    $current = Get-AppxPackage -Name Microsoft.WindowsTerminal -ErrorAction SilentlyContinue
    $currentVersion = if ($current) { $current.Version } else { $null }
    if ($currentVersion) { 
        Write-Status "当前版本: $currentVersion" -Color Gray 
    }

    # 获取最新版本信息
    Write-Status "正在获取最新版本信息..." -Color White
    try {
        $api = "https://api.github.com/repos/microsoft/terminal/releases/latest"
        $headers = @{ 'User-Agent' = 'PowerShell' }
        $release = Invoke-RestMethod -Uri $api -Headers $headers -UseBasicParsing -TimeoutSec 30
    }
    catch {
        Write-ErrorAndExit "无法连接到 GitHub API: $($_.Exception.Message)" 2
    }

    $latestVersion = $release.tag_name -replace '^v',''
    Write-Status "最新版本: $latestVersion"

    # 版本比较
    if (-not $Force -and $currentVersion) {
        try {
            if ([System.Version]::new($currentVersion) -ge [System.Version]::new($latestVersion)) {
                Write-Status "已是最新版本，无需更新。" -Color Green
                Wait-OrPause
                exit 0
            }
        }
        catch {
            Write-Status "版本比较失败，继续安装..." -Color Yellow
        }
    }

    # 检测系统版本
    $build = [System.Environment]::OSVersion.Version.Build
    $osInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
    $osCaption = if ($osInfo) { $osInfo.Caption } else { "Windows" }
    
    # 系统版本识别
    # Build 17763 = LTSC 2019 / Server 2019
    # Build 19044 = LTSC 2021
    # Build 20348 = Server 2022
    # Build 26100 = LTSC 2024 / Server 2025
    if ($build -ge 26100) {
        $systemType = "LTSC 2024 / Server 2025"
    } elseif ($build -ge 22000) {
        $systemType = "Windows 11"
    } elseif ($build -ge 20348) {
        $systemType = "Server 2022"
    } elseif ($build -ge 19041) {
        $systemType = "LTSC 2021 / Windows 10 2004+"
    } elseif ($build -ge 17763) {
        $systemType = "LTSC 2019 / Server 2019"
    } else {
        $systemType = "不支持的系统"
    }
    
    Write-Status "系统信息: $osCaption (Build $build)" -Color Gray
    Write-Status "识别为: $systemType" -Color Gray
    
    # 检查最低系统要求 (Windows Terminal 需要 Build 17763+)
    if ($build -lt 17763) {
        Write-ErrorAndExit "Windows Terminal 需要 Windows 10 1809 (Build 17763) 或更高版本。您的系统: Build $build" 1
    }
    
    # 选择正确的安装包
    # 新版 Terminal (1.19+) 不再提供 Win10 专用包，使用统一的 msixbundle
    # 统一包支持 Build 17763+ 的所有系统
    
    # 优先查找通用包（不含 Win10 或 PreinstallKit）
    $asset = $release.assets | Where-Object { 
        $_.name -match '\.msixbundle$' -and 
        $_.name -notmatch 'PreinstallKit' -and 
        $_.name -notmatch 'Win10' 
    } | Select-Object -First 1
    
    # 如果找不到通用包，尝试 Win10 版本（兼容旧版 Terminal 发布）
    if (-not $asset) {
        $asset = $release.assets | Where-Object { $_.name -match 'Win10.*\.msixbundle$' } | Select-Object -First 1
    }
    
    # 最后手段：任意 msixbundle
    if (-not $asset) {
        $asset = $release.assets | Where-Object { $_.name -match '\.msixbundle$' -and $_.name -notmatch 'PreinstallKit' } | Select-Object -First 1
    }

    if (-not $asset) {
        Write-ErrorAndExit "无法找到适合当前系统的安装包 (Build: $build)" 1
    }
    
    Write-Status "安装包: $($asset.name)" -Color Cyan

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

    # 检查并安装 Microsoft.UI.Xaml 依赖
    $xamlPackage = Get-AppxPackage -Name "Microsoft.UI.Xaml.2.8" -ErrorAction SilentlyContinue
    if (-not $xamlPackage) {
        Write-Status "正在安装依赖: Microsoft.UI.Xaml.2.8..." -Color Yellow
        
        # 从 NuGet 下载 Microsoft.UI.Xaml
        $xamlNugetUrl = "https://www.nuget.org/api/v2/package/Microsoft.UI.Xaml/2.8.6"
        $xamlZipFile = Join-Path $tmpDir "Microsoft.UI.Xaml.2.8.6.zip"
        $xamlExtractDir = Join-Path $tmpDir "Microsoft.UI.Xaml"
        
        if (-not (Invoke-DownloadWithRetry -Url $xamlNugetUrl -OutFile $xamlZipFile)) {
            Write-ErrorAndExit "下载 Microsoft.UI.Xaml 依赖失败" 2
        }
        
        # 解压并安装
        if (Test-Path $xamlExtractDir) { Remove-Item $xamlExtractDir -Recurse -Force }
        Expand-Archive -Path $xamlZipFile -DestinationPath $xamlExtractDir -Force
        
        # 查找 x64 appx 文件
        $xamlAppx = Get-ChildItem -Path $xamlExtractDir -Recurse -Filter "*.appx" | 
            Where-Object { $_.FullName -match "x64" -and $_.FullName -notmatch "arm" } | 
            Select-Object -First 1
        
        if (-not $xamlAppx) {
            Write-ErrorAndExit "无法找到 Microsoft.UI.Xaml x64 安装包" 1
        }
        
        Add-AppxPackage -Path $xamlAppx.FullName -ErrorAction Stop
        Write-Status "Microsoft.UI.Xaml.2.8 安装成功" -Color Green
    } else {
        Write-Status "依赖已满足: Microsoft.UI.Xaml $($xamlPackage.Version)" -Color Gray
    }

    # 安装 Windows Terminal
    Write-Status "正在关闭 Terminal 进程并安装..." -Color White
    Get-Process -Name "WindowsTerminal" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    
    Add-AppxPackage -Path $outFile -ForceApplicationShutdown -ErrorAction Stop

    # 清理非工具箱缓存
    if (-not $env:TOOLBOX_TMP_DIR) { 
        Remove-Item $outFile -Force -ErrorAction SilentlyContinue 
    }

    Write-Status "" -Color White
    Write-Status "========================================" -Color Green
    Write-Status "  ✅ Windows Terminal 安装成功!" -Color Green
    Write-Status "========================================" -Color Green
    Write-Status "" -Color White
    Write-Status "提示: 为确保 Terminal 正常工作，建议注销并重新登录。" -Color Yellow
    Write-Status "      注销后，您可以通过以下方式启动 Terminal:" -Color Gray
    Write-Status "      - 在开始菜单搜索 'Terminal'" -Color Gray
    Write-Status "      - 在命令行输入 'wt'" -Color Gray
    Write-Status "" -Color White
    
    # 在非工具箱模式下询问是否立即注销
    if (-not $env:TOOLBOX_TMP_DIR -and -not $Headless) {
        $response = Read-Host "是否立即注销? (Y/N)"
        if ($response -eq 'Y' -or $response -eq 'y') {
            Write-Status "正在注销..." -Color Yellow
            logoff
        }
    }
    
    Wait-OrPause
    exit 0
}
catch {
    Write-ErrorAndExit "安装过程中发生错误: $($_.Exception.Message)" 1
}
#endregion
