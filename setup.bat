@echo off
echo === Setup Laravel Photobooth ===
cd /d E:\Photobooth\laravel_backend

echo --- Running composer install ---
call C:\Users\WIDIYA\.config\herd-lite\bin\composer.bat install --no-interaction

echo --- Generating app key ---
C:\Users\WIDIYA\.config\herd\bin\php.bat artisan key:generate

echo --- Creating database (ignore error if exists) ---
C:\Users\WIDIYA\.config\herd\bin\php.bat artisan db:create 2>nul

echo --- Running migrations ---
C:\Users\WIDIYA\.config\herd\bin\php.bat artisan migrate --force

echo --- Running seeders ---
C:\Users\WIDIYA\.config\herd\bin\php.bat artisan db:seed --force

echo --- Installing Sanctum ---
C:\Users\WIDIYA\.config\herd\bin\php.bat artisan vendor:publish --provider="Laravel\Sanctum\SanctumServiceProvider" --force

echo --- Storage link ---
C:\Users\WIDIYA\.config\herd\bin\php.bat artisan storage:link

echo.
echo === SETUP SELESAI ===
echo API siap di: http://localhost:8000
echo Jalankan server: php artisan serve
echo.
pause
