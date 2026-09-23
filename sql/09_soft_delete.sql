-- 09 — Borrado lógico (soft delete) y su impacto

-- 9.1 Un DELETE físico está bloqueado por diseño
BEGIN;
DELETE FROM producto
WHERE id_producto = (SELECT id_producto FROM detalle_pedido LIMIT 1);  -- error esperado
ROLLBACK;

-- 9.2 La baja lógica: el historial se conserva
BEGIN;
UPDATE producto SET activo = FALSE WHERE id_producto = 30;

-- Ya no aparece en el catálogo vigente...
SELECT COUNT(*) AS aparece_en_vigentes
FROM vista_productos_vigentes WHERE id_producto = 30;

-- ...pero sus ventas siguen existiendo para los reportes históricos
SELECT COUNT(*) AS lineas_de_venta_conservadas
FROM detalle_pedido WHERE id_producto = 30;

-- ...y ya no se puede volver a vender (trigger de 03_restricciones.sql)
INSERT INTO detalle_pedido (cantidad, precio_unitario, id_pedido, id_producto)
VALUES (1, 100.00, (SELECT MAX(id_pedido) FROM pedido), 30);  -- error esperado
ROLLBACK;

-- 9.3 Impacto en las consultas: olvidar el filtro da datos incorrectos
SELECT COUNT(*) FILTER (WHERE activo)     AS productos_vigentes,
       COUNT(*) FILTER (WHERE NOT activo) AS productos_dados_de_baja,
       COUNT(*)                           AS total_sin_filtrar
FROM producto;

-- 9.4 Impacto en los índices: el índice parcial solo se usa si la consulta filtra activo = TRUE
SELECT indexrelname AS indice,
       pg_size_pretty(pg_relation_size(indexrelid)) AS tamanio
FROM pg_stat_user_indexes
WHERE relname = 'producto';

-- Con el filtro de vigencia -> usa el índice parcial
EXPLAIN (ANALYZE, COSTS OFF)
SELECT id_producto, nombre, precio FROM producto
WHERE id_categoria = 1 AND activo = TRUE;

-- Sin el filtro -> NO puede usarlo y recorre la tabla entera
EXPLAIN (ANALYZE, COSTS OFF)
SELECT id_producto, nombre, precio FROM producto
WHERE id_categoria = 1;
