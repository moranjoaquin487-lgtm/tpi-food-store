# Revisión de los scripts que generó OpenCode (U6)

- **Herramienta:** OpenCode, agente Build, modelo Big Pickle, en mi PC.
- **Prompt:** el de [`../prompts/opencode_generar_scripts.md`](../prompts/opencode_generar_scripts.md), con una frase agregada: «No leas los .sh ni los .sql que ya están en esta carpeta: generalos solo a partir de la spec». En el TP8, OpenCode había copiado textos de la versión que tenía a mano, y acá quería ver qué hacía solo con la spec. La sesión confirma que leyó únicamente `SPEC_U6.md` y `AGENTS.md`: [`opencode_sesion_generacion.md`](opencode_sesion_generacion.md).
- **Salida:** los cuatro archivos en [`../opencode/`](../opencode/). **No se ejecutó ninguno**: se leyeron línea por línea y se compararon con los scripts de referencia, que ya estaban probados.

## Los cinco puntos del prompt

| Punto | Versión de OpenCode |
|---|---|
| ¿Escribió alguna contraseña o un `PGPASSWORD=` fijo? | **No.** Toma la autenticación de `pgpass.conf` |
| ¿Usa `VACUUM FULL`, o un `VACUUM` sin observar antes? | **No.** Observa `pg_stat_user_tables` y aplica `VACUUM (ANALYZE)` o `ANALYZE` solo con el criterio de la spec |
| ¿`restore_test.sh` podría restaurar sobre `foodstore`? | **No.** El destino es fijo (`foodstore_restore_test`) y se niega si fuera igual al origen |
| ¿El respaldo sale con error si falla `pg_dump`? | **A medias.** Sale con error por `set -e`, pero no deja ninguna línea en `logs/backup.log`. Un fallo a las 02:00 no quedaría registrado |
| ¿El cronómetro arranca justo antes de `createdb`? | **No.** Arranca antes de contar las filas de la base principal y de borrar la base de prueba, así que el RTO incluye pasos que no son la restauración |

## Otros problemas encontrados al leerlo

| # | Problema | Por qué importa | Decisión |
|:-:|---|---|---|
| 1 | `restore_test.sh` y `maintenance.sql` usan tablas que **no existen**: `products`, `orders`, `order_details`, `customers` | La spec no nombra las tablas y OpenCode las inventó en inglés. El esquema real es `categoria`, `cliente`, `producto`, `pedido` y `detalle_pedido`. El script fallaría en la primera consulta | Descartado |
| 2 | Compara las filas restauradas con las de la base principal **en el momento de restaurar** | La spec pide comparar con las filas que se contaron **antes del respaldo**. Si se vendió algo después, el simulacro fallaría sin que el respaldo tenga nada mal. La referencia guarda el conteo junto al `.dump` | Descartado |
| 3 | `pg_restore … >/dev/null 2>&1 \|\| pg_restore …` | Esconde los errores de la restauración y la reintenta sobre una base a medio restaurar | Descartado |
| 4 | Compara los conteos con `-ne` | En Windows, `psql` termina las líneas con `\r`: es el mismo problema que tuvo el script de referencia en la primera corrida (ver `restore_test_antes_de_corregir_crlf.txt`). Acá daría «integer expression expected» | Descartado |
| 5 | `amcheck`: un `SELECT … HAVING false` de relleno y un conteo de índices revisados presentado como «problemas» | `bt_index_parent_check` no devuelve un resultado: si encuentra un índice dañado, lanza un error. Contar las filas da la cantidad de índices, no de problemas. Además toma un bloqueo más fuerte que `bt_index_check` | Descartado |
| 6 | «Resumen de la U4» = productos con precio negativo | La spec se refiere al **resumen desnormalizado** de la U4 (`resumen_ventas_categoria`), que hay que comparar contra el cálculo real. La referencia lo hace con `fn_verificar_resumen_categoria()` | Descartado |
| 7 | `backup_foodstore.sh` no fija `PGUSER` | Sin `PGUSER=postgres`, en Windows `pg_dump` se conecta con el usuario del sistema (`moran`) y falla. Me pasó con `psql` al correr las comprobaciones de la U5 | Descartado |

## Qué se aceptó

| Propuesta de OpenCode | Qué se hizo |
|---|---|
| En el chequeo de salud, el **porcentaje** de filas modificadas desde el último `ANALYZE` | Se agregó la columna `modificadas_pct` al `health_check.sql` de referencia. Es el número que usa el criterio de la spec (más del 10 %), y antes había que calcularlo a mano |
| El criterio de `ANALYZE` exactamente como lo dice la spec | Al comparar, la referencia exigía además más de 50 filas modificadas, y la spec no lo decía. Se mantuvo el piso de 50, que es el `autovacuum_analyze_threshold` por defecto, y **se corrigió la spec** para que lo diga |

El resto de la versión de OpenCode no se usó: los scripts de referencia ya cubrían lo mismo, sin los problemas de arriba.
