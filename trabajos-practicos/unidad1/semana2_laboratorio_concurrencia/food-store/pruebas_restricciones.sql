-- Food Store — pruebas_restricciones.sql (Semana 2, Parte 1)
-- Casos de la tabla de specs/spec_restricciones.md, en el mismo orden.
-- Cada caso es una sentencia suelta: los inválidos muestran el error del motor.
-- No incluye BEGIN, COMMIT ni ROLLBACK: la transacción la abre scripts/aplicar_restricciones.sh.
-- Las filas se buscan por nombre de producto/categoría o por email de cliente, nunca por id.

-- Caso 1 (Regla A) — Resultado esperado: se inserta.
-- Agrega la Napolitana al pedido de Jorge Díaz con el precio actual del producto.
WITH pedido_jorge AS (
    SELECT pe.id
      FROM pedido pe
      JOIN cliente c ON c.id = pe.cliente_id
     WHERE c.email = 'jorge.diaz@mail.com'
     ORDER BY pe.fecha DESC, pe.id DESC
     LIMIT 1
)
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
SELECT pj.id, pr.id, 1, pr.precio
  FROM pedido_jorge pj
 CROSS JOIN producto pr
 WHERE pr.nombre = 'Napolitana';

-- Caso 2 (Regla A) — Resultado esperado: error.
-- Agrega la Cerveza 1L al pedido de Jorge Díaz con un precio distinto del actual.
WITH pedido_jorge AS (
    SELECT pe.id
      FROM pedido pe
      JOIN cliente c ON c.id = pe.cliente_id
     WHERE c.email = 'jorge.diaz@mail.com'
     ORDER BY pe.fecha DESC, pe.id DESC
     LIMIT 1
)
INSERT INTO detalle_pedido (pedido_id, producto_id, cantidad, precio_unitario)
SELECT pj.id, pr.id, 1, pr.precio + 1
  FROM pedido_jorge pj
 CROSS JOIN producto pr
 WHERE pr.nombre = 'Cerveza 1L';

-- Caso 3 (Regla A) — Resultado esperado: error.
-- Cambia el precio_unitario de una línea ya registrada (Fugazzeta del pedido de Jorge Díaz).
UPDATE detalle_pedido d
   SET precio_unitario = d.precio_unitario + 1
  FROM producto pr,
       pedido pe,
       cliente c
 WHERE d.producto_id = pr.id
   AND d.pedido_id = pe.id
   AND pe.cliente_id = c.id
   AND pr.nombre = 'Fugazzeta'
   AND c.email = 'jorge.diaz@mail.com';

-- Caso 4 (Regla A) — Resultado esperado: se acepta y las líneas vendidas conservan su precio.
-- Cambia el precio de lista de la Muzzarella, que ya tiene ventas.
UPDATE producto
   SET precio = precio + 50
 WHERE nombre = 'Muzzarella';

-- Muestra que las líneas ya vendidas de la Muzzarella conservan su precio original.
SELECT c.email,
       pe.fecha,
       d.precio_unitario,
       pr.precio AS precio_actual
  FROM detalle_pedido d
  JOIN producto pr ON pr.id = d.producto_id
  JOIN pedido pe ON pe.id = d.pedido_id
  JOIN cliente c ON c.id = pe.cliente_id
 WHERE pr.nombre = 'Muzzarella'
 ORDER BY pe.fecha, c.email;

-- Caso 5 (Regla B) — Resultado esperado: se acepta.
-- Da de baja la categoría Promociones, que no tiene productos.
UPDATE categoria
   SET activo = FALSE
 WHERE nombre = 'Promociones';

-- Caso 6 (Regla B) — Resultado esperado: error.
-- Intenta dar de baja la categoría Pizzas, que tiene productos activos.
UPDATE categoria
   SET activo = FALSE
 WHERE nombre = 'Pizzas';

-- Caso 7 (Regla C) — Resultado esperado: se inserta.
-- Registra un pedido con la fecha de este momento para Carla Ortiz.
INSERT INTO pedido (fecha, forma_pago, cliente_id)
SELECT now(), 'EFECTIVO', id
  FROM cliente
 WHERE email = 'carla.ortiz@mail.com';

-- Caso 8 (Regla C) — Resultado esperado: error.
-- Intenta registrar un pedido con fecha de mañana para Pablo Rivas.
INSERT INTO pedido (fecha, forma_pago, cliente_id)
SELECT now() + INTERVAL '1 day', 'EFECTIVO', id
  FROM cliente
 WHERE email = 'pablo.rivas@mail.com';
