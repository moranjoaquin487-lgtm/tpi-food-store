-- health_check.sql
-- Chequeo de salud diario para Food Store (PostgreSQL 16+).
-- Uso sugerido: psql -d foodstore -f health_check.sql -o logs/health_check_AAAAMMDD_HHMMSS.log

\set ON_ERROR_STOP on
\timing on

SELECT now() AS checked_at,
       current_database() AS database,
       version() AS postgres_version;

-- Conexiones y estado
SELECT state, count(*) AS connections
FROM pg_stat_activity
WHERE datname = current_database()
GROUP BY state
ORDER BY state;

-- Tamaño de la base
SELECT pg_size_pretty(pg_database_size(current_database())) AS database_size;

-- Actividad de tablas de usuario
SELECT schemaname,
       relname,
       n_live_tup,
       n_dead_tup,
       last_vacuum,
       last_autovacuum,
       last_analyze,
       last_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC, relname;

-- Estadísticas de autovacuum/analyze pendientes aproximadas
SELECT schemaname,
       relname,
       n_mod_since_analyze,
       CASE WHEN n_live_tup > 0
            THEN round((n_mod_since_analyze::numeric / n_live_tup::numeric) * 100, 2)
            ELSE NULL
       END AS pct_modified_since_analyze
FROM pg_stat_user_tables
ORDER BY n_mod_since_analyze DESC, relname;

-- Operaciones de I/O y bloqueos simples
SELECT count(*) AS locks_total
FROM pg_locks l
JOIN pg_database d ON d.oid = l.database
WHERE d.datname = current_database();
