-- Parte 1 · Alternativa propia para Q1 (propuesta de Claude al leer el plan ANTES), con el mismo índice y la
-- configuración por defecto. El Sort que alimenta al GroupAggregate ordena 108 000 filas por
-- (c.nombre, mes, p.id_pedido): la primera clave es texto y se compara con la intercalación del idioma.
-- Agrupando por id_categoria (un entero) y uniendo el nombre después, sobre 35 filas, la clave del Sort
-- pasa a ser (id_categoria, mes, id_pedido) y la tabla categoria deja de participar en el join grande.

\echo '######## Q1A · Facturación por categoría y mes, agrupando por id_categoria y uniendo el nombre al final'
SELECT COUNT(*) AS filas FROM (
SELECT c.nombre AS categoria, t.mes, t.pedidos, t.facturado
  FROM (SELECT pr.id_categoria, date_trunc('month', p.fecha)::date AS mes,
               COUNT(DISTINCT p.id_pedido) AS pedidos, SUM(d.cantidad * d.precio_unitario) AS facturado
          FROM pedido p
          JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
          JOIN producto pr ON pr.id_producto = d.id_producto
         WHERE p.fecha >= date_trunc('month', now()) - INTERVAL '6 months'
         GROUP BY pr.id_categoria, date_trunc('month', p.fecha)) t
  JOIN categoria c ON c.id_categoria = t.id_categoria
) x;
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre AS categoria, t.mes, t.pedidos, t.facturado
  FROM (SELECT pr.id_categoria, date_trunc('month', p.fecha)::date AS mes,
               COUNT(DISTINCT p.id_pedido) AS pedidos, SUM(d.cantidad * d.precio_unitario) AS facturado
          FROM pedido p
          JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
          JOIN producto pr ON pr.id_producto = d.id_producto
         WHERE p.fecha >= date_trunc('month', now()) - INTERVAL '6 months'
         GROUP BY pr.id_categoria, date_trunc('month', p.fecha)) t
  JOIN categoria c ON c.id_categoria = t.id_categoria
 ORDER BY t.mes, t.facturado DESC;

\echo '######## Equivalencia de la alternativa con la consulta original (se espera 0 y 0)'
WITH q1 AS (
    SELECT c.nombre AS categoria, date_trunc('month', p.fecha)::date AS mes,
           COUNT(DISTINCT p.id_pedido) AS pedidos, SUM(d.cantidad * d.precio_unitario) AS facturado
      FROM pedido p JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
      JOIN producto pr ON pr.id_producto = d.id_producto JOIN categoria c ON c.id_categoria = pr.id_categoria
     WHERE p.fecha >= date_trunc('month', now()) - INTERVAL '6 months'
     GROUP BY c.nombre, date_trunc('month', p.fecha)),
q1a AS (
    SELECT c.nombre AS categoria, t.mes, t.pedidos, t.facturado
      FROM (SELECT pr.id_categoria, date_trunc('month', p.fecha)::date AS mes,
                   COUNT(DISTINCT p.id_pedido) AS pedidos, SUM(d.cantidad * d.precio_unitario) AS facturado
              FROM pedido p JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
              JOIN producto pr ON pr.id_producto = d.id_producto
             WHERE p.fecha >= date_trunc('month', now()) - INTERVAL '6 months'
             GROUP BY pr.id_categoria, date_trunc('month', p.fecha)) t
      JOIN categoria c ON c.id_categoria = t.id_categoria)
SELECT (SELECT COUNT(*) FROM (SELECT * FROM q1 EXCEPT SELECT * FROM q1a) a) AS q1_menos_q1a,
       (SELECT COUNT(*) FROM (SELECT * FROM q1a EXCEPT SELECT * FROM q1) b) AS q1a_menos_q1;
