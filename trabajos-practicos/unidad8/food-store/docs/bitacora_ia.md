# Bitácora de uso de IA — TP8

- **Presentado por:** Moran, Joaquín Leandro
- **Herramientas:** Claude, Kiro y OpenCode (modelo Big Pickle). Todo se corrió en mi PC: Windows, Git Bash, PostgreSQL 18.6 y SQLite 3.54.1.

Cada entrada dice qué le pedí a la IA, qué acepté, qué descarté y por qué, y cómo lo comprobé.

## 1 · Claude: primera versión del TP

| | |
|---|---|
| **Qué le pedí** | Le pasé el PDF de la consigna para que lo resolviera. Para trabajar sobre mi esquema, Claude leyó mi repo `tpi-food-store` (el `schema.sql` del TP1 y los datos de la Semana 2). |
| **Qué acepté** | La spec para Kiro y los scripts de apoyo: la copia de pruebas `foodstore_tp8`, la vista `v_snapshot_movil`, la carga de la instantánea, las pruebas de 1.c, los casos C2 a C6, la verificación final y `ejecutar_todo.sh`. También las decisiones de diseño: centavos en entero, tablas `STRICT`, `disponible` y `eliminado` por separado, lápidas en vez de borrar filas y `UPSERT` para recargar el catálogo. |
| **Qué descarté y por qué** | **Su esquema y su semáforo:** la consigna pide que se generen con OpenCode a partir de las tareas (entrada 3), así que quedaron en `docs/opencode/version_claude/` solo para comparar. **Recargar `producto_cache` con `DELETE` + `INSERT`:** borraría las lápidas y rompería la clave foránea de los borradores viejos. **Preparar C3 bajando el stock del servidor:** la consigna pide terminar mostrando que el stock no cambió; C3 es un borrador por más unidades de las que quedan (20 flanes con 15 en stock). |
| **Cómo lo comprobé** | Corrí `ejecutar_todo.sh` en mi PC: 1 `CONFLICTO`, 2 `RECHAZADO` y 3 `SIMULADO_APROBADO`, con 7 pedidos y 620 de stock antes y después. En su primera revisión, Claude encontró que `.import --skip 1` llenaba la instantánea por posición (con las columnas en otro orden, la Muzzarella quedaba a $0,40 sin error) y lo corrigió copiando por nombre de columna. |

## 2 · Kiro: revisión de la spec

| | |
|---|---|
| **Qué le pedí** | Con la spec en `.kiro/specs/tablet-feria/`, que revisara si cada requisito estaba en EARS, si tenía su caso y si las tareas apuntaban a requisitos existentes, sin modificar archivos. Después, que aplicara solo los cambios que decidí. |
| **Qué acepté** | Separar REQ-06 en dos (UUID único con `IF/THEN` y semáforo solo sobre `PENDIENTE` con `WHEN`, los dos probados con C6). Pasar «sin motivo de rechazo» de REQ-03 a un `WHILE`. Que REQ-01 diga que el catálogo no muestra `eliminado = 1`, y dejar REQ-08 solo para la lápida. Listas explícitas de IDs en las tareas. La spec quedó con 8 requisitos. |
| **Qué descarté y por qué** | **Un REQ-03b de prioridad:** ningún caso de C1 a C7 tiene un rojo y un amarillo a la vez, y la consigna pide un caso por requisito. **REQ-05 solo con C5:** la parte de «sin crear pedidos ni cambiar el stock» la prueba la verificación final. **Que el nuevo REQ-07 no tenía caso:** la segunda corrida del semáforo en C6 lo prueba. |
| **Cómo lo comprobé** | Leí el resumen de Kiro y los archivos con `cat`. Kiro cambió REQ-05 a «solo C5» aunque le había pedido dejarlo igual; le pedí que lo volviera atrás y lo verifiqué. |

## 3 · OpenCode Build: esquema y semáforo a partir de las tareas

| | |
|---|---|
| **Qué le pedí** | Implementar las tareas 2 y 5 de `tasks.md` en `opencode/`, con los nombres de tablas y columnas de la consigna, sin leer `movil/` ni ejecutar comandos. |
| **Qué acepté** | La lógica: llegó sola a lo mismo que la primera versión. Con las mismas pruebas y casos, la cola terminó igual. |
| **Qué descarté y por qué** | Esa primera versión, por 6 diferencias que aparecieron al probarla: **los triggers usaban `RAISE` con texto concatenado**, que SQLite acepta recién desde 3.47 (la consigna pide 3.37; en una versión anterior el esquema se crea sin triggers y sin avisar); **`id_local` no tenía `DEFAULT`**, así que la prueba del `ROLLBACK` fallaba; **el `CHECK` de UUID aceptaba `zzzzzzzz-…`**; **`usuario` aceptaba `ana.gomez@mail.com`**; **el motivo de una solicitud evaluada se podía cambiar**; y **los motivos mostraban «producto 3: precio visto 105000»**. |
| **Cómo lo comprobé** | Con `docs/opencode/comparar_versiones.sh` (`evidencias/5_comparacion_opencode_v1.txt`). Claude probó además la parte del `RAISE` en SQLite 3.45. |

