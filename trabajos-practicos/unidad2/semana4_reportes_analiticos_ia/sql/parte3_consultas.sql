-- Parte 3 · Ranking con función de ventana y consulta con subconsulta correlacionada, bajo especificación
-- precisa (docs/parte3_specs.md). Cada pregunta tiene dos versiones con estructura distinta, generadas por
-- Claude a partir de la spec, y se comprueban equivalentes con EXCEPT en los dos sentidos (se espera 0 y 0).

\echo '######## Spec A · Los 3 primeros puestos de productos por unidades vendidas en 90 días, dentro de cada categoría'
\echo '== Versión A1 (DENSE_RANK con PARTITION BY)'
CREATE TEMP VIEW a1 AS
WITH ventas AS (
    SELECT pr.id_categoria, pr.id_producto, pr.nombre AS producto, SUM(d.cantidad) AS unidades
      FROM producto pr
      JOIN categoria c      ON c.id_categoria = pr.id_categoria AND c.activo = TRUE
      JOIN detalle_pedido d ON d.id_producto  = pr.id_producto
      JOIN pedido p         ON p.id_pedido    = d.id_pedido
     WHERE pr.activo = TRUE
       AND p.fecha >= now() - INTERVAL '90 days'
     GROUP BY pr.id_categoria, pr.id_producto, pr.nombre
), ranking AS (
    SELECT v.*, DENSE_RANK() OVER (PARTITION BY v.id_categoria ORDER BY v.unidades DESC) AS puesto
      FROM ventas v
)
SELECT c.nombre AS categoria, r.puesto, r.id_producto, r.producto, r.unidades
  FROM ranking r
  JOIN categoria c ON c.id_categoria = r.id_categoria
 WHERE r.puesto <= 3;
SELECT * FROM a1 ORDER BY categoria, puesto, id_producto;

\echo '== Versión A2 (puesto con subconsulta correlacionada sobre los niveles de unidades de cada categoría)'
-- El puesto denso de un producto es 1 + la cantidad de valores distintos de unidades mayores al suyo en su
-- categoría. La subconsulta correlacionada recorre esos valores distintos (pocas decenas por categoría) y no
-- todos los productos vendidos: comparar cada producto con todos los de su categoría tardaba minutos.
CREATE TEMP VIEW a2 AS
WITH ventas AS (
    SELECT pr.id_categoria, pr.id_producto, pr.nombre AS producto, SUM(d.cantidad) AS unidades
      FROM producto pr
      JOIN categoria c      ON c.id_categoria = pr.id_categoria AND c.activo = TRUE
      JOIN detalle_pedido d ON d.id_producto  = pr.id_producto
      JOIN pedido p         ON p.id_pedido    = d.id_pedido
     WHERE pr.activo = TRUE
       AND p.fecha >= now() - INTERVAL '90 days'
     GROUP BY pr.id_categoria, pr.id_producto, pr.nombre
), niveles AS (
    SELECT DISTINCT id_categoria, unidades FROM ventas
), puestos AS (
    SELECT n.id_categoria, n.unidades,
           1 + (SELECT COUNT(*) FROM niveles n2
                 WHERE n2.id_categoria = n.id_categoria AND n2.unidades > n.unidades) AS puesto
      FROM niveles n
)
SELECT c.nombre AS categoria, pu.puesto, v.id_producto, v.producto, v.unidades
  FROM ventas v
  JOIN puestos pu  ON pu.id_categoria = v.id_categoria AND pu.unidades = v.unidades
  JOIN categoria c ON c.id_categoria  = v.id_categoria
 WHERE pu.puesto <= 3;
SELECT * FROM a2 ORDER BY categoria, puesto, id_producto;

\echo '== Equivalencia de la spec A'
SELECT (SELECT COUNT(*) FROM a1) AS filas_a1, (SELECT COUNT(*) FROM a2) AS filas_a2,
       (SELECT COUNT(*) FROM (SELECT * FROM a1 EXCEPT SELECT * FROM a2) x) AS diferencias_a_menos_b,
       (SELECT COUNT(*) FROM (SELECT * FROM a2 EXCEPT SELECT * FROM a1) x) AS diferencias_b_menos_a;

\echo '######## Spec B · Clientes sin compras en los últimos 60 días: fecha de la última compra y total de pedidos'
\echo '== Versión B1 (subconsultas correlacionadas)'
CREATE TEMP VIEW b1 AS
SELECT c.id_cliente, c.nombre || ' ' || c.apellido AS cliente,
       (SELECT MAX(p.fecha) FROM pedido p WHERE p.id_cliente = c.id_cliente)::date AS ultima_compra,
       (SELECT COUNT(*)     FROM pedido p WHERE p.id_cliente = c.id_cliente)       AS pedidos
  FROM cliente c
 WHERE EXISTS (SELECT 1 FROM pedido p WHERE p.id_cliente = c.id_cliente)
   AND (SELECT MAX(p.fecha) FROM pedido p WHERE p.id_cliente = c.id_cliente) < now() - INTERVAL '60 days'
 ORDER BY ultima_compra, c.id_cliente
 LIMIT 20;
SELECT * FROM b1;

\echo '== Versión B2 (JOIN + GROUP BY + HAVING)'
CREATE TEMP VIEW b2 AS
SELECT c.id_cliente, c.nombre || ' ' || c.apellido AS cliente,
       MAX(p.fecha)::date AS ultima_compra,
       COUNT(*)           AS pedidos
  FROM cliente c
  JOIN pedido p ON p.id_cliente = c.id_cliente
 GROUP BY c.id_cliente, c.nombre, c.apellido
HAVING MAX(p.fecha) < now() - INTERVAL '60 days'
 ORDER BY MAX(p.fecha)::date, c.id_cliente
 LIMIT 20;
SELECT * FROM b2;

\echo '== Equivalencia de la spec B'
SELECT (SELECT COUNT(*) FROM b1) AS filas_b1, (SELECT COUNT(*) FROM b2) AS filas_b2,
       (SELECT COUNT(*) FROM (SELECT * FROM b1 EXCEPT SELECT * FROM b2) x) AS diferencias_a_menos_b,
       (SELECT COUNT(*) FROM (SELECT * FROM b2 EXCEPT SELECT * FROM b1) x) AS diferencias_b_menos_a;
