PRAGMA foreign_keys = ON;
-- C2 · Tablet: borrador con 2 Muzzarellas y una Coca al precio que muestra el catálogo. Solicitud PENDIENTE.
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('b0c20000-0000-4000-8000-000000000000', 'feria-01', 'TARJETA');

WITH pedido (nombre, cantidad) AS (VALUES ('Muzzarella', 2), ('Coca 1.5L', 1))
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT 'b0c20000-0000-4000-8000-000000000000', c.id, p.cantidad, c.precio_centavos
  FROM pedido p JOIN producto_cache c ON c.nombre = p.nombre
 WHERE c.disponible = 1 AND c.eliminado = 0;

INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('a0c20001-0000-4000-8000-000000000000', 'b0c20000-0000-4000-8000-000000000000');
COMMIT;

SELECT c.nombre, i.cantidad, printf('%.2f', i.precio_centavos_visto / 100.0) AS precio_visto
  FROM item_borrador i JOIN producto_cache c ON c.id = i.producto_id
 WHERE i.id_local = 'b0c20000-0000-4000-8000-000000000000' ORDER BY c.nombre;
