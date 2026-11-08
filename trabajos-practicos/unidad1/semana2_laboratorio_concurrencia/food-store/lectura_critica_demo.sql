-- Parte 3: efecto real de los dos scripts, sobre un esquema de prueba que se borra al final.
-- Cada script corre dentro de BEGIN ... ROLLBACK: se ve cuántas filas toca y no queda nada aplicado.
SELECT current_database();
DROP SCHEMA IF EXISTS lectura_critica CASCADE;
CREATE SCHEMA lectura_critica;
SET search_path TO lectura_critica;

-- Esquema genérico mínimo: supuesto de columnas, porque la consigna no las detalla.
CREATE TABLE pelicula (id INT PRIMARY KEY, titulo TEXT NOT NULL, en_cartel BOOLEAN NOT NULL);
CREATE TABLE funcion  (id INT PRIMARY KEY, pelicula_id INT NOT NULL REFERENCES pelicula (id), activa BOOLEAN NOT NULL);
INSERT INTO pelicula VALUES (1, 'En cartel A', TRUE), (2, 'En cartel B', TRUE), (3, 'Retirada', FALSE);
INSERT INTO funcion  VALUES (1, 1, TRUE), (2, 1, TRUE), (3, 2, TRUE), (4, 2, TRUE), (5, 3, TRUE), (6, 3, TRUE);

CREATE TABLE categoria (id INT PRIMARY KEY, nombre TEXT NOT NULL);
CREATE TABLE producto  (id INT PRIMARY KEY, nombre TEXT NOT NULL, categoria_id INT REFERENCES categoria (id));
INSERT INTO categoria VALUES (1, 'Con productos'), (2, 'Con productos'), (3, 'Sin productos'), (4, 'Sin productos');
INSERT INTO producto  VALUES (1, 'P1', 1), (2, 'P2', 1), (3, 'P3', 2), (4, 'Sin categoría', NULL);

-- Script 1 tal como está: sin WHERE, apaga todas las funciones.
BEGIN;
UPDATE funcion SET activa = FALSE;
SELECT COUNT(*) FILTER (WHERE NOT activa) AS funciones_apagadas, COUNT(*) AS total FROM funcion;
ROLLBACK;

-- Script 1 corregido: solo las funciones activas de películas retiradas.
BEGIN;
UPDATE funcion SET activa = FALSE
WHERE activa
  AND pelicula_id IN (SELECT id FROM pelicula WHERE NOT en_cartel);
SELECT COUNT(*) FILTER (WHERE NOT activa) AS funciones_apagadas, COUNT(*) AS total FROM funcion;
ROLLBACK;

-- Script 2 tal como está: con un NULL en la subconsulta, NOT IN nunca es verdadero y no borra nada.
BEGIN;
DELETE FROM categoria WHERE id NOT IN (SELECT categoria_id FROM producto);
SELECT COUNT(*) AS categorias_que_quedan FROM categoria;
ROLLBACK;

-- Por qué: para la categoría 3, que no tiene productos, NOT IN da NULL (celda vacía) en lugar de TRUE.
SELECT 3 NOT IN (1, 1, 2, NULL)          AS not_in_con_null,
       (3 NOT IN (1, 1, 2, NULL)) IS NULL AS es_null,
       3 NOT IN (1, 1, 2)                AS not_in_sin_null;

-- Script 2 corregido: NOT EXISTS no se ve afectado por los NULL.
BEGIN;
DELETE FROM categoria c
WHERE NOT EXISTS (SELECT 1 FROM producto p WHERE p.categoria_id = c.id);
SELECT id, nombre FROM categoria ORDER BY id;
ROLLBACK;

RESET search_path;
DROP SCHEMA lectura_critica CASCADE;

-- En mi base: el mismo descuido del Script 1 (UPDATE sin WHERE) sobre las tablas del Food Store.
BEGIN;
UPDATE categoria SET activo = FALSE;   -- la Regla B (Parte 1) rechaza la sentencia entera
ROLLBACK;
BEGIN;
UPDATE producto SET activo = FALSE;    -- ninguna regla lo impide: da de baja todos los productos
ROLLBACK;

-- La baja lógica que sí corresponde: categorías activas sin ningún producto activo.
BEGIN;
UPDATE categoria c SET activo = FALSE
WHERE c.activo
  AND NOT EXISTS (SELECT 1 FROM producto p WHERE p.categoria_id = c.id AND p.activo);
SELECT nombre, activo FROM categoria ORDER BY id;
ROLLBACK;
