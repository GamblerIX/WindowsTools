# Windows Server 安全策略优化
# 禁用密码过期、密码复杂度检查、Ctrl+Alt+Delete 登录要求

[CmdletBinding()]
param(
    [switch]$Headless,    # 无头模式，禁用交互式提示
    [switch]$Silent,      # 静默模式，减少输出
    [switch]$NoAdmin      # 跳过管理员权限检查
)

# 退出码定义: 0=成功, 1=一般错误, 3=权限错误

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
        Start-Sleep -Seconds 3
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
        Write-Host "  Windows Server 安全策略优化" -ForegroundColor Cyan
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "此脚本将执行以下优化:" -ForegroundColor Yellow
        Write-Host "  • 禁用密码过期策略" -ForegroundColor White
        Write-Host "  • 禁用密码复杂度要求" -ForegroundColor White
        Write-Host "  • 禁用 Ctrl+Alt+Delete 登录要求" -ForegroundColor White
        Write-Host ""
    }

    $successCount = 0
    $totalSteps = 3

    # 步骤 1: 禁用密码过期
    Write-Status "[1/$totalSteps] 正在禁用密码过期策略..." -Color White
    try {
        # 获取所有本地用户并设置密码永不过期
        $users = Get-LocalUser -ErrorAction Stop
        foreach ($user in $users) {
            Set-LocalUser -Name $user.Name -PasswordNeverExpires $true -ErrorAction SilentlyContinue
        }
        
        # 同时通过 net accounts 设置最大密码期限为无限制
        $netResult = net accounts /maxpwage:unlimited 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Status "  ✓ 密码过期策略已禁用" -Color Green
            $successCount++
        } else {
            Write-Status "  ⚠ 密码过期策略设置可能部分生效" -Color Yellow
            $successCount++
        }
    }
    catch {
        Write-Status "  ✗ 禁用密码过期失败: $($_.Exception.Message)" -Color Red
    }

    # 步骤 2: 禁用密码复杂度要求
    Write-Status "[2/$totalSteps] 正在禁用密码复杂度要求..." -Color White
    try {
        # 创建临时目录
        $tempDir = Join-Path $env:TEMP "SecurityPolicyTemp"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
        }
        
        $cfgPath = Join-Path $tempDir "secpol.cfg"
        $dbPath = Join-Path $tempDir "secedit.sdb"
        
        # 导出当前安全策略
        $exportResult = secedit /export /cfg $cfgPath 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "无法导出安全策略: $exportResult"
        }
        
        # 读取并修改安全策略
        $content = Get-Content $cfgPath -Raw -Encoding Unicode
        
        # 禁用密码复杂度要求 (PasswordComplexity = 0)
        if ($content -match "PasswordComplexity\s*=\s*\d+") {
            $content = $content -replace "PasswordComplexity\s*=\s*\d+", "PasswordComplexity = 0"
        } else {
            # 如果没有找到，在 [System Access] 节添加
            $content = $content -replace "(\[System Access\])", "`$1`r`nPasswordComplexity = 0"
        }
        
        # 设置最小密码长度为 0
        if ($content -match "MinimumPasswordLength\s*=\s*\d+") {
            $content = $content -replace "MinimumPasswordLength\s*=\s*\d+", "MinimumPasswordLength = 0"
        } else {
            $content = $content -replace "(\[System Access\])", "`$1`r`nMinimumPasswordLength = 0"
        }
        
        # 设置最大密码期限为 -1 (永不过期)
        if ($content -match "MaximumPasswordAge\s*=\s*-?\d+") {
            $content = $content -replace "MaximumPasswordAge\s*=\s*-?\d+", "MaximumPasswordAge = -1"
        } else {
            $content = $content -replace "(\[System Access\])", "`$1`r`nMaximumPasswordAge = -1"
        }
        
        # 保存修改后的策略
        $content | Set-Content $cfgPath -Encoding Unicode -Force
        
        # 应用新的安全策略
        $importResult = secedit /configure /db $dbPath /cfg $cfgPath /areas SECURITYPOLICY 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Status "  ✓ 密码复杂度要求已禁用" -Color Green
            $successCount++
        } else {
            throw "应用安全策略失败: $importResult"
        }
        
        # 清理临时文件
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Status "  ✗ 禁用密码复杂度失败: $($_.Exception.Message)" -Color Red
        # 清理临时文件
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    # 步骤 3: 禁用 Ctrl+Alt+Delete 登录要求
    Write-Status "[3/$totalSteps] 正在禁用 Ctrl+Alt+Delete 登录要求..." -Color White
    try {
        $regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"
        
        # 设置 DisableCAD = 1 禁用 Ctrl+Alt+Delete
        if (Test-Path $regPath) {
            Set-ItemProperty -Path $regPath -Name "DisableCAD" -Value 1 -Type DWord -ErrorAction Stop
            Write-Status "  ✓ Ctrl+Alt+Delete 登录要求已禁用" -Color Green
            $successCount++
        } else {
            throw "注册表路径不存在: $regPath"
        }
    }
    catch {
        Write-Status "  ✗ 禁用 Ctrl+Alt+Delete 失败: $($_.Exception.Message)" -Color Red
    }

    # 刷新组策略
    Write-Status "" -Color White
    Write-Status "正在刷新组策略..." -Color White
    gpupdate /force 2>&1 | Out-Null

    # 输出结果
    if (-not $Silent) {
        Write-Host ""
        if ($successCount -eq $totalSteps) {
            Write-Host "============================================" -ForegroundColor Green
            Write-Host "  操作成功！所有安全策略优化已完成。" -ForegroundColor Green
            Write-Host "============================================" -ForegroundColor Green
        } elseif ($successCount -gt 0) {
            Write-Host "============================================" -ForegroundColor Yellow
            Write-Host "  部分操作完成！($successCount/$totalSteps)" -ForegroundColor Yellow
            Write-Host "============================================" -ForegroundColor Yellow
        } else {
            Write-Host "============================================" -ForegroundColor Red
            Write-Host "  操作失败！请检查上述错误信息。" -ForegroundColor Red
            Write-Host "============================================" -ForegroundColor Red
        }
        Write-Host ""
        Write-Host "提示: 部分设置可能需要重启计算机后完全生效。" -ForegroundColor Cyan
        Write-Host ""
    }

    Wait-OrPause
    
    if ($successCount -eq $totalSteps) {
        exit 0
    } elseif ($successCount -gt 0) {
        exit 0  # 部分成功也返回 0
    } else {
        exit 1
    }
}
catch {
    Write-ErrorAndExit "操作过程中发生错误: $($_.Exception.Message)" 1
}
#endregion
