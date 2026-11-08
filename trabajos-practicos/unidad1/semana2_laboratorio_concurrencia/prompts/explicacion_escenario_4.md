Hice este experimento en PostgreSQL 18 con dos sesiones concurrentes sobre mi base Food Store.
La sesión B arrancó medio segundo después que la A. Abajo están los comandos exactos de cada sesión y lo que devolvió cada uno.

Explicame qué pasó y qué nivel de aislamiento o qué mecanismo de bloqueo evitaría este comportamiento.
Respondé solo con la explicación: no crees ni modifiques archivos.

```
----- SESIÓN A -----
\set primero 'Fugazzeta'
\set segundo 'Napolitana'
\i food-store/concurrencia/e4_A.sql
-- Escenario 4 · Sesión A: toma la Napolitana y, un segundo después, pide la Fugazzeta.
\set VERBOSITY verbose
\set SHOW_CONTEXT never
BEGIN;
BEGIN
UPDATE producto SET stock = stock WHERE nombre = 'Napolitana';  -- bloquea la fila sin cambiar el valor
UPDATE 1
SELECT pg_sleep(1);
 pg_sleep 
----------
 
(1 fila)

UPDATE producto SET stock = stock WHERE nombre = 'Fugazzeta';
psql:food-store/concurrencia/e4_A.sql:7: ERROR:  40P01: se ha detectado un deadlock
DETALLE:  El proceso 21004 espera ShareLock en transacción 819; bloqueado por proceso 29864.
El proceso 29864 espera ShareLock en transacción 818; bloqueado por proceso 21004.
SUGERENCIA:  Vea el registro del servidor para obtener detalles de las consultas.
SELECT round(extract(epoch FROM clock_timestamp() - now())::numeric, 2) AS segundos_desde_begin;
psql:food-store/concurrencia/e4_A.sql:8: ERROR:  25P02: transacción abortada, las órdenes serán ignoradas hasta el fin de bloque de transacción
COMMIT;
ROLLBACK

----- SESIÓN B (arranca 0,5 s después) -----
\set primero 'Fugazzeta'
\set segundo 'Napolitana'
\i food-store/concurrencia/e4_B.sql
-- Escenario 4 · Sesión B: toma una fila y, un segundo después, pide la otra (el orden lo decide el laboratorio).
\set VERBOSITY verbose
\set SHOW_CONTEXT never
BEGIN;
BEGIN
UPDATE producto SET stock = stock WHERE nombre = :'primero';
UPDATE 1
SELECT pg_sleep(1);
 pg_sleep 
----------
 
(1 fila)

UPDATE producto SET stock = stock WHERE nombre = :'segundo';
UPDATE 1
SELECT round(extract(epoch FROM clock_timestamp() - now())::numeric, 2) AS segundos_desde_begin;
 segundos_desde_begin 
----------------------
                 1.41
(1 fila)

COMMIT;
COMMIT
```
