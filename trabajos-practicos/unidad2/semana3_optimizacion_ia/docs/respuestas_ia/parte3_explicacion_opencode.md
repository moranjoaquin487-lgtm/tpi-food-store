# Leer y responder parte3_explicar_plan.txt

**Session ID:** ses_e2026a12effefyHrk8RDCFD5J3

---

## User

Leé parte3_explicar_plan.txt y respondé lo que pide.

---

## Assistant (Plan · Big Pickle · 5.1s)

**Tool: read**

**Input:**
```json
{
  "filePath": "C:\\Users\\moran\\tp3_parte3\\parte3_explicar_plan.txt"
}
```

**Output:**
```
<path>C:\Users\moran\tp3_parte3\parte3_explicar_plan.txt</path>
<type>file</type>
<content>
1: Explicá en lenguaje natural, nodo por nodo, qué hace este plan de ejecución de PostgreSQL y por qué tarda lo que tarda.
2: 
3:  GroupAggregate  (cost=6645.23..7221.67 rows=2112 width=44) (actual time=114.304..123.900 rows=8.00 loops=1)
4:    Group Key: (date(p.fecha))
5:    Buffers: shared hit=3381
6:    ->  Gather Merge  (cost=6645.23..7137.19 rows=4224 width=22) (actual time=113.927..122.319 rows=4182.00 loops=1)
7:          Workers Planned: 2
8:          Workers Launched: 2
9:          Buffers: shared hit=3381
10:          ->  Sort  (cost=5645.21..5649.61 rows=1760 width=22) (actual time=31.456..31.567 rows=1394.00 loops=3)
11:                Sort Key: (date(p.fecha)), p.id_pedido
12:                Sort Method: quicksort  Memory: 389kB
13:                Buffers: shared hit=3381
14:                Worker 0:  Sort Method: quicksort  Memory: 25kB
15:                Worker 1:  Sort Method: quicksort  Memory: 25kB
16:                ->  Hash Join  (cost=107.79..5550.33 rows=1760 width=22) (actual time=0.232..30.626 rows=1394.00 loops=3)
17:                      Hash Cond: (d.id_pedido = p.id_pedido)
18:                      Buffers: shared hit=3349
19:                      ->  Parallel Seq Scan on detalle_pedido d  (cost=0.00..5000.64 rows=166664 width=18) (actual time=0.007..11.564 rows=133331.33 loops=3)
20:                            Buffers: shared hit=3334
21:                      ->  Hash  (cost=81.39..81.39 rows=2112 width=16) (actual time=0.598..0.599 rows=2119.00 loops=1)
22:                            Buckets: 4096  Batches: 1  Memory Usage: 132kB
23:                            Buffers: shared hit=15
24:                            ->  Index Only Scan using idx_pedido_fecha on pedido p  (cost=0.43..81.39 rows=2112 width=16) (actual time=0.022..0.310 rows=2119.00 loops=1)
25:                                  Index Cond: (fecha >= ((CURRENT_DATE - 7))::timestamp with time zone)
26:                                  Heap Fetches: 0
27:                                  Index Searches: 1
28:                                  Buffers: shared hit=15
29:  Planning:
30:    Buffers: shared hit=38
31:  Planning Time: 0.493 ms
32:  Execution Time: 124.116 ms

(End of file - total 32 lines)
</content>
```

---

## Assistant (Plan · Big Pickle · 44.6s)

_Thinking:_

The user asks in Spanish to explain node by node what this PostgreSQL execution plan does and why it takes what it takes. This is a read-only explanatory task. Plan mode says I should construct a plan... but the user's request is explanatory, not a code change task. In plan mode, I can still respond with an explanation. The task requires no edits. I should just answer.

Let me explain the plan thoroughly but concisely. The user wants detail (explicá nodo por nodo). So longer response justified.

Let me parse the plan:

- GroupAggregate (cost=6645.23..7221.67 rows=2112 width=44) (actual time=114.304..123.900 rows=8.00 loops=1)
  - Group Key: (date(p.fecha))
  - 8 rows output (8 days = last 7 days probably 8 distinct dates). Final aggregation of per-day counts/sums.
- Gather Merge: launches 2 parallel workers, merges sorted outputs. actual time 113.927..122.319 rows=4182. The Sort below produces rows=1394 per worker (loops=3: leader + 2 workers). Total ~4182 = 3 × 1394. Gather Merge merges the sorted streams.
- Sort: Sort Key (date(p.fecha)), p.id_pedido. Sort Method quicksort 389kB main, workers 25kB each. This sort exists to feed GroupAggregate in sorted order — GroupAggregate requires input sorted by group key. Sorting by (date(fecha), id_pedido).
- Hash Join: joins detalle_pedido d with pedido p on id_pedido. Hash Cond d.id_pedido = p.id_pedido.
  - Parallel Seq Scan on detalle_pedido d: 133331 rows per worker × 3 = ~400k rows, buffers 3334, time 11.5ms per loop. Full table scan of detalle_pedido because no selective predicate on d — the filter is on p.fecha, which is in the other table.
  - Hash: built from pedido p, 2119 rows, 132kB, 15 buffers, 0.6ms. Built from index-only scan on idx_pedido_fecha filtered by fecha >= current_date - 7 -> gets last 7 days' orders (2119 orders). Heap Fetches 0 = all-visible, index-only scan efficient.
