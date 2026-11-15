-- Parte A · Costo de los índices sobre las escrituras.
-- Ronda = 500 INSERT de a uno en detalle_pedido (como los hace la aplicación al guardar líneas de pedido).
-- 1 ronda de calentamiento y 15 medidas; se informa la mediana. Además se mide lo mismo para 500 INSERT en
-- pedido, porque los índices sobre pedido no los paga detalle_pedido.
-- Todo corre dentro de BEGIN ... ROLLBACK: no queda ninguna fila en la base.
BEGIN;
CREATE TEMP TABLE medicion_escritura (tabla TEXT, ronda INT, ms NUMERIC);
DO $$
DECLARE
    peds  BIGINT[];
    prods BIGINT[];
    cli   BIGINT;
    t0    TIMESTAMPTZ;
BEGIN
    SELECT MIN(id_cliente) INTO cli FROM cliente;
    -- pedido: 500 INSERT por ronda
    FOR r IN 0..15 LOOP
        t0 := clock_timestamp();
        FOR i IN 1..500 LOOP
            INSERT INTO pedido (fecha, forma_pago, id_cliente) VALUES (now(), 'EFECTIVO', cli);
        END LOOP;
        IF r > 0 THEN
            INSERT INTO medicion_escritura
            VALUES ('pedido', r, round((extract(epoch FROM clock_timestamp() - t0) * 1000)::NUMERIC, 2));
        END IF;
    END LOOP;
    -- detalle_pedido: 500 pedidos de la ronda anterior, sin líneas; cada ronda les agrega una línea con un
    -- producto distinto, así no se repite el par (id_pedido, id_producto) que exige el UNIQUE.
    SELECT array_agg(id_pedido ORDER BY id_pedido) INTO peds
      FROM (SELECT id_pedido FROM pedido ORDER BY id_pedido DESC LIMIT 500) x;
    SELECT array_agg(id_producto ORDER BY id_producto) INTO prods
      FROM (SELECT id_producto FROM producto ORDER BY id_producto LIMIT 16) y;
    FOR r IN 0..15 LOOP
        t0 := clock_timestamp();
        FOR i IN 1..500 LOOP
            INSERT INTO detalle_pedido (cantidad, precio_unitario, id_pedido, id_producto)
            VALUES (1, 100, peds[i], prods[r + 1]);
        END LOOP;
        IF r > 0 THEN
            INSERT INTO medicion_escritura
            VALUES ('detalle_pedido', r, round((extract(epoch FROM clock_timestamp() - t0) * 1000)::NUMERIC, 2));
        END IF;
    END LOOP;
END $$;
\echo '######## Índices de detalle_pedido y de pedido durante la medición'
SELECT tablename, indexname FROM pg_indexes WHERE tablename IN ('detalle_pedido', 'pedido') ORDER BY 1, 2;
\echo '######## Tiempo de cada ronda de 500 INSERT (ms)'
SELECT tabla, ronda, ms FROM medicion_escritura ORDER BY tabla, ronda;
\echo '######## Mediana (ms)'
SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY ms) AS mediana_ms FROM medicion_escritura WHERE tabla = 'detalle_pedido';
\echo '######## Mediana pedido (ms)'
SELECT percentile_cont(0.5) WITHIN GROUP (ORDER BY ms) AS mediana_ms FROM medicion_escritura WHERE tabla = 'pedido';
ROLLBACK;
