-- 08 — Transacciones

-- 8.1 ATOMICIDAD con el procedimiento sp_registrar_pedido
SELECT COUNT(*) AS pedidos_antes FROM pedido;
SELECT id_producto, stock FROM producto WHERE id_producto IN (20, 21) ORDER BY 1;

-- (a) Caso válido: dos ítems con stock suficiente -> se registra todo
CALL sp_registrar_pedido(10, 'TARJETA',
     '[{"id_producto": 20, "cantidad": 2}, {"id_producto": 21, "cantidad": 1}]');

SELECT COUNT(*) AS pedidos_despues_caso_valido FROM pedido;
SELECT id_producto, stock FROM producto WHERE id_producto IN (20, 21) ORDER BY 1;

-- (b) Caso inválido: el 1.er ítem es válido, el 2.º pide más stock del que hay.
CALL sp_registrar_pedido(10, 'EFECTIVO',
     '[{"id_producto": 20, "cantidad": 1}, {"id_producto": 21, "cantidad": 9999}]');

SELECT COUNT(*) AS pedidos_despues_caso_invalido FROM pedido;
SELECT id_producto, stock FROM producto WHERE id_producto IN (20, 21) ORDER BY 1;

-- 8.2 COMMIT y ROLLBACK explícitos
BEGIN;
UPDATE producto SET precio = precio * 1.10 WHERE id_producto = 22;
SELECT id_producto, precio AS precio_dentro_de_la_tx FROM producto WHERE id_producto = 22;
ROLLBACK;
SELECT id_producto, precio AS precio_tras_rollback FROM producto WHERE id_producto = 22;

BEGIN;
UPDATE producto SET stock = stock + 10 WHERE id_producto = 22;
COMMIT;
SELECT id_producto, stock AS stock_tras_commit FROM producto WHERE id_producto = 22;

-- 8.3 SAVEPOINT: deshacer solo una parte de la transacción
SELECT id_producto, stock, precio FROM producto WHERE id_producto = 23;

BEGIN;
UPDATE producto SET stock = stock - 1 WHERE id_producto = 23;
SAVEPOINT antes_del_precio;
UPDATE producto SET precio = -5 WHERE id_producto = 23;
ROLLBACK TO SAVEPOINT antes_del_precio;
COMMIT;
SELECT id_producto, stock, precio FROM producto WHERE id_producto = 23;

-- 8.4 Niveles de aislamiento (una sesión)
SHOW default_transaction_isolation;

-- REPEATABLE READ: la transacción ve siempre la foto de su primera consulta
BEGIN ISOLATION LEVEL REPEATABLE READ;
SHOW transaction_isolation;
SELECT COUNT(*) AS pedidos_en_la_foto FROM pedido;
-- (acá, en otra sesión, se confirma un INSERT en pedido: este COUNT no cambia)
SELECT COUNT(*) AS pedidos_en_la_foto_otra_vez FROM pedido;
COMMIT;

-- SERIALIZABLE: ante un conflicto, una transacción se aborta con SQLSTATE 40001
BEGIN ISOLATION LEVEL SERIALIZABLE;
SHOW transaction_isolation;
COMMIT;
