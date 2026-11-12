-- U4 · 01 — Esquema heredado: control_lote_almacen
-- Reproduce la tabla heredada con redundancia que se refactoriza en este trabajo.
-- Agrega al esquema de Food Store los lotes de producto, los depósitos y los
-- responsables de control (usuarios de prueba). Todos los datos son inventados.

DROP VIEW  IF EXISTS v_control_lote_almacen;
DROP TABLE IF EXISTS control_lote CASCADE;
DROP TABLE IF EXISTS responsable_deposito CASCADE;
DROP TABLE IF EXISTS control_lote_almacen_respaldo CASCADE;
DROP TABLE IF EXISTS control_lote_almacen CASCADE;
DROP TABLE IF EXISTS lote CASCADE;
DROP TABLE IF EXISTS deposito CASCADE;

-- Depósitos donde se controlan los lotes
CREATE TABLE deposito (
    id      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre  VARCHAR(80) NOT NULL UNIQUE
);

-- Lotes de elaboración de un producto
CREATE TABLE lote (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    codigo       VARCHAR(20) NOT NULL UNIQUE,
    id_producto  BIGINT      NOT NULL REFERENCES producto (id_producto) ON DELETE RESTRICT
);

-- Tabla heredada. Reglas de negocio relevadas:
--   R1. Para un lote y un depósito, el responsable del control es uno solo.
--   R2. Cada responsable pertenece a un único depósito.
-- La PK modela R1; R2 no tiene ninguna restricción que la garantice.
CREATE TABLE control_lote_almacen (
    lote_id                 BIGINT NOT NULL REFERENCES lote (id),
    deposito_id             BIGINT NOT NULL REFERENCES deposito (id),
    responsable_control_id  BIGINT NOT NULL REFERENCES usuario (id),
    PRIMARY KEY (lote_id, deposito_id)
);

-- Datos de prueba ---------------------------------------------------------------

INSERT INTO deposito (nombre)
SELECT 'Depósito ' || i FROM generate_series(1, 8) AS s(i);

DELETE FROM usuario WHERE mail LIKE 'responsable%@foodstore.test';

-- 24 responsables: 3 por depósito. La contraseña '!' no es un hash válido,
-- así que estos usuarios no pueden iniciar sesión.
INSERT INTO usuario (nombre, apellido, mail, celular, contrasena, rol, eliminado, created_at)
SELECT 'Responsable', lpad(i::TEXT, 2, '0'),
       'responsable' || lpad(i::TEXT, 2, '0') || '@foodstore.test',
       NULL, '!', 'USUARIO', FALSE,
       TIMESTAMPTZ '2026-03-01 09:00:00-03' + (i || ' days')::INTERVAL
FROM generate_series(1, 24) AS s(i);

-- 300 lotes de los 10 productos de la carga semilla
INSERT INTO lote (codigo, id_producto)
SELECT 'L-' || lpad(i::TEXT, 4, '0'),
       (SELECT MIN(id_producto) FROM producto) + (i % 10)
FROM generate_series(1, 300) AS s(i);

-- Cada lote se controla desde 1, 2 o 3 depósitos; en cada uno, por uno de sus responsables.
WITH resp AS (
    SELECT id AS responsable,
           ((ROW_NUMBER() OVER (ORDER BY id) - 1) % 8) + 1 AS dep_pos,
           ((ROW_NUMBER() OVER (ORDER BY id) - 1) / 8)     AS turno
      FROM usuario
     WHERE mail LIKE 'responsable%@foodstore.test'
), dep AS (
    SELECT id AS deposito, ROW_NUMBER() OVER (ORDER BY id) AS dep_pos FROM deposito
), lot AS (
    SELECT id AS lote, ROW_NUMBER() OVER (ORDER BY id) AS n FROM lote
)
INSERT INTO control_lote_almacen (lote_id, deposito_id, responsable_control_id)
SELECT l.lote, d.deposito, r.responsable
  FROM lot l
  CROSS JOIN generate_series(0, 2) AS j
  JOIN dep  d ON d.dep_pos = ((l.n + 3 * j) % 8) + 1
  JOIN resp r ON r.dep_pos = d.dep_pos AND r.turno = l.n % 3
 WHERE j <= l.n % 3;
