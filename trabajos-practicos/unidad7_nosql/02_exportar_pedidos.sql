-- U7 · 02 — Exportación de pedidos y detalles a JSON para MongoDB
--
-- Subconjunto migrado: los pedidos que tienen al menos una línea de un producto del
-- catálogo semilla (los 10 productos de sql/02_data.sql). Son pedidos existentes, con
-- sus líneas completas. La vista v_pedidos_migrados_mongo fija ese criterio, y
-- consultas_postgresql.sql lo usa para comparar contra los mismos pedidos.
--
-- Decisiones del documento:
--   * _id = id_pedido: se conserva el identificador de origen.
--   * Importes como texto ('2200.00') para cargarlos en MongoDB como Decimal128, sin
--     pasar por un número de punto flotante.
--   * Precio histórico: cada línea lleva precio_unitario de detalle_pedido (el de la venta),
--     no el precio actual del producto.
--   * Del cliente viajan solo id, nombre y apellido: el mail y el teléfono no hacen falta
--     para mostrar un pedido (minimización de datos personales).

-- El archivo se escribe en la codificación del cliente: se fija UTF-8 (mongosh lo lee así).
\encoding UTF8

CREATE OR REPLACE VIEW v_pedidos_migrados_mongo AS
SELECT DISTINCT dp.id_pedido
  FROM detalle_pedido dp
 WHERE dp.id_producto IN (SELECT id_producto FROM producto
                           WHERE nombre IN ('Pan de campo 1kg', 'Medialunas x6', 'Agua mineral 2L',
                                            'Gaseosa cola 2.25L', 'Leche entera 1L', 'Queso cremoso 500g',
                                            'Yerba mate 1kg', 'Aceite girasol 900ml', 'Fideos secos 500g',
                                            'Helado 1L'));

\echo '== Pedidos que se exportan'
SELECT COUNT(*) AS pedidos, MIN(id_pedido) AS primero, MAX(id_pedido) AS ultimo FROM v_pedidos_migrados_mongo;

\set QUIET on
\pset tuples_only on
\pset format unaligned
\o pedidos_export.json
SELECT jsonb_pretty(jsonb_agg(doc ORDER BY (doc->>'_id')::BIGINT))
  FROM (
    SELECT jsonb_build_object(
             '_id',        p.id_pedido,
             'fecha',      to_char(p.fecha AT TIME ZONE 'UTC', 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
             'estado',     p.estado,
             'forma_pago', p.forma_pago,
             'cliente',    jsonb_build_object('id_cliente', c.id_cliente, 'nombre', c.nombre, 'apellido', c.apellido),
             'lineas',     l.lineas,
             'total',      l.total::TEXT
           ) AS doc
      FROM pedido p
      JOIN cliente c ON c.id_cliente = p.id_cliente
      JOIN LATERAL (
            SELECT jsonb_agg(jsonb_build_object(
                       'id_detalle',      dp.id_detalle,
                       'id_producto',     dp.id_producto,
                       'producto',        pr.nombre,
                       'categoria',       ca.nombre,
                       'cantidad',        dp.cantidad,
                       'precio_unitario', dp.precio_unitario::TEXT,
                       'subtotal',        (dp.cantidad * dp.precio_unitario)::TEXT)
                     ORDER BY dp.id_detalle) AS lineas,
                   SUM(dp.cantidad * dp.precio_unitario) AS total
              FROM detalle_pedido dp
              JOIN producto  pr ON pr.id_producto  = dp.id_producto
              JOIN categoria ca ON ca.id_categoria = pr.id_categoria
             WHERE dp.id_pedido = p.id_pedido) l ON TRUE
     WHERE p.id_pedido IN (SELECT id_pedido FROM v_pedidos_migrados_mongo)
  ) docs;
\o
\pset tuples_only off
\pset format aligned
\set QUIET off
\echo '== Archivo generado: pedidos_export.json'
