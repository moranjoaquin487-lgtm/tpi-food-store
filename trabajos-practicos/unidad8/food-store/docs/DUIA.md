# DUIA — Declaración de Uso de IA · TP8

Declaración de uso de IA del TP8: base de la tablet, sincronización simulada, integración y revisión. Usé tres herramientas: **Kiro** (spec), **OpenCode** (esquema, semáforo y code review) y **Claude** (primera versión, scripts de apoyo y documentación). El detalle de cada pedido, lo que acepté y lo que descarté está en [`bitacora_ia.md`](bitacora_ia.md).

- **Presentado por:** Moran, Joaquín Leandro

## Kiro

| Campo | Completar |
|---|---|
| Herramienta | Kiro, con la spec en `.kiro/specs/tablet-feria/` (copia en [`docs/kiro/`](kiro/)) y el Autopilot apagado. |
| Spec o prompt utilizado | La spec (`requirements.md`, `design.md` y `tasks.md`), que redactó Claude a partir de la consigna. A Kiro le pedí que la revisara: notación EARS, un caso por requisito y trazabilidad entre tareas y requisitos, sin modificar archivos. Después le pedí que aplicara los cambios que decidí. |
| Qué generó | Una revisión en tres partes (EARS, cobertura de casos y trazabilidad) con 6 cambios recomendados, y después los cambios en los tres archivos. |
| Qué se aceptó | Separar REQ-06 en dos (UUID único y semáforo solo sobre `PENDIENTE`); pasar la condición de REQ-03 a un `WHILE`; que REQ-01 diga que el catálogo no muestra `eliminado = 1`; dejar REQ-08 solo para la lápida; listas explícitas de IDs en las tareas. La spec quedó con 8 requisitos. |
| Qué se modificó o descartó, y por qué | Descarté un REQ-03b de prioridad, porque ninguno de C1 a C7 lo prueba y la consigna pide un caso por requisito. Descarté dejar REQ-05 solo con C5, porque la parte de «sin crear pedidos ni cambiar el stock» la prueba la verificación final. Kiro igual cambió REQ-05 al aplicar los cambios, sin que se lo pidiera, y le pedí que lo volviera atrás. |
| Verificación realizada | Después de cada cambio se comparó el resumen de Kiro y los archivos (`cat` de `requirements.md` y `tasks.md`) con lo decidido. Así apareció el cambio de REQ-05 que no se había pedido. Los archivos finales se copiaron a `docs/kiro/`. |

## OpenCode

| Campo | Completar |
|---|---|
| Herramienta | OpenCode, modelo Big Pickle. Agente **Build** para generar y corregir el esquema y el semáforo; agente **Plan** para el code review. |
| Spec o prompt utilizado | **Build:** implementar las tareas 2 y 5 de `tasks.md` en `opencode/schema_sqlite.sql` y `opencode/semaforo.sql`, con los nombres de tablas y columnas de la consigna, sin leer `movil/` ni ejecutar comandos. Después, dos pedidos de corrección con los problemas que aparecieron al probar. **Plan:** revisar todos los `.sql` y `.sh` del repo, sin leer `.md`, `.pdf` ni `.txt`, y listar cada problema con archivo, por qué es un problema y cómo comprobarlo en la base. |
| Qué generó | `schema_sqlite.sql` y `semaforo.sql`, los que se entregan en `movil/`. El code review: 34 hallazgos, en [`code_review/revision_opencode.md`](code_review/revision_opencode.md). |
| Qué se aceptó | La versión de OpenCode del esquema y del semáforo, después de dos rondas de correcciones. Del code review: 16 hallazgos aceptados y 7 corregidos (tabla en [`code_review/hallazgos.md`](code_review/hallazgos.md)). |
| Qué se modificó o descartó, y por qué | La primera versión del esquema tenía 6 diferencias que encontré al probarla: triggers que no se crean en SQLite anterior a 3.47, `id_local` sin `DEFAULT`, un `CHECK` de UUID que aceptaba cualquier carácter, `usuario` que aceptaba mails, un motivo que se podía cambiar después de evaluado y motivos con id y centavos. Le pedí que las corrigiera y después, por el code review, que agregara tres `CHECK` y cambiara `abs(random())` por `random() & 3`. En la segunda versión OpenCode copió los textos de los motivos de la salida de la versión de Claude, que estaba en `evidencias/`. Del code review descarté 11 hallazgos, cada uno con su fundamento. |
| Verificación realizada | Probé cada versión de OpenCode con las mismas pruebas (C1 y C7) y los mismos casos (C2 a C6), con `docs/opencode/comparar_versiones.sh` (`evidencias/5_comparacion_opencode_v1.txt`, `_v2.txt` y `_final.txt`). La versión final da lo mismo que la primera versión y rechaza los controles extra. Cada hallazgo del code review se comprobó en la base con `docs/code_review/comprobar_hallazgos.sh` (`evidencias/3c_code_review.txt`). |

