# Informe de mediciones · Unidad 3 · Índices, vistas y vistas materializadas

**Alumno:** Moran, Joaquín Leandro · Trabajo individual.
**Base:** `foodstore_u3`, copia de prueba armada con `schema.sql` y `data.sql` (datos semilla y carga masiva de la Semana 3): categoria 5, producto 50010, cliente 20005, pedido 200005, detalle_pedido 399994, usuario 3. PostgreSQL 18 en Windows. No se tocó `foodstore`.
**Cómo se midió:** cada consulta se ejecuta una vez para calentar la caché y después 3 veces con `EXPLAIN (ANALYZE, BUFFERS)`; se informa la mediana. «Sin» y «con» se miden **en la misma corrida** (`ejecutar_u3.sh probar` y `despues`): en corridas distintas la misma consulta, sin ningún cambio, varió hasta un 50 %. Las escrituras son 500 `INSERT` de a uno por ronda, 15 rondas, dentro de una transacción que se deshace.

## Parte A · Plan de indexado

### Consultas de la carga de trabajo (marcadas en `queries.sql`)

| Consulta | Spec | Plan antes de indexar (`evidencias/parteA_antes.txt`) |
|---|---|---|
| C1 · Facturación por día de la última semana | `specs/A1_*.md` | Gather Merge, Parallel Hash Join, Parallel Seq Scan on detalle_pedido, Parallel Seq Scan on pedido · 92,2 ms |
| C2 · Los 10 clientes que más gastaron en 30 días | `specs/A2_*.md` | Gather, Hash Join, Parallel Hash Join, Parallel Seq Scan on detalle_pedido, Parallel Seq Scan on pedido, Seq Scan on cliente · 132,0 ms |
| C3 · Los 10 productos que más facturaron en 30 días | `specs/A3_*.md` | Gather, Hash Join, Parallel Hash Join, Parallel Seq Scan on detalle_pedido, Parallel Seq Scan on pedido, Seq Scan on producto, Seq Scan on categoria · 133,8 ms |
| C4 · Productos vigentes nunca vendidos | `specs/A4_*.md` | Hash Right Anti Join, Seq Scan on detalle_pedido, Seq Scan on producto · 89,9 ms |

Las cuatro leen `detalle_pedido` (399 994 filas) completa, y C1 a C3 también `pedido` (200 005 filas), que descarta más del 95 % por la fecha.

### Propuestas y decisiones

| Ronda | Propuesta | Origen | Decisión |
|---|---|---|---|
| 1 | `pedido (fecha) INCLUDE (id_pedido, id_cliente)` para A1, A2 y A3 | OpenCode, desde las specs (`propuestas/indices_opencode.sql`) | Se mide. Cambia el plan de `pedido` (Seq Scan → Index Only Scan), pero ninguna consulta baja a la mitad: el cuello de botella pasa a la lectura completa de `detalle_pedido` |
| 1 | Ningún índice para A4 | OpenCode | Se acepta: el anti join tiene que mirar todos los productos y el Hash es la estrategia correcta |
| 2 | `detalle_pedido (id_pedido) INCLUDE (id_producto, cantidad, precio_unitario)` | OpenCode, con los planes medidos de la ronda 1 (`propuestas/indices_opencode_ronda2.sql`) | Se mide junto con el anterior (abajo) |
| — | `producto (nombre, id_producto) WHERE activo = TRUE` para A4 | Kiro, en `specs/A4_productos_nunca_vendidos.md` | **Descartado por sobreindexación** (abajo) |

### Resultado: sin → con `indices.sql`

| Consulta | Ronda 2 (`probar`, misma corrida) | Medición final (`despues`, misma corrida) | Nodos con los índices en la medición final |
|---|---|---|---|
| C1 | 136,8 → 10,6 ms (−92 %) | 194,4 → 238,7 ms (+23 %) | Gather Merge, Hash Join, Parallel Seq Scan on detalle_pedido, Index Only Scan using idx_pedido_fecha |
| C2 | 142,4 → 130,1 ms (−9 %) | 218,4 → 235,8 ms (+8 %) | Gather, Hash Join, Parallel Seq Scan on detalle_pedido, Index Only Scan using idx_pedido_fecha, Seq Scan on cliente |
| C3 | 196,8 → 158,5 ms (−19 %) | 261,5 → 248,6 ms (−5 %) | Gather, Hash Join, Parallel Seq Scan on detalle_pedido, Index Only Scan using idx_pedido_fecha, Seq Scan on producto, Seq Scan on categoria |
| C4 | 161,1 → 125,3 ms (−22 %) | 193,2 → 179,0 ms (−7 %) | Hash Right Anti Join, Seq Scan on detalle_pedido, Seq Scan on producto |

**C1 cumplió el criterio en la ronda 2 y no en la medición final, con los mismos índices.** En la ronda 2 el planner eligió Nested Loop con dos Index Only Scan (136,8 → 10,6 ms, −92 %). En la medición final eligió el Hash Join con Seq Scan de `detalle_pedido` y no usó el índice de cobertura. El diagnóstico (`mediciones/parteA_diagnostico_c1.sql`, `evidencias/final_diagnostico_c1.txt`) muestra por qué:

