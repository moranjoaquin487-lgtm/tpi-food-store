PRAGMA foreign_keys = ON;
-- C2 · Tablet: el cliente acepta el precio nuevo. Se actualiza el precio visto con el de la última copia
-- y se manda una solicitud NUEVA (otro UUID). La solicitud anterior queda en CONFLICTO como historial.
BEGIN;
UPDATE item_borrador
   SET precio_centavos_visto = (SELECT c.precio_centavos FROM producto_cache c WHERE c.id = item_borrador.producto_id)
 WHERE id_local = 'b0c20000-0000-4000-8000-000000000000';

INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('a0c20002-0000-4000-8000-000000000000', 'b0c20000-0000-4000-8000-000000000000');
COMMIT;

SELECT c.nombre, i.cantidad, printf('%.2f', i.precio_centavos_visto / 100.0) AS precio_visto
  FROM item_borrador i JOIN producto_cache c ON c.id = i.producto_id
 WHERE i.id_local = 'b0c20000-0000-4000-8000-000000000000' ORDER BY c.nombre;
