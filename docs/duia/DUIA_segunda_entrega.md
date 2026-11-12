# Declaración de Uso de IA (DUIA) — Segunda entrega

**TPI Food Store · Base de Datos II · UTN**

- **Alumno:** Moran, Joaquín Leandro
- **Alcance:** Unidades 4 a 8 y la segunda entrega del TPI

## Criterio

La IA propone y el motor decide. Ningún script generado con IA se ejecutó sin leerlo línea por línea. Cada uno se probó primero dentro de una transacción reversible o sobre una copia: `foodstore_tp8`, `foodstore_restore_test` o MongoDB como copia. Nunca se le pasaron a una IA datos personales ni contraseñas: los usuarios y clientes son de prueba, y el log que analizó OpenCode estaba anonimizado. Si algo no lo puedo explicar en la defensa, no lo entrego.

## Herramientas

| Herramienta | Finalidad | Prompts o specs |
|---|---|---|
| **Kiro** | Specs en EARS de la migración a BCNF con plan de reversión (U4), de los roles (U5) y de la base móvil (U8). En la U8, la spec se revisó en Kiro antes de generar con OpenCode. En la U4 y la U5 la spec se escribió **después** de los scripts, a partir de ellos, y Kiro la revisó contra los scripts | `.kiro/specs/u4-migracion-fnbc/` y `.kiro/specs/u5-roles/` (copias en `unidad4/docs/kiro/` y `unidad5/docs/kiro_roles_spec/`), `unidad8/food-store/.kiro/specs/tablet-feria/` |
| **OpenCode** | Auditar `roles.sql`, reconstruir el incidente desde el log anonimizado y escribir la consulta equivalente (U5); generar los scripts de mantenimiento desde `SPEC_U6.md` (U6); comparar MongoDB y PostgreSQL (U7); generar el esquema y el semáforo, y hacer el code review en el agente Plan (U8, y U4 a U7) | Carpeta `prompts/` de cada unidad y `docs/code_review_u4_u7.md` |
| **Claude** (Anthropic) | Asistente principal: escribió los scripts de referencia y las pruebas de las cinco unidades, los ejecutó en un entorno de prueba con PostgreSQL 16 y redactó los borradores de los informes | Las consignas de cada TP y de la segunda entrega |

---

## Unidad 4 — Normalización avanzada · Claude

- ✅ DF, claves candidatas y descomposición por la DF violatoria, validadas contra los 600 registros heredados.
- ✅ Migración en una sola transacción, con ensayo (`ROLLBACK`) y plan de reversión que reconstruye desde los datos actuales.
- ✏️ Se agregó un trigger para la DF {lote, depósito} → responsable, que la descomposición en BCNF no preserva.
- ❌ La primera versión de la función que actualiza el resumen usaba un único `INSERT … ON CONFLICT`. Al borrar un pedido fallaba, porque PostgreSQL controla el `CHECK` sobre la fila propuesta antes del conflicto. Lo detectó la prueba del `DELETE` en cascada y se corrigió en dos pasos.

- ✏️ **Kiro.** La spec de la migración (`.kiro/specs/u4-migracion-fnbc/`) la redactó Claude a partir de los scripts, después de escribirlos. Kiro la revisó contra los scripts en mi PC. Acepté 3 de sus 4 cambios: «Se prueba con» lleva el script y la evidencia; REQ-07 se separó en dos (el nuevo REQ-09 cubre los responsables sin lotes, que `04_reversion_fnbc.sql` guarda aparte); y el diseño documenta qué demuestra `02_validar_dependencias.sql`. Descarté que la tarea 1 citara REQ-02: la tarea 1 carga los datos y no implementa ese control. Los cambios los aplicó Kiro. Copia en `unidad4/docs/kiro/`.

## Unidad 5 — Seguridad · Claude y OpenCode

