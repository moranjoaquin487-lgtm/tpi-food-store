-- U5 · roles.sql — Roles y permisos de Food Store con mínimo privilegio
--
-- Se ejecuta como postgres sobre la base del proyecto y se puede repetir: los roles se
-- crean si no existen y, antes de otorgar, se revoca todo lo anterior. Así, el resultado
-- es siempre exactamente lo que dice este archivo.
--
-- Las contraseñas NO se escriben acá. Después de correrlo, en psql:
--   \password app_web       \password admin_datos
--   \password usr_soporte   \password usr_reportes   \password usr_auditor
--
-- Justificación de cada rol (una oración cada uno):
--   rol_app_lectura   La tienda web muestra el catálogo y los pedidos: lee categorías, productos y pedidos, y nada con datos personales.
--   rol_app_escritura La tienda web registra ventas: inserta pedidos y sus líneas y descuenta stock, sin poder cambiar precios.
--   rol_soporte       La mesa de ayuda atiende a usuarios y clientes: los consulta sin ver contraseñas, corrige el celular o la baja, y resetea contraseñas solo con la función.
--   rol_reportes      El área comercial mira resultados agregados: lee vistas de ventas y la tabla anonimizada de usuarios, nunca datos personales.
--   rol_auditor       (adicional) Quien investiga un incidente lee los registros de auditoría, y ningún dato del negocio.
--   app_web           Login de la aplicación: lectura + escritura de la tienda y la función de autenticación.
--   admin_datos       Login del administrador de datos: todo sobre las tablas del esquema salvo modificar la auditoría, sin ser superusuario ni poder crear roles.
--   usr_soporte, usr_reportes, usr_auditor  (adicionales) Logins personales de cada área, para que el log diga quién hizo qué.

\set ON_ERROR_STOP on

-- 1. Crear los roles si no existen ------------------------------------------------
DO $$
DECLARE
    r TEXT;