| Plan de C1 con los dos índices (misma estadística) | Costo estimado | Tiempo real (mediana) |
|---|---|---|
| Hash Join en paralelo (el que eligió el planner) | 7380,03 | 203,6 ms |
| Nested Loop con Index Only Scan (forzado solo para ver su costo) | 7546,65 | — |
| Nested Loop, con `random_page_cost = 1.1` solo en la sesión | — | **14,9 ms** |

- Los dos planes cuestan casi lo mismo para el planner (el Nested Loop, un 2 % más), y la estadística de cada `ANALYZE` es una muestra: según la corrida, gana uno u otro. En la ronda 2 el Nested Loop se estimó en 7278,89 y ganó.
- En tiempo real no hay empate: el Hash Join tarda más de 10 veces. En su plan, los workers terminan el join a los ~57 ms y el `Gather Merge` recién entrega a los ~200 ms. Es la misma espera de los procesos paralelos en Windows que se midió en la Semana 3, y el costo estimado no la refleja.
- Con `random_page_cost = 1.1` (el valor para SSD que se midió en la Semana 3), el planner elige el Nested Loop siempre y C1 queda en 14,9 ms.

**Decisión:** se aceptan los dos índices para A1, con una condición documentada: el beneficio depende de que el planner elija el Nested Loop. Con la configuración por defecto eso pasa en algunas corridas y en otras no. El paso siguiente es fijar `random_page_cost = 1.1` para la base (`ALTER DATABASE … SET`). Antes, hay que medir el resto de `queries.sql`, porque ese cambio afecta todos los planes; en este trabajo solo se probó en la sesión. Si no se aplica, `idx_detalle_pedido_id_pedido_cover` no se justifica: ocupa 19 MB, unos dos tercios de lo que ocupa la tabla (3 467 páginas, ~27 MB), y el planner puede no usarlo.

C4 no tiene ningún índice nuevo que la afecte: su variación entre «sin» y «con» (−22 % y −7 %) da la medida del ruido de estas mediciones.

**A2 y A3 no cumplen el criterio** y no se agregó otro índice. Con 30 días son ~8 400 pedidos y ~16 800 líneas: el planner sigue prefiriendo leer `detalle_pedido` completa y unir con hash. `idx_pedido_fecha` cambia el nodo de `pedido` (Seq Scan → Index Only Scan, como pedía la spec), pero el tiempo no baja a la mitad. **A4 tampoco**: no se creó ningún índice y el plan no cambió.

### Costo sobre las escrituras

| 500 `INSERT` de a uno (mediana de 15 rondas) | Ronda 2: sin → con | Medición final: sin → con |
|---|---|---|
| `detalle_pedido` (paga el índice de cobertura) | 23,0 → 20,0 ms | 37,5 → 34,1 ms |
| `pedido` (paga `idx_pedido_fecha`) | 9,6 → 9,8 ms | 13,0 → 15,3 ms |

Con 500 filas por ronda, la diferencia en `detalle_pedido` queda dentro del ruido de la medición: en las dos corridas, con el índice nuevo salió apenas más rápido. En `pedido` las inserciones fueron un 3 % y un 18 % más lentas. El costo que sí es seguro es el espacio: 7936 kB para `idx_pedido_fecha` y 19 MB para el de cobertura, más que el `UNIQUE (id_pedido, id_producto)` (13 MB).

### Índice descartado por sobreindexación

Kiro sugirió en la spec A4 `CREATE INDEX … ON producto (nombre, id_producto) WHERE activo = TRUE`, para leer `producto` por índice y ya ordenado. Se descarta:

- **La condición parcial no filtra:** 50009 de 50010 productos están activos (99,998 %). Es, en la práctica, un índice completo sobre `producto`, de 2008 kB (la tabla ocupa 4128 kB), que se mantiene en cada alta y cambio de producto.
- **No ataca el cuello de botella:** C4 tarda por la lectura de las 400 000 líneas de `detalle_pedido`, no por la de `producto`.
- **Medido** (`mediciones/parteA_descartado.sql`, se crea y se deshace): el planner ni siquiera lo usa. C4 sigue con Hash Right Anti Join, Seq Scan on detalle_pedido, Seq Scan on producto: 193,2 → 179,1 ms, diferencia de ruido.
- **OpenCode llegó a la misma conclusión** al leer la spec y no lo propuso.

### Planes de la medición final (la última de las 3 ejecuciones)

**C1 · Facturación por día de la última semana · sin los índices**

