-- Food Store — semaforo.sql (TP8, tarea 5 · docs/kiro/tasks.md)
-- El semáforo: evalúa las solicitudes PENDIENTE contra la instantánea del servidor
-- (snapshot_servidor) y guarda en cola_sync el estado, el motivo y la fecha de la
-- instantánea usada (evaluada_con). Prioridad: RECHAZADO (rojo, REQ-04) > CONFLICTO
-- (amarillo, REQ-03) > SIMULADO_APROBADO (verde, REQ-05).
-- Es una simulación: no crea pedidos ni cambia el stock ni los precios del servidor.
-- La corrida va entre BEGIN y COMMIT: o se evalúan todas las PENDIENTE o ninguna, y
-- antes del COMMIT se muestra cuántas se evaluaron en esta corrida (changes()).
-- Requisitos: REQ-03, REQ-04, REQ-05 y REQ-07.

BEGIN;

WITH item_veredicto AS (
    -- Un veredicto por ítem de cada solicitud PENDIENTE. LEFT JOIN: el producto puede no
    -- estar en la instantánea, y el borrador puede no tener ítems. El nombre sale del
    -- catálogo local (producto_cache): el ítem siempre está ahí por la clave foránea,
    -- aunque el producto ya no viaje en la instantánea.
    SELECT c.solicitud_uuid,
           p.nombre,
           i.producto_id,
           i.cantidad,
           i.precio_centavos_visto,
           s.precio_centavos AS precio_actual,
           s.stock           AS stock_actual,
           CASE
               WHEN i.producto_id IS NULL THEN 'BORRADOR_VACIO'
               WHEN s.id IS NULL          THEN 'NO_EXISTE'      -- REQ-04: no está en la instantánea
               WHEN s.eliminado = 't'     THEN 'ELIMINADO'      -- REQ-04: lápida, dado de baja en el servidor
               WHEN s.disponible = 'f'    THEN 'NO_DISPONIBLE'  -- REQ-04: el servidor no lo ofrece
               WHEN i.cantidad > s.stock  THEN 'SIN_STOCK'      -- REQ-04: no alcanza el stock
               WHEN i.precio_centavos_visto <> s.precio_centavos THEN 'PRECIO_DISTINTO'  -- REQ-03
               ELSE 'OK'
           END AS veredicto
      FROM cola_sync AS c
      LEFT JOIN item_borrador AS i ON i.id_local = c.id_local
      LEFT JOIN producto_cache AS p ON p.id = i.producto_id
      LEFT JOIN snapshot_servidor AS s ON s.id = i.producto_id
     WHERE c.estado = 'PENDIENTE'                        -- REQ-07: solo se evalúa lo PENDIENTE
),
resumen AS (
    -- Conteos por solicitud y motivos para leer: nombre del producto (no el id) y precios
    -- en pesos con dos decimales; los centavos quedan para comparar, no para mostrar.
    SELECT solicitud_uuid,
           COUNT(producto_id) AS n_items,
           SUM(CASE WHEN veredicto IN ('NO_EXISTE', 'ELIMINADO', 'NO_DISPONIBLE', 'SIN_STOCK')
                    THEN 1 ELSE 0 END) AS n_rechazado,
           SUM(CASE WHEN veredicto = 'PRECIO_DISTINTO' THEN 1 ELSE 0 END) AS n_conflicto,
           GROUP_CONCAT(CASE veredicto
                            WHEN 'NO_EXISTE'     THEN nombre || ' no está en la instantánea'
                            WHEN 'ELIMINADO'     THEN nombre || ' fue dado de baja'
                            WHEN 'NO_DISPONIBLE' THEN nombre || ' no está disponible en el servidor'
                            WHEN 'SIN_STOCK'     THEN nombre || ': pide ' || cantidad || ' y quedan ' || stock_actual
                        END, '; ') AS motivos_rechazo,
           GROUP_CONCAT(CASE veredicto
                            WHEN 'PRECIO_DISTINTO' THEN nombre || ': precio visto '
                                                       || printf('%.2f', precio_centavos_visto / 100.0)
                                                       || ', precio actual '
                                                       || printf('%.2f', precio_actual / 100.0)
                        END, '; ') AS motivos_conflicto
      FROM item_veredicto
     GROUP BY solicitud_uuid
)
UPDATE cola_sync
   SET estado = CASE
                    WHEN r.n_items = 0     THEN 'RECHAZADO'     -- borrador sin ítems: no queda PENDIENTE para siempre
                    WHEN r.n_rechazado > 0 THEN 'RECHAZADO'     -- REQ-04: rojo primero
                    WHEN r.n_conflicto > 0 THEN 'CONFLICTO'     -- REQ-03: amarillo
                    ELSE 'SIMULADO_APROBADO'                    -- REQ-05: verde, solo simulación
                END,
       motivo = CASE
                    WHEN r.n_items = 0     THEN 'borrador sin ítems'
                    WHEN r.n_rechazado > 0 THEN r.motivos_rechazo
                    WHEN r.n_conflicto > 0 THEN r.motivos_conflicto
                    ELSE 'coincide con la instantánea (simulación: no es una venta)'
                END,
       evaluada_con = (SELECT MAX(copiado_en) FROM snapshot_servidor)   -- con qué instantánea se evaluó
  FROM resumen AS r
 WHERE cola_sync.solicitud_uuid = r.solicitud_uuid
   AND cola_sync.estado = 'PENDIENTE'                   -- REQ-07: lo ya evaluado queda sin cambios
   AND EXISTS (SELECT 1 FROM snapshot_servidor);   -- instantánea vacía: no se evalúa nada

-- Cuántas solicitudes dejó evaluadas esta corrida, antes de confirmar la transacción.
SELECT changes() AS solicitudes_evaluadas_en_esta_corrida;

COMMIT;

-- Cómo quedó la cola después de esta corrida.
SELECT substr(solicitud_uuid, 1, 8) AS solicitud,
       substr(id_local, 1, 8)       AS borrador,
       estado,
       motivo
  FROM cola_sync
 ORDER BY rowid;
