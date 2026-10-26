@echo off
chcp 65001 >nul
cd /d "%~dp0"
start "" "%~dp0..\tiệm lẩu test\tools\Godot.exe" --path "%~dp0." --editor