```
 GroupAggregate  (cost=10577.48..11192.12 rows=2252 width=44) (actual time=163.805..176.369 rows=8.00 loops=1)
   Group Key: (date(p.fecha))
   Buffers: shared hit=5029
   ->  Gather Merge  (cost=10577.48..11102.04 rows=4504 width=22) (actual time=163.145..173.404 rows=4473.00 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=5029
         ->  Sort  (cost=9577.46..9582.15 rows=1877 width=22) (actual time=54.081..54.261 rows=1491.00 loops=3)
               Sort Key: (date(p.fecha)), p.id_pedido
               Sort Method: quicksort  Memory: 391kB
               Buffers: shared hit=5029
               Worker 0:  Sort Method: quicksort  Memory: 36kB
               Worker 1:  Sort Method: quicksort  Memory: 25kB
               ->  Parallel Hash Join  (cost=3899.56..9475.40 rows=1877 width=22) (actual time=14.344..52.465 rows=1491.00 loops=3)
                     Hash Cond: (d.id_pedido = p.id_pedido)
                     Buffers: shared hit=4997
                     ->  Parallel Seq Scan on detalle_pedido d  (cost=0.00..5133.64 rows=166664 width=18) (actual time=0.009..18.976 rows=199997.00 loops=2)
                           Buffers: shared hit=3467
                     ->  Parallel Hash  (cost=3883.00..3883.00 rows=1325 width=16) (actual time=14.194..14.195 rows=743.67 loops=3)
                           Buckets: 4096  Batches: 1  Memory Usage: 160kB
                           Buffers: shared hit=1530
                           ->  Parallel Seq Scan on pedido p  (cost=0.00..3883.00 rows=1325 width=16) (actual time=0.054..41.603 rows=2231.00 loops=1)
                                 Filter: (fecha >= ((CURRENT_DATE - 7))::timestamp with time zone)
                                 Rows Removed by Filter: 197774
                                 Buffers: shared hit=1530
 Planning:
   Buffers: shared hit=120
 Planning Time: 0.603 ms
 Execution Time: 176.551 ms
```

**C1 · con los índices**

```
 GroupAggregate  (cost=6783.22..7376.03 rows=2172 width=44) (actual time=224.432..238.448 rows=8.00 loops=1)
   Group Key: (date(p.fecha))
   Buffers: shared hit=3514
   ->  Gather Merge  (cost=6783.22..7289.15 rows=4344 width=22) (actual time=224.031..236.542 rows=4473.00 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         Buffers: shared hit=3514
         ->  Sort  (cost=5783.20..5787.72 rows=1810 width=22) (actual time=32.808..32.949 rows=1491.00 loops=3)
               Sort Key: (date(p.fecha)), p.id_pedido
               Sort Method: quicksort  Memory: 402kB
               Buffers: shared hit=3514
               Worker 0:  Sort Method: quicksort  Memory: 25kB
               Worker 1:  Sort Method: quicksort  Memory: 25kB
               ->  Hash Join  (cost=109.59..5685.26 rows=1810 width=22) (actual time=0.386..31.751 rows=1491.00 loops=3)
                     Hash Cond: (d.id_pedido = p.id_pedido)
                     Buffers: shared hit=3482
                     ->  Parallel Seq Scan on detalle_pedido d  (cost=0.00..5133.64 rows=166664 width=18) (actual time=0.009..11.317 rows=133331.33 loops=3)
                           Buffers: shared hit=3467
                     ->  Hash  (cost=82.44..82.44 rows=2172 width=16) (actual time=0.997..0.998 rows=2231.00 loops=1)
                           Buckets: 4096  Batches: 1  Memory Usage: 137kB
                           Buffers: shared hit=15
                           ->  Index Only Scan using idx_pedido_fecha on pedido p  (cost=0.43..82.44 rows=2172 width=16) (actual time=0.036..0.490 rows=2231.00 loops=1)
                                 Index Cond: (fecha >= ((CURRENT_DATE - 7))::timestamp with time zone)
                                 Heap Fetches: 0
                                 Buffers: shared hit=15
 Planning:
   Buffers: shared hit=21
 Planning Time: 0.596 ms
 Execution Time: 238.743 ms
```

**C2 · Los 10 clientes que más gastaron en 30 días · sin los índices**

```
 Limit  (cost=13283.49..13283.51 rows=10 width=64) (actual time=197.827..207.566 rows=10.00 loops=1)
   Buffers: shared hit=5681
   ->  Sort  (cost=13283.49..13324.55 rows=16425 width=64) (actual time=197.826..207.563 rows=10.00 loops=1)
         Sort Key: (sum(((d.cantidad)::numeric * d.precio_unitario))) DESC
         Sort Method: top-N heapsort  Memory: 26kB
         Buffers: shared hit=5681
         ->  HashAggregate  (cost=12723.24..12928.55 rows=16425 width=64) (actual time=191.456..205.219 rows=6811.00 loops=1)
               Group Key: c.id_cliente
               Batches: 1  Memory Usage: 3345kB
               Buffers: shared hit=5681
               ->  Gather  (cost=5327.38..12558.99 rows=16425 width=42) (actual time=89.579..184.395 rows=16813.00 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     Buffers: shared hit=5681
                     ->  Hash Join  (cost=4327.38..9916.49 rows=6844 width=42) (actual time=36.252..81.625 rows=5604.33 loops=3)
                           Hash Cond: (p.id_cliente = c.id_cliente)
                           Buffers: shared hit=5681
                           ->  Parallel Hash Join  (cost=3649.26..9220.41 rows=6844 width=18) (actual time=26.728..69.043 rows=5604.33 loops=3)
                                 Hash Cond: (d.id_pedido = p.id_pedido)
                                 Buffers: shared hit=4997
                                 ->  Parallel Seq Scan on detalle_pedido d  (cost=0.00..5133.64 rows=166664 width=18) (actual time=0.012..13.661 rows=133331.33 loops=3)
                                       Buffers: shared hit=3467
                                 ->  Parallel Hash  (cost=3588.88..3588.88 rows=4831 width=16) (actual time=26.581..26.582 rows=2786.33 loops=3)
                                       Buckets: 16384  Batches: 1  Memory Usage: 544kB
                                       Buffers: shared hit=1530
                                       ->  Parallel Seq Scan on pedido p  (cost=0.00..3588.88 rows=4831 width=16) (actual time=0.020..75.461 rows=8359.00 loops=1)
                                             Filter: (fecha >= (now() - '30 days'::interval))
                                             Rows Removed by Filter: 191646
                                             Buffers: shared hit=1530
                           ->  Hash  (cost=428.05..428.05 rows=20005 width=32) (actual time=9.402..9.403 rows=20005.00 loops=3)
                                 Buckets: 32768  Batches: 1  Memory Usage: 1524kB
                                 Buffers: shared hit=684
                                 ->  Seq Scan on cliente c  (cost=0.00..428.05 rows=20005 width=32) (actual time=0.189..4.242 rows=20005.00 loops=3)
                                       Buffers: shared hit=684
 Planning:
   Buffers: shared hit=135
 Planning Time: 0.892 ms
 Execution Time: 208.570 ms
```

