-- U4 · 04 — Plan de reversión de la migración a BCNF
--
-- Vuelve al esquema heredado a partir de los datos ACTUALES de las tablas nuevas,
-- así no se pierden los cambios hechos después de migrar.
-- Los responsables que no controlan ningún lote no se pueden representar en la tabla
-- heredada (es la anomalía de inserción): se guardan aparte para no perderlos.
--
-- Uso:
--   psql -d foodstore -f 04_reversion_fnbc.sql                    -> ensayo (ROLLBACK)
--   psql -d foodstore -v accion=COMMIT -f 04_reversion_fnbc.sql   -> revierte de verdad

\set ON_ERROR_STOP on
\if :{?accion}
\else
  \set accion ROLLBACK
\endif
\echo '== Modo de ejecución:' :accion

BEGIN;

DO $$
BEGIN
    IF to_regclass('public.control_lote') IS NULL OR to_regclass('public.responsable_deposito') IS NULL THEN
        RAISE EXCEPTION 'No hay migración que revertir: faltan control_lote o responsable_deposito';
    END IF;
END $$;

-- 1. Recrear la tabla heredada con su PK y cargarla desde la reunión.
CREATE TABLE control_lote_almacen (
    lote_id                 BIGINT NOT NULL REFERENCES lote (id),
    deposito_id             BIGINT NOT NULL REFERENCES deposito (id),
    responsable_control_id  BIGINT NOT NULL REFERENCES usuario (id),
    PRIMARY KEY (lote_id, deposito_id)
);
INSERT INTO control_lote_almacen SELECT lote_id, deposito_id, responsable_control_id
                                   FROM v_control_lote_almacen;

-- 2. Responsables sin lotes: no entran en la tabla heredada.
CREATE TABLE reversion_responsables_sin_lote AS
SELECT rd.responsable_control_id, rd.deposito_id
  FROM responsable_deposito rd
 WHERE NOT EXISTS (SELECT 1 FROM control_lote cl
                    WHERE cl.responsable_control_id = rd.responsable_control_id);

\echo '== Verificación de la reversión'
SELECT (SELECT COUNT(*) FROM v_control_lote_almacen)          AS filas_en_tablas_nuevas,
       (SELECT COUNT(*) FROM control_lote_almacen)            AS filas_recuperadas,
       (SELECT COUNT(*) FROM reversion_responsables_sin_lote) AS responsables_sin_lote_guardados;

DO $$
BEGIN
    IF (SELECT COUNT(*) FROM control_lote_almacen) <> (SELECT COUNT(*) FROM v_control_lote_almacen) THEN
        RAISE EXCEPTION 'La reversión no recuperó todas las filas';
    END IF;
END $$;

-- 3. Quitar el esquema nuevo y el respaldo viejo.
DROP VIEW  v_control_lote_almacen;
DROP TABLE control_lote;
DROP TABLE responsable_deposito;
DROP FUNCTION fn_control_lote_df1();
DROP TABLE IF EXISTS control_lote_almacen_respaldo;

:accion;

\echo '== Estado después de' :accion
SELECT to_regclass('public.control_lote_almacen') AS tabla_heredada,
       to_regclass('public.responsable_deposito') AS r1,
       to_regclass('public.control_lote')         AS r2;
