# Food Store en la feria — TP8

**Base de Datos II · UTN · Tecnicatura Universitaria en Programación · Unidad 8**

- **Presentado por:** Moran, Joaquín Leandro
- **Motores:** PostgreSQL 16+ (servidor de pruebas) y SQLite 3.37+ (tablet). Probado en PostgreSQL 18.6 y SQLite 3.54.1.
- **IA:** Kiro (spec), OpenCode (esquema, semáforo y code review) y Claude (primera versión, scripts de apoyo y documentación). Qué hizo cada una está en [`docs/DUIA.md`](docs/DUIA.md) y en [`docs/bitacora_ia.md`](docs/bitacora_ia.md).

El food truck vende en una feria sin señal. La tablet guarda en SQLite una copia del catálogo y arma borradores; un semáforo simula la sincronización contra una instantánea de PostgreSQL. **El móvil propone, el servidor dispone:** la tablet nunca cambia precio ni stock del servidor, y `SIMULADO_APROBADO` no es una venta.

## Dónde está cada consigna

| Consigna | Archivos |
|---|---|
| 1.a Qué datos viajan | [`docs/informe.pdf`](docs/informe.pdf), sección 1.a, y la vista [`servidor/v_snapshot_movil.sql`](servidor/v_snapshot_movil.sql) |
| 1.b Las tablas | [`movil/schema_sqlite.sql`](movil/schema_sqlite.sql), generado con OpenCode a partir de las tareas · evidencia `evidencias/1b_schema_sqlite.txt` |
| 1.c Probarla | [`movil/pruebas_sqlite.sql`](movil/pruebas_sqlite.sql) · evidencia `evidencias/1c_pruebas_sqlite.txt` |
| 2.a La instantánea | [`servidor/v_snapshot_movil.sql`](servidor/v_snapshot_movil.sql), [`movil/cargar_snapshot.sql`](movil/cargar_snapshot.sql), `movil/servidor_snapshot.csv` · evidencias `2a_instantanea.txt` e `instantaneas/` |
| 2.b El semáforo | [`movil/semaforo.sql`](movil/semaforo.sql), generado con OpenCode a partir de las tareas |
| 2.c Los casos | `movil/casos/`, `servidor/casos/`, [`servidor/verificacion_final.sql`](servidor/verificacion_final.sql), informe sección 2.c · evidencias `2c_C2.txt` a `2c_C6.txt` y `2c_verificacion_servidor.txt` |
| 3.a Mapa · 3.b Mantenimiento | `docs/informe.pdf`, secciones 3.a y 3.b |
| 3.c Code review con IA | `docs/informe.pdf`, sección 3.c · los 34 hallazgos de OpenCode (Plan) con su decisión en [`docs/code_review/hallazgos.md`](docs/code_review/hallazgos.md) y la conversación en [`docs/code_review/revision_opencode.md`](docs/code_review/revision_opencode.md) · comprobaciones en [`docs/code_review/comprobar_hallazgos.sh`](docs/code_review/comprobar_hallazgos.sh) y `evidencias/3c_code_review.txt` · versiones anteriores a las correcciones en `docs/code_review/antes/` |
| 4.a Spec | `.kiro/specs/tablet-feria/` (la que abre Kiro) y su copia en [`docs/kiro/`](docs/kiro/): `requirements.md` (EARS), `design.md`, `tasks.md` |
| 4.a Generación con OpenCode | `opencode/`: la salida de OpenCode tal cual (la misma que `movil/`) · `docs/opencode/version_claude/`: la primera versión, descartada · [`docs/opencode/comparar_versiones.sh`](docs/opencode/comparar_versiones.sh) y `evidencias/5_comparacion_opencode_v1.txt`, `_v2.txt` y `_final.txt` |
| 4.b Bitácora y DUIA | [`docs/bitacora_ia.md`](docs/bitacora_ia.md) · [`docs/DUIA.md`](docs/DUIA.md) |
| 4.c README y ensayo | Este archivo |

## Requisitos

- **PostgreSQL 16 o más nuevo**, con `psql`, `createdb` y `dropdb` en el PATH de Git Bash.
- **sqlite3 3.37 o más nuevo** (las tablas `STRICT` lo necesitan). En Windows: `winget install -e --id SQLite.SQLite`, o el zip *sqlite-tools-win-x64* de sqlite.org con `sqlite3.exe` en el PATH. Comprobar con `sqlite3 -version`.
- Git Bash. La contraseña de PostgreSQL se carga a mano en la sesión; nunca se escribe en un archivo.

## Crear todo desde cero

Desde Git Bash, en esta carpeta (`food-store/`):

```bash
read -s -p "Contraseña de postgres: " PGPASSWORD; echo; export PGPASSWORD
bash ejecutar_todo.sh
```

Tarda unos segundos. Al final muestra la cola de la tablet: una solicitud `CONFLICTO`, dos `RECHAZADO` y tres `SIMULADO_APROBADO`. Cada paso deja el comando y su salida en `evidencias/`. Otro usuario: `PGUSER=mi_usuario bash ejecutar_todo.sh`.

