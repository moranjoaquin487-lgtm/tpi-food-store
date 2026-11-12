-- U5 · Parte B — Activación de la auditoría nativa del servidor
-- Se ejecuta como postgres. ALTER SYSTEM escribe en postgresql.auto.conf y no se puede
-- correr dentro de una transacción.

\echo '== Valores ANTES del cambio'
SELECT name, setting, context FROM pg_settings
 WHERE name IN ('logging_collector', 'log_destination', 'log_directory', 'log_connections',
                'log_disconnections', 'log_statement', 'log_line_prefix', 'log_min_error_statement',
                'log_file_mode')
 ORDER BY name;

ALTER SYSTEM SET log_connections         = 'on';      -- quién se conecta, desde dónde y si se autentica
ALTER SYSTEM SET log_disconnections      = 'on';      -- cuándo termina cada sesión y cuánto duró
ALTER SYSTEM SET log_statement           = 'mod';     -- DDL e INSERT/UPDATE/DELETE/TRUNCATE/COPY FROM
ALTER SYSTEM SET log_min_error_statement = 'error';   -- texto de toda sentencia que falla
-- Prefijo: hora con milisegundos, PID, usuario@base, origen (IP y puerto) y aplicación.
ALTER SYSTEM SET log_line_prefix         = '%m [%p] %q%u@%d %r app=%a ';

SELECT pg_reload_conf();
SELECT pg_sleep(1);

-- log_connections y log_disconnections rigen para las sesiones nuevas: se abre una.
\c
\echo '== Valores DESPUÉS del cambio (en una sesión nueva)'
SELECT name, setting FROM pg_settings
 WHERE name IN ('logging_collector', 'log_connections', 'log_disconnections', 'log_statement',
                'log_line_prefix', 'log_min_error_statement')
 ORDER BY name;

\echo '== Archivo de log actual (si sale vacío, logging_collector está apagado: ver PASOS.md)'
SELECT pg_current_logfile() AS archivo_de_log;
