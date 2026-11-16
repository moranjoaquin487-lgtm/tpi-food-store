-- Parte B · Verificación de las vistas contra las consultas escritas a mano (consultas_manuales.sql).
-- Para cada vista: cantidad de filas y EXCEPT en los dos sentidos (se espera 0 y 0).
-- Para la vista de seguridad: qué columnas expone y qué puede hacer rol_reportes.
\ir ../consultas_manuales.sql

\echo '######## V1 · v_productos_vigentes contra manual_v1'
SELECT (SELECT count(*) FROM v_productos_vigentes) AS filas_vista,
       (SELECT count(*) FROM manual_v1) AS filas_manual,
       (SELECT count(*) FROM (SELECT * FROM v_productos_vigentes EXCEPT SELECT * FROM manual_v1) a) AS vista_menos_manual,
       (SELECT count(*) FROM (SELECT * FROM manual_v1 EXCEPT SELECT * FROM v_productos_vigentes) b) AS manual_menos_vista;

\echo '######## V2 · v_pedidos_cliente contra manual_v2'
SELECT (SELECT count(*) FROM v_pedidos_cliente) AS filas_vista,
       (SELECT count(*) FROM manual_v2) AS filas_manual,
       (SELECT count(*) FROM (SELECT * FROM v_pedidos_cliente EXCEPT SELECT * FROM manual_v2) a) AS vista_menos_manual,
       (SELECT count(*) FROM (SELECT * FROM manual_v2 EXCEPT SELECT * FROM v_pedidos_cliente) b) AS manual_menos_vista;

\echo '######## V3 · v_detalle_pedido contra manual_v3'
SELECT (SELECT count(*) FROM v_detalle_pedido) AS filas_vista,
       (SELECT count(*) FROM manual_v3) AS filas_manual,
       (SELECT count(*) FROM (SELECT * FROM v_detalle_pedido EXCEPT SELECT * FROM manual_v3) a) AS vista_menos_manual,
       (SELECT count(*) FROM (SELECT * FROM manual_v3 EXCEPT SELECT * FROM v_detalle_pedido) b) AS manual_menos_vista;

\echo '######## V4 · v_usuario_publico contra manual_v4'
SELECT (SELECT count(*) FROM v_usuario_publico) AS filas_vista,
       (SELECT count(*) FROM manual_v4) AS filas_manual,
       (SELECT count(*) FROM (SELECT * FROM v_usuario_publico EXCEPT SELECT * FROM manual_v4) a) AS vista_menos_manual,
       (SELECT count(*) FROM (SELECT * FROM manual_v4 EXCEPT SELECT * FROM v_usuario_publico) b) AS manual_menos_vista;

\echo '######## Columnas que expone v_usuario_publico (no tiene que estar contrasena)'
SELECT ordinal_position, column_name
  FROM information_schema.columns
 WHERE table_schema = 'public' AND table_name = 'v_usuario_publico'
 ORDER BY ordinal_position;
\echo '######## Permisos de rol_reportes sobre objetos de la base'
SELECT table_name, privilege_type
  FROM information_schema.role_table_grants
 WHERE grantee = 'rol_reportes'
 ORDER BY table_name, privilege_type;
\echo '######## Prueba con SET ROLE rol_reportes'
SET ROLE rol_reportes;
SELECT current_user AS rol_actual;
\echo '== SELECT sobre la vista (tiene que funcionar)'
SELECT count(*) AS usuarios_visibles FROM v_usuario_publico;
\echo '== SELECT sobre la tabla usuario (tiene que fallar por falta de permisos)'
\set ON_ERROR_STOP 0
SELECT id, nombre FROM usuario LIMIT 1;
\set ON_ERROR_STOP 1
RESET ROLE;
\echo '== Fin de la prueba de permisos'
