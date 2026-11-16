-- Parte C · Vista materializada: tiempo del reporte en el momento frente a la vista materializada,
-- equivalencia, costo del REFRESH y qué implica que el dato no se actualice hasta el próximo REFRESH.
-- El reporte es la consulta 7.4 de queries.sql con id_categoria agregado, igual que la vista materializada.
\echo '######## C5 · Facturación por categoría y mes calculada en el momento (7.4)'
SELECT COUNT(*) AS filas FROM (
SELECT c.id_categoria,
       c.nombre AS categoria,
       DATE_TRUNC('month', pe.fecha) AS mes,
       COUNT(DISTINCT pe.id_pedido) AS cantidad_pedidos,
       SUM(dp.cantidad * dp.precio_unitario) AS facturacion_total
FROM categoria c
JOIN producto p        ON p.id_categoria = c.id_categoria
JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
JOIN pedido pe         ON pe.id_pedido = dp.id_pedido
WHERE c.activo = TRUE AND p.activo = TRUE
GROUP BY c.id_categoria, c.nombre, DATE_TRUNC('month', pe.fecha)
ORDER BY mes, facturacion_total DESC
) x;
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.id_categoria,
       c.nombre AS categoria,
       DATE_TRUNC('month', pe.fecha) AS mes,
       COUNT(DISTINCT pe.id_pedido) AS cantidad_pedidos,
       SUM(dp.cantidad * dp.precio_unitario) AS facturacion_total
FROM categoria c
JOIN producto p        ON p.id_categoria = c.id_categoria
JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
JOIN pedido pe         ON pe.id_pedido = dp.id_pedido
WHERE c.activo = TRUE AND p.activo = TRUE
GROUP BY c.id_categoria, c.nombre, DATE_TRUNC('month', pe.fecha)
ORDER BY mes, facturacion_total DESC;
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.id_categoria,
       c.nombre AS categoria,
       DATE_TRUNC('month', pe.fecha) AS mes,
       COUNT(DISTINCT pe.id_pedido) AS cantidad_pedidos,
       SUM(dp.cantidad * dp.precio_unitario) AS facturacion_total
FROM categoria c
JOIN producto p        ON p.id_categoria = c.id_categoria
JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
JOIN pedido pe         ON pe.id_pedido = dp.id_pedido
WHERE c.activo = TRUE AND p.activo = TRUE
GROUP BY c.id_categoria, c.nombre, DATE_TRUNC('month', pe.fecha)
ORDER BY mes, facturacion_total DESC;
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.id_categoria,
       c.nombre AS categoria,
       DATE_TRUNC('month', pe.fecha) AS mes,
       COUNT(DISTINCT pe.id_pedido) AS cantidad_pedidos,
       SUM(dp.cantidad * dp.precio_unitario) AS facturacion_total
FROM categoria c
JOIN producto p        ON p.id_categoria = c.id_categoria
JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
JOIN pedido pe         ON pe.id_pedido = dp.id_pedido
WHERE c.activo = TRUE AND p.activo = TRUE
GROUP BY c.id_categoria, c.nombre, DATE_TRUNC('month', pe.fecha)
ORDER BY mes, facturacion_total DESC;

\echo '######## C6 · El mismo reporte desde mv_facturacion_categoria_mes'
SELECT COUNT(*) AS filas FROM (
SELECT id_categoria, categoria, mes, cantidad_pedidos, facturacion_total
FROM mv_facturacion_categoria_mes
ORDER BY mes, facturacion_total DESC
) x;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_categoria, categoria, mes, cantidad_pedidos, facturacion_total
FROM mv_facturacion_categoria_mes
ORDER BY mes, facturacion_total DESC;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_categoria, categoria, mes, cantidad_pedidos, facturacion_total
FROM mv_facturacion_categoria_mes
ORDER BY mes, facturacion_total DESC;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_categoria, categoria, mes, cantidad_pedidos, facturacion_total
FROM mv_facturacion_categoria_mes
ORDER BY mes, facturacion_total DESC;

\echo '######## Equivalencia de la vista materializada con la consulta en el momento (se espera 0 y 0)'
SELECT (SELECT count(*) FROM mv_facturacion_categoria_mes) AS filas_vista_materializada,
       (SELECT count(*) FROM (
SELECT c.id_categoria,
       c.nombre AS categoria,
       DATE_TRUNC('month', pe.fecha) AS mes,
       COUNT(DISTINCT pe.id_pedido) AS cantidad_pedidos,
       SUM(dp.cantidad * dp.precio_unitario) AS facturacion_total
FROM categoria c
JOIN producto p        ON p.id_categoria = c.id_categoria
JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
JOIN pedido pe         ON pe.id_pedido = dp.id_pedido
WHERE c.activo = TRUE AND p.activo = TRUE
GROUP BY c.id_categoria, c.nombre, DATE_TRUNC('month', pe.fecha)
       ) o) AS filas_consulta,
       (SELECT count(*) FROM (
SELECT id_categoria, categoria, mes, cantidad_pedidos, facturacion_total
FROM mv_facturacion_categoria_mes
EXCEPT
SELECT c.id_categoria,
       c.nombre AS categoria,
       DATE_TRUNC('month', pe.fecha) AS mes,
       COUNT(DISTINCT pe.id_pedido) AS cantidad_pedidos,
       SUM(dp.cantidad * dp.precio_unitario) AS facturacion_total
FROM categoria c
JOIN producto p        ON p.id_categoria = c.id_categoria
JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
JOIN pedido pe         ON pe.id_pedido = dp.id_pedido
WHERE c.activo = TRUE AND p.activo = TRUE
GROUP BY c.id_categoria, c.nombre, DATE_TRUNC('month', pe.fecha)
       ) a) AS vista_menos_consulta,
       (SELECT count(*) FROM (
SELECT c.id_categoria,
       c.nombre AS categoria,
       DATE_TRUNC('month', pe.fecha) AS mes,
       COUNT(DISTINCT pe.id_pedido) AS cantidad_pedidos,
       SUM(dp.cantidad * dp.precio_unitario) AS facturacion_total
FROM categoria c
JOIN producto p        ON p.id_categoria = c.id_categoria
JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
JOIN pedido pe         ON pe.id_pedido = dp.id_pedido
WHERE c.activo = TRUE AND p.activo = TRUE
GROUP BY c.id_categoria, c.nombre, DATE_TRUNC('month', pe.fecha)
EXCEPT
SELECT id_categoria, categoria, mes, cantidad_pedidos, facturacion_total
FROM mv_facturacion_categoria_mes
       ) b) AS consulta_menos_vista;

\echo '######## Costo del REFRESH (ms)'
SELECT clock_timestamp() AS t0 \gset
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;
SELECT round((extract(epoch FROM clock_timestamp() - :'t0'::timestamptz) * 1000)::NUMERIC, 1) AS refresh_concurrently_ms;
SELECT clock_timestamp() AS t0 \gset
REFRESH MATERIALIZED VIEW mv_facturacion_categoria_mes;
SELECT round((extract(epoch FROM clock_timestamp() - :'t0'::timestamptz) * 1000)::NUMERIC, 1) AS refresh_comun_ms;

\echo '######## Entre dos REFRESH: una venta nueva del mes no aparece en la vista materializada'
-- Dentro de una transacción que se deshace: un pedido nuevo con una línea de 10 x 1000.
BEGIN;
INSERT INTO pedido (fecha, forma_pago, id_cliente)
VALUES (now(), 'EFECTIVO', (SELECT MIN(id_cliente) FROM cliente))
RETURNING id_pedido AS pedido_nuevo \gset
INSERT INTO detalle_pedido (cantidad, precio_unitario, id_pedido, id_producto)
SELECT 10, 1000, :pedido_nuevo, MIN(p.id_producto)
  FROM producto p JOIN categoria c ON c.id_categoria = p.id_categoria AND c.activo = TRUE
 WHERE p.activo = TRUE;
SELECT 'vista materializada' AS origen, SUM(facturacion_total) AS facturado_mes_actual
  FROM mv_facturacion_categoria_mes WHERE mes = DATE_TRUNC('month', now())
UNION ALL
SELECT 'consulta en el momento', SUM(dp.cantidad * dp.precio_unitario)
  FROM categoria c
  JOIN producto p        ON p.id_categoria = c.id_categoria
  JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
  JOIN pedido pe         ON pe.id_pedido = dp.id_pedido
 WHERE c.activo = TRUE AND p.activo = TRUE AND DATE_TRUNC('month', pe.fecha) = DATE_TRUNC('month', now());
ROLLBACK;
