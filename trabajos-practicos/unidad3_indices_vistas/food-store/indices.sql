-- indices.sql · Parte A · Índices finalmente aceptados (Unidad 3)
-- Los dos los generó OpenCode a partir de las specs de Kiro (propuestas/indices_opencode.sql y
-- propuestas/indices_opencode_ronda2.sql) y se copian sin cambios. Se midieron con
-- `bash ejecutar_u3.sh probar` y `bash ejecutar_u3.sh despues` (evidencias/).
-- Se aceptan por la spec A1: con los dos juntos, C1 deja el Hash Join con Seq Scan sobre las dos tablas,
-- pasa a Nested Loop con dos Index Only Scan y baja mucho más de la mitad.
-- Para A2, A3 y A4 el criterio no se cumplió y no se agregó ningún otro índice (informe_mediciones.md).
-- El índice descartado por sobreindexación está en mediciones/parteA_descartado.sql.

-- ===== I1 · idx_pedido_fecha (OpenCode, ronda 1)
-- Spec: A1; también lo usan C2 y C3, que filtran pedido por los últimos 30 días.
-- Nodo que ataca: el Seq Scan sobre pedido, que leía las 200 005 filas y descartaba casi todas por la fecha.
-- Tipo: B-tree sobre fecha, la única columna del filtro de rango; en 7 días deja ~1 % de los pedidos.
-- INCLUDE (id_pedido, id_cliente): el join, el COUNT(DISTINCT) y la unión con cliente se resuelven sin
-- leer la tabla (Index Only Scan con Heap Fetches: 0).
-- No repite ningún índice: pedido solo tenía la PK y (id_cliente).
CREATE INDEX idx_pedido_fecha ON pedido (fecha) INCLUDE (id_pedido, id_cliente);

