# Informe de concurrencia

Parte 2 de la Semana 2. Base: `foodstore_trabajo`, copia de `foodstore_plantilla`, en PostgreSQL 18.6.

Los cuatro escenarios se corrieron con `bash scripts/laboratorio_concurrencia.sh reproducir`. El script abre dos conexiones de `psql` a la vez y la sesión B arranca 0,5 s después que la A. Los comandos de cada sesión están en [`food-store/concurrencia/`](../food-store/concurrencia/), y la salida completa de cada escenario, en `evidencias/`. Después de cada escenario, el script deja los datos como estaban: restaura el precio y el stock, y borra el pedido de prueba.

Las explicaciones de la IA se pidieron a Kiro (modelo Auto) en un chat nuevo por escenario, pegando el pedido completo que genera el script (`prompts/explicacion_escenario_N.md`). Las respuestas están copiadas tal cual en [`docs/explicaciones_ia/`](explicaciones_ia/). Para verificarlas, se repitió cada experimento con `bash scripts/laboratorio_concurrencia.sh verificar` y con `bash scripts/verificar_lock_table.sh`.

## Resumen

| # | Escenario | Qué se observó | Qué lo evita, según el motor | ¿Acertó la IA? |
|:-:|---|---|---|---|
| 1 | Lectura no repetible | 1050.00 → 1150.00 | REPEATABLE READ y SERIALIZABLE | Sí |
| 2 | Lectura fantasma | 2 → 3 | REPEATABLE READ, SERIALIZABLE y `LOCK TABLE ... IN SHARE MODE` | Sí |
| 3 | Espera por bloqueo | B esperó 1,38 s y leyó stock 59 | NOWAIT, SKIP LOCKED y `lock_timeout` evitan la espera | En parte: se equivocó sobre SERIALIZABLE |
| 4 | Interbloqueo | A abortada con `40P01` | Tomar las filas en el mismo orden | Sí, con dos imprecisiones |

---

## Escenario 1 — Lectura no repetible

**Escenario.** La sesión A lee dos veces el precio de la Muzzarella dentro de la misma transacción, en READ COMMITTED, mientras la sesión B lo sube y confirma.

**Cómo se reprodujo.**

Sesión A ([`e1_A.sql`](../food-store/concurrencia/e1_A.sql), con `:nivel` = `READ COMMITTED`):

```sql
BEGIN;
SET TRANSACTION ISOLATION LEVEL :nivel;
SHOW transaction_isolation;
SELECT precio AS primera_lectura FROM producto WHERE nombre = 'Muzzarella';
SELECT pg_sleep(1.5);  -- mientras tanto, la sesión B cambia el precio y confirma
SELECT precio AS segunda_lectura FROM producto WHERE nombre = 'Muzzarella';
COMMIT;
```

Sesión B ([`e1_B.sql`](../food-store/concurrencia/e1_B.sql)), sin `BEGIN`, así que se confirma sola:

```sql
UPDATE producto SET precio = precio + 100 WHERE nombre = 'Muzzarella';
```

**Qué se observó** ([`e1_no_repetible_read_committed.txt`](../evidencias/e1_no_repetible_read_committed.txt)):

| Sesión | Comando | Salida |
|:-:|---|---|
| A | `SHOW transaction_isolation` | `read committed` |
| A | primera lectura | `1050.00` |
| B | `UPDATE` | `UPDATE 1` |
| A | segunda lectura | `1150.00` |
| A | `COMMIT` | `COMMIT` |

La misma consulta, dentro de la misma transacción, devolvió dos valores distintos.

**Explicación de la IA** (Kiro, modelo Auto; tal cual en [`escenario_1.md`](explicaciones_ia/escenario_1.md)). Identifica una lectura no repetible: en READ COMMITTED cada `SELECT` ve lo último confirmado. Propone REPEATABLE READ o SERIALIZABLE, que mantienen el mismo snapshot durante toda la transacción.

**Verificación en el motor.** Se repitió con la sesión A en los dos niveles propuestos:

| Nivel de A | Primera lectura | Segunda lectura | Evidencia |
|---|---|---|---|
| REPEATABLE READ | 1050.00 | 1050.00 | [`e1_verificacion_repeatable_read.txt`](../evidencias/e1_verificacion_repeatable_read.txt) |
| SERIALIZABLE | 1050.00 | 1050.00 | [`e1_verificacion_serializable.txt`](../evidencias/e1_verificacion_serializable.txt) |

En los dos casos, la sesión B igual confirmó su `UPDATE 1`: no quedó bloqueada, como dijo la IA.

