# Auditoría de mínimo privilegio en roles.sql

> Exportación de la sesión de OpenCode (agente Plan, modelo Big Pickle) con `/export`, sin cambios salvo una: se quitaron las dos líneas del encabezado con la fecha y la hora. Las decisiones están en [`../../BITACORA.md`](../../BITACORA.md).

**Session ID:** ses_e2fdb53b4ffebeGUCig0TsD59F

---

## User

Auditá el archivo sql/roles.sql de este proyecto (PostgreSQL 16+, base Food Store).
Quiero que revises si cada rol cumple el principio de mínimo privilegio y que propongas
mejoras o correcciones concretas, con la sentencia SQL de cada una. No ejecutes nada
contra la base: solo leé el archivo y respondé. 

---

## Assistant (Plan · Big Pickle · 19.6s)

_Thinking:_

**Reviewing roles.sql**

The user wants me to audit the `sql/roles.sql` file to check if each role follows the least privilege principle and suggest improvements. I’m not supposed to execute anything, just read and respond. The system reminder says I’m in read-only mode, so I’ll stick to that. First, I’ll locate and read the `sql/roles.sql` file in the working directory `C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad5_seguridad`. Time to start by reading the file.

**Tool: read**

**Input:**
```json
{
  "filePath": "C:\\Users\\moran\\BD2\\tpi-food-store\\trabajos-practicos\\unidad5_seguridad\\sql\\roles.sql"
}
```

