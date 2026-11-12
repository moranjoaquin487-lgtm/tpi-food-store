-- U5 · Parte D — Verificación de equivalencia de los agregados
-- Consulta 1 (sobre usuario_anon) y consulta 2 (la equivalente sobre usuario):
-- cantidad de usuarios por rol y por mes de alta.
-- Las dos se corren en la misma sesión: el mes de un TIMESTAMPTZ depende de la zona horaria.

\echo '== Consulta 1: usuario_anon'
SELECT rol, to_char(mes_alta, 'YYYY-MM') AS mes_alta, COUNT(*) AS usuarios
  FROM usuario_anon
 GROUP BY 1, 2
 ORDER BY 1, 2;

\echo '== Consulta 2: usuario (tabla real)'
SELECT rol, to_char(date_trunc('month', created_at), 'YYYY-MM') AS mes_alta, COUNT(*) AS usuarios
  FROM usuario
 GROUP BY 1, 2
 ORDER BY 1, 2;

\echo '== Lado a lado'
WITH a AS (SELECT rol, to_char(mes_alta, 'YYYY-MM') AS mes_alta, COUNT(*) AS n
             FROM usuario_anon GROUP BY 1, 2),
     r AS (SELECT rol, to_char(date_trunc('month', created_at), 'YYYY-MM') AS mes_alta, COUNT(*) AS n
             FROM usuario GROUP BY 1, 2)
SELECT COALESCE(r.rol, a.rol) AS rol, COALESCE(r.mes_alta, a.mes_alta) AS mes_alta,
       r.n AS usuarios_real, a.n AS usuarios_anon,
       CASE WHEN r.n IS NOT DISTINCT FROM a.n THEN 'sí' ELSE 'NO' END AS coincide
  FROM r FULL JOIN a ON a.rol = r.rol AND a.mes_alta = r.mes_alta
 ORDER BY 1, 2;

\echo '== Resumen (se espera: 0 grupos distintos y el mismo total)'
WITH a AS (SELECT rol, mes_alta AS mes, COUNT(*) AS n FROM usuario_anon GROUP BY 1, 2),
     r AS (SELECT rol, date_trunc('month', created_at)::DATE AS mes, COUNT(*) AS n FROM usuario GROUP BY 1, 2)
SELECT (SELECT COUNT(*) FROM ((SELECT * FROM r EXCEPT SELECT * FROM a)
                              UNION ALL (SELECT * FROM a EXCEPT SELECT * FROM r)) d) AS grupos_distintos,
       (SELECT COUNT(*) FROM usuario)      AS total_real,
       (SELECT COUNT(*) FROM usuario_anon) AS total_anon;
