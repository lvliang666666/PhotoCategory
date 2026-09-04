@echo off
setlocal
chcp 65001 >nul

set "PHOTO_STORER_PROJECT_ROOT=%~dp0"

rem Read the PowerShell source explicitly as UTF-8 so Chinese messages work
rem correctly in both Windows PowerShell 5.1 and newer PowerShell versions.
powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "$source = Get-Content -LiteralPath (Join-Path $env:PHOTO_STORER_PROJECT_ROOT 'scripts\deploy.ps1') -Raw -Encoding UTF8; & ([ScriptBlock]::Create($source)) -ProjectRoot $env:PHOTO_STORER_PROJECT_ROOT"
set "DEPLOY_EXIT_CODE=%ERRORLEVEL%"

if /I "%~1"=="--no-pause" exit /b %DEPLOY_EXIT_CODE%

echo.
pause
exit /b %DEPLOY_EXIT_CODE%
