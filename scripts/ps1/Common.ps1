# Common.ps1 - PowerShell 脚本通用函数库
# 所有工具箱脚本共享的通用函数
# ---------------------------------------------------------
# 使用方法: 在脚本开头添加 `. $PSScriptRoot\Common.ps1`
# ---------------------------------------------------------
# 脚本开发规范:
# 1. 脚本必须支持 -Headless 参数禁用所有交互式提示
# 2. 工具箱运行时会设置 $env:TOOLBOX_TMP_DIR，此时也应禁用交互
# 3. 所有交互式输入(Read-Host)必须检查:
#    if (-not $Headless -and -not $env:TOOLBOX_TMP_DIR) { ... }
# 4. 使用 Write-Status 而非 Write-Host 以支持静默模式
# ---------------------------------------------------------

#region 输出函数

<#
.SYNOPSIS
    输出状态消息（静默模式下不输出）
.PARAMETER Message
    要输出的消息
.PARAMETER Color
    消息颜色，默认白色
#>
function Write-Status {
    param(
        [string]$Message,
        [string]$Color = 'White'
    )
    if (-not $script:Silent) {
        Write-Host $Message -ForegroundColor $Color
    }
}

<#
.SYNOPSIS
    输出错误消息并退出脚本
.PARAMETER Message
    错误消息
.PARAMETER ExitCode
    退出码，默认为 1
#>
function Write-ErrorAndExit {
    param(
        [string]$Message,
        [int]$ExitCode = 1
    )
    Write-Host "[ERROR] $Message" -ForegroundColor Red
    if (-not $script:Headless -and -not $env:TOOLBOX_TMP_DIR) { pause }
    exit $ExitCode
}

<#
.SYNOPSIS
    根据运行模式等待或暂停
#>
function Wait-OrPause {
    if ($env:TOOLBOX_TMP_DIR) {
        Start-Sleep -Seconds 2
    } elseif (-not $script:Headless) {
        pause
    }
}

<#
.SYNOPSIS
    显示脚本标题横幅
.PARAMETER Title
    标题文本
#>
function Show-Banner {
    param([string]$Title)
    if (-not $script:Silent) {
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host "  $Title" -ForegroundColor Cyan
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host ""
    }
}

#endregion

#region 下载函数

<#
.SYNOPSIS
    带重试机制的下载函数
.PARAMETER Url
    下载 URL
.PARAMETER OutFile
    输出文件路径
.PARAMETER MaxRetries
    最大重试次数，默认 3
.RETURNS
    下载成功返回 $true，失败返回 $false
#>
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

#region 注册表函数

<#
.SYNOPSIS
    设置注册表值（自动创建路径）
.PARAMETER Path
    注册表路径
.PARAMETER Name
    值名称
.PARAMETER Value
    值数据
.PARAMETER Type
    值类型，默认 DWord
.RETURNS
    成功返回 $true，失败返回 $false
#>
function Set-RegistryValue {
    param(
        [string]$Path,
        [string]$Name,
        [object]$Value,
        [string]$Type = "DWord"
    )
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop
        return $true
    }
    catch {
        Write-Status "    ✗ 设置失败: $($_.Exception.Message)" -Color Red
        return $false
    }
}

#endregion

#region 权限函数

<#
.SYNOPSIS
    检查当前进程是否具有管理员权限
.RETURNS
    是管理员返回 $true，否则返回 $false
#>
function Test-IsAdmin {
    return ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

<#
.SYNOPSIS
    请求管理员权限并重新启动脚本
.PARAMETER ScriptPath
    脚本路径
.PARAMETER Arguments
    附加参数数组
#>
function Request-AdminPrivilege {
    param(
        [string]$ScriptPath,
        [string[]]$Arguments = @()
    )
    
    Write-Status "正在请求管理员权限..." -Color Yellow
    $baseArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$ScriptPath`"")
    $allArgs = $baseArgs + $Arguments + @("-NoAdmin")
    
    # 优先尝试 pwsh (PowerShell 7)
    Start-Process -FilePath pwsh.exe -ArgumentList $allArgs -Verb RunAs -ErrorAction SilentlyContinue
    if ($?) { exit 0 }
    
    # 回退到 Windows PowerShell
    Start-Process -FilePath powershell.exe -ArgumentList $allArgs -Verb RunAs -ErrorAction SilentlyContinue
    if ($?) { exit 0 }
    
    Write-ErrorAndExit "无法获取管理员权限" 3
}

#endregion

#region GitHub API 函数

<#
.SYNOPSIS
    从 GitHub Releases API 获取最新版本信息
.PARAMETER Owner
    仓库所有者
.PARAMETER Repo
    仓库名称
.RETURNS
    成功返回 release 对象，失败返回 $null
#>
function Get-GitHubLatestRelease {
    param(
        [string]$Owner,
        [string]$Repo
    )
    
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $api = "https://api.github.com/repos/$Owner/$Repo/releases/latest"
    $headers = @{ 'User-Agent' = 'PowerShell' }
    
    try {
        $release = Invoke-RestMethod -Uri $api -Headers $headers -UseBasicParsing -TimeoutSec 30
        return $release
    }
    catch {
        Write-Status "无法连接到 GitHub API: $($_.Exception.Message)" -Color Yellow
        return $null
    }
}

#endregion

#region 初始化

# 确保 TLS 1.2 可用
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

#endregion
