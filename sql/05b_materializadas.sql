-- 05b — Vista materializada: facturación por categoría y mes

DROP MATERIALIZED VIEW IF EXISTS mv_facturacion_cat_mes CASCADE;

CREATE MATERIALIZED VIEW mv_facturacion_cat_mes AS
SELECT
    c.id_categoria,
    c.nombre AS categoria,
    DATE_TRUNC('month', pe.fecha) AS mes,
    COUNT(DISTINCT pe.id_pedido) AS cantidad_pedidos,
    SUM(dp.cantidad * dp.precio_unitario) AS facturacion_total
FROM categoria c
JOIN producto p       ON p.id_categoria = c.id_categoria
JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
JOIN pedido pe        ON pe.id_pedido = dp.id_pedido
WHERE c.activo = TRUE AND p.activo = TRUE
GROUP BY c.id_categoria, c.nombre, DATE_TRUNC('month', pe.fecha);

-- Índice único: requisito para REFRESH MATERIALIZED VIEW CONCURRENTLY
CREATE UNIQUE INDEX uq_mv_facturacion_cat_mes
    ON mv_facturacion_cat_mes (id_categoria, mes);