**Conclusión.** La explicación se confirmó. REPEATABLE READ alcanza para evitar la lectura no repetible. Un matiz: Kiro dice que el snapshot se toma "al inicio de la transacción". En PostgreSQL se toma en la primera consulta de la transacción, no en el `BEGIN`. Acá no cambia el resultado, porque la primera lectura fue antes del `UPDATE` de B.

---

## Escenario 2 — Lectura fantasma

**Escenario.** La sesión A cuenta dos veces los pedidos de Ana Gómez, en READ COMMITTED, mientras la sesión B registra un pedido nuevo de Ana.

**Cómo se reprodujo.**

Sesión A ([`e2_A.sql`](../food-store/concurrencia/e2_A.sql), con `:nivel` = `READ COMMITTED`):

```sql
BEGIN;
SET TRANSACTION ISOLATION LEVEL :nivel;
SHOW transaction_isolation;
SELECT COUNT(*) AS primer_conteo FROM pedido p JOIN cliente c ON c.id = p.cliente_id WHERE c.email = 'ana.gomez@mail.com';
SELECT pg_sleep(1.5);  -- mientras tanto, la sesión B registra un pedido nuevo de Ana
SELECT COUNT(*) AS segundo_conteo FROM pedido p JOIN cliente c ON c.id = p.cliente_id WHERE c.email = 'ana.gomez@mail.com';
COMMIT;
```

Sesión B ([`e2_B.sql`](../food-store/concurrencia/e2_B.sql)), sin `BEGIN`:

```sql
INSERT INTO pedido (forma_pago, cliente_id)
SELECT 'EFECTIVO', id FROM cliente WHERE email = 'ana.gomez@mail.com';
```

**Qué se observó** ([`e2_fantasma_read_committed.txt`](../evidencias/e2_fantasma_read_committed.txt)):

| Sesión | Comando | Salida |
|:-:|---|---|
| A | `SHOW transaction_isolation` | `read committed` |
| A | primer conteo | `2` |
| B | `INSERT` | `INSERT 0 1` |
| A | segundo conteo | `3` |
| A | `COMMIT` | `COMMIT` |

Apareció una fila nueva que cumple el mismo `WHERE`. El pedido nuevo tiene fecha `now()` por defecto, así que la Regla C de la Parte 1 lo acepta.

**Explicación de la IA** (Kiro, modelo Auto; tal cual en [`escenario_2.md`](explicaciones_ia/escenario_2.md)). Identifica una lectura fantasma y propone REPEATABLE READ. Aclara que el estándar SQL no exige que ese nivel evite los fantasmas, pero que en PostgreSQL sí los evita. También menciona SERIALIZABLE y, como alternativa sin cambiar de nivel, `LOCK TABLE pedido IN SHARE MODE` al inicio de la transacción de A.

**Verificación en el motor.** Se probaron las tres propuestas. La de `LOCK TABLE` no estaba en el script `verificar`, así que se agregó [`scripts/verificar_lock_table.sh`](../scripts/verificar_lock_table.sh), que corre el mismo escenario con A en READ COMMITTED y el bloqueo de tabla.

| Sesión A | Primer conteo | Segundo conteo | Sesión B | Evidencia |
|---|---|---|---|---|
| REPEATABLE READ | 2 | 2 | `INSERT 0 1`, sin esperar | [`e2_verificacion_repeatable_read.txt`](../evidencias/e2_verificacion_repeatable_read.txt) |
| SERIALIZABLE | 2 | 2 | `INSERT 0 1`, sin esperar | [`e2_verificacion_serializable.txt`](../evidencias/e2_verificacion_serializable.txt) |
| READ COMMITTED + `LOCK TABLE pedido IN SHARE MODE` | 2 | 2 | `INSERT 0 1`, después de esperar 916 ms | [`e2_verificacion_lock_table.txt`](../evidencias/e2_verificacion_lock_table.txt) |

**Conclusión.** La explicación se confirmó en las tres propuestas. Hay una diferencia de costo que coincide con lo que dijo la IA: REPEATABLE READ y SERIALIZABLE evitan el fantasma sin hacer esperar a nadie, porque A sigue viendo su snapshot. `LOCK TABLE` lo evita haciendo esperar a B hasta que A confirma, y además bloquea cualquier INSERT, UPDATE o DELETE sobre toda la tabla `pedido` mientras dura la transacción. Para este caso, REPEATABLE READ es la mejor opción.

---

## Escenario 3 — Espera por bloqueo

