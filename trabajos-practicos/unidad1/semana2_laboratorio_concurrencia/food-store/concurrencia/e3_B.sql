-- Escenario 3 · Sesión B: pide la misma fila con FOR UPDATE y mide cuánto tardó en obtenerla.
\set VERBOSITY verbose
\set SHOW_CONTEXT never
BEGIN;
SELECT id, stock FROM producto WHERE nombre = 'Coca 1.5L' FOR UPDATE :modo;
SELECT round(extract(epoch FROM clock_timestamp() - now())::numeric, 2) AS segundos_desde_begin;
COMMIT;
