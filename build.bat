@echo off
REM PulseCAD Desktop App - Build Script
REM This script builds the Electron app into a Windows installer

echo Building PulseCAD Desktop App...
echo.

REM Clean previous build
if exist dist (
    echo Cleaning previous build...
    rmdir /s /q dist >nul 2>&1
)

REM Install dependencies if needed
if not exist node_modules (
    echo Installing dependencies...
    call npm install
)

REM Build the app
echo Building application...
call npm run build

if %ERRORLEVEL% EQU 0 (
    echo.
    echo Build completed successfully!
    echo The installer is ready in: dist\PulseCAD-Setup.exe
) else (
    echo.
    echo Build failed. Please check the error messages above.
    pause
    exit /b 1
)

pause
