@echo off
REM Alternatif tanpa CMake.
REM Jalankan dari "x64 Native Tools Command Prompt for VS".
setlocal
cd /d "%~dp0"
where cl >nul 2>&1
if errorlevel 1 (
  echo Jalankan skrip ini dari "x64 Native Tools Command Prompt for VS".
  exit /b 1
)
if not exist build\cl mkdir build\cl
cl /nologo /EHsc /std:c++17 /W3 /O2 /MT /utf-8 ^
   /DWIN32_LEAN_AND_MEAN /DNOMINMAX /D_WIN32_WINNT=0x0A00 /D_CRT_SECURE_NO_WARNINGS ^
   /Fo:build\cl\ /Fe:build\cl\sony_camera_helper.exe ^
   src\main.cpp src\json_min.cpp src\ptp_wia.cpp src\sony_camera.cpp ^
   /link ws2_32.lib ole32.lib oleaut32.lib wiaguid.lib
if errorlevel 1 (
  echo.
  echo BUILD GAGAL
  exit /b 1
)
echo.
echo Selesai: %~dp0build\cl\sony_camera_helper.exe
exit /b 0
