-- Parte 5 · Consulta de la competencia: productos vigentes de una categoría en un rango de precio,
-- ordenados por precio. Es la consulta de ejemplo de la consigna; se mide igual antes y después.

SELECT COUNT(*) AS filas FROM (
SELECT id_producto, nombre, precio, stock
  FROM producto
 WHERE id_categoria = 3 AND activo = TRUE AND precio BETWEEN 500 AND 520
 ORDER BY precio, id_producto
 LIMIT 20
) x;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre, precio, stock
  FROM producto
 WHERE id_categoria = 3 AND activo = TRUE AND precio BETWEEN 500 AND 520
 ORDER BY precio, id_producto
 LIMIT 20;
