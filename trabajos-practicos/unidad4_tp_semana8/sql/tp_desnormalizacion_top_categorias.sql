-- TP Unidad 4 · Parte 2 — Top 5 de categorías del día con desnormalización controlada
-- Estructura desnormalizada (tp4.ventas_dia_categoria), su sincronización con disparadores,
-- la consulta del punto 5.2(d) y el script de auditoría del punto 5.2(e).
--
-- Se corre como postgres sobre la copia foodstore_tp4 (ver ejecutar_tp_u4.sh).
-- Adaptación al esquema real de Food Store (la consigna usa nombres genéricos):
--   * no hay dp.subtotal: el monto de una línea es cantidad * precio_unitario;
--   * las claves se llaman id_producto, id_categoria e id_pedido;
--   * pedido y detalle_pedido no tienen borrado lógico. Lo que no cuenta como venta es un
--     pedido CANCELADO (columna estado, de la U7). Un pedido borrado se borra con sus líneas;
--   * pedido.fecha es TIMESTAMPTZ: «el día» es la fecha en la hora de Argentina.
\set ON_ERROR_STOP on
CREATE SCHEMA IF NOT EXISTS tp4;
SET search_path TO tp4, public;

-- Limpieza, para poder volver a correrlo ------------------------------------------------
DROP TRIGGER IF EXISTS trg_ventas_dia_detalle   ON public.detalle_pedido;
DROP TRIGGER IF EXISTS trg_ventas_dia_pedido_del ON public.pedido;
DROP TRIGGER IF EXISTS trg_ventas_dia_pedido_upd ON public.pedido;
DROP TRIGGER IF EXISTS trg_ventas_dia_producto  ON public.producto;
DROP VIEW  IF EXISTS v_auditoria_ventas_dia;
DROP TABLE IF EXISTS ventas_dia_categoria;

-- El día de una venta, siempre en la hora de Argentina (no depende de la zona de la sesión)
CREATE OR REPLACE FUNCTION dia_venta(p TIMESTAMPTZ) RETURNS DATE
LANGUAGE sql IMMUTABLE AS $$ SELECT (p AT TIME ZONE 'America/Argentina/Buenos_Aires')::DATE $$;
CREATE OR REPLACE FUNCTION hoy() RETURNS DATE
LANGUAGE sql STABLE AS $$ SELECT (now() AT TIME ZONE 'America/Argentina/Buenos_Aires')::DATE $$;

-- =====================================================================================
-- 5.2(a) La consulta original, adaptada al esquema, con EXPLAIN ANALYZE
-- =====================================================================================
ANALYZE public.pedido, public.detalle_pedido, public.producto, public.categoria;
\echo '== Tamaño de la base y ventas de hoy (hora de Argentina)'
SELECT (SELECT COUNT(*) FROM pedido) AS pedidos, (SELECT COUNT(*) FROM detalle_pedido) AS lineas,
       (SELECT COUNT(*) FROM pedido WHERE dia_venta(fecha) = hoy() AND estado <> 'CANCELADO') AS pedidos_de_hoy,
       hoy() AS hoy;

\echo '== 5.2(a) Consulta original: recorre y une detalle_pedido, producto, categoria y pedido'
SELECT c.nombre AS categoria, SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
  FROM detalle_pedido dp
  JOIN producto  pr  ON pr.id_producto   = dp.id_producto
  JOIN categoria c   ON c.id_categoria   = pr.id_categoria
  JOIN pedido    ped ON ped.id_pedido    = dp.id_pedido
 WHERE dia_venta(ped.fecha) = hoy()
   AND ped.estado <> 'CANCELADO'
 GROUP BY c.nombre
 ORDER BY total_vendido DESC
 LIMIT 5;
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre AS categoria, SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
  FROM detalle_pedido dp
  JOIN producto  pr  ON pr.id_producto   = dp.id_producto
  JOIN categoria c   ON c.id_categoria   = pr.id_categoria
  JOIN pedido    ped ON ped.id_pedido    = dp.id_pedido
 WHERE dia_venta(ped.fecha) = hoy()
   AND ped.estado <> 'CANCELADO'
 GROUP BY c.nombre
 ORDER BY total_vendido DESC
 LIMIT 5;