**C2 · con los índices**

```
 Limit  (cost=10045.68..10045.70 rows=10 width=64) (actual time=228.800..234.753 rows=10.00 loops=1)
   Buffers: shared hit=4014
   ->  Sort  (cost=10045.68..10086.75 rows=16429 width=64) (actual time=228.798..234.750 rows=10.00 loops=1)
         Sort Key: (sum(((d.cantidad)::numeric * d.precio_unitario))) DESC
         Sort Method: top-N heapsort  Memory: 26kB
         Buffers: shared hit=4014
         ->  HashAggregate  (cost=9485.29..9690.65 rows=16429 width=64) (actual time=221.901..232.367 rows=6811.00 loops=1)
               Group Key: c.id_cliente
               Batches: 1  Memory Usage: 3345kB
               Buffers: shared hit=4014
               ->  Gather  (cost=2088.99..9321.00 rows=16429 width=42) (actual time=13.826..208.198 rows=16813.00 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     Buffers: shared hit=4014
                     ->  Hash Join  (cost=1088.99..6678.10 rows=6845 width=42) (actual time=10.073..55.918 rows=5604.33 loops=3)
                           Hash Cond: (p.id_cliente = c.id_cliente)
                           Buffers: shared hit=4014
                           ->  Hash Join  (cost=410.88..5982.02 rows=6845 width=18) (actual time=2.922..45.362 rows=5604.33 loops=3)
                                 Hash Cond: (d.id_pedido = p.id_pedido)
                                 Buffers: shared hit=3558
                                 ->  Parallel Seq Scan on detalle_pedido d  (cost=0.00..5133.64 rows=166664 width=18) (actual time=0.009..13.791 rows=133331.33 loops=3)
                                       Buffers: shared hit=3467
                                 ->  Hash  (cost=308.19..308.19 rows=8215 width=16) (actual time=4.271..4.272 rows=8359.00 loops=2)
                                       Buckets: 16384  Batches: 1  Memory Usage: 520kB
                                       Buffers: shared hit=91
                                       ->  Index Only Scan using idx_pedido_fecha on pedido p  (cost=0.42..308.19 rows=8215 width=16) (actual time=0.197..2.207 rows=8359.00 loops=2)
                                             Index Cond: (fecha >= (now() - '30 days'::interval))
                                             Heap Fetches: 0
                                             Buffers: shared hit=91
                           ->  Hash  (cost=428.05..428.05 rows=20005 width=32) (actual time=10.596..10.596 rows=20005.00 loops=2)
                                 Buckets: 32768  Batches: 1  Memory Usage: 1524kB
                                 Buffers: shared hit=456
                                 ->  Seq Scan on cliente c  (cost=0.00..428.05 rows=20005 width=32) (actual time=0.157..4.553 rows=20005.00 loops=2)
                                       Buffers: shared hit=456
 Planning:
   Buffers: shared hit=29
 Planning Time: 0.804 ms
 Execution Time: 235.811 ms
```

**C3 · Los 10 productos que más facturaron en 30 días · sin los índices**

