-- Food Store — verificacion_final.sql (TP8, consigna 2.c)
-- Después de todos los casos: la cantidad de pedidos y el stock tienen que ser los mismos que al empezar.
-- Lo único que cambió en el servidor es lo que preparamos a mano para C2 (precio) y C4 (baja lógica).

-- 1. Pedidos, líneas de pedido y stock: antes y ahora
SELECT f.pedidos                              AS pedidos_al_empezar,
       (SELECT COUNT(*) FROM pedido)          AS pedidos_ahora,
       f.lineas_detalle                       AS lineas_al_empezar,
       (SELECT COUNT(*) FROM detalle_pedido)  AS lineas_ahora,
       f.stock_total                          AS stock_total_al_empezar,
       (SELECT SUM(stock) FROM producto)      AS stock_total_ahora
  FROM (SELECT MAX(pedidos) AS pedidos, MAX(lineas_detalle) AS lineas_detalle, SUM(stock) AS stock_total
          FROM tp8_foto_inicial) f;

-- 2. Productos cuyo stock cambió (tiene que dar 0 filas)
SELECT p.nombre, f.stock AS stock_al_empezar, p.stock AS stock_ahora
  FROM producto p
  JOIN tp8_foto_inicial f ON f.producto_id = p.id
 WHERE p.stock <> f.stock;

-- 3. Lo que sí cambió, y por qué: solo las preparaciones de C2 y C4, hechas en el servidor
SELECT p.nombre,
       f.precio AS precio_al_empezar, p.precio AS precio_ahora,
       f.activo AS activo_al_empezar, p.activo AS activo_ahora
  FROM producto p
  JOIN tp8_foto_inicial f ON f.producto_id = p.id
 WHERE p.precio <> f.precio OR p.activo <> f.activo
 ORDER BY p.nombre;