**Output:**
```
<path>C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad5_seguridad\sql\roles.sql</path>
<type>file</type>
<content>
1: -- U5 · roles.sql — Roles y permisos de Food Store con mínimo privilegio
2: --
3: -- Se ejecuta como postgres sobre la base del proyecto y se puede repetir: los roles se
4: -- crean si no existen y, antes de otorgar, se revoca todo lo anterior. Así, el resultado
5: -- es siempre exactamente lo que dice este archivo.
6: --
7: -- Las contraseñas NO se escriben acá. Después de correrlo, en psql:
8: --   \password app_web       \password admin_datos
9: --   \password usr_soporte   \password usr_reportes   \password usr_auditor
10: --
11: -- Justificación de cada rol (una oración cada uno):
12: --   rol_app_lectura   La tienda web muestra el catálogo y los pedidos: lee categorías, productos y pedidos, y nada con datos personales.
13: --   rol_app_escritura La tienda web registra ventas: inserta pedidos y sus líneas y descuenta stock, sin poder cambiar precios.
14: --   rol_soporte       La mesa de ayuda atiende a usuarios y clientes: los consulta sin ver contraseñas, corrige el celular o la baja, y resetea contraseñas solo con la función.
15: --   rol_reportes      El área comercial mira resultados agregados: lee vistas de ventas y la tabla anonimizada de usuarios, nunca datos personales.
16: --   rol_auditor       (adicional) Quien investiga un incidente lee los registros de auditoría, y ningún dato del negocio.
17: --   app_web           Login de la aplicación: lectura + escritura de la tienda y la función de autenticación.
18: --   admin_datos       Login del administrador de datos: todo sobre las tablas del esquema, sin ser superusuario ni poder crear roles.
19: --   usr_soporte, usr_reportes, usr_auditor  (adicionales) Logins personales de cada área, para que el log diga quién hizo qué.
20: 
21: \set ON_ERROR_STOP on
22: 
23: -- 1. Crear los roles si no existen ------------------------------------------------
24: DO $$
25: DECLARE
26:     r TEXT;
27: BEGIN
28:     FOREACH r IN ARRAY ARRAY['rol_app_lectura', 'rol_app_escritura', 'rol_soporte', 'rol_reportes', 'rol_auditor'] LOOP
29:         IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
30:             EXECUTE format('CREATE ROLE %I NOLOGIN', r);
31:         END IF;
32:     END LOOP;
33:     FOREACH r IN ARRAY ARRAY['app_web', 'admin_datos', 'usr_soporte', 'usr_reportes', 'usr_auditor'] LOOP
34:         IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = r) THEN
35:             EXECUTE format('CREATE ROLE %I LOGIN', r);
36:         END IF;
37:     END LOOP;
38: END $$;
39: 
40: -- Ningún rol es superusuario ni puede crear roles o bases.
41: ALTER ROLE app_web      NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS CONNECTION LIMIT 20;
42: ALTER ROLE admin_datos  NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS CONNECTION LIMIT 3;
43: ALTER ROLE usr_soporte  NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS CONNECTION LIMIT 5;
44: ALTER ROLE usr_reportes NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS CONNECTION LIMIT 5;
45: ALTER ROLE usr_auditor  NOSUPERUSER NOCREATEDB NOCREATEROLE NOBYPASSRLS CONNECTION LIMIT 2;
46: 
47: -- 2. Punto de partida limpio -------------------------------------------------------
48: DO $$
49: DECLARE
50:     r TEXT;
51: BEGIN
52:     FOREACH r IN ARRAY ARRAY['rol_app_lectura', 'rol_app_escritura', 'rol_soporte', 'rol_reportes', 'rol_auditor',
53:                              'app_web', 'admin_datos', 'usr_soporte', 'usr_reportes', 'usr_auditor'] LOOP
54:         EXECUTE format('REVOKE ALL ON ALL TABLES    IN SCHEMA public FROM %I', r);
55:         EXECUTE format('REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM %I', r);
56:         EXECUTE format('REVOKE ALL ON ALL ROUTINES  IN SCHEMA public FROM %I', r);
57:         EXECUTE format('REVOKE ALL ON SCHEMA public FROM %I', r);
58:         EXECUTE format('REVOKE ALL ON DATABASE %I FROM %I', current_database(), r);
59:     END LOOP;
60:     -- Los permisos de columna no se van con REVOKE ALL ON ALL TABLES.
61:     EXECUTE 'REVOKE ALL (id, nombre, apellido, mail, celular, contrasena, rol, eliminado, created_at) ON usuario FROM rol_soporte';
62:     EXECUTE 'REVOKE ALL (stock) ON producto FROM rol_app_escritura';
63: END $$;
64: 
65: -- PUBLIC (todos los roles) no se conecta, no usa el esquema y no ejecuta funciones nuevas.
66: DO $$ BEGIN EXECUTE format('REVOKE ALL ON DATABASE %I FROM PUBLIC', current_database()); END $$;
67: REVOKE ALL ON SCHEMA public FROM PUBLIC;
68: REVOKE EXECUTE ON ALL ROUTINES IN SCHEMA public FROM PUBLIC;
69: 
70: -- 3. Conexión y esquema ------------------------------------------------------------
71: DO $$
72: BEGIN
73:     EXECUTE format('GRANT CONNECT ON DATABASE %I TO app_web, admin_datos, usr_soporte, usr_reportes, usr_auditor',
74:                    current_database());
75: END $$;
76: GRANT USAGE ON SCHEMA public TO rol_app_lectura, rol_app_escritura, rol_soporte, rol_reportes, rol_auditor, admin_datos;
77: 
78: -- 4. Roles de grupo ------------------------------------------------------------------
79: 
80: -- rol_app_lectura: catálogo y pedidos (sin cliente ni usuario)
81: GRANT SELECT ON categoria, producto, pedido, detalle_pedido, vista_productos_vigentes TO rol_app_lectura;
82: 
83: -- rol_app_escritura: registrar ventas. UPDATE solo sobre la columna stock: la app no cambia precios.
84: GRANT INSERT ON pedido, detalle_pedido TO rol_app_escritura;
85: GRANT UPDATE (stock) ON producto TO rol_app_escritura;
86: GRANT EXECUTE ON PROCEDURE sp_registrar_pedido(BIGINT, forma_pago_enum, JSONB) TO rol_app_escritura;
87: GRANT EXECUTE ON FUNCTION  fn_total_pedido(BIGINT)                            TO rol_app_escritura;
88: 
89: -- rol_soporte: permisos de COLUMNA sobre usuario. Ve todo menos la contraseña y solo
90: -- corrige celular y baja. Para la contraseña usa fn_resetear_password.
91: GRANT SELECT (id, nombre, apellido, mail, celular, rol, eliminado, created_at) ON usuario TO rol_soporte;
92: GRANT UPDATE (celular, eliminado) ON usuario TO rol_soporte;
93: GRANT SELECT ON cliente TO rol_soporte;
94: GRANT EXECUTE ON FUNCTION fn_resetear_password(TEXT, TEXT) TO rol_soporte;
95: 
96: -- rol_reportes: solo vistas y agregados. vista_usuario_reportes (U3) NO se otorga:
97: -- oculta la contraseña, pero expone mail y celular. Para usuarios, usa usuario_anon (Parte D).
98: GRANT SELECT ON mv_facturacion_cat_mes, v_top5_categorias, vista_productos_vigentes,
99:                 vista_detalle_pedido_producto TO rol_reportes;
100: 
101: -- rol_auditor: registros de auditoría.
102: GRANT SELECT ON auditoria_seguridad, auditoria_precio TO rol_auditor;
103: 
104: -- 5. Logins ------------------------------------------------------------------------------
105: GRANT rol_app_lectura, rol_app_escritura TO app_web;
106: GRANT EXECUTE ON FUNCTION fn_autenticar(TEXT, TEXT) TO app_web;     -- solo la app autentica
107: 
108: GRANT rol_soporte  TO usr_soporte;
109: GRANT rol_reportes TO usr_reportes;
110: GRANT rol_auditor  TO usr_auditor;
111: 
112: -- admin_datos: DML completo sobre los datos del esquema. No recibe TRUNCATE, REFERENCES ni
113: -- TRIGGER, no es dueño de los objetos y no tiene ADMIN OPTION sobre ningún rol.
114: GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO admin_datos;
115: GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO admin_datos;
116: GRANT EXECUTE ON ALL ROUTINES IN SCHEMA public TO admin_datos;
117: 
118: -- 6. Objetos futuros -----------------------------------------------------------------------
119: -- Lo que postgres cree de acá en adelante hereda la misma política: nadie recibe acceso
120: -- automático salvo admin_datos, y las funciones nuevas no quedan abiertas a PUBLIC.
121: -- El REVOKE va sin IN SCHEMA: los privilegios por esquema solo se SUMAN a los globales,
122: -- y el EXECUTE a PUBLIC es global. Con IN SCHEMA, el REVOKE no tendría efecto.
123: ALTER DEFAULT PRIVILEGES FOR ROLE postgres
124:     REVOKE EXECUTE ON ROUTINES FROM PUBLIC;
125: ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
126:     GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO admin_datos;
127: ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
128:     GRANT USAGE, SELECT ON SEQUENCES TO admin_datos;
129: ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
130:     GRANT EXECUTE ON ROUTINES TO admin_datos;

(End of file - total 130 lines)
</content>
```

