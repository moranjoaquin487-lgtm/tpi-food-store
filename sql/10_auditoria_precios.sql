-- 10 — Trigger con tablas de transición + JSONB

DROP TRIGGER IF EXISTS trg_auditar_precios ON producto;
DROP TABLE IF EXISTS auditoria_precio;

CREATE TABLE auditoria_precio (
    id           BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cambiado_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    usuario_bd   TEXT        NOT NULL DEFAULT current_user,
    detalle      JSONB       NOT NULL
);

-- Trigger por SENTENCIA con tablas de transición (REFERENCING)
CREATE OR REPLACE FUNCTION fn_auditar_precios()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    INSERT INTO auditoria_precio (detalle)
    SELECT jsonb_build_object(
               'id_producto', n.id_producto,
               'producto',    n.nombre,
               'antes',       o.precio,
               'despues',     n.precio,
               'variacion_%', ROUND((n.precio - o.precio) / NULLIF(o.precio, 0) * 100, 2))
    FROM nuevos n
    JOIN viejos o USING (id_producto)
    WHERE n.precio IS DISTINCT FROM o.precio;
    RETURN NULL;
END;
$$;

-- Sin AFTER UPDATE OF precio: PostgreSQL no lo admite con tablas de transición
CREATE TRIGGER trg_auditar_precios
    AFTER UPDATE ON producto
    REFERENCING OLD TABLE AS viejos NEW TABLE AS nuevos
    FOR EACH STATEMENT
    EXECUTE FUNCTION fn_auditar_precios();

-- Prueba: aumento del 5 % a los productos 40 a 44 (un solo UPDATE)
UPDATE producto SET precio = ROUND(precio * 1.05, 2)
WHERE id_producto BETWEEN 40 AND 44;

-- Un UPDATE que no toca el precio no genera auditoría
UPDATE producto SET stock = stock + 1 WHERE id_producto = 40;

SELECT id, cambiado_at::timestamp(0) AS cambiado_at, detalle
FROM auditoria_precio ORDER BY id;

-- Consulta sobre el JSONB: aumentos mayores al 4 %
SELECT detalle->>'producto' AS producto,
       (detalle->>'antes')::NUMERIC   AS antes,
       (detalle->>'despues')::NUMERIC AS despues
FROM auditoria_precio
WHERE (detalle->>'variacion_%')::NUMERIC > 4;
