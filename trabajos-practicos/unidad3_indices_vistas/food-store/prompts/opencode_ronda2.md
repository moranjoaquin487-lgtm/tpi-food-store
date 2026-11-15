# Ronda siguiente para OpenCode: resultado medido de tus índices

Probé tus propuestas (propuestas/indices_opencode.sql) sobre la copia de prueba, con la configuración por defecto
(random_page_cost = 4, hasta 2 workers paralelos por consulta). Cada consulta se ejecutó una vez para
calentar la caché y después 3 veces; abajo van las medianas y el último plan de cada una.

Criterio de las specs: el plan deja el Seq Scan sobre la tabla grande y la mediana baja al menos a la mitad.

```
  C1: 92.231 -> 133.484 ms (+45 %) NO cumple el tiempo
  C2: 132.009 -> 145.157 ms (+10 %) NO cumple el tiempo
  C3: 133.836 -> 170.368 ms (+27 %) NO cumple el tiempo
  C4: 89.943 -> 136.753 ms (+52 %) NO cumple el tiempo
```

Escrituras, 500 INSERT de a uno (mediana de 15 rondas, en la misma corrida) sin -> con tus índices:
detalle_pedido 22.83 -> 25.92 ms;
pedido 10.18 -> 10.61 ms.

Leé las specs de specs/ otra vez y estos planes. Para las consultas que no cumplen el criterio, decí qué nodo
del plan medido es ahora el cuello de botella y proponé el ajuste: un índice adicional, un reemplazo o
ninguno, si creés que ningún índice puede cumplirlo. Escribí las propuestas en
propuestas/indices_opencode_ronda2.sql, con el mismo formato de comentarios (spec, nodo que ataca, por qué
esperás que cambie). No repitas lo que ya cubre un índice existente o uno tuyo de la ronda anterior.
No ejecutes nada contra la base y no modifiques otros archivos.

Índices de la base durante la prueba:

```
                indexname                 | tamano  |                                                          indexdef                                                          
------------------------------------------+---------+----------------------------------------------------------------------------------------------------------------------------
 categoria_nombre_key                     | 16 kB   | CREATE UNIQUE INDEX categoria_nombre_key ON public.categoria USING btree (nombre)
 categoria_pkey                           | 16 kB   | CREATE UNIQUE INDEX categoria_pkey ON public.categoria USING btree (id_categoria)
 cliente_email_key                        | 1376 kB | CREATE UNIQUE INDEX cliente_email_key ON public.cliente USING btree (email)
 cliente_pkey                             | 456 kB  | CREATE UNIQUE INDEX cliente_pkey ON public.cliente USING btree (id_cliente)
 detalle_pedido_id_pedido_id_producto_key | 13 MB   | CREATE UNIQUE INDEX detalle_pedido_id_pedido_id_producto_key ON public.detalle_pedido USING btree (id_pedido, id_producto)
 detalle_pedido_pkey                      | 9144 kB | CREATE UNIQUE INDEX detalle_pedido_pkey ON public.detalle_pedido USING btree (id_detalle)
 idx_detalle_pedido_id_producto           | 4848 kB | CREATE INDEX idx_detalle_pedido_id_producto ON public.detalle_pedido USING btree (id_producto)
 idx_pedido_fecha                         | 7936 kB | CREATE INDEX idx_pedido_fecha ON public.pedido USING btree (fecha) INCLUDE (id_pedido, id_cliente)
 idx_pedido_id_cliente                    | 2416 kB | CREATE INDEX idx_pedido_id_cliente ON public.pedido USING btree (id_cliente)
 pedido_pkey                              | 4592 kB | CREATE UNIQUE INDEX pedido_pkey ON public.pedido USING btree (id_pedido)
 idx_producto_categoria_activo            | 336 kB  | CREATE INDEX idx_producto_categoria_activo ON public.producto USING btree (id_categoria) WHERE (activo = true)
 producto_pkey                            | 1112 kB | CREATE UNIQUE INDEX producto_pkey ON public.producto USING btree (id_producto)
 usuario_mail_key                         | 16 kB   | CREATE UNIQUE INDEX usuario_mail_key ON public.usuario USING btree (mail)
 usuario_pkey                             | 16 kB   | CREATE UNIQUE INDEX usuario_pkey ON public.usuario USING btree (id)
(14 filas)
```

Planes medidos (la última de las 3 ejecuciones):

