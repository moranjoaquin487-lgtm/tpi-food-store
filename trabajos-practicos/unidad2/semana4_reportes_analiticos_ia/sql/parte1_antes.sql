-- Parte 1 · Dos consultas analíticas que cruzan al menos tres tablas, medidas ANTES de cualquier cambio.
-- Base: copia del estado final de la Semana 3 (carga masiva e índices de esa práctica).
-- Cada consulta se ejecuta una vez para calentar la caché y después con EXPLAIN (ANALYZE, BUFFERS).

\echo '######## Q1 · Facturación por categoría y mes (últimos 6 meses)'
SELECT COUNT(*) AS filas FROM (
SELECT c.nombre AS categoria, date_trunc('month', p.fecha)::date AS mes,
       COUNT(DISTINCT p.id_pedido) AS pedidos, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
  JOIN producto pr ON pr.id_producto = d.id_producto
  JOIN categoria c ON c.id_categoria = pr.id_categoria
 WHERE p.fecha >= date_trunc('month', now()) - INTERVAL '6 months'
 GROUP BY c.nombre, date_trunc('month', p.fecha)
) x;
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre AS categoria, date_trunc('month', p.fecha)::date AS mes,
       COUNT(DISTINCT p.id_pedido) AS pedidos, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
  JOIN producto pr ON pr.id_producto = d.id_producto
  JOIN categoria c ON c.id_categoria = pr.id_categoria
 WHERE p.fecha >= date_trunc('month', now()) - INTERVAL '6 months'
 GROUP BY c.nombre, date_trunc('month', p.fecha)
 ORDER BY mes, facturado DESC;

\echo '######## Q2 · Ranking de clientes por gasto en los últimos 90 días (los 20 primeros puestos)'
SELECT COUNT(*) AS filas FROM (
SELECT puesto, id_cliente, cliente, pedidos, gastado FROM (
    SELECT c.id_cliente, c.nombre || ' ' || c.apellido AS cliente,
           COUNT(DISTINCT p.id_pedido) AS pedidos,
           SUM(d.cantidad * d.precio_unitario) AS gastado,
           RANK() OVER (ORDER BY SUM(d.cantidad * d.precio_unitario) DESC) AS puesto
      FROM cliente c
      JOIN pedido p ON p.id_cliente = c.id_cliente
      JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
     WHERE p.fecha >= now() - INTERVAL '90 days'
     GROUP BY c.id_cliente, c.nombre, c.apellido
) r WHERE puesto <= 20
) x;
EXPLAIN (ANALYZE, BUFFERS)
SELECT puesto, id_cliente, cliente, pedidos, gastado FROM (
    SELECT c.id_cliente, c.nombre || ' ' || c.apellido AS cliente,
           COUNT(DISTINCT p.id_pedido) AS pedidos,
           SUM(d.cantidad * d.precio_unitario) AS gastado,
           RANK() OVER (ORDER BY SUM(d.cantidad * d.precio_unitario) DESC) AS puesto
      FROM cliente c
      JOIN pedido p ON p.id_cliente = c.id_cliente
      JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
     WHERE p.fecha >= now() - INTERVAL '90 days'
     GROUP BY c.id_cliente, c.nombre, c.apellido
) r
 WHERE puesto <= 20
 ORDER BY puesto, id_cliente;
