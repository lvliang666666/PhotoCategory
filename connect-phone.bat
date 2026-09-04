@echo off
setlocal
chcp 65001 >nul

set "PHOTO_STORER_PROJECT_ROOT=%~dp0"

rem Read the PowerShell source explicitly as UTF-8 for Windows PowerShell 5.1.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$source = Get-Content -LiteralPath (Join-Path $env:PHOTO_STORER_PROJECT_ROOT 'scripts\connect-phone.ps1') -Raw -Encoding UTF8; & ([ScriptBlock]::Create($source)) -ProjectRoot $env:PHOTO_STORER_PROJECT_ROOT"
set "CONNECT_EXIT_CODE=%ERRORLEVEL%"

if /I "%~1"=="--no-pause" exit /b %CONNECT_EXIT_CODE%

echo.
pause
exit /b %CONNECT_EXIT_CODE%
