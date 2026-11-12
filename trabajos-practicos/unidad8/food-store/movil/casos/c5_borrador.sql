PRAGMA foreign_keys = ON;
-- C5 · Tablet: borrador sin cambios en el servidor (una Napolitana y 2 cervezas).
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('b0c50000-0000-4000-8000-000000000000', 'feria-01', 'TRANSFERENCIA');

WITH pedido (nombre, cantidad) AS (VALUES ('Napolitana', 1), ('Cerveza 1L', 2))
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT 'b0c50000-0000-4000-8000-000000000000', c.id, p.cantidad, c.precio_centavos
  FROM pedido p JOIN producto_cache c ON c.nombre = p.nombre
 WHERE c.disponible = 1 AND c.eliminado = 0;

INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('a0c50001-0000-4000-8000-000000000000', 'b0c50000-0000-4000-8000-000000000000');
COMMIT;
