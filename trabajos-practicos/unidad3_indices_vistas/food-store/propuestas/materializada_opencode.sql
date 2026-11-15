-- =====================================================================
-- propuestas/materializada_opencode.sql
-- Vista materializada de la spec C1.
-- Este archivo es una propuesta: NO se ejecutó contra la base.
-- =====================================================================

-- ---------------------------------------------------------------------
-- C1 · mv_facturacion_categoria_mes
--      (specs/C1_mv_facturacion_categoria_mes.md)
-- Pre-calcula la facturación por categoría y mes. Incluye id_categoria en
-- el SELECT y el GROUP BY (la spec lo pide para poder crear el índice
-- único que habilita el REFRESH CONCURRENTLY). Se puebla con WITH DATA.
-- ---------------------------------------------------------------------
CREATE MATERIALIZED VIEW mv_facturacion_categoria_mes AS
SELECT c.id_categoria,
       c.nombre AS categoria,
       DATE_TRUNC('month', pe.fecha) AS mes,
       COUNT(DISTINCT pe.id_pedido) AS cantidad_pedidos,
       SUM(dp.cantidad * dp.precio_unitario) AS facturacion_total
FROM categoria c
JOIN producto p        ON p.id_categoria = c.id_categoria
JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
JOIN pedido pe         ON pe.id_pedido = dp.id_pedido
WHERE c.activo = TRUE AND p.activo = TRUE
GROUP BY c.id_categoria, c.nombre, DATE_TRUNC('month', pe.fecha)
WITH DATA;

-- Índice único requerido para el REFRESH CONCURRENTLY.
CREATE UNIQUE INDEX ON mv_facturacion_categoria_mes (id_categoria, mes);

-- Refresco sin bloquear lecturas (una vez por día, en horario de baja carga).
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes;
