-- Escenario 2 · Sesión A: cuenta dos veces los pedidos de Ana Gómez dentro de la misma transacción.
BEGIN;
SET TRANSACTION ISOLATION LEVEL :nivel;
SHOW transaction_isolation;
SELECT COUNT(*) AS primer_conteo FROM pedido p JOIN cliente c ON c.id = p.cliente_id WHERE c.email = 'ana.gomez@mail.com';
SELECT pg_sleep(1.5);  -- mientras tanto, la sesión B registra un pedido nuevo de Ana
SELECT COUNT(*) AS segundo_conteo FROM pedido p JOIN cliente c ON c.id = p.cliente_id WHERE c.email = 'ana.gomez@mail.com';
COMMIT;
