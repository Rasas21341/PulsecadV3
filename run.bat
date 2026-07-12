@echo off
REM PulseCAD Desktop App - Run Script
REM This script starts the Electron app in development mode

echo Starting PulseCAD Desktop App...
echo.

REM Install dependencies if needed
if not exist node_modules (
    echo Installing dependencies...
    call npm install
)

REM Start the app
call npm start
