# Unidad 6 — Mantenimiento, respaldo y recuperación

- **Alumno:** Moran, Joaquín Leandro
- **Bases:** `foodstore` (principal) y `foodstore_restore_test` (restauración de prueba)

| Entregable | Archivo |
|---|---|
| Especificación y plan | [`SPEC_U6.md`](SPEC_U6.md) y [`AGENTS.md`](AGENTS.md), con las reglas para OpenCode |
| Respaldo automatizable | `backup_foodstore.sh` |
| Monitoreo | `health_check.sql` |
| Mantenimiento justificado e integridad | `maintenance.sql` |
| Simulacro contra reloj (RTO y RPO) | `restore_test.sh` (`JOBS=4` para restaurar en paralelo) |
| Informe post-incidente | `informe_u6.pdf` (fuente: `informe_u6.md`) |
| Informe para el campus (todo el TP en un solo PDF) | `Informe_TP_U6_Moran.pdf` |
| Tarea programada | `programar_respaldo.cmd` (crea la tarea diaria de las 02:00) y `respaldo_tarea.cmd` (lo que ejecuta la tarea) |
| Evidencias | `evidencias/`: respaldos, `health_check.txt`, `maintenance.txt`, `restore_test_*.txt`, `tarea_programada.txt`, `revision_opencode.md` |

Ningún script tiene contraseñas (se usa `pgpass.conf`). Los `.dump` y `logs/` no se suben: el tamaño, el log y la restauración exitosa figuran en `evidencias/respaldos.txt` y en `evidencias/restore_test_*.txt`.
