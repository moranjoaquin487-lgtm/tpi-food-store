# Code review con IA — Unidades 4 a 7

- **Presentado por:** Moran, Joaquín Leandro
- **Complementa** el code review del TP8 ([`trabajos-practicos/unidad8/food-store/docs/code_review/hallazgos.md`](../trabajos-practicos/unidad8/food-store/docs/code_review/hallazgos.md)), que cubrió las Unidades 1 a 3 y 8. Las Unidades 4 a 7 se agregaron después, así que se revisan acá con el mismo criterio.
- **Revisión:** OpenCode, agente **Plan**, abierto en la raíz del repositorio, sin permiso para modificar archivos. Conversación completa: [`code_review_u4_u7_opencode.md`](code_review_u4_u7_opencode.md).

## Prompt

```
Revisá todos los .sql, .sh, .py, .js y .cmd de trabajos-practicos/unidad4_fnbc_desnormalizacion,
unidad5_seguridad, unidad6_mantenimiento y unidad7_nosql, y ejecutar_segunda_entrega.sh.
No revises unidad6_mantenimiento/opencode/, que es una versión descartada. No leas .md,
.pdf ni .txt. Para cada problema indicá: archivo, qué está mal, por qué importa y cómo
comprobarlo en la base. No modifiques nada.
```

## Hallazgos y decisiones

Aceptado: el problema es real y queda anotado. Corregido: se cambió en esta entrega. Descartado: después de comprobarlo no se cambia, por el fundamento que se indica.

