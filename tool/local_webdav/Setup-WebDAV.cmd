@echo off
chcp 65001 >nul
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Setup-LocalWebDav.ps1"
if errorlevel 1 echo 设置未完成，请保留上方错误信息。不要发送密码。
pause
