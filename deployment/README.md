# Production deployment (advanced)

> **⚠️ Do NOT use this to try the project for the first time.**
> Use `setup.sh` / `setup.bat` from the repo root — see the main
> [`README.md`](../README.md). The contents of this folder are for
> production-style deployment and advanced manual workflows.

This folder packages the **Phase 2 production stack**:

- **Django + Gunicorn** backend
- **React + Vite** built to static assets, served by **Nginx**
- **PostgreSQL 15** with a named volume
- **Redis 7** for cache + DRF throttling
- A single Nginx vhost that serves the SPA on port 80 and
  reverse-proxies `/api/*` and `/admin/` to the backend

---

## Layout of this folder

| File | Purpose |
|---|---|
| `Dockerfile.backend`     | Multi-stage build for the Django + Gunicorn image |
| `Dockerfile.frontend`    | Multi-stage build for the React-bundled-by-Nginx image |
| `docker-compose.yml`     | Full stack (db + redis + backend + frontend) |
| `nginx.conf`             | Nginx vhost (static + `/api/` and `/admin/` reverse proxy) |
| `entrypoint.sh`          | Backend container entrypoint (wait-for-db, migrate, collectstatic) |
| `.env.example`           | Environment template — copy and edit before launching the stack |
| `.dockerignore`          | Ignore rules for the build context |

---

## Prerequisites

- Docker Engine 24+
- Docker Compose v2 (the `docker compose` plugin, not the legacy
  `docker-compose` binary)
- Roughly 2 GB free disk for the images + volumes

---

## Configure the environment

Copy the template, then edit it and fill in real secrets.

**macOS / Linux:**

```bash
cp deployment/.env.example .env
```

**Windows (Command Prompt):**

```bat
copy deployment\.env.example .env
```

**Windows (PowerShell):**

```powershell
Copy-Item deployment\.env.example .env
```

Open the new `.env` in an editor and replace the placeholder values
for at least:

- `DJANGO_SECRET_KEY` — generate a long random string
- `FIELD_ENCRYPTION_KEY` — generate a 44-char urlsafe-base64 Fernet key
- `POSTGRES_PASSWORD` — pick any strong password

Generation helpers (run from the repo root after Python deps are
installed):

```bash
python -c "import secrets; print(secrets.token_urlsafe(64))"
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

The compose file refuses to start if `DJANGO_SECRET_KEY`,
`FIELD_ENCRYPTION_KEY`, or `POSTGRES_PASSWORD` are missing from the
environment.

---

## Launch the stack

Run from the **repo root** (not from inside `deployment/`):

**macOS / Linux:**

```bash
docker compose -f deployment/docker-compose.yml up --build
```

**Windows (Command Prompt or PowerShell):**

```bat
docker compose -f deployment\docker-compose.yml up --build
```

The frontend Nginx is exposed on host port 80; the backend Gunicorn
sits behind it on the internal docker network. Visit
<http://localhost> — Nginx serves the React build and reverse-proxies
`/api/*` and `/admin/` to Django.

**Known limitation:** the React bundle currently hard-codes the API
base URL to `http://localhost:8000`. The compose file does not expose
that port to the host, so logins through the Nginx-served frontend
will not work end-to-end with the default code. This is tracked as a
separate fix in the main repo; for now the Docker stack is suitable
for testing the backend / Nginx wiring rather than the full
end-to-end SPA flow.

Subsequent runs (no code changes):

```bash
docker compose -f deployment/docker-compose.yml up -d
```

Stop everything:

```bash
docker compose -f deployment/docker-compose.yml down
```

Stop everything **and wipe the database volume**:

```bash
docker compose -f deployment/docker-compose.yml down -v
```

---

## Optional first-boot seeding

Set `HMS_SEED_ON_START=1` in your `.env` before the first
`docker compose up` to have `entrypoint.sh` run `python manage.py
seed_data` automatically on the first boot. After the first run, set
it back to `0` (or remove it) so subsequent restarts don't try to
re-seed.

---

## Running the servers manually (no Docker, no setup script)

If you want full control — your own venv, only one of the two
servers, custom ports — you can run everything by hand. This is also
how you would point the backend at a real Postgres / Redis without
Compose.

### Backend — Django

**macOS / Linux:**

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
python manage.py migrate
python manage.py seed_data
python manage.py runserver 8000
```

**Windows (PowerShell):**

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python manage.py migrate
python manage.py seed_data
python manage.py runserver 8000
```

**Windows (Command Prompt):**

```bat
python -m venv .venv
.venv\Scripts\activate.bat
pip install -r requirements.txt
python manage.py migrate
python manage.py seed_data
python manage.py runserver 8000
```

If PowerShell blocks `Activate.ps1` with an execution-policy error,
run once:

```powershell
Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
```

### Frontend — React + Vite

In a second terminal, from the repo root:

**macOS / Linux:**

```bash
cd Frontend/hospital-frontend
npm install
npm run dev
```

**Windows (PowerShell or Command Prompt):**

```bat
cd Frontend\hospital-frontend
npm install
npm run dev
```

Then open <http://localhost:5173>. The backend must be running at
`http://localhost:8000` for the frontend to authenticate.

### Running the tests

Same command on every OS, no extra setup:

```bash
python manage.py test accounts
```

---

## Pointing the backend at PostgreSQL instead of SQLite

`hospital_project/settings.py` switches automatically: if the
`POSTGRES_HOST` env var is set, it uses PostgreSQL with the
`POSTGRES_*` env vars; otherwise it falls back to the dev SQLite file
at `db.sqlite3` in the repo root.

Minimum env vars to switch to PostgreSQL:

```
POSTGRES_HOST=your-db-host
POSTGRES_PORT=5432
POSTGRES_DB=hms
POSTGRES_USER=hms_user
POSTGRES_PASSWORD=...
```

---

## Health check

Once the stack is up:

```bash
curl http://localhost/api/health/
```

The backend returns `{"status":"ok","db":"ok"}` (HTTP 200) when
PostgreSQL is reachable, or `{"status":"degraded","db":"down"}` (HTTP
503) when it isn't. The Docker healthcheck on the backend container
hits the same endpoint.
