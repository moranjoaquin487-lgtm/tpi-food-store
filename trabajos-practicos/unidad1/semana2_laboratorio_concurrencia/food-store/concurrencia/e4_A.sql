-- Escenario 4 · Sesión A: toma la Napolitana y, un segundo después, pide la Fugazzeta.
\set VERBOSITY verbose
\set SHOW_CONTEXT never
BEGIN;
UPDATE producto SET stock = stock WHERE nombre = 'Napolitana';  -- bloquea la fila sin cambiar el valor
SELECT pg_sleep(1);
UPDATE producto SET stock = stock WHERE nombre = 'Fugazzeta';
SELECT round(extract(epoch FROM clock_timestamp() - now())::numeric, 2) AS segundos_desde_begin;
COMMIT;
