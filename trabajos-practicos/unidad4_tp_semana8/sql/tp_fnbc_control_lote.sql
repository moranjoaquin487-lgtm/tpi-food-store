-- TP Unidad 4 · Parte 1 — FNBC sobre control_lote_almacen
-- Esquema original, instancia de ejemplo, validación de las DF, anomalías, tablas descompuestas,
-- vista de compatibilidad y migración verificada.
--
-- Se corre como postgres sobre una COPIA de la base Food Store (foodstore_tp4, ver ejecutar_tp_u4.sh).
-- Todo lo de la extensión mayorista va en el esquema tp4, para no mezclarse con el resto del proyecto.
-- Se puede volver a correr: arranca borrando lo que creó antes.
-- Abreviaturas: L = LoteID (lote_id), D = DepositoID (deposito_id), R = ResponsableControlID
-- (responsable_control_id).
\set ON_ERROR_STOP on

DROP SCHEMA IF EXISTS tp4 CASCADE;
CREATE SCHEMA tp4;
SET search_path TO tp4, public;

-- 1. Maestras de la extensión mayorista ---------------------------------------------------
-- La consigna las da por existentes. En la copia no están, así que se crean con lo mínimo.
CREATE TABLE lote     (id BIGINT PRIMARY KEY, descripcion TEXT NOT NULL);
CREATE TABLE deposito (id BIGINT PRIMARY KEY, nombre      TEXT NOT NULL);
INSERT INTO lote     VALUES (501, 'Lote 501'), (502, 'Lote 502'), (503, 'Lote 503');
INSERT INTO deposito VALUES (30, 'Depósito 30'), (31, 'Depósito 31'), (32, 'Depósito 32');

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;   -- ya existe desde la U5; por las dudas

-- Los responsables son usuarios de Food Store (REFERENCES usuario(id)). Se crean 801, 802 y 803
-- como usuarios de prueba, con datos inventados y una contraseña al azar que nadie conoce.
INSERT INTO public.usuario (id, nombre, apellido, mail, contrasena, rol)
OVERRIDING SYSTEM VALUE
SELECT r, 'Responsable', r::TEXT, 'responsable' || r || '@foodstore.test',
       crypt(gen_random_uuid()::TEXT, gen_salt('bf')), 'USUARIO'
  FROM unnest(ARRAY[801, 802, 803]) AS r
ON CONFLICT (id) DO NOTHING;

-- 2. Esquema original e instancia de ejemplo (tal como la consigna) -------------------------
CREATE TABLE control_lote_almacen (
    lote_id                BIGINT NOT NULL REFERENCES lote(id),
    deposito_id            BIGINT NOT NULL REFERENCES deposito(id),
    responsable_control_id BIGINT NOT NULL REFERENCES usuario(id),
    PRIMARY KEY (lote_id, deposito_id)
);
INSERT INTO control_lote_almacen VALUES
    (501, 30, 801),
    (502, 30, 801),
    (503, 31, 802);

\echo '== Instancia de ejemplo'
SELECT * FROM control_lote_almacen ORDER BY lote_id;

-- 3. a) Las DF, comprobadas sobre la instancia ------------------------------------------------
\echo '== DF1: {LoteID, DepositoID} -> ResponsableControlID (se esperan 0 violaciones)'
SELECT COUNT(*) AS violaciones_df1 FROM (
    SELECT lote_id, deposito_id FROM control_lote_almacen
     GROUP BY 1, 2 HAVING COUNT(DISTINCT responsable_control_id) > 1) x;
\echo '== DF2: ResponsableControlID -> DepositoID (se esperan 0 violaciones)'
SELECT COUNT(*) AS violaciones_df2 FROM (
    SELECT responsable_control_id FROM control_lote_almacen
     GROUP BY 1 HAVING COUNT(DISTINCT deposito_id) > 1) x;
