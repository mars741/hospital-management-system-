@echo off
REM Stop immediately on any failure rather than silently continuing
REM with a broken / half-seeded environment.

echo ======================================
echo Hospital Management System - Setup
echo ======================================

SET SCRIPT_DIR=%~dp0
SET FRONTEND_DIR=%SCRIPT_DIR%Frontend\hospital-frontend

echo.
echo Installing backend dependencies...
pip install -r "%SCRIPT_DIR%requirements.txt"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] pip install failed. Aborting setup.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo Setting up database...
cd /d "%SCRIPT_DIR%"
python manage.py migrate
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Database migration failed. Aborting setup.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo Creating minimal demo users (patient1, doctor1..5 - password: test123)...
python manage.py shell < seed.py
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Minimal seed failed. Aborting setup.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo Seeding full role-based demo accounts (admin, doctor_*, nurse_*, pharmacist*, manager*, patient1..15 - password: Pass1234!)...
echo   (this uses update_or_create - safe to re-run.)
python manage.py seed_data
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] seed_data failed. The Pass1234! accounts will NOT exist. Aborting setup.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo Starting Django backend...
start "Django Backend" python manage.py runserver

echo.
echo Installing frontend dependencies...
cd /d "%FRONTEND_DIR%"
call npm install
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] npm install failed. Aborting setup.
    pause
    exit /b %ERRORLEVEL%
)

echo.
echo Starting React frontend...
start "React Frontend" npm run dev

timeout /t 3 /nobreak > nul

echo.
echo Opening browser...
start http://localhost:5173

echo.
echo ======================================
echo Website is ready!
echo Go to: http://localhost:5173
echo.
echo Login with any of:
echo   admin          / Pass1234!
echo   doctor_cardio  / Pass1234!
echo   nurse_cardio   / Pass1234!
echo   pharmacist1    / Pass1234!
echo   manager1       / Pass1234!
echo   patient1       / Pass1234!
echo ======================================
pause
