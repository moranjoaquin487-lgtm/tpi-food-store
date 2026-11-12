-- U5 · Parte D.2 — Las dos consultas de OpenCode (docs/respuestas_ia/D_consultas.md),
-- tal como las propuso, comparadas con las de referencia (sql/equivalencia_agregados.sql).
-- Solo lee: no cambia nada. Todo en la misma sesión, porque el mes de un TIMESTAMPTZ
-- depende de la zona horaria.
SHOW TimeZone;

\echo '== Consulta 1 de OpenCode: usuario_anon'
SELECT rol,
       to_char(mes_alta, 'YYYY-MM') AS mes,
       COUNT(*) AS cantidad
FROM usuario_anon
GROUP BY rol, to_char(mes_alta, 'YYYY-MM')
ORDER BY rol, mes;

\echo '== Consulta 2 de OpenCode: usuario'
SELECT rol,
       to_char(created_at, 'YYYY-MM') AS mes,
       COUNT(*) AS cantidad
FROM usuario
GROUP BY rol, to_char(created_at, 'YYYY-MM')
ORDER BY rol, mes;

\echo '== ¿Las dos de OpenCode dan lo mismo entre sí? (se espera 0)'
WITH o1 AS (SELECT rol, to_char(mes_alta, 'YYYY-MM') AS mes, COUNT(*) AS cantidad
              FROM usuario_anon GROUP BY rol, to_char(mes_alta, 'YYYY-MM')),
     o2 AS (SELECT rol, to_char(created_at, 'YYYY-MM') AS mes, COUNT(*) AS cantidad
              FROM usuario GROUP BY rol, to_char(created_at, 'YYYY-MM'))
SELECT (SELECT COUNT(*) FROM (SELECT * FROM o1 EXCEPT SELECT * FROM o2) x)
     + (SELECT COUNT(*) FROM (SELECT * FROM o2 EXCEPT SELECT * FROM o1) y) AS filas_distintas;

\echo '== ¿Coinciden con las de referencia? (se espera 0 y 0)'
WITH o2  AS (SELECT rol, to_char(created_at, 'YYYY-MM') AS mes, COUNT(*) AS cantidad
               FROM usuario GROUP BY rol, to_char(created_at, 'YYYY-MM')),
     ref AS (SELECT rol, to_char(date_trunc('month', created_at), 'YYYY-MM') AS mes, COUNT(*) AS cantidad
               FROM usuario GROUP BY 1, 2)
SELECT (SELECT COUNT(*) FROM (SELECT * FROM o2 EXCEPT SELECT * FROM ref) x) AS de_mas_en_opencode,
       (SELECT COUNT(*) FROM (SELECT * FROM ref EXCEPT SELECT * FROM o2) y) AS de_menos_en_opencode;

\echo '== La advertencia de OpenCode sobre la zona horaria: con UTC, ¿cambia algún grupo?'
WITH sesion AS (SELECT rol, to_char(created_at, 'YYYY-MM') AS mes, COUNT(*) AS cantidad
                  FROM usuario GROUP BY 1, 2),
     utc    AS (SELECT rol, to_char(created_at AT TIME ZONE 'UTC', 'YYYY-MM') AS mes, COUNT(*) AS cantidad
                  FROM usuario GROUP BY 1, 2)
SELECT (SELECT COUNT(*) FROM (SELECT * FROM sesion EXCEPT SELECT * FROM utc) x)
     + (SELECT COUNT(*) FROM (SELECT * FROM utc EXCEPT SELECT * FROM sesion) y) AS grupos_que_cambian_con_utc;
