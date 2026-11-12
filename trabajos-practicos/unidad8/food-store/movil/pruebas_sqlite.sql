PRAGMA foreign_keys = ON;
-- Food Store — pruebas_sqlite.sql (TP8, consigna 1.c · paradas 3 y 4)
-- Se corre después de schema_sqlite.sql y cargar_snapshot.sql, desde la carpeta movil/:
--   sqlite3 -header -table -echo foodstore_movil.db < pruebas_sqlite.sql
-- No hay -bail: en C7 el error del motor ES el resultado esperado y el script sigue.
-- Los productos se buscan por nombre en producto_cache, nunca por id.

-- Estado inicial
SELECT (SELECT COUNT(*) FROM pedido_borrador) AS borradores,
       (SELECT COUNT(*) FROM item_borrador)   AS items,
       (SELECT COUNT(*) FROM cola_sync)       AS solicitudes;

-- ===========================================================================
-- 1. Borrador completo (borrador + ítems + solicitud) guardado con BEGIN … COMMIT
--    6 empanadas de carne y 2 aguas, en efectivo. La solicitud queda PENDIENTE.
-- ===========================================================================
BEGIN;

INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('b001c000-0000-4000-8000-000000000000', 'feria-01', 'EFECTIVO');

WITH pedido (nombre, cantidad) AS (VALUES ('Empanada de carne', 6), ('Agua 500ml', 2))
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT 'b001c000-0000-4000-8000-000000000000', c.id, p.cantidad, c.precio_centavos
  FROM pedido p
  JOIN producto_cache c ON c.nombre = p.nombre
 WHERE c.disponible = 1 AND c.eliminado = 0;

INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('a001c001-0000-4000-8000-000000000000', 'b001c000-0000-4000-8000-000000000000');

COMMIT;

SELECT b.id_local, b.forma_pago, c.nombre AS producto, i.cantidad,
       printf('%.2f', i.precio_centavos_visto / 100.0) AS precio_visto,
       s.solicitud_uuid, s.estado
  FROM pedido_borrador b
  JOIN item_borrador  i ON i.id_local = b.id_local
  JOIN producto_cache c ON c.id = i.producto_id
  JOIN cola_sync      s ON s.id_local = b.id_local
 WHERE b.id_local = 'b001c000-0000-4000-8000-000000000000'
 ORDER BY c.nombre;

-- ===========================================================================
-- 2. Otra operación deshecha con ROLLBACK
--    El vendedor empieza un borrador (el UUID lo genera la tablet), le carga una Napolitana
--    y el cliente se arrepiente: ROLLBACK. No queda nada.
-- ===========================================================================
BEGIN;

INSERT INTO pedido_borrador (usuario, forma_pago)
VALUES ('feria-01', 'TARJETA')
RETURNING id_local AS uuid_generado_en_la_tablet;

INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT (SELECT id_local FROM pedido_borrador ORDER BY rowid DESC LIMIT 1), id, 1, precio_centavos
  FROM producto_cache
 WHERE nombre = 'Napolitana';

SELECT (SELECT COUNT(*) FROM pedido_borrador) AS borradores_dentro_de_la_transaccion,
       (SELECT COUNT(*) FROM item_borrador)   AS items_dentro_de_la_transaccion;

ROLLBACK;

SELECT (SELECT COUNT(*) FROM pedido_borrador) AS borradores_despues_del_rollback,
       (SELECT COUNT(*) FROM item_borrador)   AS items_despues_del_rollback;

-- ===========================================================================
-- 3. Caso C1: el catálogo disponible funciona sin conectarse al servidor.
--    La consulta solo lee producto_cache; la única base abierta es el archivo de la tablet.
-- ===========================================================================
SELECT name AS bases_abiertas FROM pragma_database_list;

SELECT nombre,
       printf('%.2f', precio_centavos / 100.0) AS precio,
       stock_visto
  FROM producto_cache
 WHERE disponible = 1 AND eliminado = 0
 ORDER BY nombre;

-- ===========================================================================
-- 4. Caso C7: una cantidad en 0 y un producto inexistente dan error y no dejan filas nuevas.
-- ===========================================================================
SELECT (SELECT COUNT(*) FROM pedido_borrador) AS borradores_antes,
       (SELECT COUNT(*) FROM item_borrador)   AS items_antes;

BEGIN;

INSERT INTO pedido_borrador (id_local, usuario, forma_pago)
VALUES ('b007c000-0000-4000-8000-000000000000', 'feria-01', 'TRANSFERENCIA');

-- Error esperado: CHECK constraint failed: cantidad > 0
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
SELECT 'b007c000-0000-4000-8000-000000000000', id, 0, precio_centavos
  FROM producto_cache
 WHERE nombre = 'Muzzarella';

-- Error esperado: FOREIGN KEY constraint failed (el producto 9999 no está en producto_cache)
INSERT INTO item_borrador (id_local, producto_id, cantidad, precio_centavos_visto)
VALUES ('b007c000-0000-4000-8000-000000000000', 9999, 1, 100000);

-- Ninguna de las dos sentencias dejó una fila
SELECT COUNT(*) AS items_del_borrador_c7
  FROM item_borrador
 WHERE id_local = 'b007c000-0000-4000-8000-000000000000';

ROLLBACK;  -- el borrador quedó sin ítems: se descarta

SELECT (SELECT COUNT(*) FROM pedido_borrador) AS borradores_despues,
       (SELECT COUNT(*) FROM item_borrador)   AS items_despues;
