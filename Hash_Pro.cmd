@echo off
setlocal
title AutoPilot Hash Generator - Offline Edition

REM ============================================================
REM  AutoPilot Hardware Hash Generator - Launcher
REM  All logic lives in AutoPilotHash.ps1 (single merged PS1 file)
REM ============================================================

cd /d "%~dp0"

REM ---- Administrator check ----
net session >nul 2>&1
if %errorlevel% neq 0 (
    color 0C
    echo.
    echo ========================================
    echo  ERROR: Administrator privileges required
    echo ========================================
    echo  Right-click this file and choose
    echo  "Run as Administrator", then try again.
    echo.
    pause
    exit /b 1
)

REM ---- Confirm required file exists ----
if not exist "%~dp0AutoPilotHash.ps1" (
    color 0C
    echo.
    echo ERROR: AutoPilotHash.ps1 not found in %~dp0
    echo It must be in the same folder as this file.
    echo.
    pause
    exit /b 1
)

where powershell.exe >nul 2>&1
if %errorlevel% neq 0 (
    color 0C
    echo ERROR: PowerShell is not available on this system.
    pause
    exit /b 1
)

REM ---- Hand off to PowerShell engine ----
REM (strip trailing backslash from the path - a trailing \ before a closing
REM  quote gets misread as an escaped quote and corrupts the argument)
set "ROOTDIR=%~dp0"
if "%ROOTDIR:~-1%"=="\" set "ROOTDIR=%ROOTDIR:~0,-1%"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0AutoPilotHash.ps1" -RootPath "%ROOTDIR%"
set "EXITCODE=%errorlevel%"

if "%EXITCODE%"=="0" (
    color 0A
    echo.
    echo Closing in 2 seconds...
    timeout /t 2 /nobreak >nul
) else (
    color 0C
    echo.
    pause
)

exit /b %EXITCODE%
