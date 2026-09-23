-- 03b — Pruebas de las reglas de negocio (casos válidos e inválidos)

-- Caso 1 — Producto inactivo: Helado 1L (activo = FALSE)
BEGIN;

INSERT INTO detalle_pedido (cantidad, precio_unitario, id_pedido, id_producto)
VALUES (1, 9500.00,
    (SELECT id_pedido FROM pedido LIMIT 1),
    (SELECT id_producto FROM producto WHERE nombre = 'Helado 1L'));

ROLLBACK;

-- Caso 2 — Producto activo con stock suficiente
BEGIN;

INSERT INTO detalle_pedido (cantidad, precio_unitario, id_pedido, id_producto)
VALUES (2, 1400.00,
    (SELECT id_pedido FROM pedido LIMIT 1),
    (SELECT id_producto FROM producto WHERE nombre = 'Agua mineral 2L'));

ROLLBACK;

-- Caso 3 — Stock insuficiente
BEGIN;

INSERT INTO detalle_pedido (cantidad, precio_unitario, id_pedido, id_producto)
VALUES (50, 3900.00,
    (SELECT id_pedido FROM pedido LIMIT 1),
    (SELECT id_producto FROM producto WHERE nombre = 'Gaseosa cola 2.25L'));

ROLLBACK;

-- Caso 4 — Límite exacto de stock (cantidad = stock)
BEGIN;

INSERT INTO detalle_pedido (cantidad, precio_unitario, id_pedido, id_producto)
VALUES (3, 3200.00,
    (SELECT id_pedido FROM pedido LIMIT 1),
    (SELECT id_producto FROM producto WHERE nombre = 'Medialunas x6'));

ROLLBACK;
