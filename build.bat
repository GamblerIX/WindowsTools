@echo off
echo ============================================
echo   Building Windows ToolBox EXE
echo ============================================

:: Install requirements
pip install -r requirements.txt
pip install pyinstaller

:: Build command
:: --noconsole: Don't show terminal for GUI
:: --onefile: Bundle into a single EXE
:: --add-data: Include scripts
:: --icon: Set EXE:: 打包命令
pyinstaller --noconsole --onefile --uac-admin ^
    --add-data "scripts;scripts" ^
    --add-data "logo.png;." ^
    --icon "logo.png" ^
    --name "WindowsToolBox" ^
    toolbox.py

echo.
echo ============================================
echo   Build complete! Check the 'dist' folder.
echo ============================================
