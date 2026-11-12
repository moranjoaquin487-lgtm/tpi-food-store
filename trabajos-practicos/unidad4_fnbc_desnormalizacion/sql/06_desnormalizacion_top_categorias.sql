-- U4 · 06 — Desnormalización controlada: resumen de ventas por categoría
--
-- Consulta que se quiere acelerar: el top 5 de categorías por facturación.
-- Normalizada, recorre todo detalle_pedido y lo une con producto y categoría.
-- La tabla resumen guarda esos totales ya calculados.
--
-- Salvaguardas:
--   1. Triggers que actualizan el resumen en la MISMA transacción que la venta.
--   2. fn_verificar_resumen_categoria(): compara el resumen con el cálculo real.
--   3. sp_recalcular_resumen_categoria(): reconstruye el resumen si alguna vez difiere.
--   4. CHECK de no negatividad: un descuento mal hecho da error en vez de un total absurdo.
--   5. Reversión documentada en 09_reversion_desnormalizacion.sql.

DROP VIEW    IF EXISTS v_top5_categorias;
DROP TRIGGER IF EXISTS trg_resumen_detalle_ins ON detalle_pedido;
DROP TRIGGER IF EXISTS trg_resumen_detalle_upd ON detalle_pedido;
DROP TRIGGER IF EXISTS trg_resumen_detalle_del ON detalle_pedido;
DROP TRIGGER IF EXISTS trg_resumen_cambio_categoria ON producto;
DROP TABLE   IF EXISTS resumen_ventas_categoria CASCADE;

CREATE TABLE resumen_ventas_categoria (
    id_categoria    BIGINT        PRIMARY KEY REFERENCES categoria (id_categoria),
    unidades        BIGINT        NOT NULL DEFAULT 0 CHECK (unidades >= 0),
    facturacion     NUMERIC(16,2) NOT NULL DEFAULT 0 CHECK (facturacion >= 0),
    actualizado_en  TIMESTAMPTZ   NOT NULL DEFAULT now()
);

COMMENT ON TABLE resumen_ventas_categoria IS
  'Desnormalización controlada (U4): totales por categoría mantenidos por triggers sobre detalle_pedido y producto.';

-- Aplica un conjunto de variaciones (id_categoria, unidades, facturación) al resumen.
-- Primero actualiza las categorías que ya tienen fila y después inserta las nuevas.
-- No se usa un único INSERT ... ON CONFLICT: PostgreSQL controla los CHECK sobre la fila
-- propuesta antes de detectar el conflicto, y una variación negativa (una venta que se
-- borra) haría fallar el CHECK aunque el total final sea válido.
CREATE OR REPLACE FUNCTION fn_resumen_aplicar(p_delta JSONB)
RETURNS VOID
LANGUAGE sql AS $$
    WITH d AS (
        SELECT (e->>'id_categoria')::BIGINT AS id_categoria,
               (e->>'unidades')::BIGINT     AS unidades,
               (e->>'facturacion')::NUMERIC AS facturacion
          FROM jsonb_array_elements(p_delta) AS e
    ), upd AS (
        UPDATE resumen_ventas_categoria r
           SET unidades       = r.unidades    + d.unidades,
               facturacion    = r.facturacion + d.facturacion,
               actualizado_en = now()
          FROM d
         WHERE r.id_categoria = d.id_categoria
        RETURNING r.id_categoria
    )
    INSERT INTO resumen_ventas_categoria AS r (id_categoria, unidades, facturacion)
    SELECT d.id_categoria, d.unidades, d.facturacion
      FROM d
     WHERE d.id_categoria NOT IN (SELECT id_categoria FROM upd)
    ON CONFLICT (id_categoria) DO UPDATE      -- otra transacción insertó la misma categoría a la vez
       SET unidades       = r.unidades    + EXCLUDED.unidades,
           facturacion    = r.facturacion + EXCLUDED.facturacion,
           actualizado_en = now();
$$;

-- Trigger por sentencia sobre detalle_pedido: usa tablas de transición, así un INSERT
-- de muchas líneas actualiza el resumen una sola vez.
CREATE OR REPLACE FUNCTION fn_resumen_detalle()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_delta JSONB;
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT jsonb_agg(x) INTO v_delta FROM (
            SELECT p.id_categoria, SUM(n.cantidad) AS unidades, SUM(n.cantidad * n.precio_unitario) AS facturacion
              FROM nuevas n JOIN producto p ON p.id_producto = n.id_producto
             GROUP BY p.id_categoria) x;
    ELSIF TG_OP = 'DELETE' THEN
        SELECT jsonb_agg(x) INTO v_delta FROM (
            SELECT p.id_categoria, -SUM(o.cantidad) AS unidades, -SUM(o.cantidad * o.precio_unitario) AS facturacion
              FROM viejas o JOIN producto p ON p.id_producto = o.id_producto
             GROUP BY p.id_categoria) x;
    ELSE  -- UPDATE
        SELECT jsonb_agg(x) INTO v_delta FROM (
            SELECT id_categoria, SUM(unidades) AS unidades, SUM(facturacion) AS facturacion
              FROM (SELECT p.id_categoria, n.cantidad AS unidades, n.cantidad * n.precio_unitario AS facturacion
                      FROM nuevas n JOIN producto p ON p.id_producto = n.id_producto
                    UNION ALL
                    SELECT p.id_categoria, -o.cantidad, -(o.cantidad * o.precio_unitario)
                      FROM viejas o JOIN producto p ON p.id_producto = o.id_producto) t
             GROUP BY id_categoria) x;
    END IF;
    IF v_delta IS NOT NULL THEN
        PERFORM fn_resumen_aplicar(v_delta);
    END IF;
    RETURN NULL;
