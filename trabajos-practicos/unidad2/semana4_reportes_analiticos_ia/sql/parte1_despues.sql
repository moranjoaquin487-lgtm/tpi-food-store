-- Parte 1 · DESPUÉS del índice de OpenCode, con la configuración por defecto.
-- Se mide cada consulta original (efecto del índice solo) y su reescritura de OpenCode (índice + reescritura).

\echo '######## Q1 · Facturación por categoría y mes, consulta original'
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

\echo '######## Q1R · Facturación por categoría y mes, reescritura R1 de OpenCode (sin COUNT DISTINCT)'
SELECT COUNT(*) AS filas FROM (
SELECT c.nombre AS categoria, l.mes, COUNT(*) AS pedidos, SUM(l.importe) AS facturado
  FROM (SELECT d.id_pedido, date_trunc('month', p.fecha)::date AS mes, pr.id_categoria,
               SUM(d.cantidad * d.precio_unitario) AS importe
          FROM pedido p
          JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
          JOIN producto pr      ON pr.id_producto = d.id_producto
         WHERE p.fecha >= date_trunc('month', now()) - INTERVAL '6 months'
         GROUP BY d.id_pedido, date_trunc('month', p.fecha), pr.id_categoria) l
  JOIN categoria c ON c.id_categoria = l.id_categoria
 GROUP BY c.nombre, l.mes
) x;
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre AS categoria, l.mes, COUNT(*) AS pedidos, SUM(l.importe) AS facturado
  FROM (SELECT d.id_pedido, date_trunc('month', p.fecha)::date AS mes, pr.id_categoria,
               SUM(d.cantidad * d.precio_unitario) AS importe
          FROM pedido p
          JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
          JOIN producto pr      ON pr.id_producto = d.id_producto
         WHERE p.fecha >= date_trunc('month', now()) - INTERVAL '6 months'
         GROUP BY d.id_pedido, date_trunc('month', p.fecha), pr.id_categoria) l
  JOIN categoria c ON c.id_categoria = l.id_categoria
 GROUP BY c.nombre, l.mes
 ORDER BY l.mes, facturado DESC;

\echo '######## Q2 · Ranking de clientes por gasto, consulta original'
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

\echo '######## Q2R · Ranking de clientes por gasto, reescritura R2 de OpenCode (gasto por pedido primero)'
SELECT COUNT(*) AS filas FROM (
WITH gasto_pedido AS (
  SELECT p.id_cliente, p.id_pedido, SUM(d.cantidad * d.precio_unitario) AS importe
    FROM pedido p
    JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
   WHERE p.fecha >= now() - INTERVAL '90 days'
   GROUP BY p.id_cliente, p.id_pedido
)
SELECT puesto, id_cliente, cliente, pedidos, gastado
  FROM (SELECT c.id_cliente, c.nombre || ' ' || c.apellido AS cliente,
               COUNT(*) AS pedidos, SUM(g.importe) AS gastado,
               RANK() OVER (ORDER BY SUM(g.importe) DESC) AS puesto
          FROM cliente c
          JOIN gasto_pedido g ON g.id_cliente = c.id_cliente
         GROUP BY c.id_cliente, c.nombre, c.apellido) r
 WHERE puesto <= 20
) x;
EXPLAIN (ANALYZE, BUFFERS)
WITH gasto_pedido AS (
  SELECT p.id_cliente, p.id_pedido, SUM(d.cantidad * d.precio_unitario) AS importe
    FROM pedido p
    JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
   WHERE p.fecha >= now() - INTERVAL '90 days'
   GROUP BY p.id_cliente, p.id_pedido
)
SELECT puesto, id_cliente, cliente, pedidos, gastado
  FROM (SELECT c.id_cliente, c.nombre || ' ' || c.apellido AS cliente,
               COUNT(*) AS pedidos, SUM(g.importe) AS gastado,
               RANK() OVER (ORDER BY SUM(g.importe) DESC) AS puesto
          FROM cliente c
          JOIN gasto_pedido g ON g.id_cliente = c.id_cliente
         GROUP BY c.id_cliente, c.nombre, c.apellido) r
 WHERE puesto <= 20
 ORDER BY puesto, id_cliente;