```
 Limit  (cost=14363.03..14363.06 rows=10 width=71) (actual time=243.875..244.454 rows=10.00 loops=1)
   Buffers: shared hit=6548
   ->  Sort  (cost=14363.03..14404.10 rows=16425 width=71) (actual time=243.873..244.450 rows=10.00 loops=1)
         Sort Key: (sum(((d.cantidad)::numeric * d.precio_unitario))) DESC, pr.id_producto
         Sort Method: top-N heapsort  Memory: 26kB
         Buffers: shared hit=6548
         ->  HashAggregate  (cost=13802.78..14008.09 rows=16425 width=71) (actual time=226.932..238.597 rows=14544.00 loops=1)
               Group Key: pr.id_producto, c.nombre
               Batches: 1  Memory Usage: 6417kB
               Buffers: shared hit=6548
               ->  Gather  (cost=6291.60..13556.41 rows=16425 width=41) (actual time=102.379..199.940 rows=16813.00 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     Buffers: shared hit=6548
                     ->  Hash Join  (cost=5291.60..10913.91 rows=6844 width=41) (actual time=55.223..108.369 rows=5604.33 loops=3)
                           Hash Cond: (pr.id_categoria = c.id_categoria)
                           Buffers: shared hit=6548
                           ->  Hash Join  (cost=5290.49..10879.60 rows=6844 width=40) (actual time=55.016..105.909 rows=5604.33 loops=3)
                                 Hash Cond: (d.id_producto = pr.id_producto)
                                 Buffers: shared hit=6545
                                 ->  Parallel Hash Join  (cost=3649.26..9220.41 rows=6844 width=18) (actual time=25.378..71.757 rows=5604.33 loops=3)
                                       Hash Cond: (d.id_pedido = p.id_pedido)
                                       Buffers: shared hit=4997
                                       ->  Parallel Seq Scan on detalle_pedido d  (cost=0.00..5133.64 rows=166664 width=26) (actual time=0.017..15.078 rows=133331.33 loops=3)
                                             Buffers: shared hit=3467
                                       ->  Parallel Hash  (cost=3588.88..3588.88 rows=4831 width=8) (actual time=25.168..25.168 rows=2786.33 loops=3)
                                             Buckets: 16384  Batches: 1  Memory Usage: 480kB
                                             Buffers: shared hit=1530
                                             ->  Parallel Seq Scan on pedido p  (cost=0.00..3588.88 rows=4831 width=8) (actual time=0.026..71.694 rows=8359.00 loops=1)
                                                   Filter: (fecha >= (now() - '30 days'::interval))
                                                   Rows Removed by Filter: 191646
                                                   Buffers: shared hit=1530
                                 ->  Hash  (cost=1016.10..1016.10 rows=50010 width=30) (actual time=29.450..29.450 rows=50010.00 loops=3)
                                       Buckets: 65536  Batches: 1  Memory Usage: 3638kB
                                       Buffers: shared hit=1548
                                       ->  Seq Scan on producto pr  (cost=0.00..1016.10 rows=50010 width=30) (actual time=0.159..13.580 rows=50010.00 loops=3)
                                             Buffers: shared hit=1548
                           ->  Hash  (cost=1.05..1.05 rows=5 width=17) (actual time=0.190..0.191 rows=5.00 loops=3)
                                 Buckets: 1024  Batches: 1  Memory Usage: 9kB
                                 Buffers: shared hit=3
                                 ->  Seq Scan on categoria c  (cost=0.00..1.05 rows=5 width=17) (actual time=0.172..0.175 rows=5.00 loops=3)
                                       Buffers: shared hit=3
 Planning:
   Buffers: shared hit=142
 Planning Time: 1.178 ms
 Execution Time: 246.214 ms
```

**C3 · con los índices**

```
 Limit  (cost=11125.25..11125.27 rows=10 width=71) (actual time=246.517..246.652 rows=10.00 loops=1)
   Buffers: shared hit=4593
   ->  Sort  (cost=11125.25..11166.32 rows=16429 width=71) (actual time=246.515..246.648 rows=10.00 loops=1)
         Sort Key: (sum(((d.cantidad)::numeric * d.precio_unitario))) DESC, pr.id_producto
         Sort Method: top-N heapsort  Memory: 26kB
         Buffers: shared hit=4593
         ->  HashAggregate  (cost=10564.86..10770.22 rows=16429 width=71) (actual time=231.486..241.671 rows=14544.00 loops=1)
               Group Key: pr.id_producto, c.nombre
               Batches: 1  Memory Usage: 6417kB
               Buffers: shared hit=4593
               ->  Gather  (cost=3053.21..10318.42 rows=16429 width=41) (actual time=36.641..204.487 rows=16813.00 loops=1)
                     Workers Planned: 2
                     Workers Launched: 2
                     Buffers: shared hit=4593
                     ->  Hash Join  (cost=2053.21..7675.52 rows=6845 width=41) (actual time=26.480..73.864 rows=5604.33 loops=3)
                           Hash Cond: (pr.id_categoria = c.id_categoria)
                           Buffers: shared hit=4593
                           ->  Hash Join  (cost=2052.10..7641.21 rows=6845 width=40) (actual time=26.257..71.530 rows=5604.33 loops=3)
                                 Hash Cond: (d.id_producto = pr.id_producto)
                                 Buffers: shared hit=4590
                                 ->  Hash Join  (cost=410.88..5982.02 rows=6845 width=18) (actual time=2.782..43.772 rows=5604.33 loops=3)
                                       Hash Cond: (d.id_pedido = p.id_pedido)
                                       Buffers: shared hit=3558
                                       ->  Parallel Seq Scan on detalle_pedido d  (cost=0.00..5133.64 rows=166664 width=26) (actual time=0.009..13.934 rows=133331.33 loops=3)
                                             Buffers: shared hit=3467
                                       ->  Hash  (cost=308.19..308.19 rows=8215 width=8) (actual time=3.993..3.994 rows=8359.00 loops=2)
                                             Buckets: 16384  Batches: 1  Memory Usage: 455kB
                                             Buffers: shared hit=91
                                             ->  Index Only Scan using idx_pedido_fecha on pedido p  (cost=0.42..308.19 rows=8215 width=8) (actual time=0.177..2.029 rows=8359.00 loops=2)
                                                   Index Cond: (fecha >= (now() - '30 days'::interval))
                                                   Heap Fetches: 0
                                                   Buffers: shared hit=91
                                 ->  Hash  (cost=1016.10..1016.10 rows=50010 width=30) (actual time=34.985..34.986 rows=50010.00 loops=2)
                                       Buckets: 65536  Batches: 1  Memory Usage: 3638kB
                                       Buffers: shared hit=1032
                                       ->  Seq Scan on producto pr  (cost=0.00..1016.10 rows=50010 width=30) (actual time=0.151..15.883 rows=50010.00 loops=2)
                                             Buffers: shared hit=1032
                           ->  Hash  (cost=1.05..1.05 rows=5 width=17) (actual time=0.207..0.208 rows=5.00 loops=3)
                                 Buckets: 1024  Batches: 1  Memory Usage: 9kB
                                 Buffers: shared hit=3
                                 ->  Seq Scan on categoria c  (cost=0.00..1.05 rows=5 width=17) (actual time=0.190..0.192 rows=5.00 loops=3)
                                       Buffers: shared hit=3
 Planning:
   Buffers: shared hit=35
 Planning Time: 1.318 ms
 Execution Time: 248.566 ms
```

