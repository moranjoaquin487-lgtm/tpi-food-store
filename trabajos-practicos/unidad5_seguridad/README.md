# Unidad 5 — Administración y seguridad de Food Store

- **Alumno:** Moran, Joaquín Leandro
- **Base:** `foodstore` (PostgreSQL 16+). Todo se ejecuta **solo** contra la base propia de desarrollo.

| Parte | Archivos | Evidencia |
|---|---|---|
| **A** Roles y permisos | `sql/roles.sql` (justificación de cada rol en la cabecera), `sql/01_auth_funciones.sql`, `sql/00_usuarios_prueba.sql`, `docs/kiro_roles_spec/` | `evidencias/A_03_verificacion_permisos.txt` (`\du`, `\drg`, `role_table_grants`, comparación contra la spec: 0 de más y 0 de menos, y pruebas con `SET ROLE`). Auditoría de `roles.sql` con OpenCode: `docs/respuestas_ia/A_auditoria_roles.md`, comprobada con `sql/comprobar_auditoria_ia.sql` (`evidencias/A_04_comprobacion_auditoria_ia.txt`) |
| **B** Auditoría | `sql/configurar_auditoria.sql`, `sql/auditoria_test.sql`, `scripts/correr_auditoria_test.sh` | [`docs/informe_auditoria.md`](docs/informe_auditoria.md), [`docs/log_auditoria_prueba.txt`](docs/log_auditoria_prueba.txt), `evidencias/B_configuracion.txt` |
| **C** Simulacro de incidente | `sql/simulacro_incidente.sql`, `scripts/simulacro_incidente.sh`, `scripts/anonimizar_log.py` | [`docs/log_simulacro_anonimizado.txt`](docs/log_simulacro_anonimizado.txt), [`docs/informe_incidente.md`](docs/informe_incidente.md), `docs/respuestas_ia/C_reconstruccion_incidente.md`, `evidencias/C_simulacro_verificacion.txt` |
| **D** Anonimización | `sql/usuario_anon.sql`, `sql/equivalencia_agregados.sql`, `sql/D_comprobar_consultas_ia.sql` | [`docs/verificacion_equivalencia.md`](docs/verificacion_equivalencia.md), `docs/respuestas_ia/D_consultas.md`, `evidencias/D_comprobacion_consultas_ia.txt` |
| **E** Bitácora | [`BITACORA.md`](BITACORA.md) | Historial de Git, un commit por parte |

Las contraseñas no están en ningún archivo: se ponen con `\password` y se leen de `pgpass.conf`. El log original del simulacro tiene mails y queda en `evidencias/privado/`, que no se sube al repositorio.
