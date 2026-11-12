PRAGMA foreign_keys = ON;
-- Food Store — semaforo.sql (TP8, consigna 2.b · paradas 6 a 8)
-- Compara cada solicitud PENDIENTE con snapshot_servidor y guarda en cola_sync el estado y el motivo.
--   Rojo      RECHAZADO          algún producto no existe, no está disponible, fue dado de baja o no alcanza el stock
--   Amarillo  CONFLICTO          no hay rojo, pero cambió algún precio
--   Verde     SIMULADO_APROBADO  todo coincide. Es una simulación: NO es una venta ni descuenta stock
-- Solo se evalúan las PENDIENTE, así que repetir la simulación no cambia nada.
-- No se conecta a PostgreSQL ni lo modifica: solo lee la instantánea importada.
-- Límite conocido (code review, H8): cada solicitud se compara sola contra el stock de la instantánea;
-- dos solicitudes PENDIENTE que juntas superan el stock pueden salir las dos en verde. La protección real
-- está en el servidor al confirmar la venta: UPDATE ... SET stock = stock - n con CHECK (stock >= 0).
--   sqlite3 -header -table foodstore_movil.db < semaforo.sql

BEGIN;

WITH items AS (
    -- Un renglón por ítem de cada solicitud PENDIENTE, con el problema rojo y el amarillo (o NULL)
    SELECT c.solicitud_uuid,
           CASE
               WHEN i.producto_id IS NULL THEN 'el borrador no tiene ítems'
               WHEN s.id IS NULL          THEN 'el producto ' || i.producto_id || ' no existe en el servidor'
               WHEN s.eliminado = 't'     THEN s.nombre || ' fue dado de baja'
               WHEN s.disponible = 'f'    THEN s.nombre || ' no está disponible'
               WHEN i.cantidad > s.stock  THEN s.nombre || ': pide ' || i.cantidad || ' y quedan ' || s.stock
           END AS rojo,
           CASE
               WHEN i.precio_centavos_visto <> s.precio_centavos
               THEN s.nombre || ': precio visto ' || printf('%.2f', i.precio_centavos_visto / 100.0)
                    || ', precio actual ' || printf('%.2f', s.precio_centavos / 100.0)
           END AS amarillo
      FROM cola_sync c
      LEFT JOIN item_borrador     i ON i.id_local = c.id_local
      LEFT JOIN snapshot_servidor s ON s.id = i.producto_id
     WHERE c.estado = 'PENDIENTE'
),
evaluacion AS (
    -- Agrupado por solicitud: se cuentan los ítems con problemas
    SELECT solicitud_uuid,
           CASE WHEN COUNT(rojo) > 0     THEN 'RECHAZADO'
                WHEN COUNT(amarillo) > 0 THEN 'CONFLICTO'
                ELSE 'SIMULADO_APROBADO'
           END AS estado,
           CASE WHEN COUNT(rojo) > 0     THEN group_concat(rojo, '; ')
                WHEN COUNT(amarillo) > 0 THEN group_concat(amarillo, '; ')
                ELSE 'coincide con la instantánea (simulación: no es una venta)'
           END AS motivo
      FROM items
     GROUP BY solicitud_uuid
)
UPDATE cola_sync
   SET estado       = e.estado,
       motivo       = e.motivo,
       evaluada_con = (SELECT MAX(copiado_en) FROM snapshot_servidor)
  FROM evaluacion e
 WHERE cola_sync.solicitud_uuid = e.solicitud_uuid
   AND cola_sync.estado = 'PENDIENTE'
   AND EXISTS (SELECT 1 FROM snapshot_servidor);   -- sin instantánea no se evalúa nada

SELECT changes() AS solicitudes_evaluadas_en_esta_corrida;

COMMIT;

-- Estado de la cola (las más nuevas al final)
SELECT substr(solicitud_uuid, 1, 8) AS solicitud,
       substr(id_local, 1, 8)       AS borrador,
       estado,
       motivo
  FROM cola_sync
 ORDER BY rowid;
