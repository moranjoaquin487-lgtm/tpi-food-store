-- Carga masiva de datos — TP3 (Unidad 2)

-- CONFIG: ajustar los tres generate_series para cada escenario.

-- 1. PRODUCTO
INSERT INTO producto (nombre, descripcion, precio, stock, activo, id_categoria)
SELECT
    'Producto ' || i,
    NULL,
    ROUND((random() * 990 + 10)::NUMERIC, 2),
    (random() * 150 + 50)::INTEGER,
    TRUE,
    (SELECT id_categoria FROM categoria ORDER BY random() + s.i * 0 LIMIT 1)
FROM generate_series(1, 50000) AS s(i);

-- 2. CLIENTE
INSERT INTO cliente (nombre, apellido, email, telefono)
SELECT
    'Nombre' || i,
    'Apellido' || i,
    'cliente' || i || '@mail.com',
    NULL
FROM generate_series(1, 20000) AS s(i);

-- 3. PEDIDO
INSERT INTO pedido (fecha, forma_pago, id_cliente)
SELECT
    now() - (random() * INTERVAL '2 years'),
    (ARRAY['EFECTIVO', 'TARJETA', 'TRANSFERENCIA']::forma_pago_enum[])[floor(random() * 3 + 1)],
    (SELECT id_cliente FROM cliente ORDER BY random() + s.i * 0 LIMIT 1)
FROM generate_series(1, 200000) AS s(i);

-- 4. DETALLE_PEDIDO
WITH
lineas_por_pedido AS (
    SELECT id_pedido, (random() * 3 + 1)::INTEGER AS n_lineas
    FROM pedido
)
INSERT INTO detalle_pedido (cantidad, precio_unitario, id_pedido, id_producto)
SELECT
    (random() * 3 + 1)::INTEGER,
    p.precio,
    lpp.id_pedido,
    p.id_producto
FROM lineas_por_pedido lpp
CROSS JOIN LATERAL (
    SELECT id_producto, precio,
           ROW_NUMBER() OVER () AS rn
    FROM (
        SELECT id_producto, precio
        FROM producto
        -- Solo productos vendibles (activos y con stock).
        WHERE activo = TRUE
          AND stock >= 4
        -- El "* 0" correlaciona el subquery con la fila externa.
        ORDER BY random() + lpp.id_pedido * 0
        LIMIT 4
    ) sub
) p
WHERE p.rn <= lpp.n_lineas;
