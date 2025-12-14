@echo off
:: ============================================
:: Microsoft Store Installation Script
:: Supports: Windows 10 LTSC 2019/2021, Windows 11 LTSC 2024
:: ============================================

:: Check for admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process cmd -ArgumentList '/k \"%~f0\"' -Verb RunAs"
    exit /b
)

echo ============================================
echo Microsoft Store Installation Script
echo Supports: Win10 LTSC 2019/2021, Win11 LTSC 2024
echo ============================================
echo.

:: Detect Windows version
for /f "tokens=4-5 delims=. " %%i in ('ver') do set VERSION=%%i.%%j
echo Detected Windows version: %VERSION%
echo.

echo [1/2] Installing Microsoft Store via wsreset -i ...
echo This may take a few minutes, please wait...
wsreset.exe -i
if %errorlevel% neq 0 (
    echo wsreset failed, trying alternative method...
) else (
    echo wsreset completed.
)
echo.

echo [2/2] Registering Microsoft Store ...
powershell -ExecutionPolicy Bypass -Command "$store = Get-AppxPackage -Name 'Microsoft.WindowsStore'; if ($store) { $manifest = $store.InstallLocation + '\AppxManifest.xml'; Add-AppxPackage -DisableDevelopmentMode -Register $manifest; Write-Host 'Microsoft Store registered successfully.'; Write-Host 'Version:' $store.Version } else { Write-Host 'Store not found. Trying to install from Windows Update...'; Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.WindowsStore_8wekyb3d8bbwe }"

echo.
echo ============================================
echo Installation complete!
echo.
echo You can now:
echo   1. Search "Store" in Start menu
echo   2. Press Win+R, type: ms-windows-store:
echo.
echo If not found, please restart your computer.
echo ============================================
echo.
pause
exit
