# Informe técnico — TPI Food Store, segunda entrega

**Base de Datos II · UTN · Unidades 4 a 8**

- **Alumno:** Moran, Joaquín Leandro
- **Motores:** PostgreSQL 18 (relacional), MongoDB (documental) y SQLite (móvil)
- **Cómo se ejecuta:** `./ejecutar_segunda_entrega.sh` desde Git Bash. Arma la base `foodstore` y corre las unidades 4 a 7 en orden; la U8 tiene su propio `ejecutar_todo.sh`, en `trabajos-practicos/unidad8/food-store`. Cada unidad guarda su salida en su carpeta `evidencias/`.

## Resumen: objetivos y dónde se acreditan

| Unidad | Objetivo | Dónde |
|:-:|---|---|
| 4 | Refactorización de un esquema heredado hasta BCNF, validada contra las DF reales | [`unidad4/docs/fnbc_control_lote.md`](../trabajos-practicos/unidad4_fnbc_desnormalizacion/docs/fnbc_control_lote.md), `sql/01`, `sql/02` |
| 4 | Migración sin pérdida, en una transacción reversible, especificada en Kiro y con plan de reversión | `sql/03_migracion_fnbc.sql`, `sql/04_reversion_fnbc.sql`, `docs/kiro/` |
| 4 | Desnormalización controlada documentada | [`unidad4/docs/migracion_y_desnormalizacion.md`](../trabajos-practicos/unidad4_fnbc_desnormalizacion/docs/migracion_y_desnormalizacion.md), `sql/06` a `sql/09` |
| 5 | Usuarios, roles y permisos con mínimo privilegio | [`unidad5/sql/roles.sql`](../trabajos-practicos/unidad5_seguridad/sql/roles.sql), `evidencias/A_03_verificacion_permisos.txt` |
| 5 | Auditoría activada y simulacro de acceso indebido reconstruido desde el log, con contención | [`unidad5/docs/informe_auditoria.md`](../trabajos-practicos/unidad5_seguridad/docs/informe_auditoria.md), [`informe_incidente.md`](../trabajos-practicos/unidad5_seguridad/docs/informe_incidente.md) |
| 5 | Auditoría de permisos asistida por IA, con la decisión humana documentada | [`unidad5/BITACORA.md`](../trabajos-practicos/unidad5_seguridad/BITACORA.md) |
| 6 | Plan de mantenimiento: respaldo programado, restauración probada y tareas rutinarias | [`unidad6/SPEC_U6.md`](../trabajos-practicos/unidad6_mantenimiento/SPEC_U6.md) y sus scripts |
| 6 | Simulacro de desastre contra reloj, con informe post-incidente | `restore_test.sh`, `informe_u6.pdf` |
| 7 | Modelo documental con consultas verificadas sobre datos reales | [`unidad7/docs/informe_u7.md`](../trabajos-practicos/unidad7_nosql/docs/informe_u7.md) |
| 7 | Comparación documental vs. relacional y tecnología elegida | Mismo informe, sección 3 |
| 8 | Base SQLite y su sincronización, especificadas en Kiro y generadas con OpenCode | [`unidad8/food-store/README.md`](../trabajos-practicos/unidad8/food-store/README.md), `.kiro/specs/tablet-feria/`, `opencode/` |
| 8 | Sincronización simulada con casos de conflicto resueltos | `unidad8/food-store/evidencias/2c_C2.txt` a `2c_C6.txt` y `2c_verificacion_servidor.txt` |
| 8 | Code review final con IA y decisión humana sobre cada hallazgo | [`unidad8/food-store/docs/code_review/hallazgos.md`](../trabajos-practicos/unidad8/food-store/docs/code_review/hallazgos.md) (Unidades 1 a 3 y 8) y [`docs/code_review_u4_u7.md`](code_review_u4_u7.md) (Unidades 4 a 7) |
| — | Capa de datos completa, con specs, scripts versionados, plan de mantenimiento y bitácora | Este repositorio |

## 1. Qué se implementó

**Unidad 4.**

- La tabla heredada `control_lote_almacen` (lote, depósito, responsable) tenía 600 filas para 24 hechos «responsable → depósito»: 576 repeticiones.
- La DF violatoria (`responsable → depósito`) se validó sobre los datos, y la tabla se descompuso en `responsable_deposito` y `control_lote`.
- La migración corre en **una sola transacción** que se verifica a sí misma (`EXCEPT` en los dos sentidos) y termina en `ROLLBACK` (ensayo) o en `COMMIT`. Tiene su script de reversión, que reconstruye desde los datos actuales.
- Como BCNF no preserva la DF {lote, depósito} → responsable, se la protegió con un trigger y un candado de transacción.
- Para el top 5 de categorías se creó una tabla resumen mantenida por triggers, con verificación, recálculo y reversión.

