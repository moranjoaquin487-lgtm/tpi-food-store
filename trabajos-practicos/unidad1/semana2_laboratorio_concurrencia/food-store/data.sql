-- Food Store — datos iniciales
-- Los pedidos 1 a 5 son la planilla de la Parte 3 del TP1, ya normalizada.
-- Las claves se buscan por nombre, así el script no depende de los valores que asigne IDENTITY.

INSERT INTO categoria (nombre, activo) VALUES
    ('Pizzas',       TRUE),
    ('Empanadas',    TRUE),
    ('Bebidas',      TRUE),
    ('Postres',      TRUE),
    ('Promociones',  TRUE),   -- sin productos todavía: participación parcial (R1)
    ('Congelados',   FALSE);  -- dada de baja (R7)

INSERT INTO producto (nombre, descripcion, precio, stock, activo, categoria_id)
SELECT p.nombre, p.descripcion, p.precio, p.stock, p.activo, c.id
FROM (VALUES
    ('Muzzarella',                'Pizza grande de muzzarella',        1050.00,  40, TRUE,  'Pizzas'),
    ('Napolitana',                'Muzzarella, tomate y ajo',          1500.00,  30, TRUE,  'Pizzas'),
    ('Fugazzeta',                 'Cebolla y muzzarella',              1400.00,  25, TRUE,  'Pizzas'),
    ('Empanada de carne',         'Carne cortada a cuchillo',           350.00, 120, TRUE,  'Empanadas'),
    ('Empanada de pollo',         NULL,                                 330.00, 100, TRUE,  'Empanadas'),
    ('Empanada de jamón y queso', NULL,                                 320.00,  90, TRUE,  'Empanadas'),
    ('Coca 1.5L',                 'Gaseosa 1,5 litros',                 800.00,  60, TRUE,  'Bebidas'),
    ('Agua 500ml',                NULL,                                 400.00,  80, TRUE,  'Bebidas'),
    ('Cerveza 1L',                'Rubia, retornable',                 1200.00,  50, TRUE,  'Bebidas'),
    ('Flan casero',               'Con dulce de leche',                 600.00,  15, TRUE,  'Postres'),
    ('Helado 1/4 kg',             NULL,                                 900.00,   0, TRUE,  'Postres'),   -- sin stock
    ('Pizza congelada',           'Para hornear en casa',              1100.00,  10, FALSE, 'Congelados')  -- dado de baja
) AS p (nombre, descripcion, precio, stock, activo, categoria)
JOIN categoria c ON c.nombre = p.categoria;

INSERT INTO cliente (nombre, apellido, email, telefono) VALUES
    ('Ana',   'Gómez', 'ana.gomez@mail.com',   '261 555-1001'),
    ('Luis',  'Paz',   'luis.paz@mail.com',    '261 555-1002'),
    ('Marta', 'Ruiz',  'marta.ruiz@mail.com',  '261 555-1003'),
    ('Jorge', 'Díaz',  'jorge.diaz@mail.com',  NULL),
    ('Carla', 'Ortiz', 'carla.ortiz@mail.com', '261 555-1005'),   -- sin pedidos: participación parcial (R2)
    ('Pablo', 'Rivas', 'pablo.rivas@mail.com', '261 555-1006');

INSERT INTO pedido (fecha, forma_pago, cliente_id)
SELECT v.fecha, v.forma_pago::tipo_forma_pago, c.id
FROM (VALUES
    (1, TIMESTAMPTZ '2026-03-01 12:10-03', 'EFECTIVO',      'ana.gomez@mail.com'),
    (2, TIMESTAMPTZ '2026-03-01 20:30-03', 'TARJETA',       'luis.paz@mail.com'),
    (3, TIMESTAMPTZ '2026-03-05 21:00-03', 'TRANSFERENCIA', 'ana.gomez@mail.com'),
    (4, TIMESTAMPTZ '2026-03-06 13:15-03', 'EFECTIVO',      'marta.ruiz@mail.com'),
    (5, TIMESTAMPTZ '2026-03-07 22:40-03', 'TARJETA',       'luis.paz@mail.com'),
    (6, TIMESTAMPTZ '2026-03-08 20:05-03', 'EFECTIVO',      'jorge.diaz@mail.com'),
    (7, TIMESTAMPTZ '2026-03-09 21:20-03', 'TRANSFERENCIA', 'pablo.rivas@mail.com')
) AS v (orden, fecha, forma_pago, email)
JOIN cliente c ON c.email = v.email
ORDER BY v.orden;

-- precio_unitario es el precio del momento de la venta (R4): la Muzzarella costaba 1000,00
-- en el pedido 1 y 1050,00 desde el pedido 3, como en la planilla del TP1.
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
SELECT pe.id, pr.id, d.cantidad, d.precio_unitario
FROM (VALUES
    (1, 'Muzzarella',        2, 1000.00),
    (1, 'Coca 1.5L',         1,  800.00),
    (2, 'Napolitana',        1, 1500.00),
    (3, 'Muzzarella',        3, 1050.00),
    (4, 'Coca 1.5L',         4,  800.00),
    (4, 'Napolitana',        2, 1500.00),
    (5, 'Muzzarella',        1, 1050.00),
    (6, 'Fugazzeta',         1, 1400.00),
    (6, 'Empanada de pollo', 6,  330.00),
    (6, 'Agua 500ml',        2,  400.00),
    (7, 'Empanada de carne', 12, 350.00),
    (7, 'Cerveza 1L',        2, 1200.00)
) AS d (orden_pedido, producto, cantidad, precio_unitario)
JOIN producto pr ON pr.nombre = d.producto
JOIN (SELECT id, row_number() OVER (ORDER BY fecha) AS orden FROM pedido) pe
  ON pe.orden = d.orden_pedido;