**C4 · Productos vigentes nunca vendidos · sin los índices**

```
 Sort  (cost=14608.09..14608.10 rows=1 width=32) (actual time=192.552..192.556 rows=10.00 loops=1)
   Sort Key: producto.nombre
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=3983
   ->  Hash Right Anti Join  (cost=1641.22..14608.08 rows=1 width=32) (actual time=191.286..192.508 rows=10.00 loops=1)
         Hash Cond: (detalle_pedido.id_producto = producto.id_producto)
         Buffers: shared hit=3983
         ->  Seq Scan on detalle_pedido  (cost=0.00..7466.94 rows=399994 width=8) (actual time=0.060..37.255 rows=399994.00 loops=1)
               Buffers: shared hit=3467
         ->  Hash  (cost=1016.10..1016.10 rows=50010 width=32) (actual time=31.474..31.475 rows=50009.00 loops=1)
               Buckets: 65536  Batches: 1  Memory Usage: 3828kB
               Buffers: shared hit=516
               ->  Seq Scan on producto  (cost=0.00..1016.10 rows=50010 width=32) (actual time=0.034..14.237 rows=50009.00 loops=1)
                     Filter: activo
                     Rows Removed by Filter: 1
                     Buffers: shared hit=516
 Planning:
   Buffers: shared hit=14
 Planning Time: 0.425 ms
 Execution Time: 193.233 ms
```

**C4 · con los índices**

```
 Sort  (cost=14602.97..14603.19 rows=90 width=32) (actual time=179.206..179.210 rows=10.00 loops=1)
   Sort Key: producto.nombre
   Sort Method: quicksort  Memory: 25kB
   Buffers: shared hit=3983
   ->  Hash Right Anti Join  (cost=1641.20..14600.05 rows=90 width=32) (actual time=177.530..179.154 rows=10.00 loops=1)
         Hash Cond: (detalle_pedido.id_producto = producto.id_producto)
         Buffers: shared hit=3983
         ->  Seq Scan on detalle_pedido  (cost=0.00..7466.94 rows=399994 width=8) (actual time=0.044..33.339 rows=399994.00 loops=1)
               Buffers: shared hit=3467
         ->  Hash  (cost=1016.10..1016.10 rows=50008 width=32) (actual time=25.805..25.806 rows=50009.00 loops=1)
               Buckets: 65536  Batches: 1  Memory Usage: 3828kB
               Buffers: shared hit=516
               ->  Seq Scan on producto  (cost=0.00..1016.10 rows=50008 width=32) (actual time=0.029..12.062 rows=50009.00 loops=1)
                     Filter: activo
                     Rows Removed by Filter: 1
                     Buffers: shared hit=516
 Planning:
   Buffers: shared hit=14
 Planning Time: 0.435 ms
 Execution Time: 179.922 ms
```

**C1 · con los índices, ronda 2 (el planner eligió Nested Loop)**

```
 GroupAggregate  (cost=7184.84..7278.89 rows=2090 width=44) (actual time=8.228..9.544 rows=8.00 loops=1)
   Group Key: (date(p.fecha))
   Buffers: shared hit=6727
   ->  Sort  (cost=7184.84..7195.29 rows=4180 width=22) (actual time=8.031..8.248 rows=4473.00 loops=1)
         Sort Key: (date(p.fecha)), p.id_pedido
         Sort Method: quicksort  Memory: 402kB
         Buffers: shared hit=6727
         ->  Nested Loop  (cost=0.85..6933.43 rows=4180 width=22) (actual time=0.018..6.271 rows=4473.00 loops=1)
               Buffers: shared hit=6727
               ->  Index Only Scan using idx_pedido_fecha on pedido p  (cost=0.43..81.00 rows=2090 width=16) (actual time=0.012..0.254 rows=2231.00 loops=1)
                     Index Cond: (fecha >= ((CURRENT_DATE - 7))::timestamp with time zone)
                     Heap Fetches: 0
                     Buffers: shared hit=15
               ->  Index Only Scan using idx_detalle_pedido_id_pedido_cover on detalle_pedido d  (cost=0.42..3.25 rows=2 width=18) (actual time=0.002..0.002 rows=2.00 loops=2231)
                     Index Cond: (id_pedido = p.id_pedido)
                     Heap Fetches: 0
                     Buffers: shared hit=6712
 Planning:
   Buffers: shared hit=21
 Planning Time: 0.320 ms
 Execution Time: 9.664 ms
```

