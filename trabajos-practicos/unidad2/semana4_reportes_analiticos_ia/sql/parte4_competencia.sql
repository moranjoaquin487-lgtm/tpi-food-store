-- Parte 4 · Consulta de la competencia: los 10 productos que más facturaron en los últimos 30 días,
-- con su categoría (tres JOIN y una agregación). Se mide igual antes y después.

SELECT COUNT(*) AS filas FROM (
SELECT pr.id_producto, pr.nombre AS producto, c.nombre AS categoria,
       SUM(d.cantidad) AS unidades, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM detalle_pedido d
  JOIN pedido p     ON p.id_pedido     = d.id_pedido
  JOIN producto pr  ON pr.id_producto  = d.id_producto
  JOIN categoria c  ON c.id_categoria  = pr.id_categoria
 WHERE p.fecha >= now() - INTERVAL '30 days'
 GROUP BY pr.id_producto, pr.nombre, c.nombre
 ORDER BY facturado DESC, pr.id_producto
 LIMIT 10
) x;
EXPLAIN (ANALYZE, BUFFERS)
SELECT pr.id_producto, pr.nombre AS producto, c.nombre AS categoria,
       SUM(d.cantidad) AS unidades, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM detalle_pedido d
  JOIN pedido p     ON p.id_pedido     = d.id_pedido
  JOIN producto pr  ON pr.id_producto  = d.id_producto
  JOIN categoria c  ON c.id_categoria  = pr.id_categoria
 WHERE p.fecha >= now() - INTERVAL '30 days'
 GROUP BY pr.id_producto, pr.nombre, c.nombre
 ORDER BY facturado DESC, pr.id_producto
 LIMIT 10;
