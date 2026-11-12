-- U5 · 01 — Autenticación de la aplicación: fn_autenticar y fn_resetear_password
-- Reconstrucción de las funciones de la Clase 2 (no se conservaban en el repositorio).
--
-- Decisiones:
--   * SECURITY DEFINER: corren con los permisos del dueño, así app_web puede validar una
--     contraseña sin tener permiso de lectura sobre usuario.contrasena.
--   * SET search_path fijo: evita que alguien cree un objeto con el mismo nombre en otro
--     esquema y la función lo use (ataque clásico a funciones SECURITY DEFINER).
--   * Cada intento queda en auditoria_seguridad (registro de rendición de cuentas) y,
--     además, en el log del servidor con RAISE LOG (registro técnico).
--   * EXECUTE se revoca de PUBLIC: por defecto, cualquier rol puede ejecutar una función.
--   * SET log_min_error_statement = 'panic': para el log del servidor, el nivel LOG está por
--     encima de ERROR, así que cada RAISE LOG agregaba la línea STATEMENT con la llamada
--     completa, es decir, con la contraseña en texto plano. Se detectó al probar el
--     simulacro (ver BITACORA.md). Con este ajuste, solo dentro de estas funciones, el log
--     registra el evento sin la sentencia.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS auditoria_seguridad (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    momento     TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    evento      TEXT        NOT NULL CHECK (evento IN ('LOGIN', 'RESET_PASSWORD')),
    exito       BOOLEAN     NOT NULL,
    mail        TEXT        NOT NULL,
    usuario_id  BIGINT,
    rol_bd      TEXT        NOT NULL DEFAULT session_user,
    origen      INET                 DEFAULT inet_client_addr()
);

-- Devuelve el usuario si el mail y la contraseña coinciden; si no, ninguna fila.
-- No distingue "mail inexistente" de "contraseña incorrecta" para no revelar qué mails existen.
CREATE OR REPLACE FUNCTION fn_autenticar(p_mail TEXT, p_contrasena TEXT)
RETURNS TABLE (usuario_id BIGINT, nombre TEXT, rol TEXT)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
SET log_min_error_statement = 'panic'
AS $$
DECLARE
    v_id     BIGINT;
    v_nombre TEXT;
    v_rol    TEXT;
    v_hash   TEXT;
BEGIN
    SELECT u.id, u.nombre, u.rol::TEXT, u.contrasena
      INTO v_id, v_nombre, v_rol, v_hash
      FROM usuario u
     WHERE lower(u.mail) = lower(p_mail) AND NOT u.eliminado;

    -- Solo se comparan hashes bcrypt; las contraseñas heredadas en otro formato no validan.
    IF v_hash LIKE '$2%' AND crypt(p_contrasena, v_hash) = v_hash THEN
        INSERT INTO auditoria_seguridad (evento, exito, mail, usuario_id)
        VALUES ('LOGIN', TRUE, p_mail, v_id);
        RAISE LOG 'fn_autenticar: inicio de sesion correcto mail=% usuario_id=%', p_mail, v_id;
        RETURN QUERY SELECT v_id, v_nombre, v_rol;
    ELSE
        INSERT INTO auditoria_seguridad (evento, exito, mail, usuario_id)
        VALUES ('LOGIN', FALSE, p_mail, v_id);
        RAISE LOG 'fn_autenticar: intento fallido mail=%', p_mail;
    END IF;
END $$;

-- Reemplaza la contraseña de un usuario. Reservada a soporte.
CREATE OR REPLACE FUNCTION fn_resetear_password(p_mail TEXT, p_nueva TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
SET log_min_error_statement = 'panic'
AS $$
DECLARE
    v_id BIGINT;
BEGIN
    IF length(p_nueva) < 10 THEN
        RAISE EXCEPTION 'La contraseña nueva debe tener al menos 10 caracteres';
    END IF;

    UPDATE usuario
       SET contrasena = crypt(p_nueva, gen_salt('bf', 10))
     WHERE lower(mail) = lower(p_mail) AND NOT eliminado
    RETURNING id INTO v_id;

    INSERT INTO auditoria_seguridad (evento, exito, mail, usuario_id)
    VALUES ('RESET_PASSWORD', v_id IS NOT NULL, p_mail, v_id);
    RAISE LOG 'fn_resetear_password: mail=% exito=%', p_mail, v_id IS NOT NULL;
    RETURN v_id IS NOT NULL;
END $$;

REVOKE ALL ON FUNCTION fn_autenticar(TEXT, TEXT)        FROM PUBLIC;
REVOKE ALL ON FUNCTION fn_resetear_password(TEXT, TEXT) FROM PUBLIC;

-- Funciones de trigger que escriben tablas internas (auditoría de precios de la U3 y
-- resumen de ventas de la U4). Si corrieran con los permisos de quien vende, habría que
-- darle a app_web permiso de escritura sobre esas tablas. Corriendo como dueño, no.
ALTER FUNCTION fn_auditar_precios()          SECURITY DEFINER SET search_path = public, pg_temp;
ALTER FUNCTION fn_resumen_detalle()          SECURITY DEFINER SET search_path = public, pg_temp;
ALTER FUNCTION fn_resumen_cambio_categoria() SECURITY DEFINER SET search_path = public, pg_temp;
-- Code review U4-U7, hallazgo #1: dentro de una función SECURITY DEFINER, current_user es el
-- dueño (postgres). Con el DEFAULT current_user de la U3, la auditoría de precios anotaba a
-- postgres en cada cambio. session_user es quien inició la sesión: app_web, admin_datos, etc.
ALTER TABLE auditoria_precio ALTER COLUMN usuario_bd SET DEFAULT session_user;
