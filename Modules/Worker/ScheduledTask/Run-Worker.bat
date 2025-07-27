@echo off
REM Batch script to execute Run-Worker.ps1 in administrator mode
REM This script changes to the Worker ScheduledTask directory and runs the PowerShell script using PowerShell 7 if available

echo Starting Run-Worker.ps1 execution...

REM Get the directory where this batch file is located
set "SCRIPT_DIR=%~dp0"

REM Set log file path to the ScheduledTask folder
set "LOG_FILE=%SCRIPT_DIR%Run-Worker.log"

REM Change to the script directory
cd /d "%SCRIPT_DIR%"

REM Try to use pwsh.exe (PowerShell 7+), fallback to Windows PowerShell if not found
where pwsh.exe >nul 2>&1
if %ERRORLEVEL%==0 (
    set "POWERSHELL_CMD=pwsh.exe"
) else (
    set "POWERSHELL_CMD=powershell.exe"
)

REM Execute the PowerShell script with execution policy bypass and log output
%POWERSHELL_CMD% -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT_DIR%Run-Worker.ps1" > "%LOG_FILE%" 2>&1

REM Check the exit code
if %ERRORLEVEL% neq 0 (
    echo ERROR: Run-Worker.ps1 failed with exit code %ERRORLEVEL%. See %LOG_FILE% for details.
    exit /b %ERRORLEVEL%
) else (
    echo Run-Worker.ps1 completed successfully. See %LOG_FILE% for details.
)

echo Run-Worker execution finished.