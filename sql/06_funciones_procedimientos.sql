-- 06 — Funciones y procedimientos almacenados (PL/pgSQL)

-- 6.1 FUNCIÓN: total de un pedido
CREATE OR REPLACE FUNCTION fn_total_pedido(p_id_pedido BIGINT)
RETURNS NUMERIC(14,2)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
    v_total NUMERIC(14,2);
BEGIN
    SELECT COALESCE(SUM(dp.cantidad * dp.precio_unitario), 0)
      INTO v_total
      FROM detalle_pedido dp
     WHERE dp.id_pedido = p_id_pedido;

    RETURN v_total;
END;
$$;

-- 6.2 PROCEDIMIENTO: registrar un pedido completo
CREATE OR REPLACE PROCEDURE sp_registrar_pedido(
    p_id_cliente  BIGINT,
    p_forma_pago  forma_pago_enum,
    p_items       JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_id_pedido BIGINT;
    v_item      JSONB;
BEGIN
    IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
        RAISE EXCEPTION 'El pedido debe tener al menos un ítem';
    END IF;

    INSERT INTO pedido (forma_pago, id_cliente)
    VALUES (p_forma_pago, p_id_cliente)
    RETURNING id_pedido INTO v_id_pedido;

    FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
        -- La línea se inserta con el precio de lista vigente.
        INSERT INTO detalle_pedido (cantidad, precio_unitario, id_pedido, id_producto)
        SELECT (v_item->>'cantidad')::INT, pr.precio, v_id_pedido, pr.id_producto
          FROM producto pr
         WHERE pr.id_producto = (v_item->>'id_producto')::BIGINT;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Producto % inexistente', v_item->>'id_producto';
        END IF;

        UPDATE producto
           SET stock = stock - (v_item->>'cantidad')::INT
         WHERE id_producto = (v_item->>'id_producto')::BIGINT;
    END LOOP;

    RAISE NOTICE 'Pedido % registrado. Total: %', v_id_pedido, fn_total_pedido(v_id_pedido);
END;
$$;
