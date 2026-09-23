-- 11 — Optimización medida: antes y después
-- Cada "antes" corre dentro de BEGIN ... ROLLBACK: se borra el índice solo para medir y vuelve solo.

-- C1: productos vigentes de una categoría (filtro poco selectivo: ~20 % de la tabla)
BEGIN;
DROP INDEX idx_producto_categoria_activo;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre, precio, stock
FROM producto
WHERE id_categoria = 1 AND activo = TRUE
ORDER BY precio;
ROLLBACK;

EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre, precio, stock
FROM producto
WHERE id_categoria = 1 AND activo = TRUE
ORDER BY precio;

-- C2: historial de pedidos de un cliente (filtro muy selectivo)
BEGIN;
DROP INDEX idx_pedido_id_cliente;
EXPLAIN (ANALYZE, BUFFERS)
SELECT p.id_pedido, p.fecha, p.forma_pago, c.nombre, c.apellido
FROM pedido p
JOIN cliente c ON c.id_cliente = p.id_cliente
WHERE p.id_cliente = 10
ORDER BY p.fecha DESC;
ROLLBACK;

EXPLAIN (ANALYZE, BUFFERS)
SELECT p.id_pedido, p.fecha, p.forma_pago, c.nombre, c.apellido
FROM pedido p
JOIN cliente c ON c.id_cliente = p.id_cliente
WHERE p.id_cliente = 10
ORDER BY p.fecha DESC;

-- C3: pedidos en los que se vendió un producto (filtro muy selectivo)
BEGIN;
DROP INDEX idx_detalle_pedido_id_producto;
EXPLAIN (ANALYZE, BUFFERS)
SELECT dp.id_detalle, dp.cantidad, dp.precio_unitario, pe.fecha
FROM detalle_pedido dp
JOIN pedido pe ON pe.id_pedido = dp.id_pedido
WHERE dp.id_producto = 25000
ORDER BY pe.fecha;
ROLLBACK;

EXPLAIN (ANALYZE, BUFFERS)
SELECT dp.id_detalle, dp.cantidad, dp.precio_unitario, pe.fecha
FROM detalle_pedido dp
JOIN pedido pe ON pe.id_pedido = dp.id_pedido
WHERE dp.id_producto = 25000
ORDER BY pe.fecha;

-- C4: facturación por categoría y mes, calculada en el momento vs. vista materializada
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.id_categoria, c.nombre AS categoria,
       DATE_TRUNC('month', pe.fecha) AS mes,
       COUNT(DISTINCT pe.id_pedido) AS cantidad_pedidos,
       SUM(dp.cantidad * dp.precio_unitario) AS facturacion_total
FROM categoria c
JOIN producto p        ON p.id_categoria = c.id_categoria
JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
JOIN pedido pe         ON pe.id_pedido = dp.id_pedido
WHERE c.activo = TRUE AND p.activo = TRUE
GROUP BY c.id_categoria, c.nombre, DATE_TRUNC('month', pe.fecha);

EXPLAIN (ANALYZE, BUFFERS)
SELECT id_categoria, categoria, mes, cantidad_pedidos, facturacion_total
FROM mv_facturacion_cat_mes;

-- C5: costo de sobreindexar — 20.000 INSERT en pedido sin y con un índice extra
-- (id_cliente, fecha) repite la columna que ya indexa idx_pedido_id_cliente.
BEGIN;  -- calentamiento, no se mide
INSERT INTO pedido (fecha, forma_pago, id_cliente)
SELECT now(), 'EFECTIVO', 10 + (g % 1000) FROM generate_series(1, 20000) AS g;
ROLLBACK;

BEGIN;
EXPLAIN (ANALYZE)
INSERT INTO pedido (fecha, forma_pago, id_cliente)
SELECT now(), 'EFECTIVO', 10 + (g % 1000)
FROM generate_series(1, 20000) AS g;
ROLLBACK;

BEGIN;
CREATE INDEX idx_pedido_cliente_fecha ON pedido (id_cliente, fecha);
EXPLAIN (ANALYZE)
INSERT INTO pedido (fecha, forma_pago, id_cliente)
SELECT now(), 'EFECTIVO', 10 + (g % 1000)
FROM generate_series(1, 20000) AS g;
ROLLBACK;