-- =====================================================================================
-- 5.2(c) Estructura desnormalizada y su mecanismo de sincronización
-- =====================================================================================
BEGIN;
-- Una fila por día y categoría con lo vendido. Es un dato derivado: la fuente de verdad
-- siguen siendo pedido y detalle_pedido, y la tabla se puede reconstruir en cualquier momento.
CREATE TABLE ventas_dia_categoria (
    dia            DATE          NOT NULL,
    id_categoria   BIGINT        NOT NULL REFERENCES public.categoria (id_categoria),
    unidades       BIGINT        NOT NULL CHECK (unidades > 0),
    total_vendido  NUMERIC(14,2) NOT NULL CHECK (total_vendido >= 0),
    PRIMARY KEY (dia, id_categoria)          -- el panel busca por día: WHERE dia = hoy()
);

-- Suma (o resta) una variación en la fila de ese día y categoría. Con una variación positiva
-- alcanza un INSERT ... ON CONFLICT. Con una negativa no: PostgreSQL controla el CHECK sobre la
-- fila propuesta antes de detectar el conflicto (el mismo error de la U4 del TPI). Por eso la
-- resta es un UPDATE, y si la fila queda en 0 unidades se borra.
CREATE OR REPLACE FUNCTION fn_ventas_ajustar(p_dia DATE, p_categoria BIGINT, p_unidades BIGINT, p_monto NUMERIC)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = tp4, public, pg_temp AS $$
BEGIN
    IF p_unidades = 0 AND p_monto = 0 THEN RETURN; END IF;
    IF p_unidades > 0 THEN
        INSERT INTO ventas_dia_categoria AS v (dia, id_categoria, unidades, total_vendido)
        VALUES (p_dia, p_categoria, p_unidades, p_monto)
        ON CONFLICT (dia, id_categoria) DO UPDATE
           SET unidades = v.unidades + EXCLUDED.unidades,
               total_vendido = v.total_vendido + EXCLUDED.total_vendido;
    ELSE
        UPDATE ventas_dia_categoria
           SET unidades = unidades + p_unidades, total_vendido = total_vendido + p_monto
         WHERE dia = p_dia AND id_categoria = p_categoria;
        IF NOT FOUND THEN
            RAISE EXCEPTION 'ventas_dia_categoria desincronizada: no hay fila para % / categoría %', p_dia, p_categoria;
        END IF;
        DELETE FROM ventas_dia_categoria
         WHERE dia = p_dia AND id_categoria = p_categoria AND unidades = 0;
    END IF;
END $$;

-- Línea de pedido nueva, cambiada o borrada. Si el pedido ya no existe es porque se está
-- borrando el pedido entero: eso lo descontó antes trg_ventas_dia_pedido_del.
CREATE OR REPLACE FUNCTION fn_ventas_dia_detalle() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = tp4, public, pg_temp AS $$
DECLARE v_fecha TIMESTAMPTZ; v_estado TEXT; v_cat BIGINT;
BEGIN
    IF TG_OP IN ('UPDATE', 'DELETE') THEN
        SELECT fecha, estado INTO v_fecha, v_estado FROM pedido WHERE id_pedido = OLD.id_pedido;
        IF FOUND AND v_estado <> 'CANCELADO' THEN
            SELECT id_categoria INTO v_cat FROM producto WHERE id_producto = OLD.id_producto;
            PERFORM fn_ventas_ajustar(dia_venta(v_fecha), v_cat, -OLD.cantidad, -(OLD.cantidad * OLD.precio_unitario));
        END IF;
    END IF;
    IF TG_OP IN ('INSERT', 'UPDATE') THEN
        SELECT fecha, estado INTO v_fecha, v_estado FROM pedido WHERE id_pedido = NEW.id_pedido;
        IF FOUND AND v_estado <> 'CANCELADO' THEN
            SELECT id_categoria INTO v_cat FROM producto WHERE id_producto = NEW.id_producto;
            PERFORM fn_ventas_ajustar(dia_venta(v_fecha), v_cat, NEW.cantidad, NEW.cantidad * NEW.precio_unitario);
        END IF;
    END IF;
    RETURN NULL;
END $$;