\echo '== b) {ResponsableControlID} no es superclave: el responsable 801 aparece en dos filas'
SELECT responsable_control_id, COUNT(*) AS filas, array_agg(lote_id ORDER BY lote_id) AS lotes
  FROM control_lote_almacen GROUP BY 1 ORDER BY 1;
\echo '== b) {LoteID, ResponsableControlID} identifica cada fila (clave candidata, se espera 0)'
SELECT COUNT(*) AS repetidos FROM (
    SELECT lote_id, responsable_control_id FROM control_lote_almacen
     GROUP BY 1, 2 HAVING COUNT(*) > 1) x;

-- 4. d) Las tres anomalías, cada una dentro de BEGIN ... ROLLBACK ----------------------------
\echo '== d) Anomalía de actualización: 801 pasa al depósito 32, pero se cambia una sola de sus filas'
BEGIN;
UPDATE control_lote_almacen SET deposito_id = 32 WHERE lote_id = 501 AND responsable_control_id = 801;
SELECT responsable_control_id, array_agg(DISTINCT deposito_id) AS depositos
  FROM control_lote_almacen WHERE responsable_control_id = 801 GROUP BY 1;
ROLLBACK;

\echo '== d) Anomalía de inserción: el responsable 803 pertenece al depósito 31 pero no controló ningún lote'
\set ON_ERROR_STOP off
BEGIN;
INSERT INTO control_lote_almacen VALUES (NULL, 31, 803);
ROLLBACK;
\set ON_ERROR_STOP on

\echo '== d) Anomalía de borrado: se anula el control del lote 503 y se pierde que 802 es del depósito 31'
BEGIN;
DELETE FROM control_lote_almacen WHERE lote_id = 503;
SELECT COUNT(*) AS filas_que_dicen_el_deposito_de_802
  FROM control_lote_almacen WHERE responsable_control_id = 802;
ROLLBACK;

-- 5. e) Descomposición por la DF violatoria R -> D -----------------------------------------
-- R1(R, D) con clave R conserva R -> D. R2(L, R) con clave {L, R}. El atributo común es R.
CREATE TABLE responsable_deposito (
    responsable_control_id BIGINT PRIMARY KEY REFERENCES usuario(id),
    deposito_id            BIGINT NOT NULL    REFERENCES deposito(id)
);
CREATE TABLE control_lote (
    lote_id                BIGINT NOT NULL REFERENCES lote(id),
    responsable_control_id BIGINT NOT NULL REFERENCES responsable_deposito(responsable_control_id),
    PRIMARY KEY (lote_id, responsable_control_id)
);
-- Vista de compatibilidad: reconstruye la relación original con una reunión natural (por R).
CREATE VIEW v_control_lote_almacen AS
SELECT lote_id, deposito_id, responsable_control_id
  FROM control_lote NATURAL JOIN responsable_deposito;

-- La descomposición no preserva DF1 ({L, D} -> R): ninguna tabla tiene L y D juntos. Sin una
-- salvaguarda, dos responsables del mismo depósito podrían controlar el mismo lote. El trigger
-- busca en la reunión algún (L, D) repetido y rechaza la operación. El candado de transacción
-- evita que dos transacciones concurrentes pasen el control al mismo tiempo.
CREATE FUNCTION fn_control_lote_df1() RETURNS TRIGGER
LANGUAGE plpgsql SET search_path = tp4, public, pg_temp AS $$
DECLARE v_lote BIGINT; v_dep BIGINT;
BEGIN
    PERFORM pg_advisory_xact_lock(hashtext('tp4.control_lote_df1'));
    SELECT lote_id, deposito_id INTO v_lote, v_dep
      FROM v_control_lote_almacen GROUP BY 1, 2 HAVING COUNT(*) > 1 LIMIT 1;
    IF FOUND THEN
        RAISE EXCEPTION 'El lote % ya tiene un responsable del depósito % (DF1: {lote, depósito} -> responsable)',
                        v_lote, v_dep;
    END IF;
    RETURN NULL;
