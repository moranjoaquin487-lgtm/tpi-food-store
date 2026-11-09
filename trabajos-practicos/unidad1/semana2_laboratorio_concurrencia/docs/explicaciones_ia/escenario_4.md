# Escenario 4 — Explicación de la IA

| | |
|---|---|
| Herramienta y modelo | Kiro (modelo Auto) |
| Pedido | [`prompts/explicacion_escenario_4.md`](../../prompts/explicacion_escenario_4.md), pegado completo en un chat nuevo |

## Respuesta, copiada tal cual

Lo que pasó: interbloqueo (deadlock) por orden cruzado de bloqueos
Cronología de las dos sesiones
Las dos transacciones tomaron filas en orden inverso, lo que creó una dependencia circular:

Tiempo	Sesión A	Sesión B
t=0	BEGIN	—
t=0.5	—	BEGIN
t≈0	A bloquea Napolitana (UPDATE)	—
t≈0.5	—	B bloquea Fugazzeta (UPDATE)
t≈1	A pide Fugazzeta → espera a B	—
t≈1.5	—	B pide Napolitana → espera a A
t≈1.5	DEADLOCK detectado → A aborta	—
t≈1.5	—	B obtiene Napolitana, termina en 1.41 s, COMMIT
A y B querían las mismas dos filas pero en orden opuesto. Cada una sostenía el bloqueo que la otra necesitaba: ciclo perfecto, deadlock inevitable.

El UPDATE … SET stock = stock es el detalle clave: no cambia ningún valor, pero PostgreSQL igual adquiere un RowExclusiveLock sobre la fila (un UPDATE sigue siendo un UPDATE). Eso es suficiente para crear el conflicto.

Por qué el nivel de aislamiento no es la solución aquí
El deadlock ocurrió en READ COMMITTED (el nivel por defecto), pero subiría igualmente a REPEATABLE READ o SERIALIZABLE. El nivel de aislamiento controla qué versión de los datos ves, pero no cambia que dos transacciones que quieren escribir las mismas filas en orden opuesto van a bloquearse mutuamente. SERIALIZABLE en PostgreSQL usa SSI (Serializable Snapshot Isolation) y podría detectar el ciclo, pero igualmente abortaría una de las dos transacciones.

El mecanismo que evita esto: orden consistente de bloqueos
La solución correcta es un convenio de orden: toda transacción que necesite bloquear más de una fila debe hacerlo siempre en el mismo orden (por ejemplo, por id o por nombre alfabético).

Si ambas sesiones hubieran pedido primero Fugazzeta y luego Napolitana, la segunda transacción simplemente habría esperado en el primer bloqueo sin crear ningún ciclo.

En práctica:

sql

-- Ambas sesiones usan el mismo orden (ej. alfabético por nombre)
UPDATE producto SET stock = stock WHERE nombre = 'Fugazzeta';  -- primero
UPDATE producto SET stock = stock WHERE nombre = 'Napolitana'; -- segundo
Con ese orden, cuando B llega a Fugazzeta y A ya la tiene, B espera. A avanza, toma Napolitana, termina y hace COMMIT. Luego B despierta, toma ambas y también hace COMMIT. Sin ciclo, sin deadlock.

Otras alternativas válidas:

Bloquear ambas filas de una sola vez con SELECT … FOR UPDATE en una sola sentencia que las incluya a las dos (PostgreSQL las bloquea en orden interno consistente).
LOCK TABLE si la granularidad de fila no alcanza, aunque es un cañón para este caso.
Manejo de reintentos en la aplicación ante el error 40P01, que es la práctica defensiva habitual cuando no se puede garantizar el orden.