END $$;

-- PostgreSQL no admite tablas de transición en un trigger con varios eventos: van tres.
CREATE TRIGGER trg_resumen_detalle_ins AFTER INSERT ON detalle_pedido
    REFERENCING NEW TABLE AS nuevas
    FOR EACH STATEMENT EXECUTE FUNCTION fn_resumen_detalle();
CREATE TRIGGER trg_resumen_detalle_upd AFTER UPDATE ON detalle_pedido
    REFERENCING OLD TABLE AS viejas NEW TABLE AS nuevas
    FOR EACH STATEMENT EXECUTE FUNCTION fn_resumen_detalle();
CREATE TRIGGER trg_resumen_detalle_del AFTER DELETE ON detalle_pedido
    REFERENCING OLD TABLE AS viejas
    FOR EACH STATEMENT EXECUTE FUNCTION fn_resumen_detalle();

-- Si un producto cambia de categoría, sus ventas pasan a la categoría nueva.
CREATE OR REPLACE FUNCTION fn_resumen_cambio_categoria()
RETURNS TRIGGER
LANGUAGE plpgsql AS $$
DECLARE
    v_u BIGINT;
    v_f NUMERIC;
BEGIN
    SELECT COALESCE(SUM(cantidad), 0), COALESCE(SUM(cantidad * precio_unitario), 0)
      INTO v_u, v_f
      FROM detalle_pedido WHERE id_producto = NEW.id_producto;
    IF v_u > 0 THEN
        PERFORM fn_resumen_aplicar(jsonb_build_array(
            jsonb_build_object('id_categoria', OLD.id_categoria, 'unidades', -v_u, 'facturacion', -v_f),
            jsonb_build_object('id_categoria', NEW.id_categoria, 'unidades',  v_u, 'facturacion',  v_f)));
    END IF;
    RETURN NULL;
END $$;

CREATE TRIGGER trg_resumen_cambio_categoria
    AFTER UPDATE OF id_categoria ON producto
    FOR EACH ROW WHEN (OLD.id_categoria IS DISTINCT FROM NEW.id_categoria)
    EXECUTE FUNCTION fn_resumen_cambio_categoria();

-- Salvaguarda 2: diferencias entre el resumen y el cálculo real (vacío = consistente).
CREATE OR REPLACE FUNCTION fn_verificar_resumen_categoria()
RETURNS TABLE (id_categoria BIGINT, unidades_resumen BIGINT, unidades_real BIGINT,
               facturacion_resumen NUMERIC, facturacion_real NUMERIC)
LANGUAGE sql STABLE AS $$
    WITH real AS (
        SELECT c.id_categoria,
               COALESCE(SUM(dp.cantidad), 0)::BIGINT                   AS unidades,
               COALESCE(SUM(dp.cantidad * dp.precio_unitario), 0)      AS facturacion
          FROM categoria c
          LEFT JOIN producto p        ON p.id_categoria = c.id_categoria
          LEFT JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
         GROUP BY c.id_categoria)
    SELECT real.id_categoria, r.unidades, real.unidades, r.facturacion, real.facturacion
      FROM real
      LEFT JOIN resumen_ventas_categoria r ON r.id_categoria = real.id_categoria
     WHERE r.id_categoria IS NULL
        OR r.unidades    <> real.unidades
        OR r.facturacion <> real.facturacion;
$$;

-- Salvaguarda 3: reconstrucción completa.
CREATE OR REPLACE PROCEDURE sp_recalcular_resumen_categoria()
LANGUAGE plpgsql AS $$
BEGIN
    LOCK TABLE resumen_ventas_categoria IN EXCLUSIVE MODE;
    DELETE FROM resumen_ventas_categoria;
    INSERT INTO resumen_ventas_categoria (id_categoria, unidades, facturacion)
    SELECT c.id_categoria,
           COALESCE(SUM(dp.cantidad), 0),
           COALESCE(SUM(dp.cantidad * dp.precio_unitario), 0)
      FROM categoria c
      LEFT JOIN producto p        ON p.id_categoria = c.id_categoria
      LEFT JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
     GROUP BY c.id_categoria;
END $$;

-- Carga inicial
CALL sp_recalcular_resumen_categoria();

-- Vista del top 5, para que los reportes no dependan del nombre de la tabla.
CREATE OR REPLACE VIEW v_top5_categorias AS
SELECT c.id_categoria, c.nombre, r.unidades, r.facturacion
  FROM resumen_ventas_categoria r
  JOIN categoria c ON c.id_categoria = r.id_categoria
 ORDER BY r.facturacion DESC
 LIMIT 5;
