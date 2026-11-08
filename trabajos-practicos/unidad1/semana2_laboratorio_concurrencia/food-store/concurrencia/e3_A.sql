-- Escenario 3 · Sesión A: bloquea la fila de la Coca 1.5L y la mantiene tomada 2 segundos.
\set VERBOSITY verbose
\set SHOW_CONTEXT never
BEGIN;
SELECT id, stock FROM producto WHERE nombre = 'Coca 1.5L' FOR UPDATE;
SELECT pg_sleep(2);  -- mientras tanto, la sesión B pide la misma fila
UPDATE producto SET stock = stock - 1 WHERE nombre = 'Coca 1.5L';
COMMIT;
