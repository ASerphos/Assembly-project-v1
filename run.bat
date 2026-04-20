@echo off
REM ============================================================================
REM run.bat — Build and launch the Hollow Knight Assembly Demo on Windows
REM Requires: NASM and MinGW-w64 GCC (install via MSYS2)
REM Usage: double-click run.bat, or run from cmd.exe / PowerShell
REM ============================================================================

setlocal
cd /d "%~dp0"

echo === Hollow Knight -- Assembly Demo ===
echo.

REM ---- Check for NASM ----
where nasm >nul 2>&1
if errorlevel 1 (
    echo ERROR: NASM assembler not found.
    echo.
    echo Install MSYS2 from https://www.msys2.org/
    echo Then open "MSYS2 MinGW64" terminal and run:
    echo     pacman -S mingw-w64-x86_64-nasm mingw-w64-x86_64-gcc make
    echo.
    echo After installing, make sure MSYS2's bin folder is in your PATH:
    echo     C:\msys64\mingw64\bin
    echo.
    pause
    exit /b 1
)

REM ---- Check for GCC (MinGW-w64) ----
where gcc >nul 2>&1
if errorlevel 1 (
    echo ERROR: GCC (MinGW-w64) not found.
    echo.
    echo Install MSYS2 from https://www.msys2.org/
    echo Then open "MSYS2 MinGW64" terminal and run:
    echo     pacman -S mingw-w64-x86_64-nasm mingw-w64-x86_64-gcc make
    echo.
    echo After installing, make sure MSYS2's bin folder is in your PATH:
    echo     C:\msys64\mingw64\bin
    echo.
    pause
    exit /b 1
)

REM ---- Build ----
echo Building...
if not exist obj mkdir obj

nasm -f win64 -I include/ -o obj/main_win.o src/main_win.asm
if errorlevel 1 goto :build_error

nasm -f win64 -I include/ -o obj/player.o src/player.asm
if errorlevel 1 goto :build_error

nasm -f win64 -I include/ -o obj/render.o src/render.asm
if errorlevel 1 goto :build_error

nasm -f win64 -I include/ -o obj/enemy.o src/enemy.asm
if errorlevel 1 goto :build_error

nasm -f win64 -I include/ -o obj/collision.o src/collision.asm
if errorlevel 1 goto :build_error

nasm -f win64 -I include/ -o obj/level.o src/level.asm
if errorlevel 1 goto :build_error

nasm -f win64 -I include/ -o obj/sprites.o src/sprites.asm
if errorlevel 1 goto :build_error

echo Linking...
gcc -o hollow_knight.exe obj/main_win.o obj/player.o obj/render.o obj/enemy.o obj/collision.o obj/level.o obj/sprites.o -lgdi32 -luser32 -lkernel32 -mwindows
if errorlevel 1 goto :build_error

echo.
echo Build successful!
echo.
echo Controls: WASD = move, Space = jump, Left Click = attack, Right Click = dash, Esc = quit
echo.
echo Launching hollow_knight.exe...
start "" hollow_knight.exe
goto :eof

:build_error
echo.
echo Build failed! Check the error messages above.
pause
exit /b 1
