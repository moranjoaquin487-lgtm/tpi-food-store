# Escenario 2 — Explicación de la IA

| | |
|---|---|
| Herramienta y modelo | Kiro (modelo Auto) |
| Fecha | 08/11/2026 |
| Pedido | [`prompts/explicacion_escenario_2.md`](../../prompts/explicacion_escenario_2.md), pegado completo en un chat nuevo |

## Respuesta, copiada tal cual

Qué pasó: Phantom Read (lectura fantasma)
La sesión A leyó el mismo conjunto de filas dos veces dentro de la misma transacción y obtuvo resultados distintos (2 y luego 3). Esto es exactamente una lectura fantasma: entre las dos lecturas, una transacción externa confirmó una fila nueva que satisface la misma condición del WHERE.

El flujo cronológico:

Tiempo	Sesión A	Sesión B
t=0	BEGIN + primer COUNT → 2	—
t=0.5	pg_sleep(1.5) (durmiendo)	INSERT de un nuevo pedido de Ana → COMMIT automático
t=2	segundo COUNT → 3	—
t=2+	COMMIT	—
La sesión B no tenía BEGIN explícito, así que el INSERT se confirmó de inmediato (autocommit). Cuando A hizo su segunda lectura, la fila ya era visible porque READ COMMITTED toma un nuevo snapshot al inicio de cada statement, no al inicio de la transacción.

Por qué READ COMMITTED lo permite
En READ COMMITTED, el snapshot se refresca con cada comando SQL individual. Entonces:

Primer COUNT: snapshot capturado → ve 2 pedidos.
pg_sleep: B inserta y confirma → la fila existe en disco.
Segundo COUNT: nuevo snapshot → ve 3 pedidos.
Esto es comportamiento definido y esperado de ese nivel.

Qué nivel lo evitaría
REPEATABLE READ
En PostgreSQL, REPEATABLE READ toma el snapshot una sola vez al inicio de la transacción y lo mantiene para todos los statements siguientes. Cualquier fila confirmada después de ese punto queda invisible para esa transacción.

Sesión A con REPEATABLE READ:

Primer COUNT → 2 (snapshot fijado aquí).
B inserta y confirma → la fila existe, pero está fuera del snapshot de A.
Segundo COUNT → sigue siendo 2.
No hay fantasma.
Nota: el estándar SQL dice que REPEATABLE READ solo garantiza no tener non-repeatable reads y que los phantoms pueden ocurrir igualmente. PostgreSQL va más allá: su implementación MVCC hace que REPEATABLE READ también elimine los phantoms, porque el snapshot fijo los excluye naturalmente.

SERIALIZABLE
Ofrece el aislamiento más fuerte. Además del snapshot fijo, detecta dependencias entre transacciones y puede abortar alguna si formarían un ciclo de serialización (Serializable Snapshot Isolation). Para este escenario alcanza con REPEATABLE READ, pero SERIALIZABLE también lo resuelve.

Alternativa con bloqueos explícitos (sin cambiar el nivel)
Si se necesita quedar en READ COMMITTED pero evitar que B inserte mientras A está contando, se puede usar LOCK TABLE pedido IN SHARE MODE al inicio de la transacción de A. Eso bloquearía el INSERT de B hasta que A haga COMMIT. Es una solución más agresiva y de menor concurrencia, generalmente no es la preferida frente a simplemente subir el nivel de aislamiento.