BEGIN
    FOREACH r IN ARRAY ARRAY['rol_app_lectura', 'rol_app_escritura', 'rol_soporte', 'rol_reportes', 'rol_auditor'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
            EXECUTE format('CREATE ROLE %I NOLOGIN', r);
        END IF;
    END LOOP;
    FOREACH r IN ARRAY ARRAY['app_web', 'admin_datos', 'usr_soporte', 'usr_reportes', 'usr_auditor'] LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
            EXECUTE format('CREATE ROLE %I LOGIN', r);
        END IF;
    END LOOP;
END $$;

-- Ningún rol es superusuario ni puede crear roles o bases.
ALTER ROLE app_web      NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS CONNECTION LIMIT 20;
ALTER ROLE admin_datos  NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS CONNECTION LIMIT 3;
ALTER ROLE usr_soporte  NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS CONNECTION LIMIT 5;
ALTER ROLE usr_reportes NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS CONNECTION LIMIT 5;
ALTER ROLE usr_auditor  NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS CONNECTION LIMIT 2;

-- 2. Punto de partida limpio -------------------------------------------------------
DO $$
DECLARE
    r TEXT;
BEGIN
    FOREACH r IN ARRAY ARRAY['rol_app_lectura', 'rol_app_escritura', 'rol_soporte', 'rol_reportes', 'rol_auditor',
                             'app_web', 'admin_datos', 'usr_soporte', 'usr_reportes', 'usr_auditor'] LOOP
        EXECUTE format('REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM %I', r);
        EXECUTE format('REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM %I', r);
        EXECUTE format('REVOKE ALL ON ALL ROUTINES  IN SCHEMA public FROM %I', r);
        EXECUTE format('REVOKE ALL ON SCHEMA public FROM %I', r);
        EXECUTE format('REVOKE ALL ON DATABASE %I FROM %I', current_database(), r);
    END LOOP;
    -- Los permisos de columna no se van con REVOKE ALL ON ALL TABLES.
    EXECUTE 'REVOKE ALL (id, nombre, apellido, mail, celular, contrasena, rol, eliminado, created_at) ON usuario FROM rol_soporte';
    EXECUTE 'REVOKE ALL (stock) ON producto FROM rol_app_escritura';
END $$;

-- PUBLIC (todos los roles) no se conecta, no usa el esquema y no ejecuta funciones nuevas.
DO $$ BEGIN EXECUTE format('REVOKE ALL ON DATABASE %I FROM PUBLIC', current_database()); END $$;
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE EXECUTE ON ALL ROUTINES IN SCHEMA public FROM PUBLIC;

-- 3. Conexión y esquema ------------------------------------------------------------
DO $$
BEGIN
    EXECUTE format('GRANT CONNECT ON DATABASE %I TO app_web, admin_datos, usr_soporte, usr_reportes, usr_auditor',
                   current_database());
END $$;
GRANT USAGE ON SCHEMA public TO rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes, rol_auditor, admin_datos;

-- 4. Roles de grupo ------------------------------------------------------------------

-- rol_app_lectura: catálogo y pedidos (sin cliente ni usuario)
GRANT SELECT ON categoria, producto, pedido, detalle_pedido, vista_productos_vigentes TO rol_app_lectura;

-- rol_app_escritura: registrar ventas. UPDATE solo sobre la columna stock: la app no cambia precios.
GRANT INSERT ON pedido, detalle_pedido TO rol_app_escritura;
GRANT UPDATE (stock) ON producto TO rol_app_escritura;
GRANT EXECUTE ON PROCEDURE sp_registrar_pedido(BIGINT, forma_pago_enum, JSONB) TO rol_app_escritura;
GRANT EXECUTE ON FUNCTION  fn_total_pedido(BIGINT)                            TO rol_app_escritura;

-- rol_soporte: permisos de COLUMNA sobre usuario. Ve todo menos la contraseña y solo
-- corrige celular y baja. Para la contraseña usa fn_resetear_password.
GRANT SELECT (id, nombre, apellido, mail, celular, rol, eliminado, created_at) ON usuario TO rol_soporte;
GRANT UPDATE (celular, eliminado) ON usuario TO rol_soporte;
GRANT SELECT ON cliente TO rol_soporte;
GRANT EXECUTE ON FUNCTION fn_resetear_password(TEXT, TEXT) TO rol_soporte;

-- rol_reportes: solo vistas y agregados. vista_usuario_reportes (U3) NO se otorga:
-- oculta la contraseña, pero expone mail y celular. Para usuarios, usa usuario_anon (Parte D).
GRANT SELECT ON mv_facturacion_cat_mes, v_top5_categorias, vista_productos_vigentes,
                vista_detalle_pedido_producto TO rol_reportes;

-- rol_auditor: registros de auditoría.
GRANT SELECT ON auditoria_seguridad, auditoria_precio TO rol_auditor;

-- 5. Logins ------------------------------------------------------------------------------
GRANT rol_app_lectura, rol_app_escritura TO app_web;
GRANT EXECUTE ON FUNCTION fn_autenticar(TEXT, TEXT) TO app_web;     -- solo la app autentica

GRANT rol_soporte  TO usr_soporte;
GRANT rol_reportes TO usr_reportes;
GRANT rol_auditor  TO usr_auditor;

-- admin_datos: DML completo sobre los datos del esquema. No recibe TRUNCATE, REFERENCES ni
-- TRIGGER, no es dueño de los objetos y no tiene ADMIN OPTION sobre ningún rol.
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO admin_datos;
-- La auditoría es de solo lectura también para admin_datos (hallazgo #1 de la auditoría con
-- OpenCode, comprobado en evidencias/A_04): quien administra los datos no puede borrar ni
-- cambiar la evidencia de lo que hizo. Las filas las escriben fn_autenticar y el trigger
-- de precios, que son SECURITY DEFINER y corren como su dueño.
REVOKE INSERT, UPDATE, DELETE ON auditoria_seguridad, auditoria_precio FROM admin_datos;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO admin_datos;
GRANT EXECUTE ON ALL ROUTINES IN SCHEMA public TO admin_datos;

-- 6. Objetos futuros -----------------------------------------------------------------------
-- Lo que postgres cree de acá en adelante hereda la misma política: nadie recibe acceso
-- automático salvo admin_datos, y las funciones nuevas no quedan abiertas a PUBLIC.
-- El REVOKE va sin IN SCHEMA: los privilegios por esquema solo se SUMAN a los globales,
-- y el EXECUTE a PUBLIC es global. Con IN SCHEMA, el REVOKE no tendría efecto.
ALTER DEFAULT PRIVILEGES FOR ROLE postgres
    REVOKE EXECUTE ON ROUTINES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO admin_datos;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO admin_datos;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
    GRANT EXECUTE ON ROUTINES TO admin_datos;
