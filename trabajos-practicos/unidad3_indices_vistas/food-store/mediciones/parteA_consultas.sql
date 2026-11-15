-- Parte A · Las cuatro consultas de la carga de trabajo que se indexan (marcadas en queries.sql).
-- Cada una se ejecuta una vez para calentar la caché y después 3 veces con EXPLAIN (ANALYZE, BUFFERS).
-- El runner toma la mediana de las 3 y el plan de la última.

\echo '######## C1 · Facturación por día de la última semana (S3.1)'
SELECT COUNT(*) AS filas FROM (
SELECT DATE(p.fecha) AS dia, COUNT(DISTINCT p.id_pedido) AS pedidos, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
 WHERE p.fecha >= (CURRENT_DATE - 7)::timestamptz
 GROUP BY DATE(p.fecha)
 ORDER BY dia
) x;
EXPLAIN (ANALYZE, BUFFERS)
SELECT DATE(p.fecha) AS dia, COUNT(DISTINCT p.id_pedido) AS pedidos, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
 WHERE p.fecha >= (CURRENT_DATE - 7)::timestamptz
 GROUP BY DATE(p.fecha)
 ORDER BY dia;
EXPLAIN (ANALYZE, BUFFERS)
SELECT DATE(p.fecha) AS dia, COUNT(DISTINCT p.id_pedido) AS pedidos, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
 WHERE p.fecha >= (CURRENT_DATE - 7)::timestamptz
 GROUP BY DATE(p.fecha)
 ORDER BY dia;
EXPLAIN (ANALYZE, BUFFERS)
SELECT DATE(p.fecha) AS dia, COUNT(DISTINCT p.id_pedido) AS pedidos, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
 WHERE p.fecha >= (CURRENT_DATE - 7)::timestamptz
 GROUP BY DATE(p.fecha)
 ORDER BY dia;

\echo '######## C2 · Los 10 clientes que más gastaron en los últimos 30 días (S3.2)'
SELECT COUNT(*) AS filas FROM (
SELECT c.id_cliente, c.nombre, c.apellido, SUM(d.cantidad * d.precio_unitario) AS gastado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
  JOIN cliente c ON c.id_cliente = p.id_cliente
 WHERE p.fecha >= now() - INTERVAL '30 days'
 GROUP BY c.id_cliente, c.nombre, c.apellido
 ORDER BY gastado DESC
 LIMIT 10
) x;
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.id_cliente, c.nombre, c.apellido, SUM(d.cantidad * d.precio_unitario) AS gastado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
  JOIN cliente c ON c.id_cliente = p.id_cliente
 WHERE p.fecha >= now() - INTERVAL '30 days'
 GROUP BY c.id_cliente, c.nombre, c.apellido
 ORDER BY gastado DESC
 LIMIT 10;
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.id_cliente, c.nombre, c.apellido, SUM(d.cantidad * d.precio_unitario) AS gastado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
  JOIN cliente c ON c.id_cliente = p.id_cliente
 WHERE p.fecha >= now() - INTERVAL '30 days'
 GROUP BY c.id_cliente, c.nombre, c.apellido
 ORDER BY gastado DESC
 LIMIT 10;
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.id_cliente, c.nombre, c.apellido, SUM(d.cantidad * d.precio_unitario) AS gastado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
  JOIN cliente c ON c.id_cliente = p.id_cliente
 WHERE p.fecha >= now() - INTERVAL '30 days'
 GROUP BY c.id_cliente, c.nombre, c.apellido
 ORDER BY gastado DESC
 LIMIT 10;

\echo '######## C3 · Los 10 productos que más facturaron en los últimos 30 días (S4.3)'
SELECT COUNT(*) AS filas FROM (
SELECT pr.id_producto, pr.nombre AS producto, c.nombre AS categoria,
       SUM(d.cantidad) AS unidades, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM detalle_pedido d
  JOIN pedido p ON p.id_pedido = d.id_pedido
  JOIN producto pr ON pr.id_producto = d.id_producto
  JOIN categoria c ON c.id_categoria = pr.id_categoria
 WHERE p.fecha >= now() - INTERVAL '30 days'
 GROUP BY pr.id_producto, pr.nombre, c.nombre
 ORDER BY facturado DESC, pr.id_producto
 LIMIT 10
) x;
EXPLAIN (ANALYZE, BUFFERS)
SELECT pr.id_producto, pr.nombre AS producto, c.nombre AS categoria,
       SUM(d.cantidad) AS unidades, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM detalle_pedido d
  JOIN pedido p ON p.id_pedido = d.id_pedido
  JOIN producto pr ON pr.id_producto = d.id_producto
  JOIN categoria c ON c.id_categoria = pr.id_categoria
 WHERE p.fecha >= now() - INTERVAL '30 days'
 GROUP BY pr.id_producto, pr.nombre, c.nombre
 ORDER BY facturado DESC, pr.id_producto
 LIMIT 10;
EXPLAIN (ANALYZE, BUFFERS)
SELECT pr.id_producto, pr.nombre AS producto, c.nombre AS categoria,
       SUM(d.cantidad) AS unidades, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM detalle_pedido d
  JOIN pedido p ON p.id_pedido = d.id_pedido
  JOIN producto pr ON pr.id_producto = d.id_producto
  JOIN categoria c ON c.id_categoria = pr.id_categoria
 WHERE p.fecha >= now() - INTERVAL '30 days'
 GROUP BY pr.id_producto, pr.nombre, c.nombre
 ORDER BY facturado DESC, pr.id_producto
 LIMIT 10;
EXPLAIN (ANALYZE, BUFFERS)
SELECT pr.id_producto, pr.nombre AS producto, c.nombre AS categoria,
       SUM(d.cantidad) AS unidades, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM detalle_pedido d
  JOIN pedido p ON p.id_pedido = d.id_pedido
  JOIN producto pr ON pr.id_producto = d.id_producto
  JOIN categoria c ON c.id_categoria = pr.id_categoria
 WHERE p.fecha >= now() - INTERVAL '30 days'
 GROUP BY pr.id_producto, pr.nombre, c.nombre
 ORDER BY facturado DESC, pr.id_producto
 LIMIT 10;

\echo '######## C4 · Productos vigentes nunca vendidos (7.3)'
SELECT COUNT(*) AS filas FROM (
SELECT id_producto, nombre, precio, stock
FROM producto
WHERE activo = TRUE
  AND NOT EXISTS (SELECT 1 FROM detalle_pedido WHERE id_producto = producto.id_producto)
ORDER BY nombre
) x;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre, precio, stock
FROM producto
WHERE activo = TRUE
  AND NOT EXISTS (SELECT 1 FROM detalle_pedido WHERE id_producto = producto.id_producto)
ORDER BY nombre;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre, precio, stock
FROM producto
WHERE activo = TRUE
  AND NOT EXISTS (SELECT 1 FROM detalle_pedido WHERE id_producto = producto.id_producto)
ORDER BY nombre;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre, precio, stock
FROM producto
WHERE activo = TRUE
  AND NOT EXISTS (SELECT 1 FROM detalle_pedido WHERE id_producto = producto.id_producto)
ORDER BY nombre;
