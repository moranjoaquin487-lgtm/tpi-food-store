-- Food Store — verificacion_final.sql (TP8, consigna 2.c)
-- Después de todos los casos: pedidos, líneas de pedido, productos y stock tienen que ser los mismos que al empezar.
-- Lo único que cambió en el servidor es lo que preparamos a mano para C2 (precio) y C4 (baja lógica).
-- Code review #18: además de los totales, se comparan pedidos y líneas fila por fila, y la cantidad de productos.

-- 1. Totales: antes y ahora
SELECT f.pedidos                              AS pedidos_al_empezar,
       (SELECT COUNT(*) FROM pedido)          AS pedidos_ahora,
       f.lineas_detalle                       AS lineas_al_empezar,
       (SELECT COUNT(*) FROM detalle_pedido)  AS lineas_ahora,
       f.productos                            AS productos_al_empezar,
       (SELECT COUNT(*) FROM producto)        AS productos_ahora,
       f.stock_total                          AS stock_total_al_empezar,
       (SELECT SUM(stock) FROM producto)      AS stock_total_ahora
  FROM (SELECT MAX(pedidos) AS pedidos, MAX(lineas_detalle) AS lineas_detalle,
               COUNT(*) AS productos, SUM(stock) AS stock_total
          FROM tp8_foto_inicial) f;

-- 2. Pedidos o líneas de pedido que no son iguales a los del principio (tiene que dar 0 filas)
(SELECT 'pedido que falta o cambió' AS diferencia, id::text AS clave FROM tp8_foto_pedido
 EXCEPT SELECT 'pedido que falta o cambió', id::text FROM pedido)
UNION ALL
(SELECT 'pedido nuevo', id::text FROM pedido
 EXCEPT SELECT 'pedido nuevo', id::text FROM tp8_foto_pedido)
UNION ALL
(SELECT 'línea que falta o cambió', pedido_id || '-' || producto_id || ' x' || cantidad || ' a ' || precio_unitario FROM tp8_foto_detalle
 EXCEPT SELECT 'línea que falta o cambió', pedido_id || '-' || producto_id || ' x' || cantidad || ' a ' || precio_unitario FROM detalle_pedido)
UNION ALL
(SELECT 'línea nueva', pedido_id || '-' || producto_id || ' x' || cantidad || ' a ' || precio_unitario FROM detalle_pedido
 EXCEPT SELECT 'línea nueva', pedido_id || '-' || producto_id || ' x' || cantidad || ' a ' || precio_unitario FROM tp8_foto_detalle);

-- 3. Productos cuyo stock cambió, o que aparecieron o desaparecieron (tiene que dar 0 filas)
SELECT COALESCE(p.nombre, f.nombre) AS producto, f.stock AS stock_al_empezar, p.stock AS stock_ahora
  FROM producto p
  FULL JOIN tp8_foto_inicial f ON f.producto_id = p.id
 WHERE p.id IS NULL OR f.producto_id IS NULL OR p.stock <> f.stock;

-- 4. Lo que sí cambió, y por qué: solo las preparaciones de C2 y C4, hechas en el servidor
SELECT p.nombre,
       f.precio AS precio_al_empezar, p.precio AS precio_ahora,
       f.activo AS activo_al_empezar, p.activo AS activo_ahora
  FROM producto p
  JOIN tp8_foto_inicial f ON f.producto_id = p.id
 WHERE p.precio <> f.precio OR p.activo <> f.activo
 ORDER BY p.nombre;
