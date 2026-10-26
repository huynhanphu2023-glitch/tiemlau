@echo off
chcp 65001 >nul
cd /d "%~dp0"
"%~dp0..\tiệm lẩu test\tools\Godot.exe" --headless --path "%~dp0." --editor --import --quit
if errorlevel 1 goto failed
"%~dp0..\tiệm lẩu test\tools\Godot.exe" --headless --path "%~dp0." --export-release Windows "%~dp0Choi Tiem Lau.exe"
if errorlevel 1 goto failed
echo Đã dựng xong. Mở Choi Tiem Lau.exe để chơi.
pause
exit /b 0
:failed
echo Chưa dựng được. Kiểm tra lỗi ở phía trên.
pause
exit /b 1
