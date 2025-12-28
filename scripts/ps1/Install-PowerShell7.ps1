# 安装 PowerShell 7
# 一键安装或更新至最新稳定版 PowerShell 7

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
        Write-Host "  PowerShell 7 安装/更新工具" -ForegroundColor Cyan
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host ""
    }

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
    try {
        $api = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
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
