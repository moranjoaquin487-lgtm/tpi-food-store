-- U5 · Parte D — usuario_anon: copia anonimizada y determinista de usuario
--
-- Criterio (el mismo que aplica scripts/anonimizar_log.py al log):
--   mail        -> seudónimo: 'anon_' + 10 primeros caracteres de sha256('foodstore-u5:' || mail) + '@ejemplo.test'
--   nombre      -> 'Nombre '   + 6 caracteres del mismo hash
--   apellido    -> 'Apellido ' + otros 6 caracteres del hash
--   celular     -> se suprime (NULL)
--   contrasena  -> no se copia
--   created_at  -> se generaliza al mes: columna mes_alta (DATE, primer día del mes)
--   rol, eliminado -> se conservan: son las dimensiones de los reportes
--   id          -> no se copia: usuario_anon tiene su propio id, sin vínculo con usuario
-- Es determinista: el mismo mail da siempre el mismo seudónimo, así que reconstruirla da la misma tabla.
-- Limitación: la sal es fija y está en el repositorio. Con datos reales, la sal tendría que ser
-- secreta; si no, quien tenga una lista de mails podría recalcular los seudónimos.

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

\echo '== Controles: ningún mail, nombre ni celular real quedó en la copia (se espera 0)'
SELECT COUNT(*) AS datos_reales_filtrados
  FROM usuario_anon a
 WHERE a.mail IN (SELECT mail FROM usuario)
    OR a.nombre IN (SELECT nombre FROM usuario)
    OR a.apellido IN (SELECT apellido FROM usuario);
