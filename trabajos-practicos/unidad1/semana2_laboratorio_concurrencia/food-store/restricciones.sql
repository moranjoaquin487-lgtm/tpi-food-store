-- Food Store — restricciones.sql (Semana 2, Parte 1)
-- Garantiza por el motor las reglas A, B y C de specs/spec_restricciones.md.
-- Se puede ejecutar más de una vez: los triggers se eliminan con DROP ... IF EXISTS
-- y las funciones se reemplazan con CREATE OR REPLACE.
-- No incluye control transaccional (BEGIN/COMMIT/ROLLBACK): la transacción la abre
-- scripts/aplicar_restricciones.sh. Los BEGIN ... END de las funciones son sintaxis de PL/pgSQL.

-- ============================================================================
-- Regla A — Precio congelado al vender
-- Al insertar una línea, precio_unitario debe coincidir con producto.precio.
-- Una vez registrada la línea, precio_unitario no se puede modificar.
-- No alcanza un CHECK declarativo porque hay que comparar con otra tabla.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_regla_a_precio_congelado()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_precio_actual NUMERIC(10,2);
BEGIN
    IF TG_OP = 'INSERT' THEN
        SELECT precio
          INTO v_precio_actual
          FROM producto
         WHERE id = NEW.producto_id;

        -- Si el producto no existe, la FK de detalle_pedido se encarga del error.
        IF NOT FOUND THEN
            RETURN NEW;
        END IF;

        IF NEW.precio_unitario IS DISTINCT FROM v_precio_actual THEN
            RAISE EXCEPTION
                'Regla A violada: el precio unitario (%) no coincide con el precio actual del producto (%).',
                NEW.precio_unitario, v_precio_actual;
        END IF;
    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.precio_unitario IS DISTINCT FROM OLD.precio_unitario THEN
            RAISE EXCEPTION
                'Regla A violada: no se puede modificar el precio unitario de una línea ya vendida.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_regla_a_precio_congelado ON detalle_pedido;
CREATE TRIGGER trg_regla_a_precio_congelado
    BEFORE INSERT OR UPDATE ON detalle_pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_regla_a_precio_congelado();

-- ============================================================================
-- Regla B — Baja de una categoría
-- categoria.activo no puede pasar de TRUE a FALSE si la categoría tiene al
-- menos un producto con producto.activo = TRUE.
-- No alcanza un CHECK declarativo porque hay que consultar otra tabla.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_regla_b_baja_categoria()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF OLD.activo IS TRUE AND NEW.activo IS FALSE THEN
        IF EXISTS (
            SELECT 1
              FROM producto
             WHERE categoria_id = NEW.id
               AND activo IS TRUE
        ) THEN
            RAISE EXCEPTION
                'Regla B violada: no se puede dar de baja la categoría "%" porque tiene productos activos.',
                OLD.nombre;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_regla_b_baja_categoria ON categoria;
CREATE TRIGGER trg_regla_b_baja_categoria
    BEFORE UPDATE OF activo ON categoria
    FOR EACH ROW
    EXECUTE FUNCTION fn_regla_b_baja_categoria();

-- ============================================================================
-- Regla C — Fecha de un pedido
-- pedido.fecha no puede ser posterior al momento en que se inserta o modifica
-- la fila. Se usa clock_timestamp() para tomar el momento de la sentencia.
-- ============================================================================

CREATE OR REPLACE FUNCTION fn_regla_c_fecha_pedido()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.fecha > clock_timestamp() THEN
        RAISE EXCEPTION
            'Regla C violada: la fecha del pedido no puede ser posterior al momento actual.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_regla_c_fecha_pedido ON pedido;
CREATE TRIGGER trg_regla_c_fecha_pedido
    BEFORE INSERT OR UPDATE ON pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_regla_c_fecha_pedido();
