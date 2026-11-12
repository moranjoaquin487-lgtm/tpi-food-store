-- U7 · Consultas equivalentes en PostgreSQL, sobre los mismos pedidos migrados
-- (v_pedidos_migrados_mongo, definida en 02_exportar_pedidos.sql)

\echo '== a) Pedidos migrados, con su identificador y estado'
SELECT p.id_pedido, p.estado
  FROM pedido p
 WHERE p.id_pedido IN (SELECT id_pedido FROM v_pedidos_migrados_mongo)
 ORDER BY p.id_pedido;

\echo '== b) Pedidos en estado CANCELADO'
SELECT p.id_pedido, p.estado, p.fecha
  FROM pedido p
 WHERE p.id_pedido IN (SELECT id_pedido FROM v_pedidos_migrados_mongo)
   AND p.estado = 'CANCELADO'
 ORDER BY p.id_pedido;
SELECT COUNT(*) AS cantidad, array_agg(id_pedido ORDER BY id_pedido) AS ids
  FROM pedido
 WHERE id_pedido IN (SELECT id_pedido FROM v_pedidos_migrados_mongo) AND estado = 'CANCELADO';

\echo '== c) Pedidos que contienen el producto "Yerba mate 1kg"'
SELECT p.id_pedido, p.estado, dp.cantidad, dp.precio_unitario
  FROM pedido p
  JOIN detalle_pedido dp ON dp.id_pedido = p.id_pedido
  JOIN producto pr       ON pr.id_producto = dp.id_producto
 WHERE p.id_pedido IN (SELECT id_pedido FROM v_pedidos_migrados_mongo)
   AND pr.nombre = 'Yerba mate 1kg'
 ORDER BY p.id_pedido;
SELECT COUNT(*) AS cantidad, array_agg(p.id_pedido ORDER BY p.id_pedido) AS ids
  FROM pedido p
 WHERE p.id_pedido IN (SELECT id_pedido FROM v_pedidos_migrados_mongo)
   AND EXISTS (SELECT 1 FROM detalle_pedido dp JOIN producto pr ON pr.id_producto = dp.id_producto
                WHERE dp.id_pedido = p.id_pedido AND pr.nombre = 'Yerba mate 1kg');

\echo '== d) Pedidos con total superior al ticket promedio del subconjunto'
WITH totales AS (
    SELECT dp.id_pedido, SUM(dp.cantidad * dp.precio_unitario) AS total
      FROM detalle_pedido dp
     WHERE dp.id_pedido IN (SELECT id_pedido FROM v_pedidos_migrados_mongo)
     GROUP BY dp.id_pedido)
SELECT ROUND(AVG(total), 2) AS umbral,
       COUNT(*) FILTER (WHERE total > (SELECT ROUND(AVG(total), 2) FROM totales)) AS cantidad,
       array_agg(id_pedido ORDER BY id_pedido) FILTER (WHERE total > (SELECT ROUND(AVG(total), 2) FROM totales)) AS ids
  FROM totales;
