# DUIA — Parte 0 y Parte 1

Declaración de uso de IA de la puesta a punto (Parte 0) y de las restricciones de integridad (Parte 1).

- **Presentado por:** Moran, Joaquín Leandro

## OpenCode — restricciones de las reglas A, B y C

| Campo | Completar |
|---|---|
| Herramienta | OpenCode 1.19.5, con el modelo Big Pickle que trae incluido (no configuré otro proveedor con `/connect`). Lo usé desde PowerShell, porque en Git Bash la interfaz no se dibujaba bien, y en una ventana sin la contraseña de la base. |
| Spec o prompt utilizado | La spec es [`specs/spec_restricciones.md`](../../specs/spec_restricciones.md), commiteada antes de generar el código (commit `571c9cc`). El pedido del plan, en modo Plan, es el texto exacto de la sección 1 de [`prompts/parte1_opencode.md`](../../prompts/parte1_opencode.md). El pedido de escritura, en modo Build, fue: «El plan está bien. Para la Regla C dejá el trigger, no el CHECK con now(). Escribí los dos archivos.» |
| Qué generó | El plan está guardado con `/export` en [`docs/plan_opencode_parte1.md`](../plan_opencode_parte1.md). Generó `food-store/restricciones.sql` (114 líneas): tres funciones PL/pgSQL con sus triggers `BEFORE ... FOR EACH ROW`, una por regla, con `DROP TRIGGER IF EXISTS` y `CREATE OR REPLACE FUNCTION` para poder correrlo más de una vez, y mensajes de error en español que nombran la regla. También generó `food-store/pruebas_restricciones.sql` (94 líneas): los 8 casos de la spec en orden, buscando las filas por nombre o email, y el SELECT del caso 4. |
| Qué se aceptó | Los dos archivos quedaron tal cual los escribió OpenCode. El propio OpenCode retocó el comentario del encabezado para aclarar que los `BEGIN ... END` de las funciones son sintaxis de PL/pgSQL y no control de transacción. |
| Qué se modificó o descartó, y por qué | No corregí ninguna línea a mano. En el plan, OpenCode preguntó si la Regla C iba con trigger o con `CHECK (fecha <= now())`. Elegí el trigger por dos motivos: un CHECK tiene que ser inmutable y `now()` no lo es, y el trigger permite un mensaje que nombra la regla. Antes de aprobar, revisé que los productos que elegía para los casos 1 a 3 no chocaran con la clave primaria de `detalle_pedido`. |
| Verificación realizada | Leí el diff completo con `git diff --staged` y controlé con `grep` que no hubiera `BEGIN`, `COMMIT` ni `ROLLBACK` sueltos (no imprimió nada). Corrí `bash scripts/aplicar_restricciones.sh`, que aplica y prueba dentro de `BEGIN ... ROLLBACK`. La primera vez falló la conexión porque escribí mal la contraseña; la segunda corrida ([`parte1_1_prueba_con_rollback.txt`](../../evidencias/parte1_1_prueba_con_rollback.txt)) dio lo que pide la spec en los 8 casos: pasaron el 1, 4, 5 y 7 (`INSERT 0 1` o `UPDATE 1`), y el 2, 3, 6 y 8 dieron `ERROR` con el mensaje de su regla. Después corrí `--confirmar`: hizo el respaldo en `backups/`, aplicó con `COMMIT` ([`parte1_2_aplicado.txt`](../../evidencias/parte1_2_aplicado.txt)) y repitió los casos ([`parte1_3_pruebas.txt`](../../evidencias/parte1_3_pruebas.txt)). En el caso 4, las tres ventas de la Muzzarella conservaron 1000.00, 1050.00 y 1050.00 con el precio de lista en 1100.00. |

## OpenCode — `AGENTS.md` (Parte 0)

| Campo | Completar |
|---|---|
| Herramienta | OpenCode 1.19.5, modelo Big Pickle. |
| Spec o prompt utilizado | El comando `/init` y el pedido «Reglas del protocolo», texto exacto en [`prompts/parte0_agentes.md`](../../prompts/parte0_agentes.md). |
| Qué generó | [`AGENTS.md`](../../AGENTS.md): contexto del repo, reglas de base de datos, comandos, mapa del proyecto, convenciones del esquema y la sección «Reglas para agentes». |
| Qué se aceptó | El archivo completo, tal cual. |
| Qué se modificó o descartó, y por qué | La primera vez corrí `/init` en modo Plan y no escribió el archivo; lo repetí en modo Build. OpenCode preguntó dónde escribirlo y elegí la carpeta de la Semana 2, que es la que indican el README y los prompts. |
| Verificación realizada | Leí el archivo entero y comprobé que todo lo que menciona existe: los tipos y claves de `schema.sql`, las variables de los scripts de concurrencia, el respaldo con `pg_dump`, y en la raíz del repo `ejecutar_todo.sh`, la carpeta `sql/` y las reglas de LF de `.gitattributes`. No encontré nada inventado. |

## Kiro — steering docs (Parte 0)

| Campo | Completar |
|---|---|
| Herramienta | Kiro, con el selector de modelo en Auto. Lo instalé para este TP. |
| Spec o prompt utilizado | Generación automática (panel de Kiro → *Agent Steering & Skills* → **+** → *Project steering files*), el pedido «Convenciones del esquema» y un pedido de corrección. Los tres están en [`prompts/parte0_agentes.md`](../../prompts/parte0_agentes.md). |
| Qué generó | `.kiro/steering/product.md`, `tech.md`, `structure.md` y `esquema.md`. |
| Qué se aceptó | Los cuatro archivos, después de la corrección. |
| Qué se modificó o descartó, y por qué | Al compararlos con `schema.sql`, `data.sql` y el README encontré tres errores: `product.md` decía que la Parte 3 trataba de concurrencia (es la lectura crítica de dos scripts), `structure.md` decía que `data.sql` tiene 5 pedidos (son 7) y a `esquema.md` le faltaba la regla R3. Le pedí a Kiro que los corrigiera sin cambiar nada más. |
| Verificación realizada | Revisé los cuatro archivos contra el esquema, los datos y los scripts, y después de la corrección confirmé los tres cambios con `grep`. |

## Claude (Anthropic)

| Campo | Completar |
|---|---|
| Herramienta | Claude (Anthropic). |
| Spec o prompt utilizado | Le pasé la consigna del TP y le pedí que me preparara el paquete de trabajo y me guiara paso a paso. |
| Qué generó | Con su ayuda se redactaron la spec de las reglas A, B y C, el protocolo de seguridad, `data.sql`, los scripts (`crear_base.sh`, `aplicar_restricciones.sh`), los pedidos para OpenCode y Kiro, y la guía de pasos. También señaló los errores de los steering docs y revisó conmigo el plan y el diff de OpenCode. Esta DUIA la redactó Claude con mis datos. |
| Qué se aceptó | La spec y los scripts se usaron como estaban. |
| Qué se modificó o descartó, y por qué | Las decisiones sobre lo que generaron OpenCode y Kiro, detalladas arriba. |
| Verificación realizada | Leí la spec y el protocolo antes de commitearlos, y corrí cada script en mi PC. Los resultados de las evidencias son los de esas corridas. |

## Lo que hice yo

Cloné el repo, creé las bases y controlé los conteos, leí el PDF del TP1, el protocolo, la spec, el plan y el diff, decidí qué aceptar de cada herramienta, corrí todos los scripts y commiteé cada paso. Las restricciones las tengo que poder explicar línea por línea en la defensa.
