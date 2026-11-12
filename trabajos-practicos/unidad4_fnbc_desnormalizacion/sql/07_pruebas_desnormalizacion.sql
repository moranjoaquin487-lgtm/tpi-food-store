-- U4 · 07 — Pruebas de las salvaguardas de la desnormalización
-- Todo corre dentro de BEGIN ... ROLLBACK.

\echo '== Estado inicial: diferencias entre resumen y cálculo real (se esperan 0 filas)'
SELECT * FROM fn_verificar_resumen_categoria();

\echo '== Un pedido nuevo con CALL sp_registrar_pedido actualiza el resumen en la misma transacción'
BEGIN;
SELECT id_categoria, unidades, facturacion FROM resumen_ventas_categoria
 WHERE id_categoria = (SELECT id_categoria FROM producto WHERE nombre = 'Yerba mate 1kg');
SELECT MIN(id_cliente) AS cliente FROM cliente \gset
SELECT id_producto AS yerba FROM producto WHERE nombre = 'Yerba mate 1kg' \gset
CALL sp_registrar_pedido(:cliente, 'EFECTIVO',
     jsonb_build_array(jsonb_build_object('id_producto', :yerba, 'cantidad', 2)));
SELECT id_categoria, unidades, facturacion FROM resumen_ventas_categoria
 WHERE id_categoria = (SELECT id_categoria FROM producto WHERE nombre = 'Yerba mate 1kg');
\echo '   Diferencias después del INSERT (se esperan 0 filas):'
SELECT * FROM fn_verificar_resumen_categoria();

\echo '== UPDATE de cantidades y DELETE de un pedido completo (cascada sobre detalle_pedido)'
UPDATE detalle_pedido SET cantidad = cantidad + 1
 WHERE id_pedido = (SELECT MIN(id_pedido) FROM pedido);
DELETE FROM pedido WHERE id_pedido = (SELECT MAX(id_pedido) FROM pedido);
\echo '   Diferencias (se esperan 0 filas):'
SELECT * FROM fn_verificar_resumen_categoria();

\echo '== Cambio de categoría de un producto con ventas'
UPDATE producto SET id_categoria = (SELECT id_categoria FROM categoria WHERE nombre = 'Bebidas')
 WHERE nombre = 'Yerba mate 1kg';
\echo '   Diferencias (se esperan 0 filas):'
SELECT * FROM fn_verificar_resumen_categoria();
ROLLBACK;

\echo '== Si alguien desactiva el trigger, la verificación lo detecta y el recálculo lo repara'
BEGIN;
ALTER TABLE detalle_pedido DISABLE TRIGGER trg_resumen_detalle_ins;
INSERT INTO detalle_pedido (cantidad, precio_unitario, id_pedido, id_producto)
SELECT 1, p.precio, (SELECT MIN(id_pedido) FROM pedido), p.id_producto
  FROM producto p
 WHERE p.activo AND p.stock > 0
   AND NOT EXISTS (SELECT 1 FROM detalle_pedido d
                    WHERE d.id_pedido = (SELECT MIN(id_pedido) FROM pedido) AND d.id_producto = p.id_producto)
 ORDER BY p.id_producto LIMIT 1;
\echo '   Diferencias detectadas (se espera 1 fila):'
SELECT * FROM fn_verificar_resumen_categoria();
CALL sp_recalcular_resumen_categoria();
\echo '   Después del recálculo (se esperan 0 filas):'
SELECT * FROM fn_verificar_resumen_categoria();
ROLLBACK;

\echo '== CHECK de no negatividad (se espera error)'
BEGIN;
UPDATE resumen_ventas_categoria SET unidades = -1
 WHERE id_categoria = (SELECT MIN(id_categoria) FROM resumen_ventas_categoria);
ROLLBACK;
