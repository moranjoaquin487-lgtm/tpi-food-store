-- U7 · 01 — Estado del pedido
-- El esquema de Food Store no registraba el estado de un pedido, y la consigna de la U7
-- trabaja con él (consultas por estado). Se agrega al modelo relacional, que sigue siendo
-- la fuente de verdad. Los pedidos nuevos nacen PENDIENTE.
-- Los pedidos existentes son datos de prueba: el estado se asigna con una regla fija por id,
-- así el resultado es el mismo en cualquier máquina.

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'estado_pedido_enum') THEN
        CREATE TYPE estado_pedido_enum AS ENUM ('PENDIENTE', 'CONFIRMADO', 'ENTREGADO', 'CANCELADO');
    END IF;
END $$;

-- La regla por id se aplica UNA sola vez, cuando se crea la columna. Si el script se vuelve a
-- correr, no toca nada: antes reasignaba todos los estados en cada corrida y pisaba los
-- cambios reales (code review U4-U7, hallazgo #7).
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns
                    WHERE table_schema = 'public' AND table_name = 'pedido' AND column_name = 'estado') THEN
        ALTER TABLE pedido ADD COLUMN estado estado_pedido_enum NOT NULL DEFAULT 'PENDIENTE';
        UPDATE pedido
           SET estado = CASE id_pedido % 10
                            WHEN 3 THEN 'CANCELADO'
                            WHEN 4 THEN 'CONFIRMADO'
                            WHEN 5 THEN 'PENDIENTE'
                            ELSE 'ENTREGADO'
                        END::estado_pedido_enum;
    ELSE
        RAISE NOTICE 'La columna estado ya existe: no se reasignan los estados';
    END IF;
END $$;

SELECT estado, COUNT(*) AS pedidos FROM pedido GROUP BY 1 ORDER BY 1;