END $$;
CREATE TRIGGER trg_control_lote_df1 AFTER INSERT OR UPDATE ON control_lote
    FOR EACH STATEMENT EXECUTE FUNCTION fn_control_lote_df1();
CREATE TRIGGER trg_responsable_deposito_df1 AFTER UPDATE OF deposito_id ON responsable_deposito
    FOR EACH STATEMENT EXECUTE FUNCTION fn_control_lote_df1();

-- 6. f) Migración de la instancia, en una sola transacción y verificada ----------------------
BEGIN;
INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
SELECT DISTINCT responsable_control_id, deposito_id FROM control_lote_almacen;
INSERT INTO control_lote (lote_id, responsable_control_id)
SELECT lote_id, responsable_control_id FROM control_lote_almacen;
-- Si la reunión no da exactamente la relación original, se cancela todo.
DO $$
DECLARE v_perdidas INT; v_espurias INT;
BEGIN
    SELECT COUNT(*) INTO v_perdidas FROM (SELECT * FROM control_lote_almacen
                                          EXCEPT SELECT * FROM v_control_lote_almacen) x;
    SELECT COUNT(*) INTO v_espurias FROM (SELECT * FROM v_control_lote_almacen
                                          EXCEPT SELECT * FROM control_lote_almacen) x;
    IF v_perdidas + v_espurias > 0 THEN
        RAISE EXCEPTION 'La reunión no es equivalente: % perdidas, % espurias', v_perdidas, v_espurias;
    END IF;
END $$;
COMMIT;

\echo '== f) Verificación de la equivalencia con la vista de compatibilidad (se espera 0 y 0)'
SELECT (SELECT COUNT(*) FROM (SELECT * FROM control_lote_almacen
                              EXCEPT SELECT * FROM v_control_lote_almacen) x) AS tuplas_perdidas,
       (SELECT COUNT(*) FROM (SELECT * FROM v_control_lote_almacen
                              EXCEPT SELECT * FROM control_lote_almacen) x) AS tuplas_espurias;
\echo '== Tablas descompuestas'
SELECT * FROM responsable_deposito ORDER BY 1;
SELECT * FROM control_lote ORDER BY 1, 2;
\echo '== Reunión desde la vista de compatibilidad'
SELECT * FROM v_control_lote_almacen ORDER BY lote_id;

-- 7. Las anomalías sobre el esquema nuevo (dentro de BEGIN ... ROLLBACK) --------------------
\echo '== Inserción: 803 se registra en el depósito 31 sin haber controlado lotes'
\echo '== Actualización: el depósito de 801 cambia en una sola fila (UPDATE 1)'
\echo '== Borrado: se anula el control del lote 503 y el depósito de 802 sigue registrado'
BEGIN;
INSERT INTO responsable_deposito VALUES (803, 31);
UPDATE responsable_deposito SET deposito_id = 32 WHERE responsable_control_id = 801;
DELETE FROM control_lote WHERE lote_id = 503;
SELECT * FROM responsable_deposito ORDER BY 1;
SELECT * FROM v_control_lote_almacen ORDER BY lote_id;
ROLLBACK;

\echo '== DF1 en el esquema nuevo: el lote 501 se fracciona y lo controla también 802, del depósito 31 (se acepta)'
BEGIN;
INSERT INTO control_lote VALUES (501, 802);
SELECT * FROM v_control_lote_almacen WHERE lote_id = 501 ORDER BY deposito_id;
ROLLBACK;
\echo '== DF1 en el esquema nuevo: un segundo responsable del depósito 31 para el lote 503 (se espera ERROR)'
\set ON_ERROR_STOP off
BEGIN;
INSERT INTO responsable_deposito VALUES (803, 31);
INSERT INTO control_lote VALUES (503, 803);
ROLLBACK;
\set ON_ERROR_STOP on