**Tool: bash**

**Input:**
```json
{
  "command": "Get-ChildItem -Recurse -Filter \"roles.sql\" | Select-Object -ExpandProperty FullName"
}
```

**Output:**
```
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad5_seguridad\sql\roles.sql

```

**Tool: bash**

**Input:**
```json
{
  "command": "Get-ChildItem -LiteralPath \"sql\" -ErrorAction SilentlyContinue | Select-Object Name,Mode"
}
```

**Output:**
```

Name                       Mode  
----                       ----  
00_usuarios_prueba.sql     -a----
01_auth_funciones.sql      -a----
auditoria_test.sql         -a----
configurar_auditoria.sql   -a----
equivalencia_agregados.sql -a----
roles.sql                  -a----
simulacro_incidente.sql    -a----
usuario_anon.sql           -a----
verificacion_permisos.sql  -a----



```

---

## Assistant (Plan · Big Pickle · 13.0s)

_Thinking:_

**Auditing roles.sql**

I need to audit the `roles.sql` file for least privilege in PostgreSQL 16+ for the Food Store DB. I'll focus on proposing improvements and corrections with SQL, but I can only read the files, not execute anything. I should be thorough yet concise and evidence-based. I'll also check related files in the same directory, like `auth functions`, `user anon`, `auditoria`, and `verificacion_permisos`, since `roles.sql` grants EXECUTE on `fn_autenticar` and `fn_resetear_password`, and references `usuario_anon` in comments.

**Exploring schema/tables definitions**

I’m thinking that the schema and table definitions might be elsewhere in the repo. To make sure I don’t miss anything, I’ll do some targeted reads or greps to find them. That way, I can be sure I’m covering all the bases and not overlooking anything important. It’s a bit of extra work, but it’ll help me be thorough. Let’s see what I can find!

**Tool: bash**

**Input:**
```json
{
  "command": "Get-Content -Path \"sql/01_auth_funciones.sql\""
}
```

**Output:**
```
-- U5 �� 01 �?" Autenticaci��n de la aplicaci��n: fn_autenticar y fn_resetear_password
-- Reconstrucci��n de las funciones de la Clase 2 (no se conservaban en el repositorio).
--
-- Decisiones:
--   * SECURITY DEFINER: corren con los permisos del due��o, as�� app_web puede validar una
--     contrase��a sin tener permiso de lectura sobre usuario.contrasena.
--   * SET search_path fijo: evita que alguien cree un objeto con el mismo nombre en otro
--     esquema y la funci��n lo use (ataque clǭsico a funciones SECURITY DEFINER).
--   * Cada intento queda en auditoria_seguridad (registro de rendici��n de cuentas) y,
--     ademǭs, en el log del servidor con RAISE LOG (registro tǸcnico).
--   * EXECUTE se revoca de PUBLIC: por defecto, cualquier rol puede ejecutar una funci��n.
--   * SET log_min_error_statement = 'panic': para el log del servidor, el nivel LOG estǭ por
--     encima de ERROR, as�� que cada RAISE LOG agregaba la l��nea STATEMENT con la llamada
--     completa, es decir, con la contrase��a en texto plano. Se detect�� al probar el
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

-- Devuelve el usuario si el mail y la contrase��a coinciden; si no, ninguna fila.
-- No distingue "mail inexistente" de "contrase��a incorrecta" para no revelar quǸ mails existen.
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

    -- Solo se comparan hashes bcrypt; las contrase��as heredadas en otro formato no validan.
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

-- Reemplaza la contrase��a de un usuario. Reservada a soporte.
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
        RAISE EXCEPTION 'La contrase��a nueva debe tener al menos 10 caracteres';
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

-- Funciones de trigger que escriben tablas internas (auditor��a de precios de la U3 y
-- resumen de ventas de la U4). Si corrieran con los permisos de quien vende, habr��a que
-- darle a app_web permiso de escritura sobre esas tablas. Corriendo como due��o, no.
ALTER FUNCTION fn_auditar_precios()          SECURITY DEFINER SET search_path = public, pg_temp;
ALTER FUNCTION fn_resumen_detalle()          SECURITY DEFINER SET search_path = public, pg_temp;
ALTER FUNCTION fn_resumen_cambio_categoria() SECURITY DEFINER SET search_path = public, pg_temp;

```

**Tool: bash**

**Input:**
```json
{
  "command": "Get-Content -Path \"sql/usuario_anon.sql\""
}
```

