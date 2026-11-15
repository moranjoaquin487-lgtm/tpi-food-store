-- Parte 5 · Estrategia para la consulta de la competencia (propuesta de Claude sobre el plan ANTES).
-- El plan ANTES usa el índice parcial por categoría, trae los ~10.000 productos vigentes de la categoría
-- y recién ahí filtra el rango de precio y ordena. Un índice parcial por (categoría, precio) entrega las
-- filas ya filtradas por rango y en el orden pedido, así que el LIMIT corta apenas tiene 20.
CREATE INDEX idx_producto_categoria_precio_activo ON producto (id_categoria, precio) WHERE activo = TRUE;
ANALYZE producto;
\ir parte5_competencia.sql
