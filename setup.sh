#!/bin/bash
# Works on Mac and Linux
# For Windows: use setup.bat instead
#
# Exits immediately on any failure so you don't end up with servers running
# against an empty / half-seeded database.

set -e

echo "======================================"
echo "Hospital Management System - Setup"
echo "======================================"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRONTEND_DIR="$SCRIPT_DIR/Frontend/hospital-frontend"
VENV_DIR="$SCRIPT_DIR/venv"

echo ""
echo "Checking Python version..."
python3 - <<'PY'
import sys
v = sys.version_info
if not ((3, 10) <= (v.major, v.minor) <= (3, 13)):
    print(f"[WARN] Python {v.major}.{v.minor} is outside the tested 3.10-3.13 range.")
    print("[WARN] If pip install fails (psycopg2, cffi, or cryptography wheel errors),")
    print("[WARN] install Python 3.12 and re-run setup.sh:")
    print("[WARN]   macOS: brew install python@3.12")
    print("[WARN]   Linux: use your package manager, or download from python.org")
PY

echo ""
if [ ! -d "$VENV_DIR" ]; then
    echo "Creating Python virtual environment at ./venv/ ..."
    python3 -m venv "$VENV_DIR"
else
    echo "Reusing existing virtual environment at ./venv/ ..."
fi

# Activate the venv for the remainder of this script. After this point,
# `python` and `pip` refer to the venv's binaries, not the system Python.
# shellcheck disable=SC1091
. "$VENV_DIR/bin/activate"

echo ""
echo "Installing backend dependencies (requirements.txt only — production"
echo "extras like psycopg2-binary live in requirements-prod.txt and are"
echo "NOT installed for local dev)..."
python -m pip install --upgrade pip
pip install -r "$SCRIPT_DIR/requirements.txt"

echo ""
echo "Setting up database..."
cd "$SCRIPT_DIR"
python manage.py migrate

echo ""
echo "Creating minimal demo users (patient1, doctor1..5 — password: test123)..."
python manage.py shell -c "
from accounts.models import User, Patient, Doctor, Department
from datetime import date

if not User.objects.filter(username='patient1').exists():
    u = User.objects.create_user(username='patient1', password='test123', first_name='Alex', last_name='Johnson', role='PATIENT')
    Patient.objects.create(user=u, date_of_birth=date(1995,1,1), gender='M')
    print('Patient created!')
else:
    print('Patient already exists!')

if not Department.objects.filter(name='Cardiology').exists():
    d1 = Department.objects.create(name='Cardiology')
    d2 = Department.objects.create(name='Neurology')
    d3 = Department.objects.create(name='Pediatrics')
    d4 = Department.objects.create(name='Orthopedics')
    d5 = Department.objects.create(name='Dermatology')
    u2 = User.objects.create_user(username='doctor1', password='test123', first_name='Ayse', last_name='Kaya', role='DOCTOR')
    Doctor.objects.create(user=u2, department=d1, specialization='Cardiology', license_number='LIC001', years_of_experience=10)
    u3 = User.objects.create_user(username='doctor2', password='test123', first_name='Mehmet', last_name='Celik', role='DOCTOR')
    Doctor.objects.create(user=u3, department=d2, specialization='Neurology', license_number='LIC002', years_of_experience=8)
    u4 = User.objects.create_user(username='doctor3', password='test123', first_name='Sara', last_name='Yildiz', role='DOCTOR')
    Doctor.objects.create(user=u4, department=d3, specialization='Pediatrics', license_number='LIC003', years_of_experience=6)
    u5 = User.objects.create_user(username='doctor4', password='test123', first_name='Emre', last_name='Demir', role='DOCTOR')
    Doctor.objects.create(user=u5, department=d4, specialization='Orthopedics', license_number='LIC004', years_of_experience=12)
    u6 = User.objects.create_user(username='doctor5', password='test123', first_name='Leyla', last_name='Arslan', role='DOCTOR')
    Doctor.objects.create(user=u6, department=d5, specialization='Dermatology', license_number='LIC005', years_of_experience=5)
    print('Doctors created!')
else:
    print('Doctors already exist!')
"

echo ""
echo "Seeding full role-based demo accounts (admin, doctor_*, nurse_*, pharmacist*, manager*, patient1..15 — password: Pass1234!)..."
echo "  (this uses update_or_create — safe to re-run.)"
python manage.py seed_data

echo ""
echo "Starting Django backend..."
cd "$SCRIPT_DIR"
python manage.py runserver &
BACKEND_PID=$!

echo ""
echo "Installing frontend dependencies..."
cd "$FRONTEND_DIR"
npm install

echo ""
echo "Starting React frontend..."
npm run dev &
FRONTEND_PID=$!

sleep 3

echo ""
echo "Opening browser..."
if command -v open &> /dev/null; then
    open http://localhost:5173
elif command -v xdg-open &> /dev/null; then
    xdg-open http://localhost:5173
fi

echo ""
echo "======================================"
echo "Website is ready!"
echo "Go to: http://localhost:5173"
echo ""
echo "Login with any of:"
echo "  admin          / Pass1234!"
echo "  doctor_cardio  / Pass1234!"
echo "  nurse_cardio   / Pass1234!"
echo "  pharmacist1    / Pass1234!"
echo "  manager1       / Pass1234!"
echo "  patient1       / Pass1234!"
echo "======================================"

wait $BACKEND_PID $FRONTEND_PID
