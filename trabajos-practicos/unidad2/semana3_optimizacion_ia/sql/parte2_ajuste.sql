-- Parte 2 · Ajuste posterior, con los mismos índices: costo del acceso aleatorio.
-- En los planes DESPUÉS, el planner siguió leyendo detalle_pedido completo con Seq Scan aunque ya podía
-- llegar a las líneas por el índice UNIQUE (id_pedido, id_producto) o por el nuevo índice de Q3.
-- random_page_cost vale 4 por defecto (pensado para discos mecánicos): hace parecer caro cada acceso por
-- índice. Con el disco SSD y los datos en caché de esta PC, el valor recomendado es 1.1.
-- Se cambia solo para esta sesión: no queda guardado en la base ni en el servidor.
SET random_page_cost = 1.1;
SHOW random_page_cost;
\ir parte2_despues.sql
