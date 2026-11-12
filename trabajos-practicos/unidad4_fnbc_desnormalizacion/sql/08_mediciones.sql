-- U4 · 08 — Mediciones antes y después de la desnormalización
ANALYZE detalle_pedido;
ANALYZE producto;
ANALYZE resumen_ventas_categoria;

\echo '== ANTES: top 5 calculado sobre las tablas normalizadas'
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT c.id_categoria, c.nombre, SUM(dp.cantidad) AS unidades,
       SUM(dp.cantidad * dp.precio_unitario) AS facturacion
  FROM detalle_pedido dp
  JOIN producto  p ON p.id_producto  = dp.id_producto
  JOIN categoria c ON c.id_categoria = p.id_categoria
 GROUP BY c.id_categoria, c.nombre
 ORDER BY facturacion DESC
 LIMIT 5;

\echo '== DESPUÉS: top 5 leído de la tabla resumen'
EXPLAIN (ANALYZE, BUFFERS, COSTS OFF)
SELECT * FROM v_top5_categorias;

\echo '== Los dos caminos dan el mismo resultado (se esperan 0 diferencias)'
WITH normalizado AS (
    SELECT c.id_categoria, c.nombre, SUM(dp.cantidad)::BIGINT AS unidades,
           SUM(dp.cantidad * dp.precio_unitario) AS facturacion
      FROM detalle_pedido dp
      JOIN producto  p ON p.id_producto  = dp.id_producto
      JOIN categoria c ON c.id_categoria = p.id_categoria
     GROUP BY c.id_categoria, c.nombre
     ORDER BY facturacion DESC LIMIT 5)
SELECT (SELECT COUNT(*) FROM (SELECT * FROM normalizado EXCEPT SELECT * FROM v_top5_categorias) a)
     + (SELECT COUNT(*) FROM (SELECT * FROM v_top5_categorias EXCEPT SELECT * FROM normalizado) b) AS diferencias;

SELECT * FROM v_top5_categorias;

\echo '== Costo en la escritura: 1000 líneas de detalle con el trigger del resumen'
BEGIN;
INSERT INTO pedido (forma_pago, id_cliente) VALUES ('EFECTIVO', (SELECT MIN(id_cliente) FROM cliente));
EXPLAIN (ANALYZE, COSTS OFF, SUMMARY ON)
INSERT INTO detalle_pedido (cantidad, precio_unitario, id_pedido, id_producto)
SELECT 1, precio, (SELECT MAX(id_pedido) FROM pedido), id_producto
  FROM producto WHERE activo AND stock > 0 ORDER BY id_producto LIMIT 1000;
ROLLBACK;

\echo '== Lo mismo sin el trigger del resumen'
BEGIN;
ALTER TABLE detalle_pedido DISABLE TRIGGER trg_resumen_detalle_ins;
INSERT INTO pedido (forma_pago, id_cliente) VALUES ('EFECTIVO', (SELECT MIN(id_cliente) FROM cliente));
EXPLAIN (ANALYZE, COSTS OFF, SUMMARY ON)
INSERT INTO detalle_pedido (cantidad, precio_unitario, id_pedido, id_producto)
SELECT 1, precio, (SELECT MAX(id_pedido) FROM pedido), id_producto
  FROM producto WHERE activo AND stock > 0 ORDER BY id_producto LIMIT 1000;
ROLLBACK;
