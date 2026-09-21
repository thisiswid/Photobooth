@echo off
REM Build sony_camera_helper.exe (Release, x64).
REM Jalankan dari "x64 Native Tools Command Prompt for VS" ATAU biarkan CMake
REM mencari generator Visual Studio sendiri.
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0"

REM Gunakan CMake global jika tersedia. Jika tidak, cari CMake yang dibundel
REM bersama Visual Studio melalui vswhere.
set "CMAKE_EXE=cmake"
where cmake >nul 2>nul
if errorlevel 1 (
  set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
  if not exist "!VSWHERE!" goto :cmake_missing

  set "CMAKE_EXE="
  for /f "usebackq delims=" %%I in (`"!VSWHERE!" -latest -products * -find Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe`) do (
    if not defined CMAKE_EXE set "CMAKE_EXE=%%I"
  )
  if not defined CMAKE_EXE goto :cmake_missing
)

if not exist build mkdir build
"%CMAKE_EXE%" -S . -B build -A x64 || goto :err
"%CMAKE_EXE%" --build build --config Release || goto :err
echo.
echo Selesai: %~dp0build\Release\sony_camera_helper.exe
exit /b 0

:cmake_missing
echo.
echo CMake tidak ditemukan. Buka Visual Studio Installer lalu tambahkan:
echo   Desktop development with C++
echo   C++ CMake tools for Windows
echo.
goto :err

:err
echo.
echo BUILD GAGAL
exit /b 1
