Hice este experimento en PostgreSQL 18 con dos sesiones concurrentes sobre mi base Food Store.
La sesión B arrancó medio segundo después que la A. Abajo están los comandos exactos de cada sesión y lo que devolvió cada uno.

Explicame qué pasó y qué nivel de aislamiento o qué mecanismo de bloqueo evitaría este comportamiento.
Respondé solo con la explicación: no crees ni modifiques archivos.

```
----- SESIÓN A -----
\set modo ''
\set ON_ERROR_ROLLBACK on
\i food-store/concurrencia/e3_A.sql
-- Escenario 3 · Sesión A: bloquea la fila de la Coca 1.5L y la mantiene tomada 2 segundos.
\set VERBOSITY verbose
\set SHOW_CONTEXT never
BEGIN;
BEGIN
SELECT id, stock FROM producto WHERE nombre = 'Coca 1.5L' FOR UPDATE;
 id | stock 
----+-------
  9 |    60
(1 fila)

SELECT pg_sleep(2);  -- mientras tanto, la sesión B pide la misma fila
 pg_sleep 
----------
 
(1 fila)

UPDATE producto SET stock = stock - 1 WHERE nombre = 'Coca 1.5L';
UPDATE 1
COMMIT;
COMMIT

----- SESIÓN B (arranca 0,5 s después) -----
\set modo ''
\set ON_ERROR_ROLLBACK on
\i food-store/concurrencia/e3_B.sql
-- Escenario 3 · Sesión B: pide la misma fila con FOR UPDATE y mide cuánto tardó en obtenerla.
\set VERBOSITY verbose
\set SHOW_CONTEXT never
BEGIN;
BEGIN
SELECT id, stock FROM producto WHERE nombre = 'Coca 1.5L' FOR UPDATE :modo;
 id | stock 
----+-------
  9 |    59
(1 fila)

SELECT round(extract(epoch FROM clock_timestamp() - now())::numeric, 2) AS segundos_desde_begin;
 segundos_desde_begin 
----------------------
                 1.38
(1 fila)

COMMIT;
COMMIT
```
