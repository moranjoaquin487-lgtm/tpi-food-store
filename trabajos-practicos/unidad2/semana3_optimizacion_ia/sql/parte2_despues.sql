-- Parte 2 · Las mismas tres consultas, medidas DESPUÉS de los cambios aceptados.
-- Cada consulta se ejecuta una vez para calentar la caché y después con EXPLAIN (ANALYZE, BUFFERS).
-- Única diferencia en el texto: Q1 compara la columna fecha sin envolverla en DATE() (reescritura de OpenCode).

\echo '######## Q1 · Facturación por día de la última semana'
SELECT COUNT(*) AS filas FROM (
SELECT DATE(p.fecha) AS dia, COUNT(DISTINCT p.id_pedido) AS pedidos, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
 WHERE p.fecha >= (CURRENT_DATE - 7)::timestamptz
 GROUP BY DATE(p.fecha)
) x;
EXPLAIN (ANALYZE, BUFFERS)
SELECT DATE(p.fecha) AS dia, COUNT(DISTINCT p.id_pedido) AS pedidos, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
 WHERE p.fecha >= (CURRENT_DATE - 7)::timestamptz
 GROUP BY DATE(p.fecha)
 ORDER BY dia;

\echo '######## Q2 · Los 10 clientes que más gastaron en los últimos 30 días'
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

\echo '######## Q3 · Los 10 productos más vendidos de una categoría'
SELECT COUNT(*) AS filas FROM (
SELECT pr.id_producto, pr.nombre, SUM(d.cantidad) AS unidades
  FROM detalle_pedido d
  JOIN producto pr ON pr.id_producto = d.id_producto
 WHERE pr.id_categoria = 1 AND pr.activo = TRUE
 GROUP BY pr.id_producto, pr.nombre
 ORDER BY unidades DESC
 LIMIT 10
) x;
EXPLAIN (ANALYZE, BUFFERS)
SELECT pr.id_producto, pr.nombre, SUM(d.cantidad) AS unidades
  FROM detalle_pedido d
  JOIN producto pr ON pr.id_producto = d.id_producto
 WHERE pr.id_categoria = 1 AND pr.activo = TRUE
 GROUP BY pr.id_producto, pr.nombre
 ORDER BY unidades DESC
 LIMIT 10;
