-- Parte A · Índice descartado por sobreindexación. Se mide para documentar la decisión, no para aplicarlo.
-- Lo sugirió Kiro en specs/A4_productos_nunca_vendidos.md: (nombre, id_producto) WHERE activo = TRUE, para que C4
-- lea producto por índice y ya ordenado por nombre. OpenCode no lo propuso (propuestas/indices_opencode.sql).
-- Se crea dentro de una transacción, se mide C4 y se deshace: no queda en la base.
BEGIN;
\echo '######## Selectividad de la condición del índice parcial (activo = TRUE)'
SELECT count(*) FILTER (WHERE activo) AS activos, count(*) AS total,
       round(100.0 * count(*) FILTER (WHERE activo) / count(*), 3) AS porcentaje_activos
  FROM producto;
CREATE INDEX idx_producto_nombre_vig ON producto (nombre, id_producto) WHERE activo = TRUE;
ANALYZE producto;
\echo '######## Tamaño del índice candidato frente a la tabla'
SELECT pg_size_pretty(pg_relation_size('idx_producto_nombre_vig')) AS indice,
       pg_size_pretty(pg_relation_size('producto')) AS tabla_producto;
\echo '######## C4 · Productos vigentes nunca vendidos, con el índice candidato'
SELECT COUNT(*) AS filas FROM (
SELECT id_producto, nombre, precio, stock
FROM producto
WHERE activo = TRUE
  AND NOT EXISTS (SELECT 1 FROM detalle_pedido WHERE id_producto = producto.id_producto)
ORDER BY nombre
) x;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre, precio, stock
FROM producto
WHERE activo = TRUE
  AND NOT EXISTS (SELECT 1 FROM detalle_pedido WHERE id_producto = producto.id_producto)
ORDER BY nombre;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre, precio, stock
FROM producto
WHERE activo = TRUE
  AND NOT EXISTS (SELECT 1 FROM detalle_pedido WHERE id_producto = producto.id_producto)
ORDER BY nombre;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id_producto, nombre, precio, stock
FROM producto
WHERE activo = TRUE
  AND NOT EXISTS (SELECT 1 FROM detalle_pedido WHERE id_producto = producto.id_producto)
ORDER BY nombre;
ROLLBACK;
