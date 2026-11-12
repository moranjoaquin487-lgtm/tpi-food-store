PRAGMA foreign_keys = ON;
-- Food Store — schema_sqlite.sql (TP8, consigna 1.b · paradas 3 y 4)
-- Base de la tablet del food truck. Crea todo desde cero sobre foodstore_movil.db:
--   sqlite3 foodstore_movil.db < schema_sqlite.sql
-- Regla de oro: el móvil propone, el servidor dispone. Estas tablas son una copia del catálogo y borradores;
-- precio, stock y ventas los decide PostgreSQL.
-- PRAGMA foreign_keys vale por conexión: cada script que escribe en esta base lo vuelve a activar.

DROP TABLE IF EXISTS cola_sync;
DROP TABLE IF EXISTS item_borrador;
DROP TABLE IF EXISTS pedido_borrador;
DROP TABLE IF EXISTS producto_cache;
DROP TABLE IF EXISTS snapshot_servidor;

-- Formato UUID v4 en minúsculas (8-4-4-4-12): lo usan id_local y solicitud_uuid.
-- (SQLite no deja reutilizar un CHECK con nombre entre tablas; el patrón se repite.)

-- ---------------------------------------------------------------------------
-- producto_cache: copia del catálogo del servidor. Solo la escribe cargar_snapshot.sql.
-- Las filas no se borran nunca: un producto dado de baja queda como lápida (eliminado = 1),
-- así los borradores viejos que lo usan siguen cumpliendo la clave foránea.
-- ---------------------------------------------------------------------------
CREATE TABLE producto_cache (
    id               INTEGER PRIMARY KEY,                                    -- el id del servidor
    nombre           TEXT    NOT NULL CHECK (length(trim(nombre)) > 0),
    precio_centavos  INTEGER NOT NULL CHECK (precio_centavos >= 0),           -- 1050,00 pesos = 105000
    stock_visto      INTEGER NOT NULL CHECK (stock_visto >= 0),               -- el stock de la copia, no el real
    disponible       INTEGER NOT NULL CHECK (disponible IN (0, 1)),
    eliminado        INTEGER NOT NULL CHECK (eliminado IN (0, 1)),
    copiado_en       TEXT    NOT NULL                                         -- fecha de la copia (UTC, ISO 8601)
                     CHECK (copiado_en GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T*Z'),
    CHECK (NOT (eliminado = 1 AND disponible = 1))                            -- una lápida no se ofrece
) STRICT;

-- ---------------------------------------------------------------------------
-- pedido_borrador: lo que arma el vendedor sin señal. No es una venta.
-- usuario es un código de quien carga el pedido (feria-01), no un mail ni un dato personal.
-- ---------------------------------------------------------------------------
CREATE TABLE pedido_borrador (
    id_local    TEXT NOT NULL PRIMARY KEY
                DEFAULT (lower(hex(randomblob(4)) || '-' || hex(randomblob(2)) || '-4' ||
                         substr(hex(randomblob(2)), 2) || '-' ||
                         substr('89ab', 1 + (abs(random()) % 4), 1) || substr(hex(randomblob(2)), 2) || '-' ||
                         hex(randomblob(6))))
                CHECK (id_local GLOB '[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]-4[0-9a-f][0-9a-f][0-9a-f]-[89ab][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]'),
    usuario     TEXT NOT NULL CHECK (length(trim(usuario)) > 0 AND usuario NOT LIKE '%@%'),  -- sin mails
    forma_pago  TEXT NOT NULL CHECK (forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')),
    fecha       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
) STRICT;

-- ---------------------------------------------------------------------------
-- item_borrador: una línea por producto, como detalle_pedido en el servidor.
-- precio_centavos_visto es el precio que vio el cliente; el semáforo lo compara con el actual.
-- ---------------------------------------------------------------------------
CREATE TABLE item_borrador (
    id_local               TEXT    NOT NULL REFERENCES pedido_borrador (id_local) ON DELETE CASCADE,
    producto_id            INTEGER NOT NULL REFERENCES producto_cache (id),
    cantidad               INTEGER NOT NULL CHECK (cantidad > 0),
    precio_centavos_visto  INTEGER NOT NULL CHECK (precio_centavos_visto >= 0),
    PRIMARY KEY (id_local, producto_id)
) STRICT;

CREATE INDEX idx_item_borrador_producto ON item_borrador (producto_id);

-- ---------------------------------------------------------------------------
-- cola_sync: cada envío de un borrador al servidor. La clave es el UUID de la solicitud
-- (clave de idempotencia): reenviar la misma solicitud choca con la clave primaria.
-- ---------------------------------------------------------------------------
CREATE TABLE cola_sync (
    solicitud_uuid  TEXT NOT NULL PRIMARY KEY
                    CHECK (solicitud_uuid GLOB '[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]-4[0-9a-f][0-9a-f][0-9a-f]-[89ab][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]'),
    id_local        TEXT NOT NULL REFERENCES pedido_borrador (id_local),
    estado          TEXT NOT NULL DEFAULT 'PENDIENTE'
                    CHECK (estado IN ('PENDIENTE', 'CONFLICTO', 'RECHAZADO', 'SIMULADO_APROBADO')),
    motivo          TEXT,
    creada_en       TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    evaluada_con    TEXT,                       -- fecha de la instantánea con la que la evaluó el semáforo
    CHECK ((estado = 'PENDIENTE') = (motivo IS NULL AND evaluada_con IS NULL))
) STRICT;

-- Un borrador no puede tener dos solicitudes PENDIENTE a la vez.
CREATE UNIQUE INDEX ux_cola_sync_una_pendiente ON cola_sync (id_local) WHERE estado = 'PENDIENTE';

-- Una solicitud ya evaluada no cambia más: repetir la simulación no la reevalúa.
CREATE TRIGGER trg_cola_sync_estado_final
BEFORE UPDATE ON cola_sync
WHEN OLD.estado <> 'PENDIENTE'
BEGIN
    SELECT RAISE(ABORT, 'La solicitud ya fue evaluada: su estado no cambia');
END;

-- Lo que se envió es lo que se evalúa: con una solicitud PENDIENTE, los ítems del borrador no se tocan.
CREATE TRIGGER trg_item_borrador_bloqueado_ins
BEFORE INSERT ON item_borrador
WHEN EXISTS (SELECT 1 FROM cola_sync WHERE id_local = NEW.id_local AND estado = 'PENDIENTE')
BEGIN
    SELECT RAISE(ABORT, 'El borrador tiene una solicitud PENDIENTE: no se pueden cambiar sus ítems');
END;

CREATE TRIGGER trg_item_borrador_bloqueado_upd
BEFORE UPDATE ON item_borrador
WHEN EXISTS (SELECT 1 FROM cola_sync WHERE id_local IN (OLD.id_local, NEW.id_local) AND estado = 'PENDIENTE')
BEGIN
    SELECT RAISE(ABORT, 'El borrador tiene una solicitud PENDIENTE: no se pueden cambiar sus ítems');
END;

CREATE TRIGGER trg_item_borrador_bloqueado_del
BEFORE DELETE ON item_borrador
WHEN EXISTS (SELECT 1 FROM cola_sync WHERE id_local = OLD.id_local AND estado = 'PENDIENTE')
BEGIN
    SELECT RAISE(ABORT, 'El borrador tiene una solicitud PENDIENTE: no se pueden cambiar sus ítems');
END;

-- ---------------------------------------------------------------------------
-- snapshot_servidor: la instantánea tal como viene del CSV de psql (booleanos 't'/'f').
-- La reemplaza cargar_snapshot.sql; el semáforo compara contra esta tabla.
-- ---------------------------------------------------------------------------
CREATE TABLE snapshot_servidor (
    id               INTEGER NOT NULL PRIMARY KEY,
    nombre           TEXT    NOT NULL,
    precio_centavos  INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock            INTEGER NOT NULL CHECK (stock >= 0),
    disponible       TEXT    NOT NULL CHECK (disponible IN ('t', 'f')),
    eliminado        TEXT    NOT NULL CHECK (eliminado IN ('t', 'f')),
    copiado_en       TEXT    NOT NULL
) STRICT;

-- Verificación: qué quedó creado
SELECT type AS tipo, name AS nombre, tbl_name AS tabla
  FROM sqlite_schema
 WHERE name NOT LIKE 'sqlite_%'
 ORDER BY CASE type WHEN 'table' THEN 1 WHEN 'index' THEN 2 ELSE 3 END, name;
PRAGMA foreign_keys;
