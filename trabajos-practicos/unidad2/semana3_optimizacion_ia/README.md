# TP Semana 3 (Unidad 2) — Optimización asistida por IA sobre Food Store

- **Alumno:** Moran, Joaquín Leandro. Trabajo individual.
- **Base:** copia de prueba `foodstore_tp3` (PostgreSQL 18), armada desde cero con los scripts del proyecto. No se toca `foodstore`.
- **Informe para el campus:** [`docs/Informe_TP_Semana3_Moran.pdf`](docs/Informe_TP_Semana3_Moran.pdf).

## Entregables

| Entregable | Archivo | Evidencia |
|---|---|---|
| Script de carga masiva (Parte 1) | [`../../../sql/02b_carga_masiva_rapida.sql`](../../../sql/02b_carga_masiva_rapida.sql), verificado con [`sql/parte1_verificacion.sql`](sql/parte1_verificacion.sql) | `evidencias/parte1_carga_masiva.txt`, `evidencias/parte1_verificacion.txt` |
| Tabla comparativa con los planes antes y después (Parte 2) | [`sql/parte2_antes.sql`](sql/parte2_antes.sql), [`sql/parte2_cambios.sql`](sql/parte2_cambios.sql), [`sql/parte2_despues.sql`](sql/parte2_despues.sql), [`sql/parte2_ajuste.sql`](sql/parte2_ajuste.sql), [`sql/parte2_sin_paralelo.sql`](sql/parte2_sin_paralelo.sql) | `evidencias/parte2_*.txt`; prompt y respuesta de OpenCode en `prompts/parte2_propuestas_ia.md` y `docs/respuestas_ia/parte2_propuestas_opencode.md` |
| Tabla de lectura crítica (Parte 3) | Informe, sección 3 | `prompts/parte3_explicar_plan.txt`, `docs/respuestas_ia/parte3_explicacion_opencode.md` |
| Dos consultas bajo spec con su equivalencia (Parte 4) | [`docs/parte4_specs.md`](docs/parte4_specs.md), [`sql/parte4_consultas.sql`](sql/parte4_consultas.sql) | `evidencias/parte4_equivalencia.txt` |
| Registro de la competencia (Parte 5) | [`sql/parte5_competencia.sql`](sql/parte5_competencia.sql), [`sql/parte5_cambio.sql`](sql/parte5_cambio.sql) | `evidencias/parte5_antes.txt`, `evidencias/parte5_despues.txt` |
| DUIA | Informe, sección 6 | — |

## Cómo se corre

Desde la raíz del repositorio, en Git Bash (usa el `pgpass.conf` de postgres; no pide ni guarda contraseñas):

```bash
bash trabajos-practicos/unidad2/semana3_optimizacion_ia/ejecutar_tp3.sh antes         # Parte 1 y planes ANTES
bash trabajos-practicos/unidad2/semana3_optimizacion_ia/ejecutar_tp3.sh despues       # cambios aceptados, planes DESPUÉS, Partes 4 y 5
bash trabajos-practicos/unidad2/semana3_optimizacion_ia/ejecutar_tp3.sh sin_paralelo  # comprobación de la espera del Gather
```

`antes` recrea `foodstore_tp3` con `sql/01_schema.sql` y `sql/02_data.sql` y hace un respaldo con `pg_dump` en `backups/`, que no se sube. Después ejecuta la carga masiva en una sola transacción, la verifica y mide. Entre `antes` y `despues` va el paso de la IA: OpenCode recibe `prompts/parte2_propuestas_ia.md` y se deciden los cambios. Después de `despues`, OpenCode explica `prompts/parte3_explicar_plan.txt` desde una carpeta vacía, sin otro contexto.

## Adaptaciones

- La consigna pide 20 000 «usuarios»: en Food Store los compradores están en `cliente`, y `usuario` son las cuentas de la aplicación.
- La consigna habla de `queries.sql`; las tres consultas de la Parte 2 son variantes propias sobre el modelo, que usaría el panel de la tienda.
- La competencia de la Parte 5 es entre equipos y se hace en clase con la consulta que fija la cátedra. Este TP es individual: el registro es el mío, con la consulta de ejemplo de la consigna.
- Borrado lógico del esquema: `categoria.activo` y `producto.activo`. `cliente`, `pedido` y `detalle_pedido` no tienen.
- Kiro no se usó en este TP.
