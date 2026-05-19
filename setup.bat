@echo off
REM Stop immediately on any failure rather than silently continuing
REM with a broken / half-seeded environment.

echo ======================================
echo Hospital Management System - Setup
echo ======================================

SET SCRIPT_DIR=%~dp0
SET FRONTEND_DIR=%SCRIPT_DIR%Frontend\hospital-frontend
SET VENV_DIR=%SCRIPT_DIR%venv

echo.
echo Checking Python version...
python -c "import sys; ok=(3,10)<=sys.version_info[:2]<=(3,13); print('[WARN] Python ' + str(sys.version_info.major) + '.' + str(sys.version_info.minor) + ' is outside the tested 3.10-3.13 range. If pip install fails (psycopg2, cffi, or cryptography wheel errors), install Python 3.12 from https://www.python.org/downloads/ and re-run setup.bat.') if not ok else None"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] Could not run python. Make sure Python 3.x is installed and on PATH.
    pause
    exit /b %ERRORLEVEL%
)

echo.
if not exist "%VENV_DIR%\Scripts\activate.bat" (
    echo Creating Python virtual environment at .\venv\ ...
    python -m venv "%VENV_DIR%"
    if %ERRORLEVEL% NEQ 0 (
        echo.
        echo [ERROR] Failed to create virtual environment. Aborting setup.
        pause
        exit /b %ERRORLEVEL%
    )
) else (
    echo Reusing existing virtual environment at .\venv\ ...
)

REM Activate the venv for the remainder of this script. From here on,
REM `python` and `pip` refer to the venv's binaries.
call "%VENV_DIR%\Scripts\activate.bat"

echo.
echo Installing backend dependencies (requirements.txt only - production
echo extras like psycopg2-binary live in requirements-prod.txt and are
echo NOT installed for local dev)...
python -m pip install --upgrade pip
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [ERROR] pip upgrade failed. Aborting setup.
    pause
    exit /b %ERRORLEVEL%
)
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
echo Starting Django backend (using venv's python so the new window does
echo not need to re-activate)...
start "Django Backend" "%VENV_DIR%\Scripts\python.exe" manage.py runserver

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
