@echo off
echo Installing CI Status...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1"
pause