## 4 · OpenCode Build: corrección y adopción

| | |
|---|---|
| **Qué le pedí** | Que corrigiera esas 6 diferencias, que el esquema empezara con `PRAGMA foreign_keys = ON;` y se pudiera correr desde cero, que guardara con qué instantánea se evaluó cada solicitud (`evaluada_con`) y que el semáforo fuera entre `BEGIN` y `COMMIT`, mostrando cuántas solicitudes evaluó. |
| **Qué acepté** | La versión corregida, que es la que se entrega en `movil/`. |
| **Qué descarté y por qué** | La primera versión de Claude, que quedó en `docs/opencode/version_claude/` solo para comparar. Tengo que aclarar algo: OpenCode dijo que igualó los textos de los motivos y de los triggers a los de «la versión de referencia que pasa las pruebas», o sea que los copió de la salida de la versión de Claude que estaba en `evidencias/`. |
| **Cómo lo comprobé** | `evidencias/5_comparacion_opencode_v2.txt`: la misma salida que la primera versión, y los tres controles extra ahora fallan como corresponde. Claude comprobó que los triggers se crean en SQLite 3.45. Después volví a correr `ejecutar_todo.sh` con la versión de OpenCode. |

## 5 · OpenCode Plan: code review de los scripts de la cursada

| | |
|---|---|
| **Qué le pedí** | En una sesión nueva, abierta en la raíz del repo y en modo Plan: revisar todos los `.sql` y `.sh` de `sql/`, `trabajos-practicos/unidad1/` y `trabajos-practicos/unidad8/food-store/`, sin leer `.md`, `.pdf` ni `.txt`, y listar cada problema con archivo, por qué es un problema y cómo comprobarlo en la base. |
| **Qué acepté** | 16 hallazgos como problemas reales que quedan para la entrega final del TPI, y 7 para corregir en este TP (tabla completa en `docs/code_review/hallazgos.md`). Cuando me ofreció corregirlos, elegí «No hacer nada más»: lo que se corrige lo decido yo. |
| **Qué descarté y por qué** | 11 hallazgos, cada uno con su fundamento. Por ejemplo: **#19**, la solicitud de la prueba 1.c la pide la consigna y no cambia ningún caso; **#20**, con las reglas A, B y C cargadas la instantánea da exactamente lo mismo; **#31**, ninguna fecha de `data.sql` se repite. |
| **Cómo lo comprobé** | La primera respuesta vino vacía y le pedí la lista. Después de que Claude probara los hallazgos dudosos (#6, #9, #10, #15 y #31), decidí con su recomendación. Las comprobaciones están en `docs/code_review/comprobar_hallazgos.sh` y su salida, de mi PC, en `evidencias/3c_code_review.txt`. Aunque no leyó `.md`, OpenCode vio `docs/opencode/version_claude/` y el script anterior de comprobaciones; por eso #14, #27 y #28 se comparan con «la versión de Claude». |

## 6 · Correcciones del code review

| | |
|---|---|
| **Qué le pedí** | A **OpenCode Build**, las correcciones de su propio esquema: #14 (`CHECK` de motivo y `evaluada_con` según el estado, `NOT (eliminado = 1 AND disponible = 1)` y formato de `copiado_en`) y #32 (`random() & 3`). A **Claude**, las de sus scripts: #4 (instantánea incompleta), #13 (centavos en `BIGINT`), #18 (verificación fila por fila), #28 y #29 (scripts de comprobación). |
| **Qué acepté** | Las 7 correcciones. La sesión de OpenCode que hizo #14 y #32 fue una; abrí otra con el mismo pedido y esa solo confirmó que los cambios ya estaban. |
| **Qué descarté y por qué** | Sumar la demanda de todas las solicitudes `PENDIENTE` para resolver #5: también contaría las que se rechazan por otro motivo y castigaría pedidos válidos. Quedó documentado como límite de la simulación. |
| **Cómo lo comprobé** | Corrí todo de nuevo en mi PC. **#4:** con un CSV de 5 de 12 filas, la versión anterior dejaba 7 lápidas y la corregida falla con `CHECK constraint failed: completa = 1` sin tocar el catálogo. **#13:** `INTEGER` da *entero fuera de rango* y la vista devuelve 2500000000 como `bigint`. **#18:** la verificación anterior no veía un producto nuevo y la corregida lo muestra. La verificación final siguió en 7 pedidos, 12 líneas, 12 productos y 620 de stock antes y después. |