\echo '######## Equivalencia de las reescrituras con las consultas originales (se espera 0 en todas)'
WITH q1 AS (
    SELECT c.nombre AS categoria, date_trunc('month', p.fecha)::date AS mes,
           COUNT(DISTINCT p.id_pedido) AS pedidos, SUM(d.cantidad * d.precio_unitario) AS facturado
      FROM pedido p JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
      JOIN producto pr ON pr.id_producto = d.id_producto JOIN categoria c ON c.id_categoria = pr.id_categoria
     WHERE p.fecha >= date_trunc('month', now()) - INTERVAL '6 months'
     GROUP BY c.nombre, date_trunc('month', p.fecha)),
q1r AS (
    SELECT c.nombre AS categoria, l.mes, COUNT(*) AS pedidos, SUM(l.importe) AS facturado
      FROM (SELECT d.id_pedido, date_trunc('month', p.fecha)::date AS mes, pr.id_categoria,
                   SUM(d.cantidad * d.precio_unitario) AS importe
              FROM pedido p JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
              JOIN producto pr ON pr.id_producto = d.id_producto
             WHERE p.fecha >= date_trunc('month', now()) - INTERVAL '6 months'
             GROUP BY d.id_pedido, date_trunc('month', p.fecha), pr.id_categoria) l
      JOIN categoria c ON c.id_categoria = l.id_categoria
     GROUP BY c.nombre, l.mes)
SELECT (SELECT COUNT(*) FROM (SELECT * FROM q1 EXCEPT SELECT * FROM q1r) a) AS q1_menos_q1r,
       (SELECT COUNT(*) FROM (SELECT * FROM q1r EXCEPT SELECT * FROM q1) b) AS q1r_menos_q1;
WITH q2 AS (
    SELECT puesto, id_cliente, cliente, pedidos, gastado FROM (
        SELECT c.id_cliente, c.nombre || ' ' || c.apellido AS cliente, COUNT(DISTINCT p.id_pedido) AS pedidos,
               SUM(d.cantidad * d.precio_unitario) AS gastado,
               RANK() OVER (ORDER BY SUM(d.cantidad * d.precio_unitario) DESC) AS puesto
          FROM cliente c JOIN pedido p ON p.id_cliente = c.id_cliente JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
         WHERE p.fecha >= now() - INTERVAL '90 days'
         GROUP BY c.id_cliente, c.nombre, c.apellido) r WHERE puesto <= 20),
gp AS (
    SELECT p.id_cliente, p.id_pedido, SUM(d.cantidad * d.precio_unitario) AS importe
      FROM pedido p JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
     WHERE p.fecha >= now() - INTERVAL '90 days'
     GROUP BY p.id_cliente, p.id_pedido),
q2r AS (
    SELECT puesto, id_cliente, cliente, pedidos, gastado FROM (
        SELECT c.id_cliente, c.nombre || ' ' || c.apellido AS cliente, COUNT(*) AS pedidos,
               SUM(g.importe) AS gastado, RANK() OVER (ORDER BY SUM(g.importe) DESC) AS puesto
          FROM cliente c JOIN gp g ON g.id_cliente = c.id_cliente
         GROUP BY c.id_cliente, c.nombre, c.apellido) r WHERE puesto <= 20)
SELECT (SELECT COUNT(*) FROM (SELECT * FROM q2 EXCEPT SELECT * FROM q2r) a) AS q2_menos_q2r,
       (SELECT COUNT(*) FROM (SELECT * FROM q2r EXCEPT SELECT * FROM q2) b) AS q2r_menos_q2;
