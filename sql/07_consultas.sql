-- 07 — DML y consultas

-- 7.1 JOIN + filtro — Historial de pedidos del cliente 10
SELECT p.id_pedido, p.fecha, p.forma_pago, c.nombre, c.apellido
FROM pedido p
JOIN cliente c ON c.id_cliente = p.id_cliente
WHERE p.id_cliente = 10
ORDER BY p.fecha DESC;

-- 7.2 LEFT JOIN + agregación + GROUP BY — Facturación por categoría
SELECT c.nombre AS nombre_categoria,
       COUNT(dp.id_detalle) AS cantidad_lineas_venta,
       COALESCE(SUM(dp.cantidad * dp.precio_unitario), 0) AS monto_total_facturado
FROM categoria c
LEFT JOIN producto p        ON p.id_categoria = c.id_categoria AND p.activo = TRUE
LEFT JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
WHERE c.activo = TRUE
GROUP BY c.id_categoria, c.nombre
ORDER BY monto_total_facturado DESC;

-- 7.3 Subconsulta correlacionada (NOT EXISTS) — Productos vigentes nunca vendidos
SELECT id_producto, nombre, precio, stock
FROM producto
WHERE activo = TRUE
  AND NOT EXISTS (SELECT 1 FROM detalle_pedido WHERE id_producto = producto.id_producto)
ORDER BY nombre;

-- 7.4 Cuatro tablas + agregación por mes — Facturación por categoría y mes
SELECT c.nombre AS categoria,
       DATE_TRUNC('month', pe.fecha) AS mes,
       COUNT(DISTINCT pe.id_pedido) AS cantidad_pedidos,
       SUM(dp.cantidad * dp.precio_unitario) AS facturacion_total
FROM categoria c
JOIN producto p        ON p.id_categoria = c.id_categoria
JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
JOIN pedido pe         ON pe.id_pedido = dp.id_pedido
WHERE c.activo = TRUE AND p.activo = TRUE
GROUP BY c.id_categoria, c.nombre, DATE_TRUNC('month', pe.fecha)
ORDER BY mes, facturacion_total DESC;

-- 7.5 Función de ventana — Ranking de clientes por gasto (RANK)
WITH gasto_por_cliente AS (
    SELECT pe.id_cliente, SUM(dp.cantidad * dp.precio_unitario) AS gasto_total
    FROM pedido pe
    JOIN detalle_pedido dp ON dp.id_pedido = pe.id_pedido
    GROUP BY pe.id_cliente
)
SELECT c.id_cliente, c.nombre, c.apellido, gpc.gasto_total,
       RANK() OVER (ORDER BY gpc.gasto_total DESC) AS puesto
FROM gasto_por_cliente gpc
JOIN cliente c ON c.id_cliente = gpc.id_cliente
ORDER BY gpc.gasto_total DESC
LIMIT 20;

-- 7.6 GROUP BY + HAVING — Clientes con 20 pedidos o más
SELECT c.id_cliente, c.apellido, c.nombre, COUNT(*) AS cantidad_pedidos
FROM cliente c
JOIN pedido p ON p.id_cliente = c.id_cliente
GROUP BY c.id_cliente, c.apellido, c.nombre
HAVING COUNT(*) >= 20
ORDER BY cantidad_pedidos DESC, c.apellido;

-- 7.7 Ventana con PARTITION BY — Top 3 productos más vendidos de cada categoría
WITH ventas AS (
    SELECT p.id_categoria, p.id_producto, p.nombre,
           SUM(dp.cantidad) AS unidades
    FROM producto p
    JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
    WHERE p.activo = TRUE
    GROUP BY p.id_categoria, p.id_producto, p.nombre
)
SELECT c.nombre AS categoria, v.nombre AS producto, v.unidades, v.puesto
FROM (
    SELECT ventas.*,
           ROW_NUMBER() OVER (PARTITION BY id_categoria ORDER BY unidades DESC, id_producto) AS puesto
    FROM ventas
) v
JOIN categoria c ON c.id_categoria = v.id_categoria
WHERE v.puesto <= 3 AND c.activo = TRUE
ORDER BY c.nombre, v.puesto, v.nombre;

-- 7.8 Subconsulta escalar + función propia — Pedidos por encima del ticket promedio
SELECT pe.id_pedido, pe.fecha::date AS fecha, fn_total_pedido(pe.id_pedido) AS total
FROM pedido pe
WHERE pe.id_cliente = 10
  AND fn_total_pedido(pe.id_pedido) > (
        SELECT AVG(t.total_pedido)
        FROM (SELECT SUM(dp.cantidad * dp.precio_unitario) AS total_pedido
              FROM detalle_pedido dp
              GROUP BY dp.id_pedido) t)
ORDER BY total DESC;