**Output:**
```
-- U5 �� Parte D �?" usuario_anon: copia anonimizada y determinista de usuario
--
-- Criterio (el mismo que aplica scripts/anonimizar_log.py al log):
--   mail        -> seud��nimo: 'anon_' + 10 primeros caracteres de sha256('foodstore-u5:' || mail) + '@ejemplo.test'
--   nombre      -> 'Nombre '   + 6 caracteres del mismo hash
--   apellido    -> 'Apellido ' + otros 6 caracteres del hash
--   celular     -> se suprime (NULL)
--   contrasena  -> no se copia
--   created_at  -> se generaliza al mes: columna mes_alta (DATE, primer d��a del mes)
--   rol, eliminado -> se conservan: son las dimensiones de los reportes
--   id          -> no se copia: usuario_anon tiene su propio id, sin v��nculo con usuario
-- Es determinista: el mismo mail da siempre el mismo seud��nimo, as�� que reconstruirla da la misma tabla.
-- Limitaci��n: la sal es fija y estǭ en el repositorio. Con datos reales, la sal tendr��a que ser
-- secreta; si no, quien tenga una lista de mails podr��a recalcular los seud��nimos.

DROP TABLE IF EXISTS usuario_anon;

CREATE TABLE usuario_anon (
    id_anon     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      TEXT        NOT NULL,
    apellido    TEXT        NOT NULL,
    mail        TEXT        NOT NULL UNIQUE,
    rol         rol         NOT NULL,
    eliminado   BOOLEAN     NOT NULL,
    mes_alta    DATE        NOT NULL CHECK (mes_alta = date_trunc('month', mes_alta)::DATE)
);

INSERT INTO usuario_anon (nombre, apellido, mail, rol, eliminado, mes_alta)
SELECT 'Nombre '   || substr(h, 11, 6),
       'Apellido ' || substr(h, 17, 6),
       'anon_' || substr(h, 1, 10) || '@ejemplo.test',
       rol, eliminado,
       date_trunc('month', created_at)::DATE
  FROM (SELECT u.*, encode(sha256(convert_to('foodstore-u5:' || lower(u.mail), 'UTF8')), 'hex') AS h
          FROM usuario u) x
 ORDER BY h;

-- Los reportes leen esta tabla, no la real.
GRANT SELECT ON usuario_anon TO rol_reportes;

\echo '== Muestra de usuario_anon'
SELECT nombre, apellido, mail, rol, eliminado, mes_alta FROM usuario_anon ORDER BY mail LIMIT 5;

\echo '== Controles: ningǧn mail, nombre ni celular real qued�� en la copia (se espera 0)'
SELECT COUNT(*) AS datos_reales_filtrados
  FROM usuario_anon a
 WHERE a.mail IN (SELECT mail FROM usuario)
    OR a.nombre IN (SELECT nombre FROM usuario)
    OR a.apellido IN (SELECT apellido FROM usuario);

```

**Tool: bash**

**Input:**
```json
{
  "command": "Get-Content -Path \"sql/verificacion_permisos.sql\""
}
```

