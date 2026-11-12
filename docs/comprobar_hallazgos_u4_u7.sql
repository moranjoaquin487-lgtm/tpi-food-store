-- Code review U4-U7 — Comprobación en la base de los hallazgos #1, #7 y #10, antes y después
-- de corregirlos (docs/code_review_u4_u7.md). Se corre como postgres desde la raíz del repo.
-- Cada prueba va dentro de BEGIN ... ROLLBACK: no deja cambios.
\set ON_ERROR_STOP on

\echo '== #1 ¿Quién queda en auditoria_precio cuando admin_datos cambia un precio?'
SELECT prosecdef AS fn_auditar_precios_es_security_definer FROM pg_proc WHERE proname = 'fn_auditar_precios';
BEGIN;
\echo '-- Antes de corregir: DEFAULT current_user (dentro de la función, current_user es el dueño)'
ALTER TABLE auditoria_precio ALTER COLUMN usuario_bd SET DEFAULT current_user;
SET SESSION AUTHORIZATION admin_datos;
UPDATE producto SET precio = precio + 1 WHERE id_producto = 1;
RESET SESSION AUTHORIZATION;
SELECT usuario_bd AS registrado_con_la_version_anterior FROM auditoria_precio ORDER BY id DESC LIMIT 1;
\echo '-- Con la corrección: DEFAULT session_user'
ALTER TABLE auditoria_precio ALTER COLUMN usuario_bd SET DEFAULT session_user;
SET SESSION AUTHORIZATION admin_datos;
UPDATE producto SET precio = precio + 1 WHERE id_producto = 1;
RESET SESSION AUTHORIZATION;
SELECT usuario_bd AS registrado_con_la_correccion FROM auditoria_precio ORDER BY id DESC LIMIT 1;
ROLLBACK;
SELECT column_default AS default_actual_de_usuario_bd
  FROM information_schema.columns WHERE table_name = 'auditoria_precio' AND column_name = 'usuario_bd';

\echo '== #7 ¿01_estado_pedido.sql pisa un estado que cambió de verdad?'
BEGIN;
UPDATE pedido SET estado = 'PENDIENTE' WHERE id_pedido = 3;
\echo '-- Versión anterior (docs/code_review_u4_u7_antes/01_estado_pedido.sql)'
\i docs/code_review_u4_u7_antes/01_estado_pedido.sql
SELECT estado AS pedido_3_despues_de_la_version_anterior FROM pedido WHERE id_pedido = 3;
UPDATE pedido SET estado = 'PENDIENTE' WHERE id_pedido = 3;
\echo '-- Versión corregida (trabajos-practicos/unidad7_nosql/01_estado_pedido.sql)'
\i trabajos-practicos/unidad7_nosql/01_estado_pedido.sql
SELECT estado AS pedido_3_despues_de_la_version_corregida FROM pedido WHERE id_pedido = 3;
ROLLBACK;

\echo '== #10 Un GRANT a PUBLIC: ¿lo ve la verificación de permisos?'
BEGIN;
GRANT EXECUTE ON FUNCTION fn_total_pedido(BIGINT) TO PUBLIC;
\echo '-- Como la comparación anterior: solo roles con nombre (JOIN contra pg_roles)'
SELECT COUNT(*) AS lo_ve_la_comparacion_anterior
  FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a JOIN pg_roles r ON r.oid = a.grantee
 WHERE p.proname = 'fn_total_pedido' AND a.grantee = 0;
\echo '-- El control nuevo de verificacion_permisos.sql (grantee = 0, que es PUBLIC)'
SELECT p.proname || '()' AS objeto, a.privilege_type AS privilegio_para_public
  FROM pg_proc p CROSS JOIN LATERAL aclexplode(p.proacl) a
 WHERE p.pronamespace = 'public'::regnamespace AND a.grantee = 0;
ROLLBACK;
\echo '== Fin: todo se deshizo con ROLLBACK'