-- Suma o resta todas las líneas de un pedido (signo +1 o -1), agrupadas por categoría
CREATE OR REPLACE FUNCTION fn_ventas_pedido(p_pedido BIGINT, p_fecha TIMESTAMPTZ, p_signo INT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = tp4, public, pg_temp AS $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT pr.id_categoria, SUM(dp.cantidad) AS u, SUM(dp.cantidad * dp.precio_unitario) AS m
               FROM detalle_pedido dp JOIN producto pr ON pr.id_producto = dp.id_producto
              WHERE dp.id_pedido = p_pedido GROUP BY 1 LOOP
        PERFORM fn_ventas_ajustar(dia_venta(p_fecha), r.id_categoria, p_signo * r.u, p_signo * r.m);
    END LOOP;
END $$;

-- Pedido borrado: se descuentan sus líneas ANTES de que el borrado en cascada se las lleve
CREATE OR REPLACE FUNCTION fn_ventas_dia_pedido_del() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = tp4, public, pg_temp AS $$
BEGIN
    IF OLD.estado <> 'CANCELADO' THEN PERFORM fn_ventas_pedido(OLD.id_pedido, OLD.fecha, -1); END IF;
    RETURN OLD;
END $$;

-- Pedido que cambia de fecha o de estado (por ejemplo, se cancela): sale de donde estaba
-- y entra donde corresponde
CREATE OR REPLACE FUNCTION fn_ventas_dia_pedido_upd() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = tp4, public, pg_temp AS $$
BEGIN
    IF OLD.estado <> 'CANCELADO' THEN PERFORM fn_ventas_pedido(OLD.id_pedido, OLD.fecha, -1); END IF;
    IF NEW.estado <> 'CANCELADO' THEN PERFORM fn_ventas_pedido(NEW.id_pedido, NEW.fecha, +1); END IF;
    RETURN NULL;
END $$;

-- Producto que cambia de categoría: sus ventas pasan de una categoría a la otra
CREATE OR REPLACE FUNCTION fn_ventas_dia_producto() RETURNS TRIGGER
LANGUAGE plpgsql SECURITY DEFINER SET search_path = tp4, public, pg_temp AS $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT dia_venta(ped.fecha) AS dia, SUM(dp.cantidad) AS u, SUM(dp.cantidad * dp.precio_unitario) AS m
               FROM detalle_pedido dp JOIN pedido ped ON ped.id_pedido = dp.id_pedido
              WHERE dp.id_producto = NEW.id_producto AND ped.estado <> 'CANCELADO' GROUP BY 1 LOOP
        PERFORM fn_ventas_ajustar(r.dia, OLD.id_categoria, -r.u, -r.m);
        PERFORM fn_ventas_ajustar(r.dia, NEW.id_categoria,  r.u,  r.m);
    END LOOP;
    RETURN NULL;
END $$;

CREATE TRIGGER trg_ventas_dia_detalle AFTER INSERT OR UPDATE OR DELETE ON public.detalle_pedido
    FOR EACH ROW EXECUTE FUNCTION fn_ventas_dia_detalle();
CREATE TRIGGER trg_ventas_dia_pedido_del BEFORE DELETE ON public.pedido
    FOR EACH ROW EXECUTE FUNCTION fn_ventas_dia_pedido_del();
CREATE TRIGGER trg_ventas_dia_pedido_upd AFTER UPDATE OF fecha, estado ON public.pedido
    FOR EACH ROW WHEN (OLD.fecha IS DISTINCT FROM NEW.fecha OR OLD.estado IS DISTINCT FROM NEW.estado)
    EXECUTE FUNCTION fn_ventas_dia_pedido_upd();
CREATE TRIGGER trg_ventas_dia_producto AFTER UPDATE OF id_categoria ON public.producto
    FOR EACH ROW WHEN (OLD.id_categoria IS DISTINCT FROM NEW.id_categoria)
    EXECUTE FUNCTION fn_ventas_dia_producto();

-- Carga inicial desde la fuente de verdad. Las tablas quedan bloqueadas contra escrituras
-- hasta el COMMIT: ninguna venta puede entrar entre la carga y la activación de los triggers.
LOCK TABLE public.pedido, public.detalle_pedido, public.producto IN SHARE ROW EXCLUSIVE MODE;
INSERT INTO ventas_dia_categoria (dia, id_categoria, unidades, total_vendido)
SELECT dia_venta(ped.fecha), pr.id_categoria, SUM(dp.cantidad), SUM(dp.cantidad * dp.precio_unitario)
  FROM detalle_pedido dp
  JOIN producto pr  ON pr.id_producto = dp.id_producto
  JOIN pedido   ped ON ped.id_pedido  = dp.id_pedido
 WHERE ped.estado <> 'CANCELADO'
 GROUP BY 1, 2;
COMMIT;

\echo '== Filas de la estructura desnormalizada'
SELECT COUNT(*) AS filas, MIN(dia) AS primer_dia, MAX(dia) AS ultimo_dia FROM ventas_dia_categoria;

-- =====================================================================================
-- 5.2(e) Auditoría: diferencias entre el dato redundante y su fuente de verdad
-- =====================================================================================
CREATE VIEW v_auditoria_ventas_dia AS
WITH real AS (
    SELECT dia_venta(ped.fecha) AS dia, pr.id_categoria,
           SUM(dp.cantidad) AS unidades, SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
      FROM detalle_pedido dp
      JOIN producto pr  ON pr.id_producto = dp.id_producto
      JOIN pedido   ped ON ped.id_pedido  = dp.id_pedido
     WHERE ped.estado <> 'CANCELADO'
     GROUP BY 1, 2)
SELECT COALESCE(r.dia, v.dia) AS dia, COALESCE(r.id_categoria, v.id_categoria) AS id_categoria,
       r.unidades AS unidades_reales, v.unidades AS unidades_resumen,
       r.total_vendido AS total_real, v.total_vendido AS total_resumen
  FROM real r FULL JOIN ventas_dia_categoria v ON v.dia = r.dia AND v.id_categoria = r.id_categoria
 WHERE r.unidades IS DISTINCT FROM v.unidades OR r.total_vendido IS DISTINCT FROM v.total_vendido;

\echo '== 5.2(e) Auditoría sobre la base migrada (se esperan 0 filas)'
SELECT * FROM v_auditoria_ventas_dia ORDER BY dia, id_categoria;

-- =====================================================================================
-- 5.2(d) El mismo reporte, leyendo la estructura desnormalizada
-- =====================================================================================
\echo '== 5.2(d) Top 5 del día desde ventas_dia_categoria (mismo resultado que 5.2(a))'
SELECT c.nombre AS categoria, v.total_vendido
  FROM ventas_dia_categoria v
  JOIN categoria c ON c.id_categoria = v.id_categoria
 WHERE v.dia = hoy()
 ORDER BY v.total_vendido DESC
 LIMIT 5;
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.nombre AS categoria, v.total_vendido
  FROM ventas_dia_categoria v
  JOIN categoria c ON c.id_categoria = v.id_categoria
 WHERE v.dia = hoy()
 ORDER BY v.total_vendido DESC
 LIMIT 5;

\echo '== Los dos caminos dan el mismo resultado (se esperan 0 diferencias)'
WITH antes AS (
    SELECT c.nombre AS categoria, SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
      FROM detalle_pedido dp
      JOIN producto pr ON pr.id_producto = dp.id_producto
      JOIN categoria c ON c.id_categoria = pr.id_categoria
      JOIN pedido ped  ON ped.id_pedido  = dp.id_pedido
     WHERE dia_venta(ped.fecha) = hoy() AND ped.estado <> 'CANCELADO'
     GROUP BY c.nombre ORDER BY total_vendido DESC LIMIT 5),
despues AS (
    SELECT c.nombre AS categoria, v.total_vendido
      FROM ventas_dia_categoria v JOIN categoria c ON c.id_categoria = v.id_categoria
     WHERE v.dia = hoy() ORDER BY v.total_vendido DESC LIMIT 5)
SELECT (SELECT COUNT(*) FROM (SELECT * FROM antes EXCEPT SELECT * FROM despues) a)
     + (SELECT COUNT(*) FROM (SELECT * FROM despues EXCEPT SELECT * FROM antes) b) AS diferencias;

-- =====================================================================================
-- Pruebas de la sincronización (todo dentro de BEGIN ... ROLLBACK)
-- =====================================================================================
\echo '== Sincronización: venta nueva, cambio de cantidad, cancelación, borrado y cambio de categoría'
BEGIN;
CREATE TEMP TABLE prueba AS
SELECT (SELECT MIN(id_cliente) FROM cliente) AS cliente,
       (SELECT MIN(id_producto) FROM producto WHERE activo AND stock >= 10 AND id_categoria = 1) AS prod_a,
       (SELECT MIN(id_producto) FROM producto WHERE activo AND stock >= 10 AND id_categoria = 2) AS prod_b;
SELECT dia, id_categoria, unidades, total_vendido FROM ventas_dia_categoria
 WHERE dia = hoy() AND id_categoria IN (1, 2) ORDER BY 2;

\echo '-- 1. Venta nueva de hoy con dos líneas'
INSERT INTO pedido (forma_pago, id_cliente) SELECT 'EFECTIVO', cliente FROM prueba RETURNING id_pedido AS pedido_prueba \gset
INSERT INTO detalle_pedido (cantidad, precio_unitario, id_pedido, id_producto)
SELECT 2, 1000.00, :pedido_prueba, prod_a FROM prueba UNION ALL
SELECT 3,  500.00, :pedido_prueba, prod_b FROM prueba;
SELECT dia, id_categoria, unidades, total_vendido FROM ventas_dia_categoria
 WHERE dia = hoy() AND id_categoria IN (1, 2) ORDER BY 2;
SELECT COUNT(*) AS auditoria_tras_la_venta FROM v_auditoria_ventas_dia;

\echo '-- 2. Cambio de cantidad en una línea'
UPDATE detalle_pedido SET cantidad = 5 WHERE id_pedido = :pedido_prueba AND id_producto = (SELECT prod_a FROM prueba);
SELECT COUNT(*) AS auditoria_tras_el_cambio FROM v_auditoria_ventas_dia;

\echo '-- 3. El pedido se cancela'
UPDATE pedido SET estado = 'CANCELADO' WHERE id_pedido = :pedido_prueba;
SELECT COUNT(*) AS auditoria_tras_la_cancelacion FROM v_auditoria_ventas_dia;

\echo '-- 4. El pedido vuelve a PENDIENTE y después se borra con sus líneas'
UPDATE pedido SET estado = 'PENDIENTE' WHERE id_pedido = :pedido_prueba;
DELETE FROM pedido WHERE id_pedido = :pedido_prueba;
SELECT COUNT(*) AS auditoria_tras_el_borrado FROM v_auditoria_ventas_dia;

\echo '-- 5. Un producto cambia de categoría'
UPDATE producto SET id_categoria = 3 WHERE id_producto = (SELECT prod_a FROM prueba);
SELECT COUNT(*) AS auditoria_tras_cambiar_la_categoria FROM v_auditoria_ventas_dia;
ROLLBACK;

-- =====================================================================================
-- Reversión: la desnormalización se quita sin perder información
-- =====================================================================================
-- La fuente de verdad nunca se tocó, así que revertir es borrar los triggers, las funciones y
-- la tabla. Se ensaya dentro de una transacción y se deshace, para que el TP quede armado.
\echo '== Reversión (ensayo con ROLLBACK): se borra la desnormalización y la consulta original sigue igual'
BEGIN;
DROP TRIGGER trg_ventas_dia_detalle    ON public.detalle_pedido;
DROP TRIGGER trg_ventas_dia_pedido_del ON public.pedido;
DROP TRIGGER trg_ventas_dia_pedido_upd ON public.pedido;
DROP TRIGGER trg_ventas_dia_producto   ON public.producto;
DROP VIEW  v_auditoria_ventas_dia;
DROP TABLE ventas_dia_categoria;
SELECT c.nombre AS categoria, SUM(dp.cantidad * dp.precio_unitario) AS total_vendido
  FROM detalle_pedido dp
  JOIN producto pr ON pr.id_producto = dp.id_producto
  JOIN categoria c ON c.id_categoria = pr.id_categoria
  JOIN pedido ped  ON ped.id_pedido  = dp.id_pedido
 WHERE dia_venta(ped.fecha) = hoy() AND ped.estado <> 'CANCELADO'
 GROUP BY c.nombre ORDER BY total_vendido DESC LIMIT 5;
ROLLBACK;