**Output:**
```
-- U5 �� Verificaci��n de permisos: cada rol tiene exactamente lo previsto, ni mǭs ni menos.
-- Se ejecuta como postgres despuǸs de roles.sql.

\echo '== \du: atributos de los roles'
\du rol_*|app_web|admin_datos|usr_*

\echo '== \drg: membres��as (PostgreSQL 16+)'
\drg rol_*|app_web|admin_datos|usr_*

\echo '== information_schema.role_table_grants (sin admin_datos, que se verifica aparte)'
SELECT grantee, table_name, privilege_type
  FROM information_schema.role_table_grants
 WHERE grantee IN ('rol_app_lectura', 'rol_app_escritura', 'rol_soporte', 'rol_reportes', 'rol_auditor',
                   'app_web', 'usr_soporte', 'usr_reportes', 'usr_auditor')
 ORDER BY 1, 2, 3;
\echo '   Ojo: information_schema no lista las vistas materializadas; por eso la comparaci��n de abajo usa pg_catalog.'

\echo '== Comparaci��n contra la especificaci��n (pg_catalog: tablas, vistas, vistas materializadas, columnas y funciones)'
CREATE TEMP TABLE esperado (grantee TEXT, objeto TEXT, privilegio TEXT);
INSERT INTO esperado VALUES
  ('rol_app_lectura',   'categoria',                     'SELECT'),
  ('rol_app_lectura',   'producto',                      'SELECT'),
  ('rol_app_lectura',   'pedido',                        'SELECT'),
  ('rol_app_lectura',   'detalle_pedido',                'SELECT'),
  ('rol_app_lectura',   'vista_productos_vigentes',      'SELECT'),
  ('rol_app_escritura', 'pedido',                        'INSERT'),
  ('rol_app_escritura', 'detalle_pedido',                'INSERT'),
  ('rol_app_escritura', 'producto.stock',                'UPDATE'),
  ('rol_app_escritura', 'sp_registrar_pedido()',         'EXECUTE'),
  ('rol_app_escritura', 'fn_total_pedido()',             'EXECUTE'),
  ('rol_soporte',       'cliente',                       'SELECT'),
  ('rol_soporte',       'usuario.id',                    'SELECT'),
  ('rol_soporte',       'usuario.nombre',                'SELECT'),
  ('rol_soporte',       'usuario.apellido',              'SELECT'),
  ('rol_soporte',       'usuario.mail',                  'SELECT'),
  ('rol_soporte',       'usuario.celular',               'SELECT'),
  ('rol_soporte',       'usuario.rol',                   'SELECT'),
  ('rol_soporte',       'usuario.eliminado',             'SELECT'),
  ('rol_soporte',       'usuario.created_at',            'SELECT'),
  ('rol_soporte',       'usuario.celular',               'UPDATE'),
  ('rol_soporte',       'usuario.eliminado',             'UPDATE'),
  ('rol_soporte',       'fn_resetear_password()',        'EXECUTE'),
  ('rol_reportes',      'mv_facturacion_cat_mes',        'SELECT'),
  ('rol_reportes',      'v_top5_categorias',             'SELECT'),
  ('rol_reportes',      'vista_productos_vigentes',      'SELECT'),
  ('rol_reportes',      'vista_detalle_pedido_producto', 'SELECT'),
  ('rol_auditor',       'auditoria_seguridad',           'SELECT'),
  ('rol_auditor',       'auditoria_precio',              'SELECT'),
  ('app_web',           'fn_autenticar()',               'EXECUTE');
-- usuario_anon se agrega en la Parte D; si ya existe, tambiǸn se espera para rol_reportes.
INSERT INTO esperado SELECT 'rol_reportes', 'usuario_anon', 'SELECT' WHERE to_regclass('public.usuario_anon') IS NOT NULL;

CREATE TEMP VIEW real AS
WITH roles AS (
    SELECT oid, rolname FROM pg_roles
     WHERE rolname IN ('rol_app_lectura', 'rol_app_escritura', 'rol_soporte', 'rol_reportes', 'rol_auditor',
                       'app_web', 'usr_soporte', 'usr_reportes', 'usr_auditor')
), tablas AS (
    SELECT c.relname AS objeto, (aclexplode(c.relacl)).*
      FROM pg_class c
     WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('r', 'v', 'm', 'p') AND c.relacl IS NOT NULL
), columnas AS (
    SELECT c.relname || '.' || a.attname AS objeto, (aclexplode(a.attacl)).*
      FROM pg_attribute a JOIN pg_class c ON c.oid = a.attrelid
     WHERE c.relnamespace = 'public'::regnamespace AND a.attacl IS NOT NULL
), rutinas AS (
    SELECT p.proname || '()' AS objeto, (aclexplode(p.proacl)).*
      FROM pg_proc p
     WHERE p.pronamespace = 'public'::regnamespace AND p.proacl IS NOT NULL
)
SELECT r.rolname AS grantee, x.objeto, x.privilege_type AS privilegio
  FROM (SELECT * FROM tablas UNION ALL SELECT * FROM columnas UNION ALL SELECT * FROM rutinas) x
  JOIN roles r ON r.oid = x.grantee;

\echo '   Privilegios DE M�?S (otorgados y no previstos; se esperan 0 filas):'
SELECT * FROM real EXCEPT SELECT * FROM esperado ORDER BY 1, 2, 3;
\echo '   Privilegios DE MENOS (previstos y no otorgados; se esperan 0 filas):'
SELECT * FROM esperado EXCEPT SELECT * FROM real ORDER BY 1, 2, 3;

\echo '== admin_datos: S/I/U/D sobre todas las relaciones del esquema, y nada mǭs'
SELECT COUNT(*) FILTER (WHERE NOT (has_table_privilege('admin_datos', c.oid, 'SELECT')
                               AND has_table_privilege('admin_datos', c.oid, 'INSERT')
                               AND has_table_privilege('admin_datos', c.oid, 'UPDATE')
                               AND has_table_privilege('admin_datos', c.oid, 'DELETE'))) AS relaciones_sin_dml_completo,
       COUNT(*) FILTER (WHERE has_table_privilege('admin_datos', c.oid, 'TRUNCATE')
                           OR has_table_privilege('admin_datos', c.oid, 'REFERENCES')
                           OR has_table_privilege('admin_datos', c.oid, 'TRIGGER'))       AS relaciones_con_privilegios_extra,
       COUNT(*) AS relaciones
  FROM pg_class c
 WHERE c.relnamespace = 'public'::regnamespace AND c.relkind IN ('r', 'v', 'm', 'p');

\echo '== Membres��as esperadas (se esperan 0 diferencias)'
WITH esperado_m (miembro, grupo) AS (VALUES
    ('app_web', 'rol_app_lectura'), ('app_web', 'rol_app_escritura'),
    ('usr_soporte', 'rol_soporte'), ('usr_reportes', 'rol_reportes'), ('usr_auditor', 'rol_auditor')),
real_m AS (
    SELECT m.rolname AS miembro, g.rolname AS grupo
      FROM pg_auth_members am
      JOIN pg_roles m ON m.oid = am.member
      JOIN pg_roles g ON g.oid = am.roleid
     WHERE m.rolname IN ('app_web', 'admin_datos', 'usr_soporte', 'usr_reportes', 'usr_auditor')
        OR g.rolname IN ('admin_datos', 'rol_app_lectura', 'rol_app_escritura', 'rol_soporte', 'rol_reportes', 'rol_auditor'))
SELECT 'de mǭs' AS tipo, * FROM (SELECT * FROM real_m EXCEPT SELECT * FROM esperado_m) a
UNION ALL
SELECT 'de menos', * FROM (SELECT * FROM esperado_m EXCEPT SELECT * FROM real_m) b;

\echo '== Pruebas funcionales con SET ROLE (todo dentro de BEGIN ... ROLLBACK)'
\set ON_ERROR_STOP off

\echo '-- app_web registra un pedido completo con CALL (debe funcionar)'
SELECT MIN(id_cliente) AS cli FROM cliente \gset
SELECT id_producto AS prod FROM producto WHERE nombre = 'Agua mineral 2L' \gset
BEGIN;
SET ROLE app_web;
CALL sp_registrar_pedido(:cli, 'TARJETA', jsonb_build_array(jsonb_build_object('id_producto', :prod, 'cantidad', 1)));
SELECT current_user AS como, stock FROM producto WHERE id_producto = :prod;
ROLLBACK;

\echo '-- app_web intenta cambiar un precio (se espera: permission denied)'
BEGIN; SET ROLE app_web;
UPDATE producto SET precio = 1 WHERE id_producto = :prod;
ROLLBACK;

\echo '-- app_web intenta leer clientes (se espera: permission denied)'
BEGIN; SET ROLE app_web;
SELECT COUNT(*) FROM cliente;
ROLLBACK;

\echo '-- usr_soporte lee mails de usuarios (debe funcionar)'
BEGIN; SET ROLE usr_soporte;
SELECT COUNT(*) AS usuarios_visibles FROM (SELECT id, mail FROM usuario) u;
ROLLBACK;

\echo '-- usr_soporte intenta leer la contrase��a (se espera: permission denied)'
BEGIN; SET ROLE usr_soporte;
SELECT contrasena FROM usuario LIMIT 1;
ROLLBACK;

\echo '-- usr_soporte resetea una contrase��a con la funci��n (debe funcionar)'
BEGIN; SET ROLE usr_soporte;
SELECT fn_resetear_password('usuario001@foodstore.test', 'Temporal-12345') AS reseteada;
ROLLBACK;

\echo '-- usr_reportes lee el top 5 (debe funcionar) y no lee pedidos de clientes (permission denied)'
BEGIN; SET ROLE usr_reportes;
SELECT COUNT(*) AS filas_top5 FROM v_top5_categorias;
ROLLBACK;
BEGIN; SET ROLE usr_reportes;
SELECT COUNT(*) FROM vista_pedidos_cliente;
ROLLBACK;

\echo '-- admin_datos intenta crear un rol (se espera: permission denied)'
BEGIN; SET ROLE admin_datos;
CREATE ROLE intruso;
ROLLBACK;
\set ON_ERROR_STOP on

```

