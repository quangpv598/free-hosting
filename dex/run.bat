@echo off
setlocal

REM Get the directory of the current batch file
set "scriptDir=%~dp0"

REM Run the PowerShell script install.ps1 in the same directory with ExecutionPolicy Bypass
powershell -NoProfile -ExecutionPolicy Bypass -File "%scriptDir%install.ps1"

endlocal
pause