**C1 · con los índices y `random_page_cost = 1.1` en la sesión (diagnóstico)**

```
 GroupAggregate  (cost=3026.41..3124.15 rows=2172 width=44) (actual time=12.535..14.451 rows=8.00 loops=1)
   Group Key: (date(p.fecha))
   Buffers: shared hit=6765
   ->  Sort  (cost=3026.41..3037.27 rows=4344 width=22) (actual time=12.250..12.591 rows=4473.00 loops=1)
         Sort Key: (date(p.fecha)), p.id_pedido
         Sort Method: quicksort  Memory: 402kB
         Buffers: shared hit=6765
         ->  Nested Loop  (cost=0.85..2763.93 rows=4344 width=22) (actual time=0.031..9.898 rows=4473.00 loops=1)
               Buffers: shared hit=6765
               ->  Index Only Scan using idx_pedido_fecha on pedido p  (cost=0.43..51.64 rows=2172 width=16) (actual time=0.022..0.413 rows=2231.00 loops=1)
                     Index Cond: (fecha >= ((CURRENT_DATE - 7))::timestamp with time zone)
                     Heap Fetches: 1
                     Buffers: shared hit=53
               ->  Index Only Scan using idx_detalle_pedido_id_pedido_cover on detalle_pedido d  (cost=0.42..1.22 rows=2 width=18) (actual time=0.003..0.003 rows=2.00 loops=2231)
                     Index Cond: (id_pedido = p.id_pedido)
                     Heap Fetches: 0
                     Buffers: shared hit=6712
 Planning:
   Buffers: shared hit=197
 Planning Time: 0.660 ms
 Execution Time: 14.610 ms
```

## Parte B · Vistas

`views.sql` tiene las 4 vistas que generó OpenCode desde las specs B1 a B4, sin cambios. Cada una se comparó con una consulta escrita a mano (`consultas_manuales.sql`) usando `EXCEPT` en los dos sentidos (`mediciones/parteB_verificacion.sql`, `evidencias/parteB_verificacion.txt`):

| Vista | Filas de la vista | Filas de la consulta manual | Vista − manual | Manual − vista |
|---|---|---|---|---|
| `v_productos_vigentes` | 40 009 | 40 009 | 0 | 0 |
| `v_pedidos_cliente` | 200 005 | 200 005 | 0 | 0 |
| `v_detalle_pedido` | 399 994 | 399 994 | 0 | 0 |
| `v_usuario_publico` | 2 | 2 | 0 | 0 |

Las cuatro coinciden exactamente. Las consultas manuales las escribió Claude a partir de las specs, sin mirar las vistas de OpenCode (ver `duia.md`).

**Seguridad (B4):** `v_usuario_publico` expone `id`, `nombre`, `apellido`, `mail` y `rol`; no tiene `contrasena` ni `celular`, y solo muestra usuarios con `eliminado = FALSE`. `rol_reportes` tiene un único permiso: `SELECT` sobre la vista. Con `SET ROLE rol_reportes`, la vista devuelve 2 filas y `SELECT … FROM usuario` falla con «permiso denegado a la tabla usuario». Así se le puede dar acceso a reportes sin exponer la tabla.

## Parte C · Vista materializada

`materializadas.sql` crea `mv_facturacion_categoria_mes` (la consulta 7.4 de `queries.sql`, con `id_categoria` agregado) `WITH DATA`, con un índice único sobre `(id_categoria, mes)` que habilita `REFRESH MATERIALIZED VIEW CONCURRENTLY` (`mediciones/parteC_materializada.sql`):

| | Mediana |
|---|---|
| Reporte calculado en el momento (une 4 tablas y agrega 400 000 líneas) | 1 071,1 ms |
| El mismo reporte desde la vista materializada (100 filas) | 0,121 ms |
| `REFRESH MATERIALIZED VIEW CONCURRENTLY` | 1056,2 ms |
| `REFRESH MATERIALIZED VIEW` (sin `CONCURRENTLY`) | 1081,0 ms |

El resultado es el mismo: 100 y 100 filas, 0 y 0 diferencias con `EXCEPT`.

**Frecuencia de refresco:** una vez por día, en horario de poco uso (por ejemplo, 00:30), con `CONCURRENTLY`. El refresco cuesta lo mismo que calcular el reporte una vez (~1 s) y, con `CONCURRENTLY`, no bloquea a quien está consultando la vista. La gerencia consulta el reporte varias veces por día y trabaja con el cierre del día anterior (spec C1), así que un refresco diario alcanza. Para tener el mes en curso al día, se podría refrescar cada hora: son ~1 s por vez.

**Qué implica para los usuarios:** entre dos `REFRESH`, la vista muestra lo que había al último refresco. Para probarlo, dentro de una transacción que se deshace se registró una venta nueva de 10 × 1000 en el mes actual. La consulta en el momento da 8456919,47 y la vista materializada sigue en 8446919,47: la venta no aparece hasta el próximo refresco. El reporte tiene que indicar «datos al cierre del día anterior», y no sirve para decisiones que necesiten el dato del momento (stock, caja del día).

