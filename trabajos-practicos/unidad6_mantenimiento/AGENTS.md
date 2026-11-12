# AGENTS.md — Reglas para OpenCode en la Unidad 6

Contexto: Food Store, PostgreSQL 16+, en Windows con Git Bash. La especificación está en `SPEC_U6.md`.

Reglas que todo script tiene que cumplir:

1. No escribir contraseñas en ningún archivo. No usar `PGPASSWORD=` con un valor fijo. La autenticación viene de `pgpass.conf`.
2. La base principal se llama `foodstore` y nunca se borra, se reemplaza ni se restaura encima.
3. La restauración de prueba va solo a `foodstore_restore_test`.
4. El respaldo se hace con `pg_dump -Fc` y el nombre incluye fecha y hora: `backups/foodstore_AAAAMMDD_HHMMSS.dump`.
5. Los scripts de shell usan `set -euo pipefail` y terminan con un código distinto de 0 si algo falla.
6. No usar `VACUUM FULL`. Todo `VACUUM` o `ANALYZE` se justifica con una consulta previa a `pg_stat_user_tables`.
7. Las consultas tienen que correr en PostgreSQL 16 o superior.
8. No ejecutar ningún comando contra la base sin mostrarlo antes y esperar confirmación.