**Escenario.** Las dos sesiones piden `FOR UPDATE` sobre la misma fila (la Coca 1.5L). La sesión A la toma, espera 2 s, descuenta una unidad de stock y confirma.

**Cómo se reprodujo.**

Sesión A ([`e3_A.sql`](../food-store/concurrencia/e3_A.sql)):

```sql
BEGIN;
SELECT id, stock FROM producto WHERE nombre = 'Coca 1.5L' FOR UPDATE;
SELECT pg_sleep(2);  -- mientras tanto, la sesión B pide la misma fila
UPDATE producto SET stock = stock - 1 WHERE nombre = 'Coca 1.5L';
COMMIT;
```

Sesión B ([`e3_B.sql`](../food-store/concurrencia/e3_B.sql), con `:modo` vacío):

```sql
BEGIN;
SELECT id, stock FROM producto WHERE nombre = 'Coca 1.5L' FOR UPDATE :modo;
SELECT round(extract(epoch FROM clock_timestamp() - now())::numeric, 2) AS segundos_desde_begin;
COMMIT;
```

**Qué se observó** ([`e3_espera_por_bloqueo.txt`](../evidencias/e3_espera_por_bloqueo.txt)):

| Sesión | Comando | Salida |
|:-:|---|---|
| A | `SELECT ... FOR UPDATE` | `id 9, stock 60` |
| B | `SELECT ... FOR UPDATE` | queda esperando |
| A | `UPDATE` y `COMMIT` | `UPDATE 1`, `COMMIT` |
| B | `SELECT ... FOR UPDATE` | `id 9, stock 59` |
| B | `segundos_desde_begin` | `1.38` |

La sesión B esperó a que A liberara la fila y después leyó el valor ya confirmado.

**Explicación de la IA** (Kiro, modelo Auto; tal cual en [`escenario_3.md`](explicaciones_ia/escenario_3.md)). Aclara que no es una anomalía sino el comportamiento buscado de `FOR UPDATE`. Para no esperar, propone `FOR UPDATE NOWAIT` o `FOR UPDATE SKIP LOCKED`. Además afirma que "el nivel de aislamiento no cambia esto" y que los bloqueos de fila "aplican en todos" los niveles.

**Verificación en el motor.**

| Variante | Resultado en la sesión B | Evidencia |
|---|---|---|
| `FOR UPDATE NOWAIT` | `ERROR: 55P03: no se pudo bloquear un "lock" en la fila`, a los 0,01 s | [`e3_verificacion_nowait.txt`](../evidencias/e3_verificacion_nowait.txt) |
| `FOR UPDATE SKIP LOCKED` | `(0 filas)`, a los 0,00 s | [`e3_verificacion_skip_locked.txt`](../evidencias/e3_verificacion_skip_locked.txt) |
| `lock_timeout = '1s'` (no lo propuso la IA) | `ERROR: 55P03: ... se agotó el tiempo de espera de "locks"`, a los 1,03 s | [`e3_verificacion_lock_timeout.txt`](../evidencias/e3_verificacion_lock_timeout.txt) |
| Las dos sesiones en SERIALIZABLE | Espera 1,40 s y después `ERROR: 40001: no se pudo serializar el acceso debido a un update concurrente` | [`e3_verificacion_serializable.txt`](../evidencias/e3_verificacion_serializable.txt) |

**Conclusión.** La explicación se confirmó en lo central: NOWAIT falla enseguida y SKIP LOCKED saltea la fila. Pero el motor **desmiente** que el nivel de aislamiento no cambie nada. En SERIALIZABLE, B también espera, pero cuando A confirma no lee el 59: falla con `40001`, porque la fila cambió después de que empezó su transacción. Según la documentación de PostgreSQL, en REPEATABLE READ pasa lo mismo, pero eso no se probó en este laboratorio. Es una diferencia importante: en READ COMMITTED, B sigue con el dato nuevo; en los niveles más altos, la aplicación tiene que reintentar la transacción. Si lo que se busca es no esperar, sirven NOWAIT, SKIP LOCKED o `lock_timeout`.

---

## Escenario 4 — Interbloqueo

**Escenario.** Las dos sesiones toman las mismas dos filas en orden cruzado. A toma la Napolitana y después pide la Fugazzeta; B toma la Fugazzeta y después pide la Napolitana.

**Cómo se reprodujo.**

Sesión A ([`e4_A.sql`](../food-store/concurrencia/e4_A.sql)):

