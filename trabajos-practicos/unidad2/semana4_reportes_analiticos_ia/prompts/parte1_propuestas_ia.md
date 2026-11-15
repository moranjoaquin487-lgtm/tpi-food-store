# Prompt de la Parte 1: planes reales de dos consultas analíticas para que la IA proponga cambios

Base PostgreSQL de Food Store: pedido (id_pedido, fecha TIMESTAMPTZ, forma_pago, id_cliente),
detalle_pedido (id_detalle, id_pedido, id_producto, cantidad, precio_unitario, UNIQUE (id_pedido, id_producto)),
producto (id_producto, nombre, precio, stock, activo, id_categoria), categoria (id_categoria, nombre, activo)
y cliente (id_cliente, nombre, apellido, email). Volumen: 200 000 pedidos, 400 000 líneas, 50 000 productos,
20 000 clientes y 5 categorías. Índices actuales: las PK, los UNIQUE, pedido (id_cliente),
pedido (fecha) INCLUDE (id_pedido, id_cliente), detalle_pedido (id_producto) INCLUDE (cantidad),
producto (id_categoria) WHERE activo y producto (id_categoria, precio) WHERE activo.
Contexto medido en esta misma PC en la práctica anterior: random_page_cost está en 4 (valor por defecto)
y los planes con workers paralelos tardaron más que sin ellos.

Para cada consulta, con su plan real de EXPLAIN (ANALYZE, BUFFERS): identificá qué algoritmo de join
(Nested Loop, Hash Join o Merge Join) eligió el optimizador en cada combinación de tablas, y proponé
reescrituras y/o índices que lo mejoren. Justificá cada propuesta con el nodo de join concreto del plan:
qué nodo ataca y por qué esperás que cambie.

Consultas (cada una se ejecutó primero una vez, para calentar la caché):

```sql
-- Q1 · Facturación por categoría y mes (últimos 6 meses)
SELECT c.nombre AS categoria, date_trunc('month', p.fecha)::date AS mes,
       COUNT(DISTINCT p.id_pedido) AS pedidos, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
  JOIN producto pr ON pr.id_producto = d.id_producto
  JOIN categoria c ON c.id_categoria = pr.id_categoria
 WHERE p.fecha >= date_trunc('month', now()) - INTERVAL '6 months'
 GROUP BY c.nombre, date_trunc('month', p.fecha)
 ORDER BY mes, facturado DESC;

-- Q2 · Ranking de clientes por gasto en los últimos 90 días (los 20 primeros puestos)
SELECT puesto, id_cliente, cliente, pedidos, gastado FROM (
    SELECT c.id_cliente, c.nombre || ' ' || c.apellido AS cliente,
           COUNT(DISTINCT p.id_pedido) AS pedidos,
           SUM(d.cantidad * d.precio_unitario) AS gastado,
           RANK() OVER (ORDER BY SUM(d.cantidad * d.precio_unitario) DESC) AS puesto
      FROM cliente c
      JOIN pedido p ON p.id_cliente = c.id_cliente
      JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
     WHERE p.fecha >= now() - INTERVAL '90 days'
     GROUP BY c.id_cliente, c.nombre, c.apellido
) r
 WHERE puesto <= 20
 ORDER BY puesto, id_cliente;

```

Planes reales:

