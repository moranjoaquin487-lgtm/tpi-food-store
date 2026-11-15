-- queries.sql — Carga de trabajo heredada de Food Store
-- Sección 1: las consultas de negocio y analíticas del proyecto (sql/07_consultas.sql), sin cambios.
-- Sección 2: las consultas del panel de la Semana 3 y de reportes de la Semana 4, como quedaron en esas prácticas.
-- Las marcadas [Parte A · Cn] son las que se indexan en este trabajo (mediciones/parteA_consultas.sql).
-- La 7.4 es la base de la vista materializada de la Parte C.
-- Archivo de referencia: no se ejecuta entero (la 7.8 usa fn_total_pedido, de sql/06_funciones_procedimientos.sql).

-- ============================================================================
-- Sección 1 · sql/07_consultas.sql
-- ============================================================================
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

-- 7.3 Subconsulta correlacionada (NOT EXISTS) — Productos vigentes nunca vendidos   [Parte A · C4]
SELECT id_producto, nombre, precio, stock
FROM producto
WHERE activo = TRUE
  AND NOT EXISTS (SELECT 1 FROM detalle_pedido WHERE id_producto = producto.id_producto)
ORDER BY nombre;

-- 7.4 Cuatro tablas + agregación por mes — Facturación por categoría y mes   [Parte C]
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

-- ============================================================================
-- Sección 2 · Semanas 3 y 4 (trabajos-practicos/unidad2)
-- ============================================================================

-- S3.1 Panel: facturación por día de la última semana (con el filtro sargable que se aceptó en la Semana 3)   [Parte A · C1]
SELECT DATE(p.fecha) AS dia, COUNT(DISTINCT p.id_pedido) AS pedidos, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
 WHERE p.fecha >= (CURRENT_DATE - 7)::timestamptz
 GROUP BY DATE(p.fecha)
 ORDER BY dia;

-- S3.2 Panel: los 10 clientes que más gastaron en los últimos 30 días   [Parte A · C2]
SELECT c.id_cliente, c.nombre, c.apellido, SUM(d.cantidad * d.precio_unitario) AS gastado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
  JOIN cliente c ON c.id_cliente = p.id_cliente
 WHERE p.fecha >= now() - INTERVAL '30 days'
 GROUP BY c.id_cliente, c.nombre, c.apellido
 ORDER BY gastado DESC
 LIMIT 10;

-- S3.3 Los 10 productos más vendidos de una categoría
SELECT pr.id_producto, pr.nombre, SUM(d.cantidad) AS unidades
  FROM detalle_pedido d
  JOIN producto pr ON pr.id_producto = d.id_producto
 WHERE pr.id_categoria = 1 AND pr.activo = TRUE
 GROUP BY pr.id_producto, pr.nombre
 ORDER BY unidades DESC
 LIMIT 10;

-- S3.5 Catálogo: productos vigentes de una categoría en un rango de precio
SELECT id_producto, nombre, precio, stock
  FROM producto
 WHERE id_categoria = 3 AND activo = TRUE AND precio BETWEEN 500 AND 520
 ORDER BY precio, id_producto
 LIMIT 20;

-- S4.1 Facturación por categoría y mes de los últimos 6 meses
SELECT c.nombre AS categoria, date_trunc('month', p.fecha)::date AS mes,
       COUNT(DISTINCT p.id_pedido) AS pedidos, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
  JOIN producto pr ON pr.id_producto = d.id_producto
  JOIN categoria c ON c.id_categoria = pr.id_categoria
 WHERE p.fecha >= date_trunc('month', now()) - INTERVAL '6 months'
 GROUP BY c.nombre, date_trunc('month', p.fecha)
 ORDER BY mes, facturado DESC;

-- S4.2 Ranking de clientes por gasto en los últimos 90 días (los 20 primeros puestos)
SELECT puesto, id_cliente, cliente, pedidos, gastado FROM (
    SELECT c.id_cliente, c.nombre || ' ' || c.apellido AS cliente,
           COUNT(DISTINCT p.id_pedido) AS pedidos,
           SUM(d.cantidad * d.precio_unitario) AS gastado,
           RANK() OVER (ORDER BY SUM(d.cantidad * d.precio_unitario) DESC) AS puesto
      FROM cliente c
      JOIN pedido p ON p.id_cliente = c.id_cliente
      JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
     WHERE p.fecha >= now() - INTERVAL '90 days'
     GROUP BY c.id_cliente, c.nombre, c.apellido
) r
 WHERE puesto <= 20
 ORDER BY puesto, id_cliente;

-- S4.3 Los 10 productos que más facturaron en los últimos 30 días, con su categoría   [Parte A · C3]
SELECT pr.id_producto, pr.nombre AS producto, c.nombre AS categoria,
       SUM(d.cantidad) AS unidades, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM detalle_pedido d
  JOIN pedido p ON p.id_pedido = d.id_pedido
  JOIN producto pr ON pr.id_producto = d.id_producto
  JOIN categoria c ON c.id_categoria = pr.id_categoria
 WHERE p.fecha >= now() - INTERVAL '30 days'
 GROUP BY pr.id_producto, pr.nombre, c.nombre
 ORDER BY facturado DESC, pr.id_producto
 LIMIT 10;
