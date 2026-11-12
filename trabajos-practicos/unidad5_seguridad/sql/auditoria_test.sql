-- U5 · Parte B — Secuencia de prueba para la auditoría
-- Se ejecuta conectado como app_web (lo hace scripts/correr_auditoria_test.sh).
-- El intento de inicio de sesión fallido lo provoca el script de shell, porque ocurre
-- antes de que exista una sesión.

\echo '-- 1. Lectura: catálogo vigente'
SELECT id_producto, nombre, precio FROM vista_productos_vigentes ORDER BY id_producto LIMIT 3;

\echo '-- 2. Inserción: un pedido de prueba con una línea'
INSERT INTO pedido (forma_pago, id_cliente) VALUES ('EFECTIVO', 1) RETURNING id_pedido AS pedido_prueba \gset
INSERT INTO detalle_pedido (cantidad, precio_unitario, id_pedido, id_producto)
SELECT 1, precio, :pedido_prueba, id_producto FROM producto WHERE nombre = 'Agua mineral 2L';

\echo '-- 3. Actualización: se descuenta el stock vendido'
UPDATE producto SET stock = stock - 1 WHERE nombre = 'Agua mineral 2L';

SELECT current_user AS conectado_como, :pedido_prueba AS pedido_creado;
