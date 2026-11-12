PRAGMA foreign_keys = ON;
-- C4 · Tablet: borrador con una Fugazzeta y 3 empanadas de pollo. Después el servidor da de baja la Fugazzeta.
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('b0c40000-0000-4000-8000-000000000000', 'feria-01', 'EFECTIVO');

WITH pedido (nombre, cantidad) AS (VALUES ('Fugazzeta', 1), ('Empanada de pollo', 3))
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT 'b0c40000-0000-4000-8000-000000000000', c.id, p.cantidad, c.precio_centavos
  FROM pedido p JOIN producto_cache c ON c.nombre = p.nombre
 WHERE c.disponible = 1 AND c.eliminado = 0;

INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('a0c40001-0000-4000-8000-000000000000', 'b0c40000-0000-4000-8000-000000000000');
COMMIT;
