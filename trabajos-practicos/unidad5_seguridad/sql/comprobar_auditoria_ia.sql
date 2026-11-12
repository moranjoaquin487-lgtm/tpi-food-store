-- U5 · Parte A.4 — Comprobación en la base de los hallazgos de OpenCode sobre roles.sql
-- (respuesta completa en docs/respuestas_ia/A_auditoria_roles.md; decisiones en BITACORA.md).
-- Se ejecuta como postgres. TODO corre dentro de BEGIN ... ROLLBACK: no cambia nada.
-- ON_ERROR_ROLLBACK hace que un error esperado no corte el resto de las pruebas.
\set ON_ERROR_ROLLBACK on
BEGIN;

\echo '== #1 ¿admin_datos puede borrar la auditoría? (antes de corregir roles.sql: sí, DELETE 6; después: permiso denegado)'
SET ROLE admin_datos;
SELECT COUNT(*) AS filas_auditoria_seguridad_antes FROM auditoria_seguridad;
DELETE FROM auditoria_seguridad;
SELECT COUNT(*) AS filas_auditoria_seguridad_despues FROM auditoria_seguridad;
RESET ROLE;

\echo '== #1 (segunda parte) La corrección de OpenCode para la contraseña: REVOKE de columna'
\echo '   Con un GRANT de tabla, revocar una columna no tiene efecto: admin_datos sigue leyendo contrasena'
REVOKE SELECT (contrasena), UPDATE (contrasena) ON usuario FROM admin_datos;
SELECT has_column_privilege('admin_datos', 'usuario', 'contrasena', 'SELECT') AS admin_datos_puede_leer_contrasena;
SET ROLE admin_datos;
SELECT COUNT(contrasena) AS contrasenas_que_lee_admin_datos FROM usuario;
RESET ROLE;

\echo '== #2 usuario_anon para rol_reportes: lo otorga usuario_anon.sql, que corre después de roles.sql'
SELECT has_table_privilege('rol_reportes', 'usuario_anon', 'SELECT') AS rol_reportes_lee_usuario_anon;

\echo '== #3 app_web lee los pedidos de todos los clientes (el hallazgo es real; ver la decisión en la bitácora)'
SET ROLE app_web;
SELECT COUNT(*) AS pedidos_visibles, COUNT(DISTINCT id_cliente) AS clientes_distintos FROM pedido;
RESET ROLE;

\echo '== #4 Secuencias: las claves son GENERATED ALWAYS AS IDENTITY'
SELECT attrelid::regclass AS tabla, attname AS columna, attidentity AS identity
  FROM pg_attribute
 WHERE attrelid IN ('pedido'::regclass, 'detalle_pedido'::regclass) AND attidentity <> '';
SELECT has_sequence_privilege('app_web', pg_get_serial_sequence('pedido', 'id_pedido'), 'USAGE') AS app_web_tiene_usage_en_la_secuencia;
\echo '   app_web inserta igual, sin permiso sobre la secuencia:'
SET ROLE app_web;
INSERT INTO pedido (forma_pago, id_cliente) VALUES ('EFECTIVO', 1) RETURNING id_pedido AS pedido_insertado_por_app_web;
RESET ROLE;
\echo '   Lo que otorgaría GRANT USAGE, SELECT ON ALL SEQUENCES: todas las secuencias del esquema'
SELECT COUNT(*) AS secuencias_en_public FROM pg_sequences WHERE schemaname = 'public';

\echo '== #5 rol_soporte puede dar de baja una cuenta ADMIN (el hallazgo es real)'
SET ROLE usr_soporte;
UPDATE usuario SET eliminado = true WHERE rol = 'ADMIN' AND NOT eliminado;
RESET ROLE;
SELECT COUNT(*) AS admins_dados_de_baja_por_soporte FROM usuario WHERE rol = 'ADMIN' AND eliminado;

\echo '== #6 ALTER DEFAULT PRIVILEGES ... REVOKE ALL ON TABLES/SEQUENCES FROM PUBLIC'
\echo '   Una tabla y una secuencia nuevas no le dan nada a PUBLIC: el REVOKE propuesto no cambia nada'
CREATE TABLE prueba_privilegios_por_defecto (x INT);
CREATE SEQUENCE prueba_secuencia_por_defecto;
CREATE FUNCTION prueba_funcion_por_defecto() RETURNS INT LANGUAGE sql AS 'SELECT 1';
SELECT c.relname AS objeto, COUNT(*) FILTER (WHERE a.grantee = 0) AS permisos_para_public,
       string_agg(DISTINCT pg_get_userbyid(a.grantee), ', ') FILTER (WHERE a.grantee <> 0) AS reciben_permisos
  FROM pg_class c CROSS JOIN LATERAL aclexplode(c.relacl) a
 WHERE c.relname IN ('prueba_privilegios_por_defecto', 'prueba_secuencia_por_defecto')
 GROUP BY c.relname;
SELECT has_function_privilege('usr_reportes', 'prueba_funcion_por_defecto()', 'EXECUTE') AS una_funcion_nueva_queda_abierta;

ROLLBACK;
\echo '== Fin: todo se deshizo con ROLLBACK'
