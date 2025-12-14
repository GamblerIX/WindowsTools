@echo off
:: ============================================
:: Windows Terminal Installation Script
:: Auto-detect Windows 10/11 and install correct version
:: ============================================

:: Check for admin privileges
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting administrator privileges...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

echo ============================================
echo Windows Terminal Installation Script
echo ============================================
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0Install-WindowsTerminal.ps1"

echo.
echo ============================================
echo You can now:
echo   1. Search "Terminal" in Start menu
echo   2. Right-click in Explorer, select "Open in Terminal"
echo ============================================
pause
