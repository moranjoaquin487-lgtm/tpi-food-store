-- Parte B · Consultas manuales para verificar las vistas.
-- Escritas a partir de las specs de Kiro, sin mirar las vistas de OpenCode (ver duia.md).
-- Cada una va dentro de su CREATE TEMP VIEW y devuelve las mismas columnas, en el mismo orden,
-- que la vista que verifica. El runner compara con EXCEPT en los dos sentidos.

-- ######## V1 · productos vigentes con su categoría (specs/B1_v_productos_vigentes.md)
CREATE TEMP VIEW manual_v1 AS
SELECT pr.id_producto, pr.nombre AS nombre_producto, pr.precio, pr.stock,
       cat.id_categoria, cat.nombre AS nombre_categoria
  FROM producto pr
  JOIN categoria cat USING (id_categoria)
 WHERE pr.activo AND cat.activo
;

-- ######## V2 · pedidos con los datos del cliente (specs/B2_v_pedidos_cliente.md)
CREATE TEMP VIEW manual_v2 AS
SELECT pe.id_pedido, pe.fecha, pe.forma_pago, cl.id_cliente, cl.nombre, cl.apellido
  FROM pedido pe
  JOIN cliente cl USING (id_cliente)
;

-- ######## V3 · detalle de un pedido con el nombre del producto (specs/B3_v_detalle_pedido.md)
CREATE TEMP VIEW manual_v3 AS
SELECT dp.id_pedido, dp.id_detalle, pr.id_producto, pr.nombre AS nombre_producto,
       dp.cantidad, dp.precio_unitario, dp.cantidad * dp.precio_unitario AS importe
  FROM detalle_pedido dp
  JOIN producto pr USING (id_producto)
;

-- ######## V4 · usuarios sin la contraseña (specs/B4_v_usuario_publico.md)
CREATE TEMP VIEW manual_v4 AS
SELECT u.id, u.nombre, u.apellido, u.mail, u.rol
  FROM usuario u
 WHERE NOT u.eliminado
;