PRAGMA foreign_keys = ON;
-- Food Store — cargar_snapshot.sql (TP8, consigna 2.a · parada 5)
-- Importa servidor_snapshot.csv en snapshot_servidor y con eso recarga producto_cache.
-- Usa .import, que es un comando de sqlite3: se corre desde la carpeta movil/.
--   sqlite3 -bail foodstore_movil.db < cargar_snapshot.sql
-- En DB Browser: Archivo → Importar → Tabla desde CSV, a una tabla nueva snapshot_csv con encabezado,
-- y después ejecutar desde el DELETE de abajo.
-- Todo va en una transacción: si la importación o un control fallan, -bail corta y no cambia nada.
.bail on

BEGIN;

-- .import llena las columnas por posición. Para no depender del orden de las columnas de la vista,
-- el CSV entra primero en una tabla de paso que .import crea con los nombres del encabezado,
-- y de ahí se copia a snapshot_servidor por nombre. Si falta o cambia una columna, el INSERT falla.
DROP TABLE IF EXISTS snapshot_csv;
.import --csv servidor_snapshot.csv snapshot_csv

DELETE FROM snapshot_servidor;
INSERT INTO snapshot_servidor (id, nombre, precio_centavos, stock, disponible, eliminado, copiado_en)
SELECT id, nombre, precio_centavos, stock, disponible, eliminado, copiado_en
  FROM snapshot_csv;
DROP TABLE snapshot_csv;

-- Controles: una instantánea vacía o mezclada no se usa (el CHECK falla y -bail corta antes del COMMIT).
CREATE TEMP TABLE control_instantanea (
    filas    INTEGER NOT NULL CHECK (filas > 0),
    copias   INTEGER NOT NULL CHECK (copias = 1)
);
INSERT INTO control_instantanea
SELECT COUNT(*), COUNT(DISTINCT copiado_en) FROM snapshot_servidor;

-- Recarga del catálogo: UPSERT. Nunca se borran filas; una baja queda como lápida.
INSERT INTO producto_cache (id, nombre, precio_centavos, stock_visto, disponible, eliminado, copiado_en)
SELECT id,
       nombre,
       precio_centavos,
       stock,
       CASE disponible WHEN 't' THEN 1 ELSE 0 END,
       CASE eliminado  WHEN 't' THEN 1 ELSE 0 END,
       copiado_en
  FROM snapshot_servidor
 WHERE TRUE                                   -- necesario para que SQLite lea bien el ON CONFLICT
    ON CONFLICT (id) DO UPDATE
   SET nombre          = excluded.nombre,
       precio_centavos = excluded.precio_centavos,
       stock_visto     = excluded.stock_visto,
       disponible      = excluded.disponible,
       eliminado       = excluded.eliminado,
       copiado_en      = excluded.copiado_en;

-- Un producto que ya no viene en la instantánea tampoco se ofrece: queda como lápida.
UPDATE producto_cache
   SET disponible = 0,
       eliminado  = 1,
       copiado_en = (SELECT MAX(copiado_en) FROM snapshot_servidor)
 WHERE id NOT IN (SELECT id FROM snapshot_servidor);

DROP TABLE control_instantanea;
COMMIT;

-- Qué quedó en la tablet
SELECT COUNT(*)                                   AS productos_en_cache,
       SUM(disponible = 1 AND eliminado = 0)      AS disponibles,
       SUM(eliminado = 1)                         AS lapidas,
       MAX(copiado_en)                            AS fecha_de_la_copia
  FROM producto_cache;
