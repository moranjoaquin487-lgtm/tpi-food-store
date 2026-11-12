-- U4 · 05 — Las anomalías desaparecen en el esquema nuevo
-- Cada prueba corre dentro de BEGIN ... ROLLBACK: la base queda igual.

\echo '== Inserción: un responsable nuevo se registra sin inventar un lote'
BEGIN;
INSERT INTO usuario (nombre, apellido, mail, contrasena)
VALUES ('Responsable', 'Nuevo', 'responsable.nuevo@foodstore.test', '!');
INSERT INTO responsable_deposito (responsable_control_id, deposito_id)
SELECT id, (SELECT MAX(id) FROM deposito) FROM usuario WHERE mail = 'responsable.nuevo@foodstore.test';
SELECT rd.responsable_control_id, rd.deposito_id,
       (SELECT COUNT(*) FROM control_lote cl WHERE cl.responsable_control_id = rd.responsable_control_id) AS lotes
  FROM responsable_deposito rd
  JOIN usuario u ON u.id = rd.responsable_control_id
 WHERE u.mail = 'responsable.nuevo@foodstore.test';
ROLLBACK;

\echo '== Borrado: borrar todos los controles de un responsable no borra su depósito'
BEGIN;
CREATE TEMP TABLE _uno AS
SELECT responsable_control_id FROM control_lote
 GROUP BY 1 ORDER BY COUNT(*), 1 LIMIT 1;
DELETE FROM control_lote WHERE responsable_control_id = (SELECT responsable_control_id FROM _uno);
SELECT rd.* , 'sigue registrado' AS estado
  FROM responsable_deposito rd
 WHERE rd.responsable_control_id = (SELECT responsable_control_id FROM _uno);
ROLLBACK;

\echo '== Actualización: transferir un responsable toca una sola fila'
BEGIN;
-- Se elige un responsable y un depósito destino donde ninguno de sus lotes ya tenga control.
CREATE TEMP TABLE _traslado AS
SELECT rd.responsable_control_id, d.id AS deposito_destino,
       (SELECT COUNT(*) FROM control_lote cl
         WHERE cl.responsable_control_id = rd.responsable_control_id) AS lotes_que_controla
  FROM responsable_deposito rd
  CROSS JOIN deposito d
 WHERE d.id <> rd.deposito_id
   AND NOT EXISTS (SELECT 1
                     FROM control_lote cl
                     JOIN v_control_lote_almacen v ON v.lote_id = cl.lote_id
                    WHERE cl.responsable_control_id = rd.responsable_control_id
                      AND v.deposito_id = d.id)
 ORDER BY 1, 2
 LIMIT 1;
SELECT * FROM _traslado;
UPDATE responsable_deposito rd
   SET deposito_id = t.deposito_destino
  FROM _traslado t
 WHERE rd.responsable_control_id = t.responsable_control_id;
\echo '   (UPDATE 1: en la tabla heredada habría que tocar una fila por cada lote que controla)'
SELECT responsable_control_id, array_agg(DISTINCT deposito_id) AS depositos_en_la_reunion
  FROM v_control_lote_almacen
 WHERE responsable_control_id = (SELECT responsable_control_id FROM _traslado)
 GROUP BY 1;
ROLLBACK;

\echo '== Salvaguarda DF1: otro responsable del mismo depósito no puede controlar el mismo lote (se espera error)'
BEGIN;
INSERT INTO control_lote (lote_id, responsable_control_id)
SELECT v.lote_id, otro.responsable_control_id
  FROM v_control_lote_almacen v
  JOIN responsable_deposito otro
    ON otro.deposito_id = v.deposito_id
   AND otro.responsable_control_id <> v.responsable_control_id
 ORDER BY v.lote_id, otro.responsable_control_id
 LIMIT 1;
ROLLBACK;

\echo '== Un responsable de OTRO depósito sí puede controlar ese lote'
BEGIN;
INSERT INTO control_lote (lote_id, responsable_control_id)
SELECT v.lote_id, otro.responsable_control_id
  FROM v_control_lote_almacen v
  JOIN responsable_deposito otro ON otro.deposito_id <> v.deposito_id
 WHERE NOT EXISTS (SELECT 1 FROM v_control_lote_almacen w
                    WHERE w.lote_id = v.lote_id AND w.deposito_id = otro.deposito_id)
 ORDER BY v.lote_id, otro.responsable_control_id
 LIMIT 1;
SELECT 'insertado sin error' AS resultado;
ROLLBACK;