## Claude (Anthropic)

| Campo | Completar |
|---|---|
| Herramienta | Claude, con un entorno donde pudo ejecutar PostgreSQL 16 y sqlite3 3.45. |
| Spec o prompt utilizado | Le pasé el PDF de la consigna. Para trabajar sobre mi esquema leyó mi repo `tpi-food-store` (TP1, Semana 2 y TPI). Después lo usé para guiarme paso a paso con Kiro y OpenCode, para probar lo que generaban y para escribir la documentación con mis resultados. |
| Qué generó | La primera versión completa del TP (spec, scripts, informe y documentación). De esa versión quedan en la entrega `servidor/` (salvo `schema.sql` y `data.sql`, que son copias de mis archivos del TP1 y la Semana 2), `movil/cargar_snapshot.sql`, `movil/pruebas_sqlite.sql`, `movil/casos/`, `ejecutar_todo.sh`, los scripts de `docs/code_review/` y `docs/opencode/`, el informe, el README, esta DUIA y la bitácora. Su primera versión del esquema y del semáforo quedó en `docs/opencode/version_claude/`, descartada. |
| Qué se aceptó | Los scripts de apoyo y las correcciones #4, #13, #18, #28 y #29 del code review. Las recomendaciones para decidir qué aceptar y qué descartar de Kiro y de OpenCode, que revisé y aprobé. |
| Qué se modificó o descartó, y por qué | Descarté su esquema y su semáforo para entregar los de OpenCode, como pide la consigna («se generan con OpenCode a partir de esas tareas»). En su primera revisión corrigió `cargar_snapshot.sql`, que llenaba la instantánea por posición. |
| Verificación realizada | Todo lo que se entrega lo corrí en mi PC (Windows, Git Bash, PostgreSQL 18.6 y SQLite 3.54.1): `ejecutar_todo.sh`, `comparar_versiones.sh` y `comprobar_hallazgos.sh`. Las evidencias de `evidencias/` son esa salida. |

## Lo que hice yo

- Instalé SQLite 3.54.1, cloné mi repo y corrí todo en mi PC con PostgreSQL 18.6.
- Cargué la spec en Kiro, le pedí la revisión y decidí qué aceptar, con la recomendación de Claude. Revertí el cambio de REQ-05 que hizo Kiro por su cuenta.
- Usé OpenCode Build para generar el esquema y el semáforo a partir de `tasks.md`, los probé contra la primera versión, elegí entregar los de OpenCode y le pedí las correcciones.
- Pedí el code review en OpenCode Plan y decidí cada uno de los 34 hallazgos, con la recomendación y las comprobaciones de Claude.
- Corrí las comprobaciones en mi base: las evidencias son la salida de mi PC.

## Datos y seguridad

- Todo corre sobre copias de prueba con datos inventados: `foodstore_tp8`, `foodstore_tp8_reglas` y una copia de `tpi_food_store`; el script borra las dos últimas al terminar.
- No les pasé contraseñas ni datos personales a las herramientas: la contraseña de PostgreSQL se carga a mano en cada sesión de Git Bash.
- La tablet no guarda mails ni contraseñas: identifica a quien carga el pedido con un código (`feria-01`), y un `CHECK` rechaza cualquier texto con `@`.
