# Tech Stack

## Database

- **Engine:** PostgreSQL 18.6 (local)
- **Client:** `psql` (Git Bash on Windows)
- **Utilities:** `createdb`, `dropdb`, `pg_dump`, `pg_restore`

## Key PostgreSQL features used

- `GENERATED ALWAYS AS IDENTITY` primary keys
- Custom `ENUM` type (`tipo_forma_pago`)
- `CHECK` constraints, `UNIQUE`, composite `PRIMARY KEY`
- `ON DELETE RESTRICT` / `ON DELETE CASCADE` foreign keys
- Partial indexes (`WHERE activo`)
- Transaction isolation levels: `READ COMMITTED`, `REPEATABLE READ`, `SERIALIZABLE`
- Row-level locking: `FOR UPDATE`, `FOR UPDATE NOWAIT`, `FOR UPDATE SKIP LOCKED`, `lock_timeout`
- Triggers and trigger functions (generated in Parte 1)

## Shell scripts

All orchestration is in Bash scripts under `scripts/`. They run in Git Bash on Windows.

- `\set ON_ERROR_ROLLBACK on` is used in `psql` sessions so an intentionally failing case does not abort the full script.
- `PGUSER` defaults to `postgres`; override with `PGUSER=other_user bash scripts/...`.
- `PGPASSWORD` is loaded once per Git Bash session with `read -s`; never written to a file.
- `PGCLIENTENCODING=UTF8` is exported by every script.

## No build system

There is no `package.json`, Makefile, or test runner. "Running tests" means executing a script and inspecting its output in `evidencias/`.

## Common commands

```bash
# Load password once per Git Bash session
read -s -p "Contraseña de postgres: " PGPASSWORD; echo; export PGPASSWORD

# (Re)create template and working copy from repo files
bash scripts/crear_base.sh

# Parte 1 — dry run (ROLLBACK, no changes committed)
bash scripts/aplicar_restricciones.sh

# Parte 1 — backup, apply, run test cases (COMMIT)
bash scripts/aplicar_restricciones.sh --confirmar

# Parte 2 — reproduce the four concurrency scenarios
bash scripts/laboratorio_concurrencia.sh reproducir

# Parte 2 — repeat with the level/mechanism that prevents each anomaly
bash scripts/laboratorio_concurrencia.sh verificar

# Parte 3 — critical reading demo
bash scripts/lectura_critica.sh
```

## AI agents

- **OpenCode:** used in Plan mode first; no files written until the plan is reviewed.
- **Kiro:** this workspace; steering files live in `.kiro/steering/`.
- Neither agent executes database commands directly — the user runs all scripts.
