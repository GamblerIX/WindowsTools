@echo off
setlocal enabledelayedexpansion

:: ============================================
:: PowerShell 7 Silent Installer
:: Auto-fetch latest stable version + UAC elevation
:: ============================================

:: UAC auto elevation
>nul 2>&1 "%SYSTEMROOT%\system32\cacls.exe" "%SYSTEMROOT%\system32\config\system"
if '%errorlevel%' neq '0' (
    echo Requesting administrator privileges...
    goto UACPrompt
) else ( goto gotAdmin )

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    exit /b

:gotAdmin
    if exist "%temp%\getadmin.vbs" ( del "%temp%\getadmin.vbs" )
    pushd "%CD%"
    cd /d "%~dp0"

title PowerShell 7 Silent Installer

set "TEMP_DIR=%TEMP%\PS7Install"

echo ============================================
echo   PowerShell 7 Silent Installer
echo   Auto-fetch latest stable version
echo ============================================
echo.

:: Create temp directory
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

:: Get latest version and download
echo [1/3] Fetching latest version and downloading...
echo.

powershell -Command "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $release = Invoke-RestMethod -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest'; $version = $release.tag_name -replace '^v',''; $msiName = 'PowerShell-' + $version + '-win-x64.msi'; $asset = $release.assets | Where-Object { $_.name -eq $msiName }; if ($asset) { Write-Host 'Latest version:' $version; Write-Host 'Download URL:' $asset.browser_download_url; Invoke-WebRequest -Uri $asset.browser_download_url -OutFile '%TEMP_DIR%\ps7.msi' -UseBasicParsing; exit 0 } else { Write-Host 'MSI package not found'; exit 1 }"

if not exist "%TEMP_DIR%\ps7.msi" (
    echo [ERROR] Download failed! Please check network connection.
    pause
    exit /b 1
)

echo.
echo [2/3] Download complete, installing...
echo.

:: Silent install PowerShell 7
msiexec.exe /package "%TEMP_DIR%\ps7.msi" /quiet /norestart ADD_PATH=1 ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=0 ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=0 ENABLE_PSREMOTING=0 REGISTER_MANIFEST=0 USE_MU=0 ENABLE_MU=0

if %errorlevel% neq 0 (
    echo [ERROR] Installation failed! Error code: %errorlevel%
    pause
    exit /b 1
)

echo [3/3] Cleaning up temp files...
del /q "%TEMP_DIR%\ps7.msi" >nul 2>&1
rmdir /q "%TEMP_DIR%" >nul 2>&1

echo.
echo ============================================
echo   Installation complete!
echo   PowerShell 7 installed to:
echo   %ProgramFiles%\PowerShell\7
echo ============================================
echo.
echo You can start PowerShell 7 by:
echo   - Search "PowerShell 7" in Start Menu
echo   - Type "pwsh" in command line
echo.

pause