**Planes**

```
 Incremental Sort  (cost=29333.47..86396.52 rows=319979 width=65) (actual time=799.392..1034.443 rows=100.00 loops=1)
   Sort Key: (date_trunc('month'::text, pe.fecha)), (sum(((dp.cantidad)::numeric * dp.precio_unitario))) DESC
   Presorted Key: (date_trunc('month'::text, pe.fecha))
   Full-sort Groups: 4  Sort Method: quicksort  Average Memory: 27kB  Peak Memory: 27kB
   Buffers: shared hit=6596, temp read=2313 written=2319
   ->  GroupAggregate  (cost=29333.23..76199.43 rows=319979 width=65) (actual time=702.967..1034.242 rows=100.00 loops=1)
         Group Key: (date_trunc('month'::text, pe.fecha)), c.nombre
         Buffers: shared hit=6596, temp read=2313 written=2319
         ->  Gather Merge  (cost=29333.23..66600.06 rows=319979 width=43) (actual time=701.370..879.764 rows=320008.00 loops=1)
               Workers Planned: 2
               Workers Launched: 2
               Buffers: shared hit=6596, temp read=2313 written=2319
               ->  Sort  (cost=28333.21..28666.52 rows=133325 width=43) (actual time=568.507..617.374 rows=106669.33 loops=3)
                     Sort Key: (date_trunc('month'::text, pe.fecha)), c.nombre, pe.id_pedido
                     Sort Method: external merge  Disk: 6808kB
                     Buffers: shared hit=6596, temp read=2313 written=2319
                     Worker 0:  Sort Method: external merge  Disk: 6624kB
                     Worker 1:  Sort Method: external merge  Disk: 5072kB
                     ->  Parallel Hash Join  (cost=5819.43..12882.19 rows=133325 width=43) (actual time=58.790..288.147 rows=106669.33 loops=3)
                           Hash Cond: (dp.id_pedido = pe.id_pedido)
                           Buffers: shared hit=6548
                           ->  Hash Join  (cost=1642.30..8021.76 rows=133325 width=35) (actual time=26.777..166.323 rows=106669.33 loops=3)
                                 Hash Cond: (p.id_categoria = c.id_categoria)
                                 Buffers: shared hit=5018
                                 ->  Hash Join  (cost=1641.20..7212.37 rows=166658 width=26) (actual time=26.532..125.873 rows=133331.33 loops=3)
                                       Hash Cond: (dp.id_producto = p.id_producto)
                                       Buffers: shared hit=5015
                                       ->  Parallel Seq Scan on detalle_pedido dp  (cost=0.00..5133.64 rows=166664 width=26) (actual time=0.016..16.362 rows=133331.33 loops=3)
                                             Buffers: shared hit=3467
                                       ->  Hash  (cost=1016.10..1016.10 rows=50008 width=16) (actual time=26.322..26.323 rows=50009.00 loops=3)
                                             Buckets: 65536  Batches: 1  Memory Usage: 2857kB
                                             Buffers: shared hit=1548
                                             ->  Seq Scan on producto p  (cost=0.00..1016.10 rows=50008 width=16) (actual time=0.188..14.601 rows=50009.00 loops=3)
                                                   Filter: activo
                                                   Rows Removed by Filter: 1
                                                   Buffers: shared hit=1548
                                 ->  Hash  (cost=1.05..1.05 rows=4 width=17) (actual time=0.232..0.232 rows=4.00 loops=3)
                                       Buckets: 1024  Batches: 1  Memory Usage: 9kB
                                       Buffers: shared hit=3
                                       ->  Seq Scan on categoria c  (cost=0.00..1.05 rows=4 width=17) (actual time=0.211..0.214 rows=4.00 loops=3)
                                             Filter: activo
                                             Rows Removed by Filter: 1
                                             Buffers: shared hit=3
                           ->  Parallel Hash  (cost=2706.50..2706.50 rows=117650 width=16) (actual time=31.410..31.410 rows=66668.33 loops=3)
                                 Buckets: 262144  Batches: 1  Memory Usage: 11456kB
                                 Buffers: shared hit=1530
                                 ->  Parallel Seq Scan on pedido pe  (cost=0.00..2706.50 rows=117650 width=16) (actual time=0.010..33.205 rows=200005.00 loops=1)
                                       Buffers: shared hit=1530
 Planning:
   Buffers: shared hit=163
 Planning Time: 1.495 ms
 Execution Time: 1037.389 ms
```

```
 Sort  (cost=6.32..6.57 rows=100 width=234) (actual time=0.091..0.100 rows=100.00 loops=1)
   Sort Key: mes, facturacion_total DESC
   Sort Method: quicksort  Memory: 31kB
   Buffers: shared hit=2
   ->  Seq Scan on mv_facturacion_categoria_mes  (cost=0.00..3.00 rows=100 width=234) (actual time=0.024..0.034 rows=100.00 loops=1)
         Buffers: shared hit=2
 Planning Time: 0.079 ms
 Execution Time: 0.121 ms
```
