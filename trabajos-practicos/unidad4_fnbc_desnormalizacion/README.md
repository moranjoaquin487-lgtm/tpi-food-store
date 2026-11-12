# Unidad 4 — Normalización avanzada, migración reversible y desnormalización controlada

- **Alumno:** Moran, Joaquín Leandro
- **Base:** `foodstore` (PostgreSQL 16+). Se ejecuta con `ejecutar_segunda_entrega.sh`, desde la raíz del repositorio.

| Consigna | Archivo | Evidencia |
|---|---|---|
| Esquema heredado con redundancia | `sql/01_esquema_heredado.sql` | `evidencias/01_esquema_heredado.txt` |
| Validación de las DF sobre los datos reales | `sql/02_validar_dependencias.sql` | `evidencias/02_validar_dependencias.txt` |
| DF, claves candidatas, BCNF, anomalías, Heath | [`docs/fnbc_control_lote.md`](docs/fnbc_control_lote.md) | — |
| Migración sin pérdida en una transacción reversible | `sql/03_migracion_fnbc.sql` | `evidencias/03a_ensayo_migracion.txt` (ROLLBACK) y `03b_migracion_aplicada.txt` (COMMIT) |
| Plan de reversión | `sql/04_reversion_fnbc.sql` | `evidencias/04_ensayo_reversion.txt` |
| Las anomalías desaparecen y se protege la DF1 | `sql/05_pruebas_esquema_nuevo.sql` | `evidencias/05_pruebas_esquema_nuevo.txt` |
| Desnormalización controlada (resumen por categoría) | `sql/06_desnormalizacion_top_categorias.sql` | `evidencias/06_desnormalizacion.txt` |
| Salvaguardas | `sql/07_pruebas_desnormalizacion.sql` | `evidencias/07_pruebas_desnormalizacion.txt` |
| Mediciones antes y después | `sql/08_mediciones.sql` | `evidencias/08_mediciones.txt` |
| Reversión de la desnormalización | `sql/09_reversion_desnormalizacion.sql` | `evidencias/09_ensayo_reversion_desnormalizacion.txt` |
| Decisiones: cuándo, por qué y con qué salvaguardas | [`docs/migracion_y_desnormalizacion.md`](docs/migracion_y_desnormalizacion.md) | — |
| Spec en Kiro de la migración | `docs/kiro/` (requirements, design y tasks) | — |

Los errores en las evidencias de prueba son a propósito: son los casos que el motor tiene que rechazar.
