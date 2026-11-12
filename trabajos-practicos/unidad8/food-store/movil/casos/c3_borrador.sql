PRAGMA foreign_keys = ON;
-- C3 · Tablet: borrador por 20 flanes cuando la copia dice que quedan 15.
-- La tablet no lo bloquea (propone); el que decide es el servidor, con el semáforo.
BEGIN;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('b0c30000-0000-4000-8000-000000000000', 'feria-01', 'EFECTIVO');

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT 'b0c30000-0000-4000-8000-000000000000', id, 20, precio_centavos
  FROM producto_cache WHERE nombre = 'Flan casero';

INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('a0c30001-0000-4000-8000-000000000000', 'b0c30000-0000-4000-8000-000000000000');
COMMIT;

SELECT c.nombre, i.cantidad, c.stock_visto
  FROM item_borrador i JOIN producto_cache c ON c.id = i.producto_id
 WHERE i.id_local = 'b0c30000-0000-4000-8000-000000000000';
