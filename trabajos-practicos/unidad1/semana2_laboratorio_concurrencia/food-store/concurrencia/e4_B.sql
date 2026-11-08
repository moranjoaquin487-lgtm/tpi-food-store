-- Escenario 4 · Sesión B: toma una fila y, un segundo después, pide la otra (el orden lo decide el laboratorio).
\set VERBOSITY verbose
\set SHOW_CONTEXT never
BEGIN;
UPDATE producto SET stock = stock WHERE nombre = :'primero';
SELECT pg_sleep(1);
UPDATE producto SET stock = stock WHERE nombre = :'segundo';
SELECT round(extract(epoch FROM clock_timestamp() - now())::numeric, 2) AS segundos_desde_begin;
COMMIT;