| # | Unidad · archivo | Hallazgo de OpenCode | Decisión | Motivo y comprobación |
|:-:|---|---|:-:|---|
| 1 | U5 · `sql/01_auth_funciones.sql` | Desde que `fn_auditar_precios` es `SECURITY DEFINER`, `auditoria_precio.usuario_bd` (`DEFAULT current_user`) anota al dueño, `postgres`, y no a quien cambió el precio | **Corregido** | Es real, y lo causó un cambio de la U5. El `DEFAULT` pasó a `session_user`. Comprobado con `SET SESSION AUTHORIZATION admin_datos`: antes quedaba `postgres`, ahora `admin_datos` (`evidencias/code_review_u4_u7.txt`) |
| 2 | U5 · `scripts/correr_auditoria_test.sh` | El log de la parte B se guarda en `docs/` sin pasar por `anonimizar_log.py` | Descartado | Lo revisé: no tiene ningún mail (lo que parecía un mail es `app_web@foodstore`, el formato usuario@base de `log_line_prefix`) y la única IP es `::1`. La secuencia de la parte B no toca datos personales |
| 3 | U5 · `sql/configurar_auditoria.sql` | No enciende `logging_collector`, que en Windows vendría apagado | Descartado | En mi instalación ya estaba en `on` (`evidencias/B_configuracion.txt`), y encenderlo exige reiniciar el servicio, que no se puede hacer desde un script SQL. El informe de auditoría explica qué hacer si está apagado, y `extraer_log.py` lo avisa |
| 4 | `ejecutar_segunda_entrega.sh` | Sigue aunque falle la configuración de la auditoría o la carga a MongoDB | **Corregido** | Es real: `configurar_auditoria.sql` corría sin `ON_ERROR_STOP` y la carga tenía `\|\| echo`. Ahora los dos cortan el script con `exit 1` |
| 5 | U5 · `scripts/simulacro_incidente.sh` | Los controles de anonimización solo muestran el número y nunca fallan | **Corregido** | Es real. Ahora, si queda un mail real o una contraseña, el script corta con error. Comprobado con un log de prueba: la versión anterior terminaba en 0 y la corregida en 1 |
| 6 | U7 · `verificar_consultas.sh` | No quita el `\r` de la salida de `psql`, así que la comparación daría «No» | Descartado | En mi PC la tabla salió con «Sí» en las dos consultas, y `cat -A` muestra las líneas sin `\r` (`unidad7_nosql/evidencias/tabla_verificacion.md`): tal como está, la comparación funciona. El `\r` sí apareció en `restore_test.sh`, que lee un archivo de conteos con `read`, y ahí se corrigió |
| 7 | U7 · `01_estado_pedido.sql` | El `UPDATE` reasigna los estados en cada corrida y pisa los cambios reales | **Corregido** | Es real. La regla por id se aplica solo cuando se crea la columna. Comprobado: con el pedido 3 cambiado a `PENDIENTE`, la versión anterior lo volvía a `CANCELADO` y la corregida lo deja igual |
| 8 | U6 · `backup_foodstore.sh`, `restore_test.sh` | El respaldo no incluye los roles ni sus permisos, y la restauración usa `--no-owner --no-privileges` | Aceptado | Es real: el simulacro pasa porque restaura en el mismo servidor, donde los roles ya existen. Ante la pérdida del servidor entero faltarían. Queda para la entrega final: sumar `pg_dumpall --globals-only --no-role-passwords` al respaldo |
| 9 | U5 · `sql/roles.sql` | `ALTER DEFAULT PRIVILEGES FOR ROLE postgres` supone que el dueño es `postgres` | Descartado | Es así a propósito: todos los objetos los crea `postgres` (REQ-09 de la spec de roles), y un usuario de la aplicación no debe poder crear objetos |
| 10 | U5 · `sql/verificacion_permisos.sql` | La comparación no ve los permisos dados a `PUBLIC`: el `JOIN` contra `pg_roles` lo deja afuera | **Corregido** | Es real. Se agregó un control que busca permisos para `PUBLIC` en la base, el esquema, las relaciones, las columnas y las funciones. Comprobado con un `GRANT … TO PUBLIC` dentro de `ROLLBACK`: la comparación anterior daba 0 y el control nuevo lo muestra |
| 11 | U6 · `respaldo_tarea.cmd` | Si la ruta tiene espacios, el `cd` falla y el respaldo no corre | **Corregido** | Es real (mi ruta no tiene espacios). La ruta va entre comillas simples para bash. Se volvió a correr la tarea programada |
| 12 | U6 · `programar_respaldo.cmd` | `schtasks /Run` no espera el resultado | Descartado | El resultado no se controla ahí, sino en `logs/tarea_programada.log` y en `evidencias/tarea_programada.txt`, que tienen la línea `OK` y el código de salida |
| 13 | U7 · `cargar_mongodb.js` | Un `_id` mayor que el máximo de int32 se guardaría como `double` y el validador lo rechazaría | Descartado | El pedido más alto es el 260.013, muy lejos de 2.147.483.647. Y si pasara, el validador lo rechaza: la falla es visible, no silenciosa |
| 14 | U5 · `scripts/anonimizar_log.py` | El comentario dice que usa «el mismo criterio» que `usuario_anon.sql`, pero no trata nombres ni celulares | **Corregido** | El comentario ahora dice lo que hace: los mails se tratan igual, y el log no tiene nombres ni celulares |
| 15 | U4 · `sql/06_desnormalizacion_top_categorias.sql` | El comentario nombra `07_reversion_desnormalizacion.sql`, pero el archivo es `09_…` | **Corregido** | Se corrigió el nombre |

**Resultado:** 15 hallazgos: 8 corregidos, 1 aceptado y 6 descartados. Además, OpenCode dejó anotados 6 puntos que revisó y no consideró problema (al final de la conversación). Las correcciones que viven en la base se aplican y se comprueban con `bash docs/comprobar_hallazgos_u4_u7.sh`, que deja la salida en `evidencias/code_review_u4_u7.txt`. Las versiones anteriores de los dos scripts que se comparan están en `docs/code_review_u4_u7_antes/`.

**Cómo se trabajó.** OpenCode corrió en el agente Plan, en la raíz del repositorio, con el prompt de arriba. Leyó los scripts, chequeó la sintaxis de los `.js` y los `.py`, y dejó las comprobaciones en la base como comandos, porque no tenía `psql` en su `PATH`. Las decisiones son mías, con la recomendación de Claude, después de comprobar cada hallazgo en los archivos o en la base.