- Index Only Scan using idx_pedido_fecha on pedido p: index cond fecha >= current_date-7, 2119 rows, 15 buffers, 0.3ms. Very cheap.
- Planning time 0.493ms, Execution 124ms.

Why it takes 124ms: The dominant cost is the parallel seq scan of detalle_pedido (~400k rows, ~11.5ms each) plus hash join and sort of 4182 rows. Actually execution 124ms but the child nodes sum to ~31ms in worker time... The GroupAggregate actual time 114-123ms. Interesting: the sort finishes at 31.5ms but Gather Merge starts at 113.9ms — meaning workers spend time producing rows; startup of gather merge 113ms reflects waiting. Hmm, note loops and actual times: parallel workers' times are per-loop averages, not wall clock. The real wall clock for seq scan could be ~11.5ms×3? Actually each loop is a separate process running concurrently, so wall time is roughly max, not sum. But the execution 124ms is dominated by... there's a discrepancy: sort actual 31ms, but gather merge 113ms. This is likely because actual times in parallel nodes are measured per worker and there might be overhead/timing. Anyway, explain: most time is scanning detalle_pedido fully (~400k rows) because there's no index usable for the date filter on the detail table; the join has to hash all orders from the last week against every detail row.

Key insight: it reads entire detalle_pedido table (about 400,000 rows: 133,331.33 × 3) even though only 7 days of orders matter. That's the main inefficiency. If instead the index-only scan on pedido drives the join via nested loop with index on detalle_pedido(id_pedido), or if detalle_pedido had a date column/indexed, it could be much faster. But note the planner chose hash join with parallel seq scan because reading 400k rows in parallel is cheap (~11ms) vs random lookups of 2119 orders × detail rows.

Why slow-ish 124ms: aggregation run over 4182 rows is trivial; the sort of 4182 rows is cheap (389kB quicksort); the bulk is parallel scan + hash join. Also 3381 shared buffers hit (all cached, no disk I/O), so it's CPU-bound not I/O.

Let me write node-by-node explanation in Spanish, structured bottom-up (how execution actually flows) which is the conventional way, noting root summary too. Also mention estimated vs actual row counts: GroupAggregate estimated 2112 rows but actual 8 — estimate off because it didn't estimate distinct dates; not a performance problem here though.

Rows meaning: detalle_pedido rows ~400k (133331.33×3). Note loops=3 for parallel node counts leader + 2 workers.

Explain costs: cost units arbitrary; startup..total.

Buffers: shared hit=3381 means all pages found in shared_buffers — no physical reads, so I/O isn't the issue.

I should format with headers per node, bottom-up. Length: this is a detailed explanation request, so a somewhat longer answer is fine, but keep tight. Use Spanish (rioplatense since user uses "Leé", "respondé"). No emojis.

Also perhaps note "8 filas = 8 días" and width.

Explain the timing discrepancy carefully but honestly: parallel node actual times are averaged per worker/loop; total wall time includes workers coordination, and the Gather Merge waits for all workers to finish. The 114ms startup at GroupAggregate vs sort at 31ms suggests the merge waits for slowest worker and process startup overhead.

Let me double check numbers: 1394 × 3 = 4182. Yes. Seq scan rows 133331.33 × 3 ≈ 399,994. So detalle_pedido has ~400k rows. pedido last 7 days: 2119 rows.

Hash join output 1394 per worker × 3 = 4182 detail rows matched to the 2119 orders from last week. So on average ~2 detail lines per order.

Rows estimate for hash join: 1760 per worker estimated vs 1394 actual — good estimate.

GroupAggregate estimated 2112 groups but actual 8 — because it estimated rows after aggregation = number of input rows roughly? Actually rows=2112 at GroupAggregate is odd; it seems planner's estimate for groups equals the number of pedido rows (2112) rather than distinct dates. Anyway.

Why 124ms: main factors:
1. Full parallel seq scan of detalle_pedido (~400k rows, 3334 buffers ≈ 26MB) — unavoidable given the query shape, dominant cost.
2. Hash join on 400k × 2119 — cheap-ish, probe of 400k rows.
3. Sort 4182 rows — negligible (389kB quicksort, ~sub-ms to few ms).
4. Gathering/merging parallel results + startup overhead of parallel workers (~ms tens).
5. Everything cached in RAM (3381 shared hits, 0 reads) so it's CPU-bound.

Optimization suggestions: index on detalle_pedido wouldn't help seq scan directly; better: use nested loop with index scan on detalle_pedido(id_pedido) driven by 2119 index-only rows, or add fecha to detalle_pedido, or partition. Also could avoid sort if index order matched. But maybe suggestions optional — the user only asked to explain why it takes long. I can add a brief "por qué tarda" section. Keep suggestions short since not asked; maybe one line.

