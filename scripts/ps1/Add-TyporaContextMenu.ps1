<#
.SYNOPSIS
    添加 "新建 Markdown 文件" 到右键菜单 (关联 Typora)
.DESCRIPTION
    参考文档: https://blog.csdn.net/qq_43564374/article/details/109471694
    该脚本修改注册表以添加 .md 文件的 ShellNew 项，并设置 Typora 为默认打开程序。
    
    主要注册表项:
    - HKCR\.md
    - HKCR\.md\ShellNew
    - HKCR\Typora.exe
.PARAMETER Headless
    静默模式，不显示任何交互式提示
.PARAMETER Silent
    不输出任何状态信息
.PARAMETER NoAdmin
    不自动请求管理员权限（仅用于内部调用）
#>
param(
    [switch]$Headless,
    [switch]$Silent,
    [switch]$NoAdmin
)

# 导入通用模块
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$ScriptDir\Common.ps1"

# 检查管理员权限
if (-not (Test-IsAdmin)) {
    if ($NoAdmin) {
        Write-ErrorAndExit "此脚本需要管理员权限才能修改注册表。"
    }
    Request-AdminPrivilege -ScriptPath $MyInvocation.MyCommand.Path -Arguments $PSBoundParameters.Values
}

Show-Banner "添加 Typora 右键新建菜单"

# 查找 Typora 安装路径 (用于设置图标和打开命令)
Write-Status "正在查找 Typora 安装路径..."
$TyporaPath = $null
$PossiblePaths = @(
    "$env:ProgramFiles\Typora\Typora.exe",
    "$env:ProgramFiles (x86)\Typora\Typora.exe",
    "$env:LOCALAPPDATA\Programs\Typora\Typora.exe"
)

# 尝试从注册表获取
try {
    $AppPath = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\Typora.exe" -ErrorAction SilentlyContinue
    if ($AppPath) { $TyporaPath = $AppPath.'(default)' }
} catch {}

# 尝试从常用路径获取
if (-not $TyporaPath) {
    foreach ($path in $PossiblePaths) {
        if (Test-Path $path) {
            $TyporaPath = $path
            break
        }
    }
}

if ($TyporaPath) {
    Write-Status "找到 Typora: $TyporaPath" -Color Green
} else {
    Write-Status "未找到自动安装的 Typora，将仅应用通用注册表设置。" -Color Yellow
    Write-Status "如果菜单图标不显示，请确保 Typora 已正确安装。" -Color Gray
}

# 定义注册表操作
try {
    Write-Status "正在配置注册表..."

    # 1. 设置 .md 默认关联为 Typora.exe
    Set-RegistryValue -Path "Registry::HKEY_CLASSES_ROOT\.md" -Name "(default)" -Value "Typora.exe" -Type String

    # 2. 设置新建菜单项
    $ShellNewPath = "Registry::HKEY_CLASSES_ROOT\.md\ShellNew"
    if (-not (Test-Path $ShellNewPath)) { New-Item -Path $ShellNewPath -Force | Out-Null }
    Set-RegistryValue -Path $ShellNewPath -Name "NullFile" -Value "" -Type String

    # 3. 配置 Typora.exe ProgID
    $TyporaProgIDPath = "Registry::HKEY_CLASSES_ROOT\Typora.exe"
    Set-RegistryValue -Path $TyporaProgIDPath -Name "(default)" -Value "Markdown 文件" -Type String

    # 4. 如果找到路径，设置图标和打开命令
    if ($TyporaPath) {
        # 设置图标
        Set-RegistryValue -Path "$TyporaProgIDPath\DefaultIcon" -Name "(default)" -Value "$TyporaPath" -Type String
        
        # 设置打开命令
        $CommandPath = "$TyporaProgIDPath\shell\open\command"
        if (-not (Test-Path $CommandPath)) { New-Item -Path $CommandPath -Force | Out-Null }
        Set-RegistryValue -Path $CommandPath -Name "(default)" -Value "`"$TyporaPath`" `"%1`"" -Type String
    }

    Write-Status "`n[√] 成功! 右键新建菜单已添加。" -Color Green
    Write-Status "注意: 如果右键菜单未立即生效，请重启资源管理器或注销重试。" -Color Yellow

} catch {
    Write-ErrorAndExit "注册表修改失败: $($_.Exception.Message)"
}

Wait-OrPause
