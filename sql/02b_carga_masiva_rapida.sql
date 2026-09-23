-- 02b — Carga masiva (versión rápida, ~15 s)

-- 1. PRODUCTO: repartidos en partes iguales entre las 5 categorías
INSERT INTO producto (nombre, descripcion, precio, stock, activo, id_categoria)
SELECT 'Producto ' || i, NULL,
       ROUND((random() * 990 + 10)::NUMERIC, 2),
       (random() * 150 + 50)::INT,
       TRUE,
       (SELECT MIN(id_categoria) FROM categoria) + (i % 5)
FROM generate_series(1, 50000) AS s(i);

-- 2. CLIENTE
INSERT INTO cliente (nombre, apellido, email, telefono)
SELECT 'Nombre' || i, 'Apellido' || i, 'cliente' || i || '@mail.com', NULL
FROM generate_series(1, 20000) AS s(i);

-- 3. PEDIDO: fechas repartidas en los últimos 2 años, cliente al azar
INSERT INTO pedido (fecha, forma_pago, id_cliente)
SELECT now() - (random() * INTERVAL '2 years'),
       (ARRAY['EFECTIVO','TARJETA','TRANSFERENCIA']::forma_pago_enum[])[floor(random() * 3 + 1)],
       (SELECT MIN(id_cliente) FROM cliente) + (random() * 19999)::INT
FROM generate_series(1, 200000) AS s(i);

-- 4. DETALLE_PEDIDO: 1 a 3 líneas por pedido, sin repetir producto
INSERT INTO detalle_pedido (cantidad, precio_unitario, id_pedido, id_producto)
SELECT DISTINCT ON (t.id_pedido, t.id_producto)
       t.cantidad, pr.precio, t.id_pedido, t.id_producto
FROM (
    SELECT pe.id_pedido,
           (1 + ((pe.id_pedido * 31 + k * 7) % 4))::INT AS cantidad,
           (SELECT MIN(id_producto) FROM producto)
             + ((pe.id_pedido * 7919 + k * 104729) % 50000) AS id_producto
    FROM pedido pe
    CROSS JOIN LATERAL generate_series(1, 1 + (pe.id_pedido % 3)) AS g(k)
) t
JOIN producto pr ON pr.id_producto = t.id_producto
                AND pr.activo = TRUE
                AND pr.stock >= 4
WHERE NOT EXISTS (SELECT 1 FROM detalle_pedido d
                  WHERE d.id_pedido = t.id_pedido AND d.id_producto = t.id_producto);

-- 5. Estadísticas actualizadas para el optimizador
ANALYZE;
