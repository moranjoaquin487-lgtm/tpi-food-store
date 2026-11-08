Hice este experimento en PostgreSQL 18 con dos sesiones concurrentes sobre mi base Food Store.
La sesión B arrancó medio segundo después que la A. Abajo están los comandos exactos de cada sesión y lo que devolvió cada uno.

Explicame qué pasó y qué nivel de aislamiento o qué mecanismo de bloqueo evitaría este comportamiento.
Respondé solo con la explicación: no crees ni modifiques archivos.

```
----- SESIÓN A -----
\set nivel 'READ COMMITTED'
\i food-store/concurrencia/e1_A.sql
-- Escenario 1 · Sesión A: lee dos veces el precio de la Muzzarella dentro de la misma transacción.
BEGIN;
BEGIN
SET TRANSACTION ISOLATION LEVEL :nivel;
SET
SHOW transaction_isolation;
 transaction_isolation 
-----------------------
 read committed
(1 fila)

SELECT precio AS primera_lectura FROM producto WHERE nombre = 'Muzzarella';
 primera_lectura 
-----------------
         1050.00
(1 fila)

SELECT pg_sleep(1.5);  -- mientras tanto, la sesión B cambia el precio y confirma
 pg_sleep 
----------
 
(1 fila)

SELECT precio AS segunda_lectura FROM producto WHERE nombre = 'Muzzarella';
 segunda_lectura 
-----------------
         1150.00
(1 fila)

COMMIT;
COMMIT

----- SESIÓN B (arranca 0,5 s después) -----
\set nivel 'READ COMMITTED'
\i food-store/concurrencia/e1_B.sql
-- Escenario 1 · Sesión B: sube el precio de la Muzzarella; sin BEGIN, se confirma solo.
UPDATE producto SET precio = precio + 100 WHERE nombre = 'Muzzarella';
UPDATE 1
```
