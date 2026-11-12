PRAGMA foreign_keys = ON;

-- Food Store — schema_sqlite.sql (TP8, tarea 2 · docs/kiro/tasks.md)
-- Base de la tablet (SQLite): una copia del catálogo para consultar sin señal (REQ-01),
-- los borradores de pedido que arma la tablet y la cola de solicitudes que viajan
-- al servidor cuando hay conexión. Regla de oro: el móvil propone, el servidor dispone.
-- Requisitos: REQ-01, REQ-02, REQ-06 y REQ-07 (las lápidas de REQ-08 se conservan en producto_cache).
-- Arranca con el PRAGMA en la primera línea: las claves foráneas quedan activadas antes de
-- tocar nada. Se puede correr de nuevo sobre una base existente: primero borra triggers,
-- índice y tablas (hijas antes que padres) y después crea todo.

-- Borrado previo: el orden importa porque con las claves foráneas activadas el DROP hace
-- un DELETE implícito y no puede quedar una tabla hija apuntando a una ya borrada.
DROP TRIGGER IF EXISTS trg_cola_sync_estado_final;
DROP TRIGGER IF EXISTS trg_item_borrador_bloqueado_insert;
DROP TRIGGER IF EXISTS trg_item_borrador_bloqueado_update;
DROP TRIGGER IF EXISTS trg_item_borrador_bloqueado_delete;
DROP INDEX IF EXISTS idx_cola_sync_un_pendiente_por_borrador;
DROP TABLE IF EXISTS item_borrador;    -- hija de pedido_borrador y producto_cache
DROP TABLE IF EXISTS cola_sync;        -- hija de pedido_borrador
DROP TABLE IF EXISTS pedido_borrador;
DROP TABLE IF EXISTS producto_cache;
DROP TABLE IF EXISTS snapshot_servidor;

-- Catálogo local (REQ-01): la tablet consulta solo esta tabla, nunca al servidor.
-- No se borran filas: lo que el servidor da de baja queda como lápida con eliminado = 1
-- (REQ-08), así no se rompen las claves foráneas de los borradores viejos.
CREATE TABLE IF NOT EXISTS producto_cache (
    id              INTEGER NOT NULL PRIMARY KEY,                    -- mismo id que producto en el servidor
    nombre          TEXT    NOT NULL,
    precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0),   -- NUMERIC(10,2) * 100: entero, sin redondeos binarios
    stock_visto     INTEGER NOT NULL CHECK (stock_visto >= 0),
    disponible      INTEGER NOT NULL CHECK (disponible IN (0, 1)),   -- booleano de la tablet: 0/1
    eliminado       INTEGER NOT NULL CHECK (eliminado IN (0, 1)),    -- 1 = lápida
    copiado_en      TEXT    NOT NULL                                  -- fecha de la instantánea que trajo la fila
                    CHECK (copiado_en GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]Z'),  -- AAAA-MM-DDThh:mm:ssZ
    CHECK (NOT (eliminado = 1 AND disponible = 1))
) STRICT;

