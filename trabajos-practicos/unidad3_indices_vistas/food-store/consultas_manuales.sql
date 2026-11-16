-- Parte B · Consultas manuales para verificar las vistas.
-- Las escribe el estudiante a mano, a partir de las specs y sin copiar las vistas de OpenCode.
-- Cada una va dentro de su CREATE TEMP VIEW y tiene que devolver las mismas columnas,
-- en el mismo orden, que la vista que verifica. El runner compara con EXCEPT en los dos sentidos.
-- Si dos columnas se llaman igual (por ejemplo, el nombre del producto y el de la categoría), ponele un
-- alias a una: una vista no puede tener dos columnas con el mismo nombre.

-- ######## V1 · productos vigentes con su categoría (specs/B1_v_productos_vigentes.md)
CREATE TEMP VIEW manual_v1 AS
-- escribí acá tu SELECT
;

-- ######## V2 · pedidos con los datos del cliente (specs/B2_v_pedidos_cliente.md)
CREATE TEMP VIEW manual_v2 AS
-- escribí acá tu SELECT
;

-- ######## V3 · detalle de un pedido con el nombre del producto (specs/B3_v_detalle_pedido.md)
CREATE TEMP VIEW manual_v3 AS
-- escribí acá tu SELECT
;

-- ######## V4 · usuarios sin la contraseña (specs/B4_v_usuario_publico.md)
CREATE TEMP VIEW manual_v4 AS
-- escribí acá tu SELECT
;
