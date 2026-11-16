-- Parte A · Diagnóstico de C1 después de la medición final, con indices.sql aplicado.
-- En la prueba de la ronda 2 el planner eligió Nested Loop con los dos índices; en la medición final, con
-- las mismas consultas e índices, eligió Hash Join con Seq Scan de detalle_pedido. Este script muestra
-- por qué: los costos estimados de los dos planes, con la misma estadística, y qué pasa con
-- random_page_cost = 1.1 (el valor para SSD que se midió en la Semana 3). Todo es solo de la sesión.
\echo '######## Plan que elige el planner con la configuración por defecto (solo costos)'
EXPLAIN
SELECT DATE(p.fecha) AS dia, COUNT(DISTINCT p.id_pedido) AS pedidos, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
 WHERE p.fecha >= (CURRENT_DATE - 7)::timestamptz
 GROUP BY DATE(p.fecha)
 ORDER BY dia;
\echo '######## Plan Nested Loop forzado, solo para ver su costo estimado (enable_hashjoin y enable_mergejoin en off)'
SET enable_hashjoin = off;
SET enable_mergejoin = off;
EXPLAIN
SELECT DATE(p.fecha) AS dia, COUNT(DISTINCT p.id_pedido) AS pedidos, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
 WHERE p.fecha >= (CURRENT_DATE - 7)::timestamptz
 GROUP BY DATE(p.fecha)
 ORDER BY dia;
RESET enable_hashjoin;
RESET enable_mergejoin;
SHOW random_page_cost;
\echo '######## C1d · C1 con la configuración por defecto (random_page_cost = 4)'
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
SET random_page_cost = 1.1;
SHOW random_page_cost;
\echo '######## C1r · C1 con random_page_cost = 1.1, solo en la sesión'
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
RESET random_page_cost;