Plan mode: I'm not to make edits. I just answer. Perhaps I should note that this is explanation only, no plan needed. Just answer directly.

## Lectura del plan, de abajo hacia arriba (el flujo real de ejecución)

**1. Index Only Scan sobre `pedido` (línea 24)**
`cost=0.43..81.39 rows=2112`, `actual ... rows=2119`, `Heap Fetches: 0`, 15 buffers, 0.3 ms.
Recorre el índice `idx_pedido_fecha` buscando `fecha >= CURRENT_DATE - 7`, o sea los pedidos de la última semana: 2119 pedidos. Es "index only" porque las columnas que necesita (`id_pedido`, `fecha`) están en el índice, así que no toca la tabla (`Heap Fetches: 0`). Es el nodo más barato de todo el plan.

**2. Hash (línea 21)**
Con esas 2119 filas arma una tabla hash en memoria (132 kB, 4096 buckets, 1 batch). Es la "tabla chica" del join, la que se carga entera.

**3. Parallel Seq Scan sobre `detalle_pedido` (línea 19)**
`rows=166664` estimadas, `actual rows=133331.33 loops=3`, 3334 buffers, 11.5 ms por worker.
Acá está el grueso del trabajo: lee **toda** la tabla `detalle_pedido` (≈ 400.000 filas: 133.331 × 3 loops, que son el líder + 2 workers). No hay ningún filtro sobre `detalle_pedido`: la condición de fecha vive en `pedido`, no acá. Por eso no puede usar un índice y hace un scan secuencial completo, repartido entre los 2 workers paralelos.

**4. Hash Join (línea 16)**
`Hash Cond: (d.id_pedido = p.id_pedido)`, `actual rows=1394 loops=3` (≈ 4182 totales), 30.6 ms acumulados por worker.
Por cada una de las ~400.000 líneas de detalle calcula el hash de `id_pedido` y busca si corresponde a alguno de los 2119 pedidos de la última semana. Solo sobreviven ~4182 líneas de detalle (≈ 2 por pedido). La estimación (1760 por worker) fue bastante buena contra las 1394 reales.

**5. Sort (línea 10)**
`Sort Key: (date(p.fecha)), p.id_pedido`, quicksort, 389 kB en el líder y 25 kB en cada worker, 31.5 ms.
Ordena las 4182 filas resultantes por fecha e `id_pedido`. No es para el usuario: es un requisito del `GroupAggregate` de arriba, que necesita la entrada ya ordenada por la clave de agrupación. Es un sort chico y en memoria (nada va a disco).

**6. Gather Merge (línea 6)**
Junta las 3 corrientes ya ordenadas (líder + 2 workers) y las fusiona manteniendo el orden por fecha. Salen 4182 filas. `Workers Planned: 2`, `Workers Launched: 2`: el paralelismo se usó efectivamente.

**7. GroupAggregate (raíz, línea 3)**
`Group Key: (date(p.fecha))`, `actual rows=8`, 123.9 ms.
Como la entrada ya viene ordenada por fecha, agrupa por día en una sola pasada sin volver a ordenar: recorre las 4182 filas, va cortando grupo cuando cambia la fecha y emite **8 filas = 8 días** (la semana pedida, contando bordes). El costo real del agregado en sí es despreciable.

## Por qué tarda ~124 ms

- **Todo está en RAM**: `shared hit=3381`, cero lecturas físicas. No es un problema de I/O; es CPU.
- **El costo dominante es el Parallel Seq Scan + Hash Join sobre `detalle_pedido`**: se leen ~400.000 filas para terminar usando solo ~4.200. Es un desperdicio estructural: el filtro de fecha está en `pedido`, así que no hay forma de "saltear" líneas de detalle con un índice; hay que leer la tabla entera y descartar en el join.
- El **Sort** (389 kB) y el **GroupAggregate** (8 grupos) son baratos; no explican el tiempo.
- El **Gather Merge** suma overhead de arranque y coordinación de los workers: el `Sort` termina a los ~31 ms en cada worker, pero la raíz recién "ve" datos a los ~114 ms; esa diferencia es espera de workers + merge de las 3 corrientes.
- La estimación de filas de la raíz está muy errada (2112 estimadas vs 8 reales) porque el planner no estima bien los valores distintos de `date(fecha)`; acá no duele, pero con más joins podría llevar a malas decisiones.

## Resumen en una frase

El plan es correcto y razonable, pero paga el precio de **escanear completa `detalle_pedido` (~400k filas) en paralelo** porque la condición de fecha solo se puede aplicar sobre `pedido`; una alternativa sería un Nested Loop con índice sobre `detalle_pedido(id_pedido)` manejado por los 2119 pedidos de la semana, o bien llevar la fecha a `detalle_pedido`/particionar por fecha.

---

