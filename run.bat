@echo off
REM ============================================================================
REM run.bat — Build and launch the Hollow Knight Assembly Demo on Windows
REM Runs inside WSL (Windows Subsystem for Linux). WSL 2 + Ubuntu required.
REM GUI window appears automatically via WSLg (Windows 10 22H2 / Windows 11).
REM Usage: double-click run.bat, or run from cmd.exe / PowerShell
REM ============================================================================

setlocal
cd /d "%~dp0"

echo === Hollow Knight -- Assembly Demo (Windows / WSL) ===
echo.

REM ---- Check that WSL is installed ----
where wsl >nul 2>&1
if errorlevel 1 (
    echo ERROR: WSL is not installed.
    echo.
    echo This demo runs on Linux/X11. On Windows, launch it via WSL.
    echo Install WSL with:
    echo     wsl --install
    echo Then reboot, launch Ubuntu once to finish setup, and re-run this script.
    echo.
    pause
    exit /b 1
)

REM ---- Check that a WSL distro is installed ----
wsl -l -q >nul 2>&1
if errorlevel 1 (
    echo ERROR: No WSL distribution is installed.
    echo Install Ubuntu with:  wsl --install -d Ubuntu
    echo.
    pause
    exit /b 1
)

REM ---- Run build + launch inside WSL ----
REM Convert the Windows working-directory path to a WSL path via wslpath,
REM then invoke run.sh inside WSL.
echo Launching in WSL...
echo.

wsl bash -lc "cd \"$(wslpath -a '%CD%')\" && chmod +x run.sh && ./run.sh"

if errorlevel 1 (
    echo.
    echo Game exited with an error.
    pause
    exit /b 1
)

endlocal
