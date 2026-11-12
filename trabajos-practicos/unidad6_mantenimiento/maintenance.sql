-- U6 — Revisión de mantenimiento y acción justificada
-- Uso: psql -d foodstore -f maintenance.sql
-- No usa VACUUM FULL. VACUUM no puede correr dentro de una transacción, así que este
-- archivo no se ejecuta con --single-transaction.

\echo '== 1. Configuración de autovacuum'
SELECT name, setting, unit FROM pg_settings
 WHERE name IN ('autovacuum', 'autovacuum_naptime', 'autovacuum_vacuum_threshold',
                'autovacuum_vacuum_scale_factor', 'autovacuum_analyze_threshold',
                'autovacuum_analyze_scale_factor')
 ORDER BY name;

\echo '== 2. Observación previa: estado de cada tabla'
SELECT relname AS tabla, n_live_tup AS vivas, n_dead_tup AS muertas,
       ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup, 0), 2) AS muertas_pct,
       n_mod_since_analyze AS modificadas_desde_analyze,
       COALESCE(last_autovacuum, last_vacuum)   AS ultimo_vacuum,
       COALESCE(last_autoanalyze, last_analyze) AS ultimo_analyze
  FROM pg_stat_user_tables
 ORDER BY n_dead_tup DESC;

\echo '== 3. Decisión: tablas que cumplen el criterio de SPEC_U6.md'
CREATE TEMP TABLE decision AS
SELECT relname AS tabla,
       CASE WHEN n_dead_tup > 1000 AND n_dead_tup > 0.10 * n_live_tup THEN 'VACUUM (ANALYZE)'
            WHEN n_mod_since_analyze > 0.10 * GREATEST(n_live_tup, 1) AND n_mod_since_analyze > 50 THEN 'ANALYZE'
       END AS accion,
       n_dead_tup AS muertas, n_live_tup AS vivas, n_mod_since_analyze AS modificadas
  FROM pg_stat_user_tables;
SELECT tabla, accion, muertas, vivas, modificadas
  FROM decision WHERE accion IS NOT NULL ORDER BY tabla;
SELECT CASE WHEN COUNT(*) = 0 THEN 'Ninguna tabla cumple el criterio: no se aplica mantenimiento manual.'
            ELSE COUNT(*) || ' tabla(s) cumplen el criterio.' END AS resultado
  FROM decision WHERE accion IS NOT NULL;

\echo '== 4. Acción (solo sobre las tablas elegidas en el paso 3)'
SELECT format('%s %I', accion, tabla) FROM decision WHERE accion IS NOT NULL ORDER BY tabla \gexec

\echo '== 5. Después de la acción'
SELECT s.relname AS tabla, s.n_dead_tup AS muertas, s.n_mod_since_analyze AS modificadas_desde_analyze,
       s.last_vacuum, s.last_analyze
  FROM pg_stat_user_tables s
  JOIN decision d ON d.tabla = s.relname
 WHERE d.accion IS NOT NULL
 ORDER BY 1;

\echo '== 6. Vista materializada de facturación (U3): se refresca con el mantenimiento semanal'
REFRESH MATERIALIZED VIEW mv_facturacion_cat_mes;
SELECT COUNT(*) AS filas_mv_facturacion FROM mv_facturacion_cat_mes;

\echo '== 7. Verificación de integridad'
\echo '   7.a Índices B-tree con amcheck (se espera 0 errores; si hay uno, bt_index_check lo informa con un ERROR)'
CREATE EXTENSION IF NOT EXISTS amcheck;
SELECT COUNT(*) AS indices_verificados
  FROM (SELECT bt_index_check(i.indexrelid)
          FROM pg_index i
          JOIN pg_class c ON c.oid = i.indexrelid
          JOIN pg_am am   ON am.oid = c.relam
         WHERE c.relnamespace = 'public'::regnamespace AND am.amname = 'btree' AND i.indisvalid) x;

\echo '   7.b Resumen desnormalizado de la U4 contra el cálculo real (se esperan 0 filas)'
SELECT * FROM fn_verificar_resumen_categoria();

\echo '   7.c Reglas lógicas (se espera 0 en las dos)'
SELECT (SELECT COUNT(*) FROM producto WHERE precio < 0 OR stock < 0)                  AS productos_invalidos,
       (SELECT COUNT(*) FROM detalle_pedido WHERE cantidad <= 0 OR precio_unitario < 0) AS detalles_invalidos;
