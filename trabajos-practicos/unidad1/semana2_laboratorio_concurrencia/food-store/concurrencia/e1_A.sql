-- Escenario 1 · Sesión A: lee dos veces el precio de la Muzzarella dentro de la misma transacción.
BEGIN;
SET TRANSACTION ISOLATION LEVEL :nivel;
SHOW transaction_isolation;
SELECT precio AS primera_lectura FROM producto WHERE nombre = 'Muzzarella';
SELECT pg_sleep(1.5);  -- mientras tanto, la sesión B cambia el precio y confirma
SELECT precio AS segunda_lectura FROM producto WHERE nombre = 'Muzzarella';
COMMIT;
