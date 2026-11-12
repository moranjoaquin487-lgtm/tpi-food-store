-- U4 · 02 — Validación de las dependencias funcionales sobre los datos reales
-- Antes de refactorizar, se comprueba en la instancia qué DF se cumplen y cuáles no.
-- Abreviaturas: L = lote_id, D = deposito_id, R = responsable_control_id.

\echo '== Volumen de la tabla heredada'
SELECT COUNT(*) AS filas,
       COUNT(DISTINCT lote_id) AS lotes,
       COUNT(DISTINCT deposito_id) AS depositos,
       COUNT(DISTINCT responsable_control_id) AS responsables
  FROM control_lote_almacen;

\echo '== DF1 {L, D} -> R: grupos (L, D) con más de un responsable (se espera 0)'
SELECT COUNT(*) AS violaciones_df1
  FROM (SELECT lote_id, deposito_id
          FROM control_lote_almacen
         GROUP BY 1, 2
        HAVING COUNT(DISTINCT responsable_control_id) > 1) v;

\echo '== DF2 R -> D: responsables que aparecen en más de un depósito (se espera 0)'
SELECT COUNT(*) AS violaciones_df2
  FROM (SELECT responsable_control_id
          FROM control_lote_almacen
         GROUP BY 1
        HAVING COUNT(DISTINCT deposito_id) > 1) v;

\echo '== L -> D no se cumple: lotes controlados desde más de un depósito (se espera > 0)'
SELECT COUNT(*) AS lotes_en_varios_depositos
  FROM (SELECT lote_id FROM control_lote_almacen
         GROUP BY 1 HAVING COUNT(DISTINCT deposito_id) > 1) v;

\echo '== L -> R no se cumple: lotes con más de un responsable (se espera > 0)'
SELECT COUNT(*) AS lotes_con_varios_responsables
  FROM (SELECT lote_id FROM control_lote_almacen
         GROUP BY 1 HAVING COUNT(DISTINCT responsable_control_id) > 1) v;

\echo '== {L, R} también es clave: grupos (L, R) repetidos (se espera 0)'
SELECT COUNT(*) AS repetidos_l_r
  FROM (SELECT lote_id, responsable_control_id
          FROM control_lote_almacen
         GROUP BY 1, 2 HAVING COUNT(*) > 1) v;

\echo '== Redundancia: cuántas veces se repite el dato "R pertenece a D"'
SELECT COUNT(*) AS filas,
       COUNT(DISTINCT (responsable_control_id, deposito_id)) AS hechos_distintos,
       COUNT(*) - COUNT(DISTINCT (responsable_control_id, deposito_id)) AS repeticiones
  FROM control_lote_almacen;

\echo '== Anomalía de actualización (dentro de BEGIN ... ROLLBACK)'
\echo '   Se cambia el depósito del responsable en una sola de sus filas.'
BEGIN;
UPDATE control_lote_almacen
   SET deposito_id = (SELECT MAX(id) FROM deposito)
 WHERE (lote_id, deposito_id) = (SELECT lote_id, deposito_id
                                   FROM control_lote_almacen
                                  WHERE responsable_control_id = (SELECT MIN(responsable_control_id) FROM control_lote_almacen)
                                    AND deposito_id <> (SELECT MAX(id) FROM deposito)
                                  ORDER BY lote_id LIMIT 1);
SELECT responsable_control_id, array_agg(DISTINCT deposito_id) AS depositos
  FROM control_lote_almacen
 WHERE responsable_control_id = (SELECT MIN(responsable_control_id) FROM control_lote_almacen)
 GROUP BY 1;
\echo '   El mismo responsable quedó en dos depósitos: la tabla heredada no impide violar R2.'
ROLLBACK;

\echo '== Anomalía de inserción: un responsable nuevo sin lotes no se puede registrar'
\echo '   (lote_id es parte de la PK y no admite NULL; se espera error)'
BEGIN;
INSERT INTO control_lote_almacen (lote_id, deposito_id, responsable_control_id)
VALUES (NULL, (SELECT MIN(id) FROM deposito), (SELECT MIN(id) FROM usuario));
ROLLBACK;
