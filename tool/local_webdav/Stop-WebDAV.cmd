@echo off
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Stop-LocalWebDav.ps1" -StateDirectory "%LOCALAPPDATA%\MyLedger-WebDAV"
pause
