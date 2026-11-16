-- views.sql · Parte B · Vistas para los reportes (Unidad 3)
-- Las generó OpenCode a partir de las specs de Kiro (propuestas/views_opencode.sql) y se copian sin cambios.
-- Cada una se verificó contra una consulta escrita a mano (consultas_manuales.sql) con EXCEPT en los dos
-- sentidos, y la de seguridad además con SET ROLE rol_reportes (mediciones/parteB_verificacion.sql).
-- La vista materializada de la Parte C está en materializadas.sql.

-- ===== B1 · v_productos_vigentes
-- ---------------------------------------------------------------------
-- B1 · v_productos_vigentes (specs/B1_v_productos_vigentes.md)
-- Solo productos vigentes (producto.activo AND categoria.activo) con el
-- nombre de la categoría. Columnas en el orden de la spec.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_productos_vigentes AS
SELECT p.id_producto,
       p.nombre AS producto,
       p.precio,
       p.stock,
       p.id_categoria,
       c.nombre AS categoria
FROM producto p
JOIN categoria c ON c.id_categoria = p.id_categoria
WHERE p.activo = TRUE
  AND c.activo = TRUE;

-- ===== B2 · v_pedidos_cliente
-- ---------------------------------------------------------------------
-- B2 · v_pedidos_cliente (specs/B2_v_pedidos_cliente.md)
-- Cada pedido con los datos básicos de identificación del cliente.
-- Sin filtro de vigencia: pedido y cliente no tienen borrado lógico.
-- Columnas en el orden de la spec.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_pedidos_cliente AS
SELECT p.id_pedido,
       p.fecha,
       p.forma_pago,
       p.id_cliente,
       c.nombre,
       c.apellido
FROM pedido p
JOIN cliente c ON c.id_cliente = p.id_cliente;

-- ===== B3 · v_detalle_pedido
-- ---------------------------------------------------------------------
-- B3 · v_detalle_pedido (specs/B3_v_detalle_pedido.md)
-- Cada línea de detalle_pedido con el nombre del producto y el subtotal.
-- Sin filtro por producto.activo: el historial debe conservar productos
-- dados de baja. Columnas en el orden de la spec.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_detalle_pedido AS
SELECT dp.id_pedido,
       dp.id_detalle,
       dp.id_producto,
       pr.nombre AS producto,
       dp.cantidad,
       dp.precio_unitario,
       dp.cantidad * dp.precio_unitario AS subtotal
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.id_producto;

-- ===== B4 · v_usuario_publico y rol_reportes
-- ---------------------------------------------------------------------
-- B4 · v_usuario_publico (specs/B4_v_usuario_publico.md)
-- Vista de seguridad: expone solo id, nombre, apellido, mail y rol de los
-- usuarios no eliminados, ocultando contrasena y celular. Columnas en el
-- orden de la spec.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW v_usuario_publico AS
SELECT id,
       nombre,
       apellido,
       mail,
       rol
FROM usuario
WHERE eliminado = FALSE;

-- ---------------------------------------------------------------------
-- B4 · Control de acceso
-- El rol de solo lectura rol_reportes puede consultar la vista pero no la
-- tabla base usuario. La vista corre con los privilegios de su owner, por
-- lo que basta con el GRANT sobre la vista.
-- ---------------------------------------------------------------------

-- Crear el rol solo si no existe (CREATE ROLE no admite IF NOT EXISTS).
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rol_reportes') THEN
        CREATE ROLE rol_reportes NOLOGIN;
    END IF;
END
$$;

-- El rol recibe SELECT sobre la vista...
GRANT SELECT ON v_usuario_publico TO rol_reportes;

-- ...y ningún permiso sobre la tabla base.
REVOKE ALL ON usuario FROM rol_reportes;
