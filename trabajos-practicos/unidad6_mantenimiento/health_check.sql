-- U6 — Chequeo de salud de foodstore (solo lectura)
-- Uso: psql -d foodstore -f health_check.sql

\echo '== 1. Tamaño de la base y de las tablas más grandes'
SELECT pg_size_pretty(pg_database_size(current_database())) AS tamano_base;
SELECT relname AS tabla,
       pg_size_pretty(pg_total_relation_size(relid)) AS total,
       pg_size_pretty(pg_relation_size(relid))       AS datos,
       pg_size_pretty(pg_indexes_size(relid))        AS indices
  FROM pg_stat_user_tables
 ORDER BY pg_total_relation_size(relid) DESC
 LIMIT 5;

\echo '== 2. Actividad de conexiones y transacciones'
SELECT numbackends AS conexiones, xact_commit, xact_rollback,
       ROUND(100.0 * blks_hit / NULLIF(blks_hit + blks_read, 0), 2) AS aciertos_cache_pct,
       deadlocks, temp_files
  FROM pg_stat_database
 WHERE datname = current_database();
SELECT usename AS usuario, COALESCE(state, 'sin estado') AS estado, COUNT(*) AS sesiones
  FROM pg_stat_activity
 WHERE datname = current_database()
 GROUP BY 1, 2 ORDER BY 1, 2;

\echo '== 3. Estado de las tablas (tuplas muertas, autovacuum y estadísticas)'
SELECT relname AS tabla, n_live_tup AS vivas, n_dead_tup AS muertas,
       ROUND(100.0 * n_dead_tup / NULLIF(n_live_tup, 0), 2) AS muertas_pct,
       n_mod_since_analyze AS modificadas_desde_analyze,
       ROUND(100.0 * n_mod_since_analyze / NULLIF(n_live_tup, 0), 2) AS modificadas_pct,  -- tomado de la versión de OpenCode
       last_autovacuum, last_autoanalyze, last_vacuum, last_analyze
  FROM pg_stat_user_tables
 ORDER BY n_dead_tup DESC;

\echo '== 4. Consultas activas (sin contar esta sesión)'
SELECT pid, usename AS usuario, state AS estado, now() - query_start AS duracion,
       left(query, 80) AS consulta
  FROM pg_stat_activity
 WHERE datname = current_database() AND state <> 'idle' AND pid <> pg_backend_pid()
 ORDER BY duracion DESC;

\echo '== 5. Transacciones abiertas hace más de 5 minutos (frenan a autovacuum)'
SELECT pid, usename AS usuario, state AS estado, now() - xact_start AS abierta_hace
  FROM pg_stat_activity
 WHERE datname = current_database() AND xact_start < now() - interval '5 minutes'
   AND pid <> pg_backend_pid();

\echo '== 6. Sesiones bloqueadas y quién las bloquea'
SELECT pid AS bloqueada, pg_blocking_pids(pid) AS bloqueada_por, left(query, 60) AS consulta
  FROM pg_stat_activity
 WHERE cardinality(pg_blocking_pids(pid)) > 0;
