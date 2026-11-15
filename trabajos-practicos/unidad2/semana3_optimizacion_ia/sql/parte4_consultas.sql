-- Parte 4 · Consultas bajo especificación precisa (las specs están en docs/parte4_specs.md).
-- Cada pregunta tiene dos versiones con distinta estructura, generadas por Claude a partir de la spec,
-- y se comprueban equivalentes con EXCEPT en los dos sentidos (se espera 0 y 0).

\echo '######## Spec 1 · Resumen por categoría vigente: productos, precio promedio y unidades de los últimos 90 días'
\echo '== Versión A (agregaciones previas y LEFT JOIN)'
CREATE TEMP VIEW s1_a AS
WITH prod AS (
    SELECT id_categoria, COUNT(*) AS productos_vigentes, ROUND(AVG(precio), 2) AS precio_promedio
      FROM producto
     WHERE activo = TRUE
     GROUP BY id_categoria
), vendidas AS (
    SELECT pr.id_categoria, SUM(d.cantidad) AS unidades
      FROM detalle_pedido d
      JOIN pedido p    ON p.id_pedido    = d.id_pedido
      JOIN producto pr ON pr.id_producto = d.id_producto
     WHERE pr.activo = TRUE
       AND p.fecha >= now() - INTERVAL '90 days'
     GROUP BY pr.id_categoria
)
SELECT c.nombre AS categoria,
       COALESCE(prod.productos_vigentes, 0) AS productos_vigentes,
       prod.precio_promedio,
       COALESCE(vendidas.unidades, 0) AS unidades_90_dias
  FROM categoria c
  LEFT JOIN prod     ON prod.id_categoria     = c.id_categoria
  LEFT JOIN vendidas ON vendidas.id_categoria = c.id_categoria
 WHERE c.activo = TRUE;
SELECT * FROM s1_a ORDER BY unidades_90_dias DESC, categoria;

\echo '== Versión B (subconsultas escalares correlacionadas)'
CREATE TEMP VIEW s1_b AS
SELECT c.nombre AS categoria,
       (SELECT COUNT(*) FROM producto pr
         WHERE pr.id_categoria = c.id_categoria AND pr.activo = TRUE) AS productos_vigentes,
       (SELECT ROUND(AVG(pr.precio), 2) FROM producto pr
         WHERE pr.id_categoria = c.id_categoria AND pr.activo = TRUE) AS precio_promedio,
       (SELECT COALESCE(SUM(d.cantidad), 0)
          FROM detalle_pedido d
          JOIN pedido p    ON p.id_pedido    = d.id_pedido
          JOIN producto pr ON pr.id_producto = d.id_producto
         WHERE pr.id_categoria = c.id_categoria AND pr.activo = TRUE
           AND p.fecha >= now() - INTERVAL '90 days') AS unidades_90_dias
  FROM categoria c
 WHERE c.activo = TRUE;
SELECT * FROM s1_b ORDER BY unidades_90_dias DESC, categoria;

\echo '== Equivalencia de la spec 1'
SELECT (SELECT COUNT(*) FROM s1_a) AS filas_a, (SELECT COUNT(*) FROM s1_b) AS filas_b,
       (SELECT COUNT(*) FROM (SELECT * FROM s1_a EXCEPT SELECT * FROM s1_b) x) AS diferencias_a_menos_b,
       (SELECT COUNT(*) FROM (SELECT * FROM s1_b EXCEPT SELECT * FROM s1_a) x) AS diferencias_b_menos_a;

\echo '######## Spec 2 · Clientes que gastaron más de un 50 % por encima del promedio por cliente (los 15 primeros)'
\echo '== Versión A (subconsulta en el HAVING)'
CREATE TEMP VIEW s2_a AS
SELECT c.id_cliente, c.nombre, c.apellido,
       COUNT(DISTINCT p.id_pedido) AS pedidos,
       ROUND(SUM(d.cantidad * d.precio_unitario), 2) AS gasto_total
  FROM cliente c
  JOIN pedido p         ON p.id_cliente = c.id_cliente
  JOIN detalle_pedido d ON d.id_pedido  = p.id_pedido
 GROUP BY c.id_cliente, c.nombre, c.apellido
HAVING SUM(d.cantidad * d.precio_unitario) > 1.5 * (
        SELECT AVG(t.gasto)
          FROM (SELECT SUM(d2.cantidad * d2.precio_unitario) AS gasto
                  FROM pedido p2
                  JOIN detalle_pedido d2 ON d2.id_pedido = p2.id_pedido
                 GROUP BY p2.id_cliente) t)
 ORDER BY gasto_total DESC, c.id_cliente
 LIMIT 15;
SELECT * FROM s2_a;

\echo '== Versión B (CTE con promedio por función de ventana)'
CREATE TEMP VIEW s2_b AS
WITH gasto AS (
    SELECT p.id_cliente,
           COUNT(DISTINCT p.id_pedido) AS pedidos,
           SUM(d.cantidad * d.precio_unitario) AS total
      FROM pedido p
      JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
     GROUP BY p.id_cliente
), con_promedio AS (
    SELECT g.*, AVG(g.total) OVER () AS promedio
      FROM gasto g
)
SELECT c.id_cliente, c.nombre, c.apellido, cp.pedidos, ROUND(cp.total, 2) AS gasto_total
  FROM con_promedio cp
  JOIN cliente c ON c.id_cliente = cp.id_cliente
 WHERE cp.total > 1.5 * cp.promedio
 ORDER BY cp.total DESC, c.id_cliente
 LIMIT 15;
SELECT * FROM s2_b;

\echo '== Equivalencia de la spec 2'
SELECT (SELECT COUNT(*) FROM s2_a) AS filas_a, (SELECT COUNT(*) FROM s2_b) AS filas_b,
       (SELECT COUNT(*) FROM (SELECT * FROM s2_a EXCEPT SELECT * FROM s2_b) x) AS diferencias_a_menos_b,
       (SELECT COUNT(*) FROM (SELECT * FROM s2_b EXCEPT SELECT * FROM s2_a) x) AS diferencias_b_menos_a;