**Unidad 5.**

- Cinco roles de grupo y cinco logins, con permisos de columna sobre `usuario`.
- `REVOKE EXECUTE … FROM PUBLIC`, privilegios por defecto para los objetos futuros y una verificación automática contra la especificación.
- `fn_autenticar` y `fn_resetear_password` como `SECURITY DEFINER`, con `search_path` fijo y registro de cada intento.
- Auditoría nativa activada (`log_connections`, `log_disconnections`, `log_statement = mod`).
- Simulacro de incidente, con extracción y anonimización del log.
- `usuario_anon` con seudónimos deterministas.

**Unidad 6.**

- `SPEC_U6.md` y `AGENTS.md`.
- Respaldo `pg_dump -Fc` con conteo de filas previo y verificación con `pg_restore --list`.
- Chequeo de salud, mantenimiento que solo actúa donde la observación lo justifica, y verificación de integridad con `amcheck` y con el resumen de la U4.
- Simulacro de restauración cronometrado, con RTO y RPO.

**Unidad 7.**

- Columna `estado` en `pedido`, que faltaba.
- Exportación de 62 pedidos con sus líneas a JSON y carga en MongoDB con `Decimal128`.
- Validador `$jsonSchema`, consultas a–d y equivalentes en PostgreSQL.
- Tabla de verificación automática y pruebas de laboratorio para contrastar a la IA.

**Unidad 8** (TP8, en `trabajos-practicos/unidad8/food-store`).

- Spec en Kiro (`tablet-feria`), con 8 requisitos EARS, cada uno ligado a un caso.
- Esquema SQLite `STRICT` y semáforo **generados con OpenCode** a partir de las tareas, después de dos rondas de correcciones. La primera versión, de Claude, quedó descartada en `docs/opencode/version_claude/`.
- Instantánea `v_snapshot_movil` con lápidas, sobre la copia de pruebas `foodstore_tp8`.
- Casos C1 a C7, mapa de los motores y agregado al plan de mantenimiento.
- Code review de OpenCode, en el agente Plan, de los scripts de las Unidades 1 a 3 y 8.

## 2. Cómo se probó

| Técnica | Dónde |
|---|---|
| **Transacciones reversibles.** Cada migración y cada reversión se ensaya primero con `ROLLBACK`. Las pruebas de anomalías y de salvaguardas corren dentro de `BEGIN … ROLLBACK` | U4 |
| **Copias de prueba.** El servidor de la U8 es `foodstore_tp8`; la restauración va a `foodstore_restore_test`; MongoDB recibe una copia | U6, U7, U8 |
| **Simulacro de acceso indebido.** Fuerza bruta contra `fn_autenticar`, lectura masiva e intento de escalamiento, como `app_web` y desde la base propia | U5, Parte C |
| **Simulacro de desastre.** Último respaldo restaurado contra reloj y validado (filas y restricciones) | U6 |
| **Conflictos de sincronización.** Precio cambiado (C2), stock insuficiente (C3), baja lógica (C4), sin cambios (C5) y reenvío (C6) | U8 |
| **Verificación por comparación.** Permisos reales contra la spec; reunión contra la tabla original; resumen contra el cálculo real; usuarios reales contra los anonimizados; MongoDB contra PostgreSQL | Todas |

## 3. Resultados

