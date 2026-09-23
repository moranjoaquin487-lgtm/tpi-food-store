-- 05 — Vistas

-- vista_cliente_completo

CREATE OR REPLACE VIEW vista_cliente_completo AS
SELECT id_cliente, nombre, apellido, email, telefono
FROM cliente;

-- vista_pedidos_cliente

CREATE OR REPLACE VIEW vista_pedidos_cliente AS
SELECT p.id_pedido, p.fecha, p.forma_pago, c.nombre, c.apellido
FROM pedido p
JOIN cliente c ON c.id_cliente = p.id_cliente;

-- vista_productos_vigentes

CREATE OR REPLACE VIEW vista_productos_vigentes AS
SELECT p.id_producto, p.nombre, p.precio, p.stock, c.nombre AS nombre_categoria
FROM producto p
JOIN categoria c ON c.id_categoria = p.id_categoria
WHERE p.activo = TRUE AND c.activo = TRUE;

-- vista_detalle_pedido_producto

CREATE OR REPLACE VIEW vista_detalle_pedido_producto AS
SELECT dp.id_detalle, dp.id_pedido, pr.nombre AS nombre_producto,
       dp.cantidad, dp.precio_unitario
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.id_producto;

-- vista_usuario_reportes: expone usuario sin la contraseña

CREATE OR REPLACE VIEW vista_usuario_reportes AS
SELECT id, nombre, apellido, mail, celular, rol, eliminado, created_at
FROM usuario
WHERE eliminado = FALSE;
