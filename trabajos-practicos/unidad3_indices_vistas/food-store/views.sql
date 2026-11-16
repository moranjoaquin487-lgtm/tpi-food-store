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