| Prueba | Resultado | Evidencia |
|---|---|---|
| Migración a BCNF | 600 filas → 24 + 600; 0 tuplas perdidas y 0 espurias | `unidad4/evidencias/03b_migracion_aplicada.txt` |
| Top 5 de categorías | 304,8 ms → 0,12 ms; el trigger del resumen suma 14,6 ms por cada 1000 líneas | `unidad4/evidencias/08_mediciones.txt` |
| Permisos contra la spec | 0 de más, 0 de menos | `unidad5/evidencias/A_03_verificacion_permisos.txt` |
| Escalamiento en el simulacro | Falló: `app_web` no quedó como miembro de `admin_datos` | `unidad5/evidencias/C_simulacro_verificacion.txt` |
| Agregados de `usuario_anon` | 0 grupos distintos, 147 usuarios en las dos tablas | `unidad5/docs/verificacion_equivalencia.md` |
| **Simulacro de desastre: RTO** | 6,7 s con 1 proceso y 5,0 s con `--jobs 4` (objetivo ≤ 15 min) | `unidad6/evidencias/restore_test_*.txt` |
| **RPO observado** | 5 min 40 s (objetivo ≤ 24 h) | Ídem |
| Validaciones de la restauración | OK: las 5 tablas con las mismas filas, 0 productos y 0 detalles inválidos | Ídem |
| MongoDB contra PostgreSQL | Estado: 10 y 10; producto: 9 y 9; los mismos IDs | `unidad7/evidencias/tabla_verificacion.md` |
| Casos de sincronización C2 a C6 | 1 `CONFLICTO`, 2 `RECHAZADO` y 3 `SIMULADO_APROBADO`; en el servidor, la cantidad de pedidos y el stock no cambiaron | `unidad8/food-store/evidencias/2c_*.txt` |
| Code review | U1 a U3 y U8: 34 hallazgos (16 aceptados, 7 corregidos, 11 descartados). U4 a U7: 15 hallazgos (8 corregidos, 1 aceptado, 6 descartados) | `unidad8/food-store/docs/code_review/hallazgos.md`, `docs/code_review_u4_u7.md` |

**Informe post-incidente:** [`unidad6/informe_u6.pdf`](../trabajos-practicos/unidad6_mantenimiento/informe_u6.pdf).

## 4. Decisiones de diseño

- **Refactorización.** BCNF antes que preservar la DF1, que pasa a un trigger. La tabla original se conserva como respaldo hasta confirmar que nadie escribe en ella, y una vista mantiene las lecturas viejas.
- **Desnormalización.** Una sola, medida y reversible: el resumen por categoría. Los precios y las cantidades de cada venta siguen solo en `detalle_pedido`. Se aceptó un costo pequeño en cada escritura a cambio de una lectura de 5 filas.
- **Roles y permisos.**
  - `app_web` no lee `usuario`: autentica con una función `SECURITY DEFINER`.
  - Soporte ve los usuarios sin la contraseña (permiso de columna).
  - Reportes solo lee vistas y la tabla anonimizada; `vista_usuario_reportes` no se le otorgó porque expone mail y celular.
  - `admin_datos` no es superusuario ni puede crear roles.
  - Las funciones de trigger que escriben tablas internas corren como dueño, para no darle a la app permisos de escritura sobre la auditoría ni sobre el resumen.
- **Auditoría.** `log_statement = mod` como base, con el límite documentado: las lecturas no quedan registradas. Durante una investigación se sumaría el registro de lecturas de `app_web` o pgaudit.
- **Documental o relacional.** Se mantiene **PostgreSQL** como fuente de verdad: una venta toca el pedido, sus líneas y el stock en una transacción, con controles del motor. MongoDB queda como copia de solo lectura, regenerable. Justificación completa en el informe de la U7.
- **Móvil.** La tablet nunca decide precio, stock ni ventas. Las bajas viajan como lápidas, y cada envío lleva su propio UUID para que reenviar no duplique.

## 5. Herramientas de IA

| Herramienta | Uso |
|---|---|
| **Kiro** | Specs de la migración (U4), de roles (U5) y de la base móvil (U8) |
| **OpenCode** | Auditoría de `roles.sql`, reconstrucción del incidente y consulta equivalente (U5); generación de los scripts de mantenimiento (U6); comparación de tecnologías (U7); esquema y semáforo, y code review en el agente Plan (U8, y U4 a U7 en `docs/code_review_u4_u7.md`) |
| **Claude** (Anthropic) | Asistente principal de las U4 a U7: escribió los scripts de referencia y las pruebas, los corrió en un entorno de prueba y redactó los borradores de los informes. En la U8 hizo la primera versión, que se descartó para entregar la de OpenCode. Todo se revisó y se volvió a ejecutar en mi PC |

**Errores de la IA detectados al probar** (detalle en la bitácora de cada unidad y en la DUIA):

- **U4.** El `INSERT … ON CONFLICT` del resumen fallaba al borrar ventas por el `CHECK`.
- **U5.** Un `ALTER DEFAULT PRIVILEGES … IN SCHEMA` que no revocaba nada.
- **U5.** Funciones de trigger que impedían vender con `app_web`.
- **U5.** `RAISE LOG` que escribía la contraseña en el log.

Lo aceptado y lo descartado de OpenCode está en cada bitácora. Declaración completa: [`docs/duia/DUIA_segunda_entrega.md`](duia/DUIA_segunda_entrega.md).
