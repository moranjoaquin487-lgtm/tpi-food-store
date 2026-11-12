# Diseño — U4 · Migración a BCNF

## Esquema nuevo
| Tabla | Atributos | Clave | DF que conserva |
|---|---|---|---|
| `responsable_deposito` | R, D | R | R → D |
| `control_lote` | L, R | {L, R} | — |

La descomposición es **sin pérdida** por el teorema de Heath: el atributo común R es clave de `responsable_deposito`. **No preserva DF1**: ninguna tabla tiene L y D juntos, así que DF1 pasa a un trigger.

## Validación previa (`02_validar_dependencias.sql`)
Antes de migrar, este script comprueba sobre los datos reales qué dependencias se cumplen y cuáles no: confirma que DF1 y DF2 se cumplen (0 violaciones), y muestra que L → D y L → R no se cumplen (hay lotes controlados desde más de un depósito y con más de un responsable). También cuantifica la redundancia: cuántas veces se repite el hecho "R pertenece a D". Finalmente, dentro de sendos `BEGIN … ROLLBACK`, reproduce la **anomalía de actualización** (un responsable queda en dos depósitos si se toca solo una fila) y la **anomalía de inserción** (un responsable nuevo sin lotes no se puede registrar porque `lote_id` es parte de la PK y no admite NULL). Estas demostraciones son el argumento empírico de por qué la tabla heredada no está en BCNF y justifican la migración.


1. Verificación previa: existe la tabla heredada y DF2 se cumple en los datos; si no, `RAISE EXCEPTION` (REQ-02).
2. Dentro de una sola transacción: crear las dos tablas, copiar los datos, renombrar la original a `control_lote_almacen_respaldo` y crear la vista `v_control_lote_almacen` (REQ-03, REQ-08).
3. Control de la reunión con `EXCEPT` en los dos sentidos; si hay diferencias, `RAISE EXCEPTION` y se deshace todo (REQ-04).
4. Trigger por sentencia sobre `control_lote` y sobre los cambios de depósito en `responsable_deposito`: busca un (L, D) repetido en la vista y rechaza la operación. Toma `pg_advisory_xact_lock` para que dos transacciones no pasen el control a la vez (REQ-06).
5. Termina con `:accion`: `ROLLBACK` por defecto (ensayo) o `COMMIT` con `-v accion=COMMIT` (REQ-05).

## Plan de reversión (`04_reversion_fnbc.sql`)
Reconstruye la tabla heredada con la reunión de los datos **actuales**, para no perder cambios posteriores a la migración. Los responsables sin lotes no se pueden representar en la tabla heredada (anomalía de inserción) y se guardan aparte. También se ensaya con `ROLLBACK` por defecto (REQ-07).
