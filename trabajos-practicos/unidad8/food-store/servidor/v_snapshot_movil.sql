-- Food Store — v_snapshot_movil.sql (TP8, consigna 2.a · parada 5)
-- Lo que viaja a la tablet: solo columnas del catálogo. No viajan clientes, pedidos ni usuarios.
-- Incluye los productos dados de baja (lápidas, eliminado = true) para que la tablet se entere de la baja.
-- Se corre sobre la copia de pruebas (foodstore_tp8), nunca sobre la base real.
-- Code review (OpenCode): #13 centavos en BIGINT; #4 filas_totales para detectar un CSV incompleto.

CREATE OR REPLACE VIEW v_snapshot_movil AS
SELECT p.id,
       p.nombre,
       ROUND(p.precio * 100)::BIGINT                     AS precio_centavos,  -- 1050.00 -> 105000; NUMERIC(10,2) no entra en INTEGER
       p.stock,
       (p.activo AND c.activo AND p.stock > 0)           AS disponible,       -- se puede ofrecer ahora
       NOT p.activo                                      AS eliminado,        -- baja lógica (R7): lápida
       to_char(now() AT TIME ZONE 'UTC',
               'YYYY-MM-DD"T"HH24:MI:SS"Z"')             AS copiado_en,       -- fecha de la copia
       COUNT(*) OVER ()                                  AS filas_totales     -- cuántas filas tiene la instantánea entera
  FROM producto p
  JOIN categoria c ON c.id = p.categoria_id;

COMMENT ON VIEW v_snapshot_movil IS
  'Instantánea del catálogo para la tablet (TP8). Precio en centavos; eliminado = lápida de baja lógica; filas_totales para controlar la carga.';
