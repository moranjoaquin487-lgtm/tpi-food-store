-- U5 · Parte C — Simulacro de incidente de acceso indebido (SOLO sobre la base propia de desarrollo)
--
-- Escenario: alguien obtuvo la contraseña de app_web (por ejemplo, de un archivo de
-- configuración del servidor web) y se conecta directamente a la base.
-- Lo ejecuta scripts/simulacro_incidente.sh, conectado como app_web.
-- No se corta ante errores: los rechazos son parte de lo que se quiere registrar.

\set ON_ERROR_STOP off

\echo '-- 1. Intentos fallidos de inicio de sesión contra fn_autenticar (fuerza bruta sobre una cuenta)'
SELECT * FROM fn_autenticar('usuario007@foodstore.test', '123456');
SELECT * FROM fn_autenticar('usuario007@foodstore.test', 'password');
SELECT * FROM fn_autenticar('usuario007@foodstore.test', 'foodstore');
SELECT * FROM fn_autenticar('usuario007@foodstore.test', 'Prueba-000');
SELECT * FROM fn_autenticar('usuario007@foodstore.test', 'Prueba-006');

\echo '-- 2. Inicio de sesión exitoso'
SELECT * FROM fn_autenticar('usuario007@foodstore.test', 'Prueba-007');

\echo '-- 3. Lectura masiva de la tabla usuario'
SELECT * FROM usuario;
SELECT id, nombre, apellido, mail FROM usuario;
SELECT * FROM vista_usuario_reportes;

\echo '-- 4. Intento de escalamiento de privilegios'
GRANT admin_datos TO rol_app_lectura;
GRANT admin_datos TO app_web;
SET ROLE admin_datos;
SELECT fn_resetear_password('usuario007@foodstore.test', 'Tomada-por-el-atacante');

\echo '-- Fin de la secuencia'
SELECT current_user AS sigue_siendo, session_user AS sesion;