**Tool: bash**

**Input:**
```json
{
  "command": "Get-Content -Path \"sql/configurar_auditoria.sql\""
}
```

**Output:**
```
-- U5 �� Parte B �?" Activaci��n de la auditor��a nativa del servidor
-- Se ejecuta como postgres. ALTER SYSTEM escribe en postgresql.auto.conf y no se puede
-- correr dentro de una transacci��n.

\echo '== Valores ANTES del cambio'
SELECT name, setting, context FROM pg_settings
 WHERE name IN ('logging_collector', 'log_destination', 'log_directory', 'log_connections',
                'log_disconnections', 'log_statement', 'log_line_prefix', 'log_min_error_statement',
                'log_file_mode')
 ORDER BY name;

ALTER SYSTEM SET log_connections         = 'on';      -- quiǸn se conecta, desde d��nde y si se autentica
ALTER SYSTEM SET log_disconnections      = 'on';      -- cuǭndo termina cada sesi��n y cuǭnto dur��
ALTER SYSTEM SET log_statement           = 'mod';     -- DDL e INSERT/UPDATE/DELETE/TRUNCATE/COPY FROM
ALTER SYSTEM SET log_min_error_statement = 'error';   -- texto de toda sentencia que falla
-- Prefijo: hora con milisegundos, PID, usuario@base, origen (IP y puerto) y aplicaci��n.
ALTER SYSTEM SET log_line_prefix         = '%m [%p] %q%u@%d %r app=%a ';

SELECT pg_reload_conf();
SELECT pg_sleep(1);

-- log_connections y log_disconnections rigen para las sesiones nuevas: se abre una.
\c
\echo '== Valores DESPU�%S del cambio (en una sesi��n nueva)'
SELECT name, setting FROM pg_settings
 WHERE name IN ('logging_collector', 'log_connections', 'log_disconnections', 'log_statement',
                'log_line_prefix', 'log_min_error_statement')
 ORDER BY name;

\echo '== Archivo de log actual (si sale vac��o, logging_collector estǭ apagado: ver PASOS.md)'
SELECT pg_current_logfile() AS archivo_de_log;

```

---

## Assistant (Plan · Big Pickle · 72.8s)

_Thinking:_

**Analyzing roles for least privilege**

The user wants me to audit the `sql/roles.sql` file for minimum privilege in a PostgreSQL 16+ Food Store project. I need to review each role and propose improvements with SQL for each. I have the roles and supporting scripts, including auth functions and verification. I'll focus on roles like `rol_app_lectura`, `rol_app_escritura`, `rol_soporte`, `rol_reportes`, and `rol_auditor`, as well as logins like `app_web`, `admin_datos`, `usr_soporte`, `usr_reportes`, and `usr_auditor`. I'll analyze them for least privilege and suggest concrete changes.

**Reviewing role privileges**

I’m reviewing the privileges and roles in the system. Some good things: revokes from PUBLIC, column-level grants, separate logins, and no superuser/createrole privileges. But there are a few issues to address:

