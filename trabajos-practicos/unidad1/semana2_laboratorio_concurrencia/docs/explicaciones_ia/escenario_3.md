# Escenario 3 — Explicación de la IA

| | |
|---|---|
| Herramienta y modelo | Kiro (modelo Auto) |
| Pedido | [`prompts/explicacion_escenario_3.md`](../../prompts/explicacion_escenario_3.md), pegado completo en un chat nuevo |

## Respuesta, copiada tal cual

Qué pasó: Espera por bloqueo (Lock Wait)
El mecanismo: SELECT ... FOR UPDATE
Cuando la Sesión A ejecutó SELECT ... FOR UPDATE sobre la fila de la Coca 1.5L, PostgreSQL adquirió un bloqueo exclusivo de fila (row-level exclusive lock). Ese lock impide que cualquier otra transacción lea esa misma fila con FOR UPDATE o la modifique hasta que A haga COMMIT o ROLLBACK.

La secuencia paso a paso
Tiempo	Sesión A	Sesión B
t=0	BEGIN + FOR UPDATE → obtiene lock, ve stock=60	—
t=0.5s	pg_sleep(2) (duerme)	BEGIN + FOR UPDATE → queda bloqueada esperando
t≈2s	UPDATE stock = 60-1 + COMMIT → libera lock	—
t≈2s	—	despierta, obtiene lock, lee stock=59
La Sesión B reportó 1.38 segundos desde su BEGIN hasta obtener la fila, que es consistente con haber esperado ~1.5s (arrancó 0.5s después, A durmió 2s; la diferencia es el tiempo de espera real).

Lo clave: B vio stock=59, no 60
Esto es el comportamiento correcto del mecanismo. B no leyó el valor "viejo" de 60; esperó a que A terminara y leyó el valor comprometido actualizado (59). No hay anomalía aquí — el bloqueo funcionó exactamente como debe.

¿Qué nivel de aislamiento o mecanismo evita/controla este comportamiento?
"Evitar" depende de lo que quieras lograr:

Para evitar la espera (no bloquear): usás FOR UPDATE SKIP LOCKED o FOR UPDATE NOWAIT.

NOWAIT falla de inmediato con un error si la fila está bloqueada.
SKIP LOCKED omite las filas bloqueadas y sigue adelante (útil para colas de trabajo).
Para evitar que B vea datos desactualizados sin bloquear: usás el nivel REPEATABLE READ o SERIALIZABLE, que en PostgreSQL usan MVCC. Pero en esos niveles un SELECT sin FOR UPDATE puede leer una snapshot vieja — justo la fuente de anomalías como lecturas no repetibles.

El comportamiento que viste es el diseñado: SELECT ... FOR UPDATE es el mecanismo explícito de serialización pesimista. Garantiza que dos transacciones no modifiquen la misma fila simultáneamente, a costa de que una espere a la otra. Es la herramienta correcta para escenarios como descuento de stock, donde necesitás que la lectura y la escritura sean atómicas respecto a otras transacciones.

Resumen
Lo que observaste se llama espera por bloqueo (lock wait), no una anomalía. Es el comportamiento esperado de FOR UPDATE bajo cualquier nivel de aislamiento en PostgreSQL. El nivel de aislamiento (READ COMMITTED, que es el default) no cambia esto — los locks de fila son ortogonales al nivel de aislamiento y aplican en todos ellos.