-- Borrador de pedido: lo arma la tablet en la feria; todavía no es un pedido del servidor.
-- id_local se genera solo en la tablet con randomblob(): 32 hexadecimales en minúsculas
-- con el 4 de la versión y la variante 8, 9, a o b; el CHECK deja pasar solo eso.
CREATE TABLE IF NOT EXISTS pedido_borrador (
    id_local   TEXT NOT NULL PRIMARY KEY
               DEFAULT (lower(hex(randomblob(4))) || '-'
                        || lower(hex(randomblob(2))) || '-4'
                        || substr(lower(hex(randomblob(2))), 2) || '-'
                         || substr('89ab', 1 + (random() & 3), 1)
                        || substr(lower(hex(randomblob(2))), 2) || '-'
                        || lower(hex(randomblob(6))))
               CHECK (id_local GLOB '[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]-4[0-9a-f][0-9a-f][0-9a-f]-[89ab][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]'),
    usuario    TEXT NOT NULL
               -- código de quien carga el pedido (feria-01): ni vacío ni con '@';
               -- en la tablet no hay datos personales, así que tampoco mails
               CHECK (length(trim(usuario)) > 0 AND usuario NOT LIKE '%@%'),
    forma_pago TEXT NOT NULL
               CHECK (forma_pago IN ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA')),       -- mismo dominio que tipo_forma_pago
    fecha      TEXT NOT NULL DEFAULT (datetime('now'))
) STRICT;

-- Ítems del borrador: guardan el precio visto al armarlo, que es lo que el móvil propone.
CREATE TABLE IF NOT EXISTS item_borrador (
    id_local              TEXT    NOT NULL,
    producto_id           INTEGER NOT NULL,
    cantidad              INTEGER NOT NULL CHECK (cantidad > 0),                -- REQ-02: cantidad > 0
    precio_centavos_visto INTEGER NOT NULL CHECK (precio_centavos_visto >= 0),
    PRIMARY KEY (id_local, producto_id),                                         -- un producto, una vez por borrador
    FOREIGN KEY (id_local)    REFERENCES pedido_borrador (id_local),
    FOREIGN KEY (producto_id) REFERENCES producto_cache (id)                     -- REQ-02: tiene que estar en el catálogo local
) STRICT;

-- Cola de sincronización: una fila por solicitud que viaja al servidor.
-- solicitud_uuid es la clave de idempotencia: un reenvío con el mismo UUID choca contra la
-- clave primaria y no agrega filas a la cola (REQ-06).
CREATE TABLE IF NOT EXISTS cola_sync (
    solicitud_uuid TEXT NOT NULL PRIMARY KEY
                    CHECK (solicitud_uuid GLOB '[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f]-4[0-9a-f][0-9a-f][0-9a-f]-[89ab][0-9a-f][0-9a-f][0-9a-f]-[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]'),  -- mismo patrón que id_local
    id_local       TEXT NOT NULL,
    estado         TEXT NOT NULL DEFAULT 'PENDIENTE'
                    CHECK (estado IN ('PENDIENTE', 'CONFLICTO', 'RECHAZADO', 'SIMULADO_APROBADO')),
    motivo         TEXT,                     -- NULL mientras está PENDIENTE; lo llena el semáforo al evaluar
    evaluada_con   TEXT,                     -- fecha copiado_en de la instantánea con la que la evaluó el semáforo
                    CHECK ((estado = 'PENDIENTE' AND motivo IS NULL AND evaluada_con IS NULL)
                           OR (estado <> 'PENDIENTE' AND motivo IS NOT NULL AND evaluada_con IS NOT NULL)),  -- PENDIENTE: ambos NULL; evaluada: ambos NOT NULL
    FOREIGN KEY (id_local) REFERENCES pedido_borrador (id_local)
) STRICT;

-- Instantánea cruda del servidor (v_snapshot_movil exportada a CSV por psql): disponible y
-- eliminado viajan como texto 't'/'f' tal cual salen del CSV, no como 0/1. La carga
-- (cargar_snapshot.sql) la vuelca a producto_cache traduciendo los booleanos.
CREATE TABLE IF NOT EXISTS snapshot_servidor (
    id              INTEGER NOT NULL PRIMARY KEY,
    nombre          TEXT    NOT NULL,
    precio_centavos INTEGER NOT NULL CHECK (precio_centavos >= 0),
    stock           INTEGER NOT NULL CHECK (stock >= 0),
    disponible      TEXT    NOT NULL CHECK (disponible IN ('t', 'f')),   -- booleano de psql tal cual viene
    eliminado       TEXT    NOT NULL CHECK (eliminado IN ('t', 'f')),    -- 't' = lápida
    copiado_en      TEXT    NOT NULL
) STRICT;

-- Regla 1 (índice parcial único): un borrador no puede tener dos solicitudes PENDIENTE a la vez.
CREATE UNIQUE INDEX IF NOT EXISTS idx_cola_sync_un_pendiente_por_borrador
    ON cola_sync (id_local)
    WHERE estado = 'PENDIENTE';

-- Regla 2 (trigger de estado final): una solicitud ya evaluada no cambia en nada, ni el
-- estado ni el motivo ni ninguna otra columna (REQ-07); el semáforo solo escribe sobre
-- las PENDIENTE. El mensaje del RAISE es un literal: la concatenación en el mensaje
-- recién se puede desde SQLite 3.47 y la consigna pide 3.37.
CREATE TRIGGER IF NOT EXISTS trg_cola_sync_estado_final
BEFORE UPDATE ON cola_sync
FOR EACH ROW
WHEN OLD.estado <> 'PENDIENTE'
BEGIN
    SELECT RAISE(ABORT, 'La solicitud ya fue evaluada: su estado no cambia');
END;

-- Regla 3 (trigger de ítems bloqueados): mientras un borrador tiene una solicitud PENDIENTE,
-- sus ítems no se pueden cambiar ni borrar: lo que se envió es lo que el semáforo evalúa.
-- Mensajes fijos por lo mismo: literales, sin concatenar.
CREATE TRIGGER IF NOT EXISTS trg_item_borrador_bloqueado_insert
BEFORE INSERT ON item_borrador
FOR EACH ROW
WHEN EXISTS (SELECT 1 FROM cola_sync
              WHERE cola_sync.id_local = NEW.id_local
                AND cola_sync.estado = 'PENDIENTE')
BEGIN
    SELECT RAISE(ABORT, 'El borrador tiene una solicitud PENDIENTE: los ítems están bloqueados');
END;

CREATE TRIGGER IF NOT EXISTS trg_item_borrador_bloqueado_update
BEFORE UPDATE ON item_borrador
FOR EACH ROW
WHEN EXISTS (SELECT 1 FROM cola_sync
              WHERE cola_sync.estado = 'PENDIENTE'
                AND cola_sync.id_local IN (OLD.id_local, NEW.id_local))
BEGIN
    SELECT RAISE(ABORT, 'El borrador tiene una solicitud PENDIENTE: los ítems están bloqueados');
END;

CREATE TRIGGER IF NOT EXISTS trg_item_borrador_bloqueado_delete
BEFORE DELETE ON item_borrador
FOR EACH ROW
WHEN EXISTS (SELECT 1 FROM cola_sync
              WHERE cola_sync.id_local = OLD.id_local
                AND cola_sync.estado = 'PENDIENTE')
BEGIN
    SELECT RAISE(ABORT, 'El borrador tiene una solicitud PENDIENTE: los ítems están bloqueados');
END;
