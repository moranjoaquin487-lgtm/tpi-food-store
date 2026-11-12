-- Food Store — foto_inicial.sql (TP8, consigna 2.c)
-- Guarda pedidos y stock de la copia de pruebas ANTES de los casos, para comprobar al final
-- que la simulación no creó pedidos ni tocó el stock (verificacion_final.sql).

DROP TABLE IF EXISTS tp8_foto_inicial;
DROP TABLE IF EXISTS tp8_foto_pedido;
DROP TABLE IF EXISTS tp8_foto_detalle;

CREATE TABLE tp8_foto_inicial AS
SELECT p.id    AS producto_id,
       p.nombre,
       p.stock,
       p.precio,
       p.activo,
       (SELECT COUNT(*) FROM pedido)         AS pedidos,
       (SELECT COUNT(*) FROM detalle_pedido) AS lineas_detalle
  FROM producto p;

-- Copia fila por fila de pedidos y líneas (code review #18): así se detecta también un cambio
-- que no mueve los totales, como borrar una línea y agregar otra.
CREATE TABLE tp8_foto_pedido  AS SELECT id, fecha, forma_pago, cliente_id FROM pedido;
CREATE TABLE tp8_foto_detalle AS SELECT pedido_id, producto_id, cantidad, precio_unitario FROM detalle_pedido;

SELECT MAX(pedidos)        AS pedidos,
       MAX(lineas_detalle) AS lineas_detalle,
       SUM(stock)          AS stock_total,
       COUNT(*)            AS productos
  FROM tp8_foto_inicial;