```
######## Q1 · Facturación por categoría y mes (últimos 6 meses)

                                                                                       QUERY PLAN                                                                                        
 Sort  (cost=43321.41..43591.63 rows=108086 width=61) (actual time=579.613..579.621 rows=35.00 loops=1)
   Sort Key: (((date_trunc('month'::text, p.fecha)))::date), (sum(((d.cantidad)::numeric * d.precio_unitario))) DESC
   Sort Method: quicksort  Memory: 27kB
   Buffers: shared hit=4138, temp read=791 written=793
   ->  GroupAggregate  (cost=26164.21..30217.44 rows=108086 width=61) (actual time=508.386..579.529 rows=35.00 loops=1)
         Group Key: c.nombre, (date_trunc('month'::text, p.fecha))
         Buffers: shared hit=4132, temp read=791 written=793
         ->  Sort  (cost=26164.21..26434.43 rows=108086 width=43) (actual time=506.226..539.802 rows=108616.00 loops=1)
               Sort Key: c.nombre, (date_trunc('month'::text, p.fecha)), p.id_pedido
               Sort Method: external merge  Disk: 6328kB
               Buffers: shared hit=4132, temp read=791 written=793
               ->  Hash Join  (cost=4340.12..13802.24 rows=108086 width=43) (actual time=35.277..256.847 rows=108616.00 loops=1)
                     Hash Cond: (pr.id_categoria = c.id_categoria)
                     Buffers: shared hit=4123
                     ->  Hash Join  (cost=4339.00..13006.70 rows=108086 width=34) (actual time=35.212..206.788 rows=108616.00 loops=1)
                           Hash Cond: (d.id_producto = pr.id_producto)
                           Buffers: shared hit=4122
                           ->  Hash Join  (cost=2697.78..11081.72 rows=108086 width=34) (actual time=19.350..139.102 rows=108616.00 loops=1)
                                 Hash Cond: (d.id_pedido = p.id_pedido)
                                 Buffers: shared hit=3606
                                 ->  Seq Scan on detalle_pedido d  (cost=0.00..7333.94 rows=399994 width=26) (actual time=0.040..26.447 rows=399994.00 loops=1)
                                       Buffers: shared hit=3334
                                 ->  Hash  (cost=2022.21..2022.21 rows=54045 width=16) (actual time=19.143..19.144 rows=54309.00 loops=1)
                                       Buckets: 65536  Batches: 1  Memory Usage: 3058kB
                                       Buffers: shared hit=272
                                       ->  Index Only Scan using idx_pedido_fecha on pedido p  (cost=0.43..2022.21 rows=54045 width=16) (actual time=0.045..9.307 rows=54309.00 loops=1)
                                             Index Cond: (fecha >= (date_trunc('month'::text, now()) - '6 mons'::interval))
                                             Heap Fetches: 0
                                             Index Searches: 1
                                             Buffers: shared hit=272
                           ->  Hash  (cost=1016.10..1016.10 rows=50010 width=16) (actual time=15.744..15.745 rows=50010.00 loops=1)
                                 Buckets: 65536  Batches: 1  Memory Usage: 2857kB
                                 Buffers: shared hit=516
                                 ->  Seq Scan on producto pr  (cost=0.00..1016.10 rows=50010 width=16) (actual time=0.016..7.419 rows=50010.00 loops=1)
                                       Buffers: shared hit=516
                     ->  Hash  (cost=1.05..1.05 rows=5 width=17) (actual time=0.047..0.048 rows=5.00 loops=1)
                           Buckets: 1024  Batches: 1  Memory Usage: 9kB
                           Buffers: shared hit=1
                           ->  Seq Scan on categoria c  (cost=0.00..1.05 rows=5 width=17) (actual time=0.031..0.033 rows=5.00 loops=1)
                                 Buffers: shared hit=1
 Planning:
   Buffers: shared hit=75
 Planning Time: 1.159 ms
 Execution Time: 582.079 ms
(44 filas)

######## Q2 · Ranking de clientes por gasto en los últimos 90 días (los 20 primeros puestos)

                                                                                             QUERY PLAN                                                                                             
 Sort  (cost=18862.07..18912.08 rows=20005 width=88) (actual time=169.457..169.462 rows=20.00 loops=1)
   Sort Key: r.puesto, r.id_cliente
   Sort Method: quicksort  Memory: 26kB
   Buffers: shared hit=3688, temp read=396 written=397
   ->  Subquery Scan on r  (cost=16782.76..17432.91 rows=20005 width=88) (actual time=169.423..169.449 rows=20.00 loops=1)
         Buffers: shared hit=3688, temp read=396 written=397
         ->  WindowAgg  (cost=16782.76..17232.86 rows=20005 width=112) (actual time=169.422..169.444 rows=20.00 loops=1)
               Window: w1 AS (ORDER BY (sum(((d.cantidad)::numeric * d.precio_unitario))) ROWS UNBOUNDED PRECEDING)
               Run Condition: (rank() OVER w1 <= 20)
               Storage: Memory  Maximum Storage: 17kB
               Buffers: shared hit=3688, temp read=396 written=397
               ->  Sort  (cost=16782.74..16832.76 rows=20005 width=72) (actual time=169.399..169.404 rows=21.00 loops=1)
                     Sort Key: (sum(((d.cantidad)::numeric * d.precio_unitario))) DESC
                     Sort Method: quicksort  Memory: 1331kB
                     Buffers: shared hit=3688, temp read=396 written=397
                     ->  GroupAggregate  (cost=14352.59..15353.58 rows=20005 width=72) (actual time=134.313..163.856 rows=14226.00 loops=1)
                           Group Key: c.id_cliente
                           Buffers: shared hit=3688, temp read=396 written=397
                           ->  Sort  (cost=14352.59..14477.74 rows=50062 width=50) (actual time=134.297..140.698 rows=49623.00 loops=1)
                                 Sort Key: c.id_cliente, p.id_pedido
                                 Sort Method: external merge  Disk: 3168kB
                                 Buffers: shared hit=3688, temp read=396 written=397
                                 ->  Hash Join  (cost=1929.50..10444.89 rows=50062 width=50) (actual time=12.365..101.544 rows=49623.00 loops=1)
                                       Hash Cond: (p.id_cliente = c.id_cliente)
                                       Buffers: shared hit=3688
                                       ->  Hash Join  (cost=1251.38..9635.33 rows=50062 width=26) (actual time=6.481..81.576 rows=49623.00 loops=1)
                                             Hash Cond: (d.id_pedido = p.id_pedido)
                                             Buffers: shared hit=3460
                                             ->  Seq Scan on detalle_pedido d  (cost=0.00..7333.94 rows=399994 width=18) (actual time=0.015..22.937 rows=399994.00 loops=1)
                                                   Buffers: shared hit=3334
                                             ->  Hash  (cost=938.48..938.48 rows=25032 width=16) (actual time=6.389..6.390 rows=24810.00 loops=1)
                                                   Buckets: 32768  Batches: 1  Memory Usage: 1419kB
                                                   Buffers: shared hit=126
                                                   ->  Index Only Scan using idx_pedido_fecha on pedido p  (cost=0.42..938.48 rows=25032 width=16) (actual time=0.027..3.070 rows=24810.00 loops=1)
                                                         Index Cond: (fecha >= (now() - '90 days'::interval))
                                                         Heap Fetches: 0
                                                         Index Searches: 1
                                                         Buffers: shared hit=126
                                       ->  Hash  (cost=428.05..428.05 rows=20005 width=32) (actual time=5.808..5.808 rows=20005.00 loops=1)
                                             Buckets: 32768  Batches: 1  Memory Usage: 1524kB
                                             Buffers: shared hit=228
                                             ->  Seq Scan on cliente c  (cost=0.00..428.05 rows=20005 width=32) (actual time=0.023..2.338 rows=20005.00 loops=1)
                                                   Buffers: shared hit=228
 Planning:
   Buffers: shared hit=28
 Planning Time: 0.735 ms
 Execution Time: 171.783 ms
(47 filas)

```
