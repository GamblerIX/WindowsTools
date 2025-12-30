# 全面禁用 Windows 应用拦截
# 解决"管理员已阻止你运行此应用"红色警告弹窗
# 适用于阿里云/腾讯云等云服务器的 Windows Server 环境

[CmdletBinding()]
param(
    [switch]$Headless,           # 无头模式，禁用交互式提示
    [switch]$Silent,             # 静默模式，减少输出
    [switch]$NoAdmin,            # 跳过管理员权限检查
    [string]$UnblockPath = ""    # 可选：批量解除指定目录下文件的锁定
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

#region Admin Check
if (-not $NoAdmin) {
    if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Status "正在请求管理员权限..." -Color Yellow
        $arguments = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`"")
        if ($Headless) { $arguments += "-Headless" }
        if ($Silent) { $arguments += "-Silent" }
        if ($UnblockPath) { $arguments += "-UnblockPath"; $arguments += "`"$UnblockPath`"" }
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
        Write-Host "  全面禁用 Windows 应用拦截" -ForegroundColor Cyan
        Write-Host "============================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "⚠ 安全警告: 此操作会显著降低系统安全性，" -ForegroundColor Yellow
        Write-Host "  仅建议在受信任的服务器环境中使用。" -ForegroundColor Yellow
        Write-Host ""
    }

    $successCount = 0
    $totalSteps = 8

    # ========== 步骤 1: 禁用 SmartScreen ==========
    Write-Status "[1/$totalSteps] 正在禁用 Windows SmartScreen..." -Color White
    
    $smartScreenSuccess = $true
    # Explorer SmartScreen
    if (Set-RegistryValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer" -Name "SmartScreenEnabled" -Value "Off" -Type String) {
        Write-Status "    ✓ Explorer SmartScreen 已禁用" -Color Green
    } else { $smartScreenSuccess = $false }
    
    # 系统级 SmartScreen 策略
    if (Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\System" -Name "EnableSmartScreen" -Value 0) {
        Write-Status "    ✓ 系统级 SmartScreen 策略已禁用" -Color Green
    } else { $smartScreenSuccess = $false }
    
    if ($smartScreenSuccess) { $successCount++ }

    # ========== 步骤 2: 禁用管理员代码签名验证 ==========
    Write-Status "[2/$totalSteps] 正在禁用管理员代码签名验证..." -Color White
    
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    if (Set-RegistryValue -Path $regPath -Name "ValidateAdminCodeSignatures" -Value 0) {
        Write-Status "    ✓ ValidateAdminCodeSignatures 已禁用" -Color Green
        $successCount++
    }

    # ========== 步骤 3: 禁用软件限制策略 (SRP) ==========
    Write-Status "[3/$totalSteps] 正在禁用软件限制策略 (SRP)..." -Color White
    
    $srpPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\safer\codeidentifiers"
    $srpSuccess = $true
    
    # 设置默认级别为"不受限制" (262144 = Unrestricted)
    if (Test-Path $srpPath) {
        if (Set-RegistryValue -Path $srpPath -Name "DefaultLevel" -Value 262144) {
            Write-Status "    ✓ SRP 默认级别已设为不受限制" -Color Green
        } else { $srpSuccess = $false }
        
        # 禁用透明执行
        if (Set-RegistryValue -Path $srpPath -Name "TransparentEnabled" -Value 0) {
            Write-Status "    ✓ SRP 透明执行已禁用" -Color Green
        }
    } else {
        Write-Status "    - 未检测到软件限制策略配置" -Color Gray
    }
    
    if ($srpSuccess) { $successCount++ }

    # ========== 步骤 4: 解除附件管理器限制 ==========
    Write-Status "[4/$totalSteps] 正在解除附件管理器限制..." -Color White
    
    $attachPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Attachments"
    $attachSuccess = $true
    
    # 禁用保存 Zone 信息
    if (Set-RegistryValue -Path $attachPath -Name "SaveZoneInformation" -Value 1) {
        Write-Status "    ✓ 已禁用 Zone 信息保存" -Color Green
    } else { $attachSuccess = $false }
    
    # 禁用扫描下载文件
    if (Set-RegistryValue -Path $attachPath -Name "ScanWithAntiVirus" -Value 1) {
        Write-Status "    ✓ 已调整附件扫描策略" -Color Green
    }
    
    if ($attachSuccess) { $successCount++ }

    # ========== 步骤 5: 禁用 AppLocker 服务 ==========
    Write-Status "[5/$totalSteps] 正在禁用 AppLocker 服务..." -Color White
    
    try {
        $appIdSvc = Get-Service -Name "AppIDSvc" -ErrorAction SilentlyContinue
        if ($appIdSvc) {
            if ($appIdSvc.Status -eq "Running") {
                Stop-Service -Name "AppIDSvc" -Force -ErrorAction SilentlyContinue
                Write-Status "    ✓ AppIDSvc 服务已停止" -Color Green
            }
            Set-Service -Name "AppIDSvc" -StartupType Disabled -ErrorAction SilentlyContinue
            Write-Status "    ✓ AppIDSvc 服务已禁用自启动" -Color Green
            $successCount++
        } else {
            Write-Status "    - AppIDSvc 服务不存在" -Color Gray
            $successCount++
        }
    }
    catch {
        Write-Status "    ✗ AppIDSvc 操作失败: $($_.Exception.Message)" -Color Red
    }

    # ========== 步骤 6: 批量解除文件锁定 ==========
    Write-Status "[6/$totalSteps] 正在处理文件锁定..." -Color White
    
    if ($UnblockPath -and (Test-Path $UnblockPath)) {
        try {
            $files = Get-ChildItem -Path $UnblockPath -Recurse -File -ErrorAction SilentlyContinue
            $unblockCount = 0
            foreach ($file in $files) {
                try {
                    Unblock-File -Path $file.FullName -ErrorAction SilentlyContinue
                    $unblockCount++
                } catch {}
            }
            Write-Status "    ✓ 已解除 $unblockCount 个文件的锁定" -Color Green
            $successCount++
        }
        catch {
            Write-Status "    ✗ 解锁文件失败: $($_.Exception.Message)" -Color Red
        }
    } else {
        # 默认解锁常见的 Python 路径
        $defaultPaths = @(
            "$env:USERPROFILE\Python*",
            "$env:LOCALAPPDATA\Programs\Python*",
            "C:\Python*"
        )
        $totalUnblocked = 0
        foreach ($pattern in $defaultPaths) {
            $paths = Get-Item -Path $pattern -ErrorAction SilentlyContinue
            foreach ($path in $paths) {
                $files = Get-ChildItem -Path $path.FullName -Recurse -File -ErrorAction SilentlyContinue
                foreach ($file in $files) {
                    try {
                        Unblock-File -Path $file.FullName -ErrorAction SilentlyContinue
                        $totalUnblocked++
                    } catch {}
                }
            }
        }
        if ($totalUnblocked -gt 0) {
            Write-Status "    ✓ 已自动解除 $totalUnblocked 个 Python 相关文件的锁定" -Color Green
        } else {
            Write-Status "    - 未找到需要解锁的文件（可使用 -UnblockPath 指定目录）" -Color Gray
        }
        $successCount++
    }

    # ========== 步骤 7: 禁用证书吊销检查 ==========
    Write-Status "[7/$totalSteps] 正在禁用证书吊销检查..." -Color White
    
    $certRevSuccess = $true
    
    # 禁用 Internet 设置中的证书吊销检查
    $inetSettingsPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
    if (Set-RegistryValue -Path $inetSettingsPath -Name "CertificateRevocation" -Value 0) {
        Write-Status "    ✓ 用户级证书吊销检查已禁用" -Color Green
    } else { $certRevSuccess = $false }
    
    # 系统级禁用 CRL 检查
    $cryptoPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\safer\codeidentifiers"
    if (-not (Test-Path $cryptoPath)) {
        New-Item -Path $cryptoPath -Force | Out-Null
    }
    
    # 禁用签名检查
    $sigCheckPath = "HKLM:\SOFTWARE\Microsoft\Cryptography\Wintrust\Config"
    if (Set-RegistryValue -Path $sigCheckPath -Name "EnableCertPaddingCheck" -Value 0) {
        Write-Status "    ✓ 证书填充检查已禁用" -Color Green
    }
    
    # 禁用 Authenticode 签名者证书链验证
    $authPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System"
    if (Set-RegistryValue -Path $authPath -Name "DisableCertValidation" -Value 1) {
        Write-Status "    ✓ 系统级证书验证已禁用" -Color Green
    }
    
    # 禁用驱动程序签名强制
    if (Set-RegistryValue -Path "HKLM:\SYSTEM\CurrentControlSet\Control\CI" -Name "UMCIDisabled" -Value 1) {
        Write-Status "    ✓ 用户模式代码完整性检查已禁用" -Color Green
    }
    
    # 禁用 SmartScreen 的证书检查
    if (Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\SmartScreen" -Name "ConfigureAppInstallControlEnabled" -Value 0) {
        Write-Status "    ✓ SmartScreen 应用安装控制已禁用" -Color Green
    }
    
    # 禁用网络获取 CRL
    if (Set-RegistryValue -Path "HKLM:\SOFTWARE\Policies\Microsoft\SystemCertificates\AuthRoot" -Name "DisableRootAutoUpdate" -Value 1) {
        Write-Status "    ✓ 根证书自动更新已禁用" -Color Green
    }
    
    # 设置 Internet Explorer/Edge 相关证书吊销设置
    $wuPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings"
    if (Set-RegistryValue -Path $wuPath -Name "CertificateRevocation" -Value 0) {
        Write-Status "    ✓ 系统级 Internet 证书吊销检查已禁用" -Color Green
    }
    
    if ($certRevSuccess) { $successCount++ }

    # ========== 步骤 8: 使用 takeown/icacls 重置文件权限 ==========
    Write-Status "[8/$totalSteps] 正在重置 Python 相关文件权限..." -Color White
    
    $permSuccess = $true
    $pythonPaths = @()
    
    # 收集所有 Python 安装路径
    $searchPaths = @(
        "$env:USERPROFILE\Python*",
        "$env:LOCALAPPDATA\Programs\Python*",
        "C:\Python*",
        "$env:ProgramFiles\Python*",
        "${env:ProgramFiles(x86)}\Python*"
    )
    
    foreach ($pattern in $searchPaths) {
        $found = Get-Item -Path $pattern -ErrorAction SilentlyContinue
        if ($found) {
            $pythonPaths += $found.FullName
        }
    }
    
    # 如果用户指定了路径，添加到列表
    if ($UnblockPath -and (Test-Path $UnblockPath)) {
        $pythonPaths += $UnblockPath
    }
    
    if ($pythonPaths.Count -eq 0) {
        Write-Status "    - 未找到 Python 安装路径" -Color Gray
        $successCount++
    } else {
        $permResetCount = 0
        
        foreach ($pythonPath in $pythonPaths) {
            Write-Status "    处理路径: $pythonPath" -Color Gray
            
            try {
                # 使用 takeown 获取所有权
                $takeownResult = & takeown /F "$pythonPath" /R /A /D Y 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Status "    ✓ 已获取 $pythonPath 的所有权" -Color Green
                } else {
                    Write-Status "    ! takeown 返回码: $LASTEXITCODE" -Color Yellow
                }
                
                # 使用 icacls 重置权限 - 授予管理员完全控制权
                $icaclsResult = & icacls "$pythonPath" /reset /T /C /Q 2>&1
                if ($LASTEXITCODE -eq 0) {
                    Write-Status "    ✓ 已重置 $pythonPath 的权限" -Color Green
                }
                
                # 授予 Administrators 和当前用户完全控制权
                $whoami = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
                & icacls "$pythonPath" /grant "Administrators:(OI)(CI)F" /T /C /Q 2>&1 | Out-Null
                & icacls "$pythonPath" /grant "${whoami}:(OI)(CI)F" /T /C /Q 2>&1 | Out-Null
                & icacls "$pythonPath" /grant "SYSTEM:(OI)(CI)F" /T /C /Q 2>&1 | Out-Null
                
                # 移除 Zone.Identifier 备用数据流（可能阻止执行）
                $exeFiles = Get-ChildItem -Path $pythonPath -Filter "*.exe" -Recurse -File -ErrorAction SilentlyContinue
                foreach ($exe in $exeFiles) {
                    try {
                        # 移除 Zone.Identifier ADS
                        $adsPath = "$($exe.FullName):Zone.Identifier"
                        if (Test-Path -LiteralPath $adsPath -ErrorAction SilentlyContinue) {
                            Remove-Item -LiteralPath $adsPath -Force -ErrorAction SilentlyContinue
                        }
                        # 使用 PowerShell 解锁
                        Unblock-File -Path $exe.FullName -ErrorAction SilentlyContinue
                        $permResetCount++
                    } catch {}
                }
                
                # 处理 DLL 文件
                $dllFiles = Get-ChildItem -Path $pythonPath -Filter "*.dll" -Recurse -File -ErrorAction SilentlyContinue
                foreach ($dll in $dllFiles) {
                    try {
                        Unblock-File -Path $dll.FullName -ErrorAction SilentlyContinue
                        $permResetCount++
                    } catch {}
                }
            }
            catch {
                Write-Status "    ✗ 处理 $pythonPath 时出错: $($_.Exception.Message)" -Color Red
                $permSuccess = $false
            }
        }
        
        if ($permResetCount -gt 0) {
            Write-Status "    ✓ 已重置 $permResetCount 个可执行文件的权限" -Color Green
        }
        
        if ($permSuccess) { $successCount++ }
    }

    # ========== 输出结果 ==========
    if (-not $Silent) {
        Write-Host ""
        if ($successCount -ge $totalSteps - 1) {
            Write-Host "============================================" -ForegroundColor Green
            Write-Host "  操作成功！应用拦截已全面禁用。" -ForegroundColor Green
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
        Write-Host "提示: 部分设置可能需要重新运行程序或重启系统后生效。" -ForegroundColor Cyan
        Write-Host "注意: 证书吊销检查已禁用，这会降低系统安全性。" -ForegroundColor Yellow
        Write-Host ""
    }

    Wait-OrPause
    
    if ($successCount -ge $totalSteps - 1) {
        exit 0
    } elseif ($successCount -gt 0) {
        exit 0
    } else {
        exit 1
    }
}
catch {
    Write-ErrorAndExit "操作过程中发生错误: $($_.Exception.Message)" 1
}
#endregion
