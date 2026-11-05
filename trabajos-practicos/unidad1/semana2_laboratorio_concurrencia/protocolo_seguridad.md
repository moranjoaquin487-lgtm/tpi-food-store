# Protocolo de seguridad

Se aplica a **todo** script que escriba en la base, propio o generado por IA, sin excepción.

## Mi entorno

| | |
|---|---|
| Motor | PostgreSQL 18.6, local |
| Sistema | Windows, con Git Bash como terminal (`psql`, `createdb`, `pg_dump`, `pg_restore`) |
| Usuario de la base | `postgres` |
| Contraseña | Se carga una vez por sesión de Git Bash con `read -s -p "Contraseña de postgres: " PGPASSWORD; echo; export PGPASSWORD`. Nunca se escribe en un archivo del repo. |
| Agentes de IA | OpenCode y Kiro, sobre esta carpeta |

## Bases

| Base | Rol |
|---|---|
| `foodstore_plantilla` | Esquema y datos iniciales (`food-store/schema.sql` y `data.sql`). **No se modifica.** |
| `foodstore_trabajo` | Copia de trabajo. Es la única base sobre la que se ejecutan scripts. |

## Paso 1 — Copia

Todo se ejecuta sobre la copia, nunca sobre la plantilla:

```bash
createdb -T foodstore_plantilla foodstore_trabajo
```

Si la copia quedó inservible, se descarta y se rehace (`scripts/crear_base.sh` recrea las dos bases desde los archivos del repo):

```bash
dropdb foodstore_trabajo
createdb -T foodstore_plantilla foodstore_trabajo
```

Antes de correr cualquier script, confirmar contra qué base apunta la sesión:

```sql
SELECT current_database();   -- tiene que decir foodstore_trabajo
```

## Paso 2 — Transacción

Todo script que escribe corre primero dentro de una transacción que termina en `ROLLBACK`, para leer el efecto real (filas afectadas, mensajes, resultado de los controles) antes de confirmar nada:

```sql
BEGIN;
-- script a evaluar
-- controles: SELECT de verificación, casos válidos e inválidos
ROLLBACK;   -- recién después de revisar la salida, se repite terminando en COMMIT
```

- En `psql`, `\set ON_ERROR_ROLLBACK on` hace que un caso que falla a propósito no aborte toda la prueba: `psql` pone un `SAVEPOINT` antes de cada sentencia.
- `EXPLAIN ANALYZE` sobre `INSERT`, `UPDATE` o `DELETE` ejecuta la sentencia de verdad: también va dentro de `BEGIN ... ROLLBACK`.

## Paso 3 — Respaldo

Antes de cualquier cambio estructural (`CREATE TRIGGER`, `ALTER`, `DROP`, migraciones), se respalda la copia de trabajo:

```bash
pg_dump -F c -f "backups/foodstore_trabajo_$(date +%Y%m%d_%H%M).dump" foodstore_trabajo
```

- Los respaldos viven en `backups/`, que está en `.gitignore`: son binarios y se regeneran.
- Para comprobar que el respaldo sirve: `pg_restore -l backups/<archivo>.dump` lista su contenido.
- Para volver atrás:

```bash
pg_restore -d foodstore_trabajo --clean --if-exists "backups/<archivo>.dump"
```

`scripts/aplicar_restricciones.sh --confirmar` hace el respaldo automáticamente antes de aplicar, y si el respaldo falla no aplica nada.

## Con agentes de IA

- OpenCode se usa en modo **Plan** primero: describe qué va a hacer sin tocar archivos. Recién después de revisar el plan se pasa a modo Build.
- Nada generado se aplica sin leer el diff completo (`git diff`) línea por línea.
- Los agentes no ejecutan comandos contra la base: los scripts los corro yo, siguiendo los tres pasos de arriba.
- No se le pasan credenciales a ningún agente. OpenCode se abre en una ventana de Git Bash distinta de la que tiene `PGPASSWORD` cargada: si intentara conectarse a la base, no podría.