- ✅ Roles con mínimo privilegio y verificación automática contra la spec.
- ❌ `ALTER DEFAULT PRIVILEGES … IN SCHEMA public REVOKE EXECUTE … FROM PUBLIC` no tiene efecto: los privilegios por esquema solo se suman a los globales. Se pasó a la forma global.
- ❌ Con `EXECUTE` revocado a `PUBLIC`, `app_web` no podía vender: el trigger del resumen de la U4 llamaba a una función sin permiso. Las funciones de trigger pasaron a `SECURITY DEFINER`.
- ❌ El `RAISE LOG` de `fn_autenticar` hacía que el log registrara la llamada completa, **con la contraseña**. Se vio en el log original del simulacro y se corrigió con `SET log_min_error_statement = 'panic'` en la función.
- ✏️ OpenCode (agente Plan, en mi PC) auditó `roles.sql` y propuso 7 cambios. Antes de decidir, comprobé cada uno en mi base dentro de `BEGIN … ROLLBACK` (`unidad5/evidencias/A_04_comprobacion_auditoria_ia.txt`). **Corregido:** `admin_datos` podía borrar la auditoría (borró las 6 filas), y ahora la tiene en solo lectura.
- ❌ **Más amplio de lo necesario:** `GRANT USAGE, SELECT ON ALL SEQUENCES` a la app. Las claves son `IDENTITY ALWAYS` y `app_web` inserta sin ese permiso, así que habría abierto 11 secuencias sin necesidad. Tampoco se aplicó su `REVOKE SELECT (contrasena)`: lo probé y no tiene efecto con un permiso de tabla (`admin_datos` siguió leyendo las 147 contraseñas). Los demás cambios, con su decisión, están en `unidad5/BITACORA.md`.
- ❌ OpenCode reconstruyó el incidente desde el log anonimizado, en una carpeta fuera del repo y sin contexto. Acertó la secuencia y que el escalamiento falló. **Sin sustento en el log:** que la fuerza bruta le dio el rol `app_web` (ya estaba conectado como `app_web` antes de los intentos), que había que bloquear `ip_origen_1` (es un seudónimo) y que había que terminar una sesión que el log muestra cerrada. **Omitió** que la credencial comprometida es la de `app_web`. La decisión de contención es mía (`unidad5/docs/informe_incidente.md`, punto 6).
- ✅ La consulta equivalente de la parte D dio los mismos grupos que la de referencia (0 diferencias).
- ✏️ **Kiro.** La spec de roles (`.kiro/specs/u5-roles/`) también se redactó a partir de `roles.sql`, y Kiro la revisó. Acepté 6 de sus 7 cambios. Entre ellos: sacar de REQ-08 «sin ser dueño», que ninguna prueba comprobaba como permiso, y aclarar en el diseño por qué `rol_reportes` no recibe `vista_pedidos_cliente`. Descarté ponerle un `WHEN` a REQ-02: es un requisito ubicuo de EARS, que rige siempre. Corregí un dato que Kiro escribió mal: la vista tiene nombre y apellido del cliente, no el mail. Copia en `unidad5/docs/kiro_roles_spec/`.

## Unidad 6 — Mantenimiento · OpenCode y Claude

- ✅ Scripts de referencia (Claude), probados: respaldo, chequeo, mantenimiento y simulacro.
- ❌ OpenCode (agente Build, en mi PC) generó los cuatro scripts desde `SPEC_U6.md` y `AGENTS.md`, en `opencode/`. No se ejecutaron: los leí y los comparé con los de referencia. Se descartaron porque consultaban tablas inventadas (`products`, `orders`, `order_details`, `customers`), arrancaban el cronómetro antes de tiempo, comparaban contra la base actual y no contra el conteo del respaldo, y escondían los errores de `pg_restore`.
- ✅ Se tomó de OpenCode el porcentaje de filas modificadas desde el último `ANALYZE` en `health_check.sql`. La comparación también mostró que la spec no decía el mínimo de 50 filas que usaba la referencia, y se corrigió la spec. Detalle: `unidad6/evidencias/revision_opencode.md`.

## Unidad 7 — NoSQL · Claude y OpenCode

- ✅ Modelo embebido, carga con `Decimal128` y consultas verificadas contra PostgreSQL con la misma vista de origen.
- ✏️ OpenCode (agente Plan, en mi PC) comparó PostgreSQL y MongoDB y recomendó mantener PostgreSQL como fuente de verdad, con MongoDB a lo sumo como copia de lectura. Antes de responder abrió `informe_u7.md`, que ya tenía el borrador de la conclusión, y lo cita: queda declarado.
- ✅ Contrasté dos afirmaciones en mi MongoDB (`unidad7/pruebas_afirmaciones_ia.js`). **Se sostiene** que las transacciones necesitan un replica set: en mi servidor standalone, la transacción falló.
- ❌ **No se sostiene** que la suma de las líneas «queda a cargo de la aplicación»: un validador con `$expr` rechazó un pedido con el total mal y aceptó el real.

## Unidad 8 — Móvil · Kiro, OpenCode y Claude

Declaración completa en [`trabajos-practicos/unidad8/food-store/docs/DUIA.md`](../../trabajos-practicos/unidad8/food-store/docs/DUIA.md). En resumen:

- ✅ El esquema y el semáforo que se entregan son los de OpenCode, generados desde las tareas de Kiro.
- ❌ La primera versión de OpenCode tenía 6 diferencias, encontradas al probarla. Se corrigieron en dos rondas.
- ❌ La versión de Claude se descartó, porque la consigna pide que el esquema y el semáforo salgan de OpenCode.
- ✏️ Code review de las Unidades 1 a 3 y 8: 34 hallazgos (16 aceptados, 7 corregidos y 11 descartados), cada uno comprobado en la base.

## Code review de las Unidades 4 a 7 · OpenCode (agente Plan)

- ✏️ Code review de las U4 a U7 con OpenCode (agente Plan, en mi PC): 15 hallazgos. Quedaron 8 corregidos, 1 aceptado y 6 descartados, cada uno comprobado en los archivos o en la base (`docs/code_review_u4_u7.md`, `evidencias/code_review_u4_u7.txt`). El más importante lo causó un cambio nuestro de la U5: al pasar el trigger de precios a `SECURITY DEFINER`, la auditoría anotaba a `postgres` en vez de a quien cambió el precio. Un descartado: según OpenCode, `verificar_consultas.sh` daría «No» por el `\r` de Windows, pero en mi PC la tabla salió con «Sí» y sin `\r`.