> ⚠️ Borra y vuelve a crear **solo** la copia de pruebas `foodstore_tp8` y `movil/foodstore_movil.db`. No toca ninguna otra base.

### El mismo orden, a mano

| # | Paso | Comando |
|:-:|---|---|
| 1 | Copia de pruebas del servidor (esquema y datos inventados del TP1) | `createdb foodstore_tp8` y `psql -d foodstore_tp8 -f servidor/schema.sql -f servidor/data.sql` |
| 2 | Vista de la instantánea y foto inicial de pedidos y stock | `psql -d foodstore_tp8 -f servidor/v_snapshot_movil.sql -f servidor/foto_inicial.sql` |
| 3 | Base de la tablet (1.b) | `cd movil && sqlite3 foodstore_movil.db < schema_sqlite.sql` |
| 4 | Exportar la instantánea (2.a) | `psql -d foodstore_tp8 -c "\copy (SELECT * FROM v_snapshot_movil ORDER BY id) TO 'movil/servidor_snapshot.csv' CSV HEADER"` |
| 5 | Importarla y recargar el catálogo (2.a) | `cd movil && sqlite3 -bail foodstore_movil.db < cargar_snapshot.sql` |
| 6 | Pruebas de la tablet (1.c; los errores de C7 son esperados) | `cd movil && sqlite3 -header -table -echo foodstore_movil.db < pruebas_sqlite.sql` |
| 7 | Por cada caso C2 a C6: borrador → cambio en el servidor (si corresponde) → pasos 4 y 5 → semáforo | `sqlite3 ... < casos/cN_*.sql`, `psql -d foodstore_tp8 -f servidor/casos/cN_*.sql`, `sqlite3 -bail -header -table foodstore_movil.db < semaforo.sql` |
| 8 | Verificación final: pedidos y stock no cambiaron | `psql -d foodstore_tp8 -f servidor/verificacion_final.sql` |

El orden exacto de cada caso está en `ejecutar_todo.sh`. Los scripts de la tablet se corren desde `movil/`, porque `cargar_snapshot.sql` busca `servidor_snapshot.csv` en esa carpeta. En DB Browser for SQLite se pueden abrir y ejecutar todos menos `cargar_snapshot.sql`, que usa `.import`: ahí la importación se hace con *Archivo → Importar → Tabla desde CSV* (ver el encabezado del script).

Para comparar la versión de OpenCode con la primera versión (solo SQLite, en carpetas temporales):

```bash
bash docs/opencode/comparar_versiones.sh
```

Para repetir las comprobaciones del code review hace falta la base del TPI (`./ejecutar_todo.sh` en la raíz del repo `tpi-food-store`, que crea `tpi_food_store`) y la carpeta de la Semana 2 (`trabajos-practicos/unidad1/semana2_laboratorio_concurrencia/food-store`; otra ruta: `S2_DIR=...`):

```bash
bash docs/code_review/comprobar_hallazgos.sh     # trabaja sobre copias y las borra al final
```

Los montos de #1 dependen de la carga masiva del TPI, que es al azar: en otra base dan otros números.

## Reglas que se respetan

1. Todo corre sobre `foodstore_tp8`, una copia con datos inventados.
2. En SQLite no hay contraseñas, mails ni datos personales: el `CHECK` de `usuario` rechaza cualquier texto con `@`.
3. La tablet no escribe en PostgreSQL. Los únicos cambios del servidor son los que se preparan a mano para C2 (precio) y C4 (baja lógica); `verificacion_final.sql` muestra que pedidos y stock quedaron igual.
4. Lo generado con IA se ejecutó y se comprobó: las evidencias son la salida de los scripts en mi PC.

## Ensayo de defensa (10 minutos)

| Tiempo | Qué se muestra | Apoyo |
|---|---|---|
| 0–2 min | **El mapa:** PostgreSQL manda sobre catálogo, stock y ventas; MongoDB, sobre los documentos de la Unidad 7; SQLite solo copia y propone. La regla de oro. | Informe 3.a |
| 2–7 min | **Un caso en vivo, C4:** borrador con una Fugazzeta, baja lógica en el servidor, instantánea nueva, semáforo → `RECHAZADO`; el catálogo ya no la muestra pero la fila queda como lápida. Cerrar con `verificacion_final.sql`. | `movil/casos/c4_*.sql`, `servidor/casos/c4_baja_logica.sql` |
| 7–10 min | **El code review de OpenCode:** #4 (corregido), el CSV cortado que dejaba 7 lápidas y ahora corta con `completa = 1`; #3 (aceptado), con las dos sesiones que muestran que el stock no queda negativo; y #20 (descartado), porque con las reglas de la Semana 2 la instantánea da lo mismo. | Informe 3.c, `docs/code_review/hallazgos.md`, `evidencias/3c_code_review.txt` |

Preguntas para tener listas: por qué centavos en `INTEGER` (y `BIGINT` en la vista, #13); por qué `PRAGMA foreign_keys = ON` en cada script (vale por conexión); qué pasa si se repite el semáforo; por qué dos solicitudes que juntas superan el stock salen en verde (#5); por qué se entrega el esquema de OpenCode y no la primera versión; dónde iría la idempotencia en un sistema real.