1. `app_web` has both lectura and escritura, and EXECUTE on certain functions. Do all these EXECUTE grants make sense?
2. `rol_app_lectura` can read all orders, which might not be ideal for least privilege. A function/view with row filtering could help.
3. `rol_app_escritura` doesn't have sequence privileges, but it might need them for inserts.
4. `admin_datos` has broad privileges, including DELETE/UPDATE on audit tables, which could compromise audit integrity. This is a big concern.

**Final audit thoughts**

I’m still reviewing the roles and privileges. A few more things to note:

1. `app_web` needs CONNECT, but group roles don’t, which is fine.
2. Default privileges only apply to `postgres` in the public schema, so objects created by others might not have the right access.
3. `rol_soporte` doesn’t have sequence privileges, but it’s probably not inserting.
4. `usuario_anon` is granted in a separate file, which might affect idempotency.

I’ll create a concise audit with SQL corrections and improvements for each role, making sure it’s clear and structured.

## Alcance revisado
- `sql/roles.sql` (principal), contrastado con `sql/01_auth_funciones.sql`, `sql/usuario_anon.sql`, `sql/verificacion_permisos.sql`, `sql/configurar_auditoria.sql`.

## Hallazgos por rol y correcciones SQL

### 1. `admin_datos` — puede alterar/borrar evidencia de auditoría (exceso crítico)
**Qué hace hoy:** `GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public` (roles.sql:114). Eso incluye `auditoria_seguridad` y `auditoria_precio`, y le permite modificar o eliminar registros (integridad de auditoría comprometida).
**Mínimo privilegio:** administrar datos de negocio, pero sin mutar auditoría (solo lectura) y sin acceso directo al hash de contraseña.
```sql
-- Corrección: separar auditoría y columna sensible de usuario
REVOKE INSERT, UPDATE, DELETE ON TABLE auditoria_seguridad, auditoria_precio FROM admin_datos;
GRANT  SELECT                 ON TABLE auditoria_seguridad, auditoria_precio TO admin_datos;

REVOKE SELECT (contrasena), UPDATE (contrasena) ON TABLE usuario FROM admin_datos;
-- (mantiene SELECT/INSERT/UPDATE/DELETE sobre el resto de columnas según necesidad operativa;
-- si no necesita corregir datos personales, restringir también columnas de usuario/cliente)
```
> Nota: al ser `GRANT ... ON ALL TABLES` el origen, la revocación explícita posterior es necesaria para que el estado sea exacto (y conviene reflejarlo también en los `ALTER DEFAULT PRIVILEGES` para objetos futuros de auditoría).

### 2. `rol_reportes` / `usr_reportes` — falta acceso explícito a `usuario_anon` en `roles.sql`
**Qué hace hoy:** `roles.sql` no otorga `usuario_anon` (el comentario en :97 lo menciona y `usuario_anon.sql` hace el `GRANT`). El archivo se declara repetible/idempotente, pero no deja el estado completo de reportes si se ejecuta solo.
**Mínimo privilegio:** lectura solo de la copia anonimizada cuando exista.
```sql
-- Corrección idempotente en roles.sql (bloque rol_reportes)
GRANT SELECT ON TABLE mv_facturacion_cat_mes, v_top5_categorias,
                     vista_productos_vigentes, vista_detalle_pedido_producto
  TO rol_reportes;
DO $$
BEGIN
  IF to_regclass('public.usuario_anon') IS NOT NULL THEN
    EXECUTE 'GRANT SELECT ON TABLE usuario_anon TO rol_reportes';
  END IF;
END $$;
-- y, si usuario_anon es objeto estable del esquema, otorgarlo de forma directa.
```

### 3. `app_web` hereda lectura total de `pedido`/`detalle_pedido` (todos los clientes)
**Qué hace hoy:** por `rol_app_lectura` (:81) puede `SELECT` sobre `pedido` y `detalle_pedido` completos (“muestra el catálogo y los pedidos”). Con un único login compartido, eso expone pedidos ajenos si la app o una inyección lo consulta.
**Mínimo privilegio:** la app no debería leer tablas base de pedidos sin filtro; exponer solo lo propio vía función/procedimiento `SECURITY DEFINER` (o vista/RLS) parametrizado por el cliente autenticado.
```sql
-- Corrección orientativa (requiere función de consulta filtrada; la app deja de leer la tabla base)
REVOKE SELECT ON TABLE pedido, detalle_pedido FROM rol_app_lectura;

-- Ejemplo de acceso mínimo mediado por función (el dueño valida pertenencia):
CREATE OR REPLACE FUNCTION fn_pedidos_de_cliente(p_id_cliente BIGINT)
RETURNS SETOF pedido
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT * FROM pedido WHERE id_cliente = p_id_cliente;
$$;
REVOKE ALL ON FUNCTION fn_pedidos_de_cliente(BIGINT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_pedidos_de_cliente(BIGINT) TO rol_app_lectura; -- o a app_web
```
> Impacto: cambio funcional en la app; si el modelo actual exige lectura amplia desde el backend, documentarlo como riesgo aceptado. Alternativa en PG16: `ENABLE ROW LEVEL SECURITY` + política por `id_cliente` con un `SET` de contexto de sesión.

