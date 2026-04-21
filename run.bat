@echo off
REM ============================================================================
REM run.bat — Launch the Hollow Knight Assembly Demo
REM Just double-click this file to play!
REM ============================================================================

cd /d "%~dp0"

if not exist hollow_knight.exe (
    echo hollow_knight.exe not found!
    echo Re-download the project from GitHub.
    pause
    exit /b 1
)

echo === Hollow Knight -- Assembly Demo ===
echo.
echo Controls: WASD = move, Space = jump, Left Click = attack, Right Click = dash, Esc = quit
echo.
start "" hollow_knight.exe
