@echo off
chcp 65001 >nul
cd /d "%~dp0"
"%~dp0..\tiệm lẩu test\tools\WebServer.exe" "%~dp0Ban Web"
if errorlevel 1 pause