### 4. `rol_app_escritura` — secuencias/identidades para futuros inserts directos
**Qué hace hoy:** `INSERT` en `pedido, detalle_pedido` (:84) sin `USAGE, SELECT` en sus secuencias. Con columnas `GENERATED ALWAYS AS IDENTITY` el insert directo suele no requerir privilegio de secuencia al invocador, pero con `GENERATED BY DEFAULT`/`SERIAL` sí; además `ALTER DEFAULT PRIVILEGES` (:128) solo cubre a `admin_datos`.
**Mínimo privilegio:** garantizar que la app pueda insertar según el tipo real de columna y mantenerlo en objetos futuros usados por la app.
```sql
-- Corrección defensiva (ajustar a las secuencias reales de pedido/detalle_pedido)
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO rol_app_escritura;
-- o, acotado: GRANT USAGE, SELECT ON SEQUENCE pedido_id_seq, detalle_pedido_id_seq TO rol_app_escritura;

-- y para objetos futuros creados por postgres que la app necesite:
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
  GRANT USAGE, SELECT ON SEQUENCES TO rol_app_escritura; -- solo si la política lo requiere
```
> Verificar en catálogo (`\d pedido`, `\d detalle_pedido`) si son `IDENTITY ALWAYS` antes de ampliar; lo mínimo estricto es otorgar solo las secuencias necesarias.

### 5. `rol_soporte` — puede reactivar/bajar cualquier usuario sin restricción de rol/alcance
**Qué hace hoy:** `UPDATE (celular, eliminado) ON usuario` (:92). Permite marcar `eliminado` (baja/alta lógica) de cualquier cuenta, potencialmente incluso administrativas.
**Mínimo privilegio:** si soporte no debe gestionar cuentas privilegiadas, mediar con función que restrinja objetivos.
```sql
-- Corrección: retirar UPDATE directo y usar función acotada
REVOKE UPDATE (celular, eliminado) ON TABLE usuario FROM rol_soporte;

CREATE OR REPLACE FUNCTION fn_soporte_actualizar_usuario(
  p_mail TEXT, p_celular TEXT, p_eliminado BOOLEAN
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE v_ok BOOLEAN;
BEGIN
  UPDATE usuario
     SET celular   = COALESCE(p_celular, celular),
         eliminado = COALESCE(p_eliminado, eliminado)
   WHERE lower(mail) = lower(p_mail)
     AND rol NOT IN ('admin'::rol)   -- ajustar a los valores reales del enum rol
  RETURNING TRUE INTO v_ok;
  RETURN COALESCE(v_ok, FALSE);
END $$;
REVOKE ALL ON FUNCTION fn_soporte_actualizar_usuario(TEXT, TEXT, BOOLEAN) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_soporte_actualizar_usuario(TEXT, TEXT, BOOLEAN) TO rol_soporte;
```
> Ajustar la lista de roles protegidos al `enum rol` real del esquema.

### 6. `ALTER DEFAULT PRIVILEGES` — cobertura incompleta y riesgo de deriva
**Qué hace hoy:** revoca `EXECUTE` de `PUBLIC` y otorga a `admin_datos` solo para objetos creados por `postgres` (:123-130). No cubre otros creadores ni revoca privilegios de tabla por defecto de `PUBLIC` explícitamente en el contexto del creador.
**Mínimo privilegio / robustez:** fijar política para cada rol que cree objetos y blindar tablas futuras.
```sql
-- Corrección: ampliar al/los roles creadores reales (ej. postgres y admin_datos si migra/crea objetos)
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON TABLES    FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON SEQUENCES FROM PUBLIC;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public REVOKE ALL ON ROUTINES  FROM PUBLIC;

-- Repetir el bloque anterior sustituyendo FOR ROLE postgres por cada rol que pueda crear objetos.
-- (Los GRANT específicos a admin_datos ya presentes se mantienen.)
```

### 7. Superficie de lectura de la app (`rol_app_lectura` sobre `cliente`/`usuario`): OK por omisión, pero conviene explicitar
`rol_app_lectura` no recibe `cliente` ni `usuario` (:81) y `app_web` autentica vía `fn_autenticar` (`SECURITY DEFINER`, `01_auth_funciones.sql`): correcto para mínimo privilegio. No requiere cambio; sí vale mantener la verificación automatizada (`verificacion_permisos.sql`) como guardarraíl ante futuras ampliaciones.

## Resumen
- **Bien resuelto:** sin superusuario/createrole/createdb, `REVOKE` amplio + `PUBLIC` sin CONNECT/USAGE/EXECUTE, permisos de columna (`usuario` para soporte, `stock` para escritura), separación de logins por área, funciones sensibles `SECURITY DEFINER` con `search_path` fijo y `EXECUTE` revocado a `PUBLIC`, `CONNECTION LIMIT`.
- **Corregir prioritariamente:** (1) `admin_datos` no debe poder `UPDATE/DELETE` auditoría ni leer hashes de contraseña; (3) lectura global de pedidos por `app_web`.
- **Endurecer:** (2) incluir `usuario_anon` en el estado idempotente, (4) secuencias según tipo real, (5) acotar acciones de soporte sobre cuentas sensibles, (6) `ALTER DEFAULT PRIVILEGES` para todos los creadores.

---

