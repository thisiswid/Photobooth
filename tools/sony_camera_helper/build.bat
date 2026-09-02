@echo off
REM Build sony_camera_helper.exe (Release, x64).
REM Jalankan dari "x64 Native Tools Command Prompt for VS" ATAU biarkan CMake
REM mencari generator Visual Studio sendiri.
setlocal
cd /d "%~dp0"
if not exist build mkdir build
cmake -S . -B build -A x64 || goto :err
cmake --build build --config Release || goto :err
echo.
echo Selesai: %~dp0build\Release\sony_camera_helper.exe
exit /b 0
:err
echo.
echo BUILD GAGAL
exit /b 1
