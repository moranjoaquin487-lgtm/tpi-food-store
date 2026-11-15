-- Parte 1 · Verificación de la carga masiva (solo lectura)
-- Controla que la carga respete las restricciones del esquema y que el volumen sea el pedido.

\echo '== Volumen cargado (consigna: 50.000 productos, 20.000 clientes, 200.000 pedidos con sus detalles)'
SELECT 'producto' AS tabla, COUNT(*) AS filas FROM producto
UNION ALL SELECT 'cliente', COUNT(*) FROM cliente
UNION ALL SELECT 'pedido', COUNT(*) FROM pedido
UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido;

\echo '== Productos por categoría (se espera un reparto parejo)'
SELECT c.nombre AS categoria, COUNT(*) AS productos
  FROM producto p JOIN categoria c USING (id_categoria)
 GROUP BY c.nombre ORDER BY c.nombre;

\echo '== Restricciones (se espera 0 en todas)'
SELECT (SELECT COUNT(*) FROM producto WHERE precio < 0 OR stock < 0)                      AS check_producto,
       (SELECT COUNT(*) FROM detalle_pedido WHERE cantidad <= 0 OR precio_unitario < 0)  AS check_detalle,
       (SELECT COUNT(*) FROM detalle_pedido d
         WHERE NOT EXISTS (SELECT 1 FROM pedido p WHERE p.id_pedido = d.id_pedido)
            OR NOT EXISTS (SELECT 1 FROM producto p WHERE p.id_producto = d.id_producto)) AS detalles_huerfanos,
       (SELECT COUNT(*) FROM pedido p
         WHERE NOT EXISTS (SELECT 1 FROM cliente c WHERE c.id_cliente = p.id_cliente))   AS pedidos_huerfanos,
       (SELECT COUNT(*) FROM (SELECT id_pedido, id_producto FROM detalle_pedido
                               GROUP BY 1, 2 HAVING COUNT(*) > 1) x)                     AS lineas_repetidas,
       (SELECT COUNT(*) FROM pedido WHERE fecha > now())                                  AS pedidos_futuros;

\echo '== Cobertura: pedidos sin líneas, clientes con pedidos y líneas por pedido'
SELECT (SELECT COUNT(*) FROM pedido p WHERE NOT EXISTS (SELECT 1 FROM detalle_pedido d WHERE d.id_pedido = p.id_pedido)) AS pedidos_sin_lineas,
       (SELECT COUNT(DISTINCT id_cliente) FROM pedido) AS clientes_con_pedidos,
       ROUND((SELECT COUNT(*) FROM detalle_pedido)::NUMERIC / (SELECT COUNT(*) FROM pedido), 2) AS lineas_por_pedido;
