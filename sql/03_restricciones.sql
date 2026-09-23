-- 03 — Reglas de negocio con triggers

-- REGLA 1 — Producto inactivo

CREATE OR REPLACE FUNCTION fn_verificar_producto_activo()
RETURNS TRIGGER AS $$
DECLARE
    v_activo BOOLEAN;
BEGIN
    SELECT activo INTO v_activo
      FROM producto
     WHERE id_producto = NEW.id_producto;

    IF v_activo = FALSE THEN
        RAISE EXCEPTION 'No se puede vender el producto con id %: está dado de baja (activo = FALSE)',
                        NEW.id_producto;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_verificar_producto_activo ON detalle_pedido;

CREATE TRIGGER trg_verificar_producto_activo
    BEFORE INSERT OR UPDATE
    ON detalle_pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_verificar_producto_activo();

-- REGLA 2 — Stock insuficiente

CREATE OR REPLACE FUNCTION fn_verificar_stock_suficiente()
RETURNS TRIGGER AS $$
DECLARE
    v_stock INTEGER;
BEGIN
    SELECT stock INTO v_stock
      FROM producto
     WHERE id_producto = NEW.id_producto;

    IF NEW.cantidad > v_stock THEN
        RAISE EXCEPTION 'Stock insuficiente para el producto con id %: se solicitan % unidades, pero hay % en stock',
                        NEW.id_producto, NEW.cantidad, v_stock;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_verificar_stock_suficiente ON detalle_pedido;

CREATE TRIGGER trg_verificar_stock_suficiente
    BEFORE INSERT OR UPDATE
    ON detalle_pedido
    FOR EACH ROW
    EXECUTE FUNCTION fn_verificar_stock_suficiente();
