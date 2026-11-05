# AGENTS.md

## Contexto

- Repo de trabajos prácticos de Base de Datos II (UTN) sobre PostgreSQL. No es una aplicación: no hay `package.json`, build, lint ni suite de tests.
- Esta carpeta es la raíz de ejecución de la Semana 2. Los agentes se abren acá, no en la raíz del repo.
- Comentarios SQL, mensajes de error y documentación en español.
- `.gitattributes` exige LF en `*.sh` y `*.sql`; no los guardes con CRLF.

## Reglas de base de datos (obligatorias)

- No ejecutes `psql`, `createdb`, `dropdb`, `pg_dump` ni `pg_restore`: los scripts los corre el usuario.
- No pidas, leas ni escribas `PGPASSWORD`.
- `foodstore_plantilla` es de solo lectura. Escribí únicamente en `foodstore_trabajo`.
- En los `.sql` que generes no incluyas `BEGIN`, `COMMIT` ni `ROLLBACK`: la transacción la abren los scripts de `scripts/`.
- `protocolo_seguridad.md` es la fuente de verdad: primero probar con `ROLLBACK`, respaldar antes de cambios estructurales y confirmar `SELECT current_database();`.
- Las evidencias incluyen errores a propósito (casos inválidos). No los "corrijas" eliminándolos.
- `scripts/crear_base.sh`, `aplicar_restricciones.sh --confirmar` y `../../../ejecutar_todo.sh` pueden borrar y recrear bases. No los corras sin pedido explícito.

## Comandos (Git Bash, desde esta carpeta)

```bash
read -s -p "Contraseña de postgres: " PGPASSWORD; echo; export PGPASSWORD
bash scripts/crear_base.sh                          # recrea plantilla y copia de trabajo
bash scripts/aplicar_restricciones.sh               # prueba con ROLLBACK
bash scripts/aplicar_restricciones.sh --confirmar   # respaldo, COMMIT y casos
bash scripts/laboratorio_concurrencia.sh reproducir # 4 escenarios concurrentes
bash scripts/laboratorio_concurrencia.sh verificar  # repite con el mecanismo que los evita
bash scripts/lectura_critica.sh                     # Parte 3
```

- `PGUSER` permite otro usuario; los scripts ya exportan `PGCLIENTENCODING=UTF8`.
- No hay test runner. Verificar = correr un script y revisar su salida en `evidencias/`.

## Mapa del proyecto

- `food-store/schema.sql` es copia de `../semana1_modelo_er_normalizacion_ddl/schema.sql`; mantenelos sincronizados.
- `food-store/data.sql` busca filas por `nombre`/`email`; no hardcodees IDs.
- `food-store/concurrencia/e{1..4}_{A,B}.sql` son fragmentos de psql que usan variables como `:nivel`, `:modo`, `:primero` y `:segundo`, seteadas por `laboratorio_concurrencia.sh`. No se ejecutan solos.
- `scripts/` es dueño de transacciones, respaldos y generación de evidencias.
- La raíz del repo tiene otro flujo (`sql/` + `ejecutar_todo.sh` → base `tpi_food_store`) que no se usa en la Semana 2. No mezcles ambos.
- Cada README mapea consigna → archivos; actualizá ese mapa al agregar entregables.

## Convenciones del esquema

- Tablas en singular y `snake_case`; PK `id BIGINT GENERATED ALWAYS AS IDENTITY`; FK `<tabla>_id`.
- `detalle_pedido` tiene PK compuesta `(pedido_id, producto_id)`.
- Baja lógica con `activo = FALSE`; las FK hacia `categoria`/`producto` usan `ON DELETE RESTRICT`.
- `tipo_forma_pago` es ENUM con `EFECTIVO`, `TARJETA`, `TRANSFERENCIA`.
- Las reglas R1 a R7 están comentadas en `schema.sql`.

## Estado actual

El README y los prompts mencionan archivos que todavía no existen; son entregables pendientes, no errores del repo:

- `.kiro/`
- `food-store/restricciones.sql`
- `food-store/pruebas_restricciones.sql`
- `docs/plan_opencode_parte1.md`
- `docs/informe_concurrencia.md`
- `docs/duia/duia_parte1.md`, `duia_parte2.md`, `duia_parte3.md`

`prompts/explicacion_escenario_1.md` a `4.md` los genera `laboratorio_concurrencia.sh reproducir`.

## Antes de generar código

Leé `specs/spec_restricciones.md` (comportamiento esperado), `prompts/parte0_agentes.md` y `prompts/parte1_opencode.md` (flujo pedido). Proponé un plan y esperá confirmación antes de escribir archivos.

## Reglas para agentes

- No ejecutes `psql` ni ningún otro comando contra la base de datos: los scripts los corre el usuario.
- En los archivos `.sql` que generes no escribas `BEGIN`, `COMMIT` ni `ROLLBACK`: la transacción la abren los scripts de la carpeta `scripts/`.
- Antes de escribir cualquier archivo, proponé un plan y esperá confirmación.
- Comentarios y mensajes de error en español.
