-- 02 — Datos semilla

-- CATEGORIA
INSERT INTO categoria (nombre, activo) VALUES
    ('Panificados',   TRUE),
    ('Bebidas',       TRUE),
    ('Lácteos',       TRUE),
    ('Almacén',       TRUE),
    ('Congelados',    FALSE);

-- CLIENTE
INSERT INTO cliente (nombre, apellido, email, telefono) VALUES
    ('Ana',      'Gutiérrez', 'ana.gutierrez@example.com',  '2614001001'),
    ('Bruno',    'Salinas',   'bruno.salinas@example.com',  '2614001002'),
    ('Carla',    'Medina',    'carla.medina@example.com',   NULL),
    ('Diego',    'Ferrari',   'diego.ferrari@example.com',  '2614001004'),
    ('Elena',    'Ríos',      'elena.rios@example.com',     '2614001005');

-- PRODUCTO
INSERT INTO producto (nombre, descripcion, precio, stock, activo, id_categoria) VALUES
    ('Pan de campo 1kg',      'Pan de masa madre, horneado del día', 2500.00,  12, TRUE,
        (SELECT id_categoria FROM categoria WHERE nombre = 'Panificados')),
    ('Medialunas x6',         'Medialunas de manteca',               3200.00,   3, TRUE,
        (SELECT id_categoria FROM categoria WHERE nombre = 'Panificados')),
    ('Agua mineral 2L',       'Agua sin gas',                        1400.00,  40, TRUE,
        (SELECT id_categoria FROM categoria WHERE nombre = 'Bebidas')),
    ('Gaseosa cola 2.25L',    'Bebida gasificada',                   3900.00,   1, TRUE,
        (SELECT id_categoria FROM categoria WHERE nombre = 'Bebidas')),
    ('Leche entera 1L',       'Leche entera en sachet',              1800.00,  25, TRUE,
        (SELECT id_categoria FROM categoria WHERE nombre = 'Lácteos')),
    ('Queso cremoso 500g',    'Queso cremoso fraccionado',           7600.00,   8, TRUE,
        (SELECT id_categoria FROM categoria WHERE nombre = 'Lácteos')),
    ('Yerba mate 1kg',        'Yerba con palo',                      6800.00,  15, TRUE,
        (SELECT id_categoria FROM categoria WHERE nombre = 'Almacén')),
    ('Aceite girasol 900ml',  'Aceite de girasol',                   4100.00,  20, TRUE,
        (SELECT id_categoria FROM categoria WHERE nombre = 'Almacén')),
    ('Fideos secos 500g',     'Fideos tipo mostachol',               1950.00,  30, TRUE,
        (SELECT id_categoria FROM categoria WHERE nombre = 'Almacén')),
    ('Helado 1L',             'Producto dado de baja lógicamente',   9500.00,   0, FALSE,
        (SELECT id_categoria FROM categoria WHERE nombre = 'Congelados'));

-- PEDIDO
INSERT INTO pedido (fecha, forma_pago, id_cliente) VALUES
    ('2026-08-01 10:15:00-03', 'EFECTIVO',
        (SELECT id_cliente FROM cliente WHERE email = 'ana.gutierrez@example.com')),
    ('2026-08-03 18:40:00-03', 'TARJETA',
        (SELECT id_cliente FROM cliente WHERE email = 'bruno.salinas@example.com')),
    ('2026-08-07 09:05:00-03', 'TRANSFERENCIA',
        (SELECT id_cliente FROM cliente WHERE email = 'ana.gutierrez@example.com')),
    ('2026-08-12 20:30:00-03', 'TARJETA',
        (SELECT id_cliente FROM cliente WHERE email = 'carla.medina@example.com')),
    ('2026-08-18 12:00:00-03', 'EFECTIVO',
        (SELECT id_cliente FROM cliente WHERE email = 'diego.ferrari@example.com'));

-- DETALLE_PEDIDO
INSERT INTO detalle_pedido (cantidad, precio_unitario, id_pedido, id_producto) VALUES
    (2, 2200.00,
        (SELECT id_pedido FROM pedido WHERE fecha = '2026-08-01 10:15:00-03'),
        (SELECT id_producto FROM producto WHERE nombre = 'Pan de campo 1kg')),
    (1, 1650.00,
        (SELECT id_pedido FROM pedido WHERE fecha = '2026-08-01 10:15:00-03'),
        (SELECT id_producto FROM producto WHERE nombre = 'Leche entera 1L')),

    (3, 1400.00,
        (SELECT id_pedido FROM pedido WHERE fecha = '2026-08-03 18:40:00-03'),
        (SELECT id_producto FROM producto WHERE nombre = 'Agua mineral 2L')),
    (1, 6800.00,
        (SELECT id_pedido FROM pedido WHERE fecha = '2026-08-03 18:40:00-03'),
        (SELECT id_producto FROM producto WHERE nombre = 'Yerba mate 1kg')),

    (1, 7600.00,
        (SELECT id_pedido FROM pedido WHERE fecha = '2026-08-07 09:05:00-03'),
        (SELECT id_producto FROM producto WHERE nombre = 'Queso cremoso 500g')),
    (2, 3200.00,
        (SELECT id_pedido FROM pedido WHERE fecha = '2026-08-07 09:05:00-03'),
        (SELECT id_producto FROM producto WHERE nombre = 'Medialunas x6')),

    (4, 1950.00,
        (SELECT id_pedido FROM pedido WHERE fecha = '2026-08-12 20:30:00-03'),
        (SELECT id_producto FROM producto WHERE nombre = 'Fideos secos 500g')),
    (1, 4100.00,
        (SELECT id_pedido FROM pedido WHERE fecha = '2026-08-12 20:30:00-03'),
        (SELECT id_producto FROM producto WHERE nombre = 'Aceite girasol 900ml')),

    (1, 3900.00,
        (SELECT id_pedido FROM pedido WHERE fecha = '2026-08-18 12:00:00-03'),
        (SELECT id_producto FROM producto WHERE nombre = 'Gaseosa cola 2.25L'));

-- USUARIO (datos de prueba)
INSERT INTO usuario (nombre, apellido, mail, celular, contrasena, rol, eliminado)
VALUES
    ('Nicole', 'González', 'n.gonzalez@foodstore.com', '+54 9 11 5555-0101',
     '3f7a9c1e5b2d4f6a8c0e1d2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7c8d9e0f1a2b', 'ADMIN', FALSE),
    ('Matías', 'Ríos',     'm.rios@foodstore.com',     '+54 9 11 5555-0102',
     '9c3e2d1f4a6b8c5d7e9f0a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d', 'USUARIO', FALSE),
    ('Sofía',  'Luna',     's.luna@foodstore.com',     '+54 9 11 5555-0103',
     'b0a9c8d7e6f5a4b3c2d1e0f9a8b7c6d5e4f3a2b1c0d9e8f7a6b5c4d3e2f1a0b9c', 'USUARIO', TRUE);

-- ============================================================================
-- Ampliación de volumen para la Unidad 3: es la carga masiva de la Semana 3
-- (sql/02b_carga_masiva_rapida.sql), sin cambios. Deja 200 000 pedidos, 400 000 líneas,
-- 50 000 productos y 20 000 clientes, para que los planes y los tiempos se diferencien.
-- ============================================================================

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
