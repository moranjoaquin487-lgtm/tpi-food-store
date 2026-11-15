-- Parte 4 · Estrategia para la consulta de la competencia (propuesta de Claude sobre el plan ANTES).
-- 1. Reescritura: agregar antes de unir. Se suman las líneas por id_producto, se toman los 10 primeros y
--    recién ahí se unen producto y categoria, por clave primaria, para 10 filas (en lugar de unir las ~16 000
--    líneas del mes con los 50 000 productos y agrupar por nombre).
-- 2. Con el índice de la Parte 1 (detalle_pedido (id_pedido) INCLUDE ...) y random_page_cost = 1.1 solo en
--    la sesión, el join pedido-detalle de los pedidos del mes puede ser Nested Loop con Index Only Scan.
SET random_page_cost = 1.1;

SELECT COUNT(*) AS filas FROM (
SELECT t.id_producto, pr.nombre AS producto, c.nombre AS categoria, t.unidades, t.facturado
  FROM (SELECT d.id_producto, SUM(d.cantidad) AS unidades, SUM(d.cantidad * d.precio_unitario) AS facturado
          FROM pedido p
          JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
         WHERE p.fecha >= now() - INTERVAL '30 days'
         GROUP BY d.id_producto
         ORDER BY facturado DESC, d.id_producto
         LIMIT 10) t
  JOIN producto pr ON pr.id_producto  = t.id_producto
  JOIN categoria c ON c.id_categoria  = pr.id_categoria
) x;
EXPLAIN (ANALYZE, BUFFERS)
SELECT t.id_producto, pr.nombre AS producto, c.nombre AS categoria, t.unidades, t.facturado
  FROM (SELECT d.id_producto, SUM(d.cantidad) AS unidades, SUM(d.cantidad * d.precio_unitario) AS facturado
          FROM pedido p
          JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
         WHERE p.fecha >= now() - INTERVAL '30 days'
         GROUP BY d.id_producto
         ORDER BY facturado DESC, d.id_producto
         LIMIT 10) t
  JOIN producto pr ON pr.id_producto  = t.id_producto
  JOIN categoria c ON c.id_categoria  = pr.id_categoria
 ORDER BY t.facturado DESC, t.id_producto;

\echo '== Mismo resultado que la consulta original (se espera 0 y 0)'
WITH original AS (
    SELECT pr.id_producto, pr.nombre AS producto, c.nombre AS categoria,
           SUM(d.cantidad) AS unidades, SUM(d.cantidad * d.precio_unitario) AS facturado
      FROM detalle_pedido d
      JOIN pedido p ON p.id_pedido = d.id_pedido
      JOIN producto pr ON pr.id_producto = d.id_producto
      JOIN categoria c ON c.id_categoria = pr.id_categoria
     WHERE p.fecha >= now() - INTERVAL '30 days'
     GROUP BY pr.id_producto, pr.nombre, c.nombre
     ORDER BY facturado DESC, pr.id_producto LIMIT 10),
nueva AS (
    SELECT t.id_producto, pr.nombre AS producto, c.nombre AS categoria, t.unidades, t.facturado
      FROM (SELECT d.id_producto, SUM(d.cantidad) AS unidades, SUM(d.cantidad * d.precio_unitario) AS facturado
              FROM pedido p JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
             WHERE p.fecha >= now() - INTERVAL '30 days'
             GROUP BY d.id_producto ORDER BY facturado DESC, d.id_producto LIMIT 10) t
      JOIN producto pr ON pr.id_producto = t.id_producto
      JOIN categoria c ON c.id_categoria = pr.id_categoria)
SELECT (SELECT COUNT(*) FROM (SELECT * FROM original EXCEPT SELECT * FROM nueva) a) AS original_menos_nueva,
       (SELECT COUNT(*) FROM (SELECT * FROM nueva EXCEPT SELECT * FROM original) b) AS nueva_menos_original;
