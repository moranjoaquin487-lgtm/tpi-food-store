# Escenario 1 — Explicación de la IA

| | |
|---|---|
| Herramienta y modelo |Kiro (modelo Auto) |
| Pedido | [`prompts/explicacion_escenario_1.md`](../../prompts/explicacion_escenario_1.md), pegado completo en un chat nuevo |

## Respuesta, copiada tal cual

Lo que pasó: Lectura No Repetible (Non-Repeatable Read)
La sesión A leyó el precio de Muzzarella dos veces dentro de la misma transacción y obtuvo valores distintos: 1050.00 la primera vez y 1150.00 la segunda.

Esto ocurrió porque:

A inicia la transacción y lee el precio → 1050.00
Mientras A duerme 1.5s, B ejecuta un UPDATE sin BEGIN explícito, por lo que se auto-confirma (autocommit) inmediatamente → el precio queda en 1150.00 en la base de datos
A vuelve a leer el mismo registro y, como está en READ COMMITTED, cada SELECT ve la última versión confirmada al momento de ejecutarse → ahora ve 1150.00
El problema es exactamente eso: READ COMMITTED no garantiza que dos lecturas del mismo dato dentro de una transacción devuelvan el mismo resultado. Cada SELECT obtiene un snapshot nuevo del estado confirmado, no uno fijo desde el inicio de la transacción.

Qué anomalía es
Se llama lectura no repetible (non-repeatable read). El estándar SQL la define como: una transacción lee una fila, otra transacción la modifica y confirma, y la primera transacción vuelve a leer esa fila obteniendo un valor diferente.

Qué evitaría este comportamiento
REPEATABLE READ (o superior). Con ese nivel, PostgreSQL toma un snapshot del estado de la base al inicio de la transacción y lo mantiene fijo para todos los SELECT de esa transacción, sin importar qué confirmen otras sesiones en el medio.

Si la sesión A hubiera arrancado con:

sql

SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
la segunda lectura también habría devuelto 1050.00, porque el snapshot fue tomado antes de que B hiciera el commit.

En PostgreSQL, REPEATABLE READ usa MVCC (Multi-Version Concurrency Control): no bloquea la fila ni hace esperar a B; simplemente A sigue viendo la versión de la fila que existía cuando arrancó su transacción. B puede escribir y confirmar libremente, pero A no ve ese cambio hasta que termine su propia transacción.

Resumen de niveles vs. esta anomalía
Nivel de aislamiento	Lectura no repetible
READ COMMITTED	✗ posible (lo que viste)
REPEATABLE READ	✓ prevenida
SERIALIZABLE	✓ prevenida