```
######## C1 · Facturación por día de la última semana (S3.1)
 GroupAggregate  (cost=6775.43..7342.59 rows=2078 width=44) (actual time=119.550..130.166 rows=8.00 loops=1)
   Group Key: (date(p.fecha))
   Buffers: shared hit=3514
   ->  Gather Merge  (cost=6775.43..7259.47 rows=4156 width=22) (actual time=119.205..128.701 rows=4473.00 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=3514
         ->  Sort  (cost=5775.41..5779.74 rows=1732 width=22) (actual time=31.106..31.223 rows=1491.00 loops=3)
               Sort Key: (date(p.fecha)), p.id_pedido
               Sort Method: quicksort  Memory: 402kB
               Buffers: shared hit=3514
               Worker 0:  Sort Method: quicksort  Memory: 25kB
               Worker 1:  Sort Method: quicksort  Memory: 25kB
               ->  Hash Join  (cost=106.77..5682.24 rows=1732 width=22) (actual time=0.431..30.119 rows=1491.00 loops=3)
                     Hash Cond: (d.id_pedido = p.id_pedido)
                     Buffers: shared hit=3482
                     ->  Parallel Seq Scan on detalle_pedido d  (cost=0.00..5133.64 rows=166664 width=18) (actual time=0.005..10.365 rows=133331.33 loops=3)
                           Buffers: shared hit=3467
                     ->  Hash  (cost=80.79..80.79 rows=2078 width=16) (actual time=1.130..1.131 rows=2231.00 loops=1)
                           Buckets: 4096  Batches: 1  Memory Usage: 137kB
                           Buffers: shared hit=15
                           ->  Index Only Scan using idx_pedido_fecha on pedido p  (cost=0.43..80.79 rows=2078 width=16) (actual time=0.051..0.583 rows=2231.00 loops=1)
                                 Index Cond: (fecha >= ((CURRENT_DATE - 7))::timestamp with time zone)
                                 Heap Fetches: 0
                                 Index Searches: 1
                                 Buffers: shared hit=15
 Planning:
   Buffers: shared hit=22
 Planning Time: 0.388 ms
 Execution Time: 130.400 ms

######## C2 · Los 10 clientes que más gastaron en los últimos 30 días (S3.2)
 Limit  (cost=10016.20..10016.23 rows=10 width=64) (actual time=121.920..127.094 rows=10.00 loops=1)
   Buffers: shared hit=4288
   ->  Sort  (cost=10016.20..10056.82 rows=16245 width=64) (actual time=121.919..127.091 rows=10.00 loops=1)
         Sort Key: (sum(((d.cantidad)::numeric * d.precio_unitario))) DESC
         Sort Method: top-N heapsort  Memory: 26kB
         Buffers: shared hit=4288
         ->  HashAggregate  (cost=9462.09..9665.15 rows=16245 width=64) (actual time=117.042..125.526 rows=6815.00 loops=1)
               Group Key: c.id_cliente
               Batches: 1  Memory Usage: 3345kB
               Buffers: shared hit=4288
               ->  Gather  (cost=2086.23..9299.64 rows=16245 width=42) (actual time=10.590..109.693 rows=16825.00 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     Buffers: shared hit=4288
                     ->  Hash Join  (cost=1086.23..6675.14 rows=6769 width=42) (actual time=9.915..38.969 rows=5608.33 loops=3)
                           Hash Cond: (p.id_cliente = c.id_cliente)
                           Buffers: shared hit=4288
                           ->  Hash Join  (cost=408.12..5979.26 rows=6769 width=18) (actual time=2.633..29.364 rows=5608.33 loops=3)
                                 Hash Cond: (d.id_pedido = p.id_pedido)
                                 Buffers: shared hit=3604
                                 ->  Parallel Seq Scan on detalle_pedido d  (cost=0.00..5133.64 rows=166664 width=18) (actual time=0.011..8.960 rows=133331.33 loops=3)
                                       Buffers: shared hit=3467
                                 ->  Hash  (cost=306.58..306.58 rows=8123 width=16) (actual time=2.579..2.580 rows=8366.00 loops=3)
                                       Buckets: 16384 (originally 8192)  Batches: 1 (originally 1)  Memory Usage: 521kB
                                       Buffers: shared hit=137
                                       ->  Index Only Scan using idx_pedido_fecha on pedido p  (cost=0.42..306.58 rows=8123 width=16) (actual time=0.158..1.318 rows=8366.00 loops=3)
                                             Index Cond: (fecha >= (now() - '30 days'::interval))
                                             Heap Fetches: 0
                                             Index Searches: 3
                                             Buffers: shared hit=137
                           ->  Hash  (cost=428.05..428.05 rows=20005 width=32) (actual time=7.207..7.207 rows=20005.00 loops=3)
                                 Buckets: 32768  Batches: 1  Memory Usage: 1524kB
                                 Buffers: shared hit=684
                                 ->  Seq Scan on cliente c  (cost=0.00..428.05 rows=20005 width=32) (actual time=0.127..3.148 rows=20005.00 loops=3)
                                       Buffers: shared hit=684
 Planning:
   Buffers: shared hit=30
 Planning Time: 0.642 ms
 Execution Time: 127.913 ms

######## C3 · Los 10 productos que más facturaron en los últimos 30 días (S4.3)
 Limit  (cost=11094.48..11094.51 rows=10 width=71) (actual time=165.289..165.413 rows=10.00 loops=1)
   Buffers: shared hit=5155
   ->  Sort  (cost=11094.48..11135.10 rows=16245 width=71) (actual time=165.287..165.410 rows=10.00 loops=1)
         Sort Key: (sum(((d.cantidad)::numeric * d.precio_unitario))) DESC, pr.id_producto
         Sort Method: top-N heapsort  Memory: 26kB
         Buffers: shared hit=5155
         ->  HashAggregate  (cost=10540.37..10743.44 rows=16245 width=71) (actual time=150.987..160.523 rows=14553.00 loops=1)
               Group Key: pr.id_producto, c.nombre
               Batches: 1  Memory Usage: 6417kB
               Buffers: shared hit=5155
               ->  Gather  (cost=3050.45..10296.70 rows=16245 width=41) (actual time=22.122..127.372 rows=16825.00 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     Buffers: shared hit=5155
                     ->  Hash Join  (cost=2050.45..7672.20 rows=6769 width=41) (actual time=25.179..62.715 rows=5608.33 loops=3)
                           Hash Cond: (pr.id_categoria = c.id_categoria)
                           Buffers: shared hit=5155
                           ->  Hash Join  (cost=2049.34..7638.25 rows=6769 width=40) (actual time=25.026..60.842 rows=5608.33 loops=3)
                                 Hash Cond: (d.id_producto = pr.id_producto)
                                 Buffers: shared hit=5152
                                 ->  Hash Join  (cost=408.12..5979.26 rows=6769 width=18) (actual time=3.100..35.407 rows=5608.33 loops=3)
                                       Hash Cond: (d.id_pedido = p.id_pedido)
                                       Buffers: shared hit=3604
                                       ->  Parallel Seq Scan on detalle_pedido d  (cost=0.00..5133.64 rows=166664 width=26) (actual time=0.010..10.829 rows=133331.33 loops=3)
                                             Buffers: shared hit=3467
                                       ->  Hash  (cost=306.58..306.58 rows=8123 width=8) (actual time=3.043..3.044 rows=8366.00 loops=3)
                                             Buckets: 16384 (originally 8192)  Batches: 1 (originally 1)  Memory Usage: 455kB
                                             Buffers: shared hit=137
                                             ->  Index Only Scan using idx_pedido_fecha on pedido p  (cost=0.42..306.58 rows=8123 width=8) (actual time=0.160..1.542 rows=8366.00 loops=3)
                                                   Index Cond: (fecha >= (now() - '30 days'::interval))
                                                   Heap Fetches: 0
                                                   Index Searches: 3
                                                   Buffers: shared hit=137
                                 ->  Hash  (cost=1016.10..1016.10 rows=50010 width=30) (actual time=21.792..21.793 rows=50010.00 loops=3)
                                       Buckets: 65536  Batches: 1  Memory Usage: 3638kB
                                       Buffers: shared hit=1548
                                       ->  Seq Scan on producto pr  (cost=0.00..1016.10 rows=50010 width=30) (actual time=0.169..9.962 rows=50010.00 loops=3)
                                             Buffers: shared hit=1548
                           ->  Hash  (cost=1.05..1.05 rows=5 width=17) (actual time=0.138..0.138 rows=5.00 loops=3)
                                 Buckets: 1024  Batches: 1  Memory Usage: 9kB
                                 Buffers: shared hit=3
                                 ->  Seq Scan on categoria c  (cost=0.00..1.05 rows=5 width=17) (actual time=0.125..0.127 rows=5.00 loops=3)
                                       Buffers: shared hit=3
 Planning:
   Buffers: shared hit=36
 Planning Time: 0.879 ms
 Execution Time: 166.928 ms

######## C4 · Productos vigentes nunca vendidos (7.3)
 Sort  (cost=14586.60..14587.81 rows=484 width=32) (actual time=128.522..128.525 rows=10.00 loops=1)
   Sort Key: producto.nombre
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=3983
   ->  Hash Right Anti Join  (cost=1641.22..14565.02 rows=484 width=32) (actual time=127.510..128.483 rows=10.00 loops=1)
         Hash Cond: (detalle_pedido.id_producto = producto.id_producto)
         Buffers: shared hit=3983
         ->  Seq Scan on detalle_pedido  (cost=0.00..7466.94 rows=399994 width=8) (actual time=0.047..23.706 rows=399994.00 loops=1)
               Buffers: shared hit=3467
         ->  Hash  (cost=1016.10..1016.10 rows=50010 width=32) (actual time=17.074..17.075 rows=50009.00 loops=1)
               Buckets: 65536  Batches: 1  Memory Usage: 3828kB
               Buffers: shared hit=516
               ->  Seq Scan on producto  (cost=0.00..1016.10 rows=50010 width=32) (actual time=0.025..8.248 rows=50009.00 loops=1)
                     Filter: activo
                     Rows Removed by Filter: 1
                     Buffers: shared hit=516
 Planning:
   Buffers: shared hit=14
 Planning Time: 0.361 ms
 Execution Time: 129.082 ms

```