```sql
BEGIN;
UPDATE producto SET stock = stock WHERE nombre = 'Napolitana';  -- bloquea la fila sin cambiar el valor
SELECT pg_sleep(1);
UPDATE producto SET stock = stock WHERE nombre = 'Fugazzeta';
SELECT round(extract(epoch FROM clock_timestamp() - now())::numeric, 2) AS segundos_desde_begin;
COMMIT;
```

Sesión B ([`e4_B.sql`](../food-store/concurrencia/e4_B.sql), con `:primero` = `Fugazzeta` y `:segundo` = `Napolitana`):

```sql
BEGIN;
UPDATE producto SET stock = stock WHERE nombre = :'primero';
SELECT pg_sleep(1);
UPDATE producto SET stock = stock WHERE nombre = :'segundo';
SELECT round(extract(epoch FROM clock_timestamp() - now())::numeric, 2) AS segundos_desde_begin;
COMMIT;
```

**Qué se observó** ([`e4_interbloqueo_orden_cruzado.txt`](../evidencias/e4_interbloqueo_orden_cruzado.txt)):

| Sesión | Comando | Salida |
|:-:|---|---|
| A | `UPDATE` Napolitana | `UPDATE 1` |
| B | `UPDATE` Fugazzeta | `UPDATE 1` |
| A | `UPDATE` Fugazzeta | `ERROR: 40P01: se ha detectado un deadlock`, con el detalle de los dos procesos que se esperan entre sí |
| A | `COMMIT` | `ROLLBACK`: la transacción ya estaba abortada |
| B | `UPDATE` Napolitana | `UPDATE 1` |
| B | `segundos_desde_begin` | `1.41` |
| B | `COMMIT` | `COMMIT` |

El motor detectó el ciclo, abortó a A y dejó terminar a B.

**Explicación de la IA** (Kiro, modelo Auto; tal cual en [`escenario_4.md`](explicaciones_ia/escenario_4.md)). Identifica el interbloqueo por orden cruzado. Dice que subir el nivel de aislamiento no lo evita y que la solución es que todas las transacciones tomen las filas en el mismo orden. Como alternativas, menciona tomar las dos filas con un solo `SELECT ... FOR UPDATE`, usar `LOCK TABLE` o reintentar ante el `40P01`.

**Verificación en el motor.**

| Variante | Resultado | Evidencia |
|---|---|---|
| Mismo orden en las dos sesiones (Napolitana → Fugazzeta) | Sin error: A termina en 1,01 s, B espera y termina en 1,41 s, y las dos confirman | [`e4_verificacion_mismo_orden.txt`](../evidencias/e4_verificacion_mismo_orden.txt) |
| Orden cruzado con las dos sesiones en SERIALIZABLE | Mismo `ERROR: 40P01` en A; B confirma | [`e4_verificacion_serializable.txt`](../evidencias/e4_verificacion_serializable.txt) |

**Conclusión.** La explicación se confirmó: el mismo orden de bloqueo evita el interbloqueo, y SERIALIZABLE no. Kiro cometió dos imprecisiones que no cambian la conclusión:

- Dice que el `UPDATE` toma un `RowExclusiveLock` "sobre la fila". Ese es un bloqueo de tabla, compatible con otros iguales. El conflicto lo produce el bloqueo de fila que también toma el `UPDATE`.
- Dice que un único `SELECT ... FOR UPDATE` con las dos filas las bloquea "en orden interno consistente". PostgreSQL no garantiza ese orden, porque depende de cómo recorra la tabla. Para asegurarlo, hay que ordenar la consulta, por ejemplo con `ORDER BY id`.

Estas dos alternativas no se verificaron en el motor.

---

## Conclusión general

| Problema | Lo resuelve | No lo resuelve |
|---|---|---|
| Lectura no repetible | REPEATABLE READ, SERIALIZABLE | — |
| Lectura fantasma | REPEATABLE READ (en PostgreSQL), SERIALIZABLE, `LOCK TABLE ... IN SHARE MODE` | — |
| Espera por bloqueo | NOWAIT, SKIP LOCKED, `lock_timeout` (evitan esperar) | Subir el nivel: se sigue esperando y además B falla con `40001` |
| Interbloqueo | Mismo orden de bloqueo | Subir el nivel: el `40P01` sigue apareciendo |

La IA acertó en el diagnóstico de los cuatro escenarios, pero no en todos los detalles: en el escenario 3 hizo una afirmación general que el motor desmintió, y en el 4 dio dos datos técnicos imprecisos. Ninguna de esas fallas se notaba leyendo la explicación; aparecieron al repetir el experimento.
