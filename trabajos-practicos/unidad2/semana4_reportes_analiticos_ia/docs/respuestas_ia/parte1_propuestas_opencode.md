# Leer y responder propuestas IA parte 1

**Session ID:** ses_e200f9d47ffeM4Fjg2n6OvNWfW

---

## User

Leé prompts/parte1_propuestas_ia.md y respondé lo que pide. No modifiques ningún archivo.

---

## Assistant (Plan · Big Pickle · 12.3s)

**Tool: read**

**Input:**
```json
{
  "filePath": "C:\\Users\\moran\\BD2\\tpi-food-store\\trabajos-practicos\\unidad2\\semana4_reportes_analiticos_ia\\prompts\\parte1_propuestas_ia.md"
}
```

**Output:**
```
<path>C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad2\semana4_reportes_analiticos_ia\prompts\parte1_propuestas_ia.md</path>
<type>file</type>
<content>
1: # Prompt de la Parte 1: planes reales de dos consultas analíticas para que la IA proponga cambios
2: 
3: Base PostgreSQL de Food Store: pedido (id_pedido, fecha TIMESTAMPTZ, forma_pago, id_cliente),
4: detalle_pedido (id_detalle, id_pedido, id_producto, cantidad, precio_unitario, UNIQUE (id_pedido, id_producto)),
5: producto (id_producto, nombre, precio, stock, activo, id_categoria), categoria (id_categoria, nombre, activo)
6: y cliente (id_cliente, nombre, apellido, email). Volumen: 200 000 pedidos, 400 000 líneas, 50 000 productos,
7: 20 000 clientes y 5 categorías. Índices actuales: las PK, los UNIQUE, pedido (id_cliente),
8: pedido (fecha) INCLUDE (id_pedido, id_cliente), detalle_pedido (id_producto) INCLUDE (cantidad),
9: producto (id_categoria) WHERE activo y producto (id_categoria, precio) WHERE activo.
10: Contexto medido en esta misma PC en la práctica anterior: random_page_cost está en 4 (valor por defecto)
11: y los planes con workers paralelos tardaron más que sin ellos.
12: 
13: Para cada consulta, con su plan real de EXPLAIN (ANALYZE, BUFFERS): identificá qué algoritmo de join
14: (Nested Loop, Hash Join o Merge Join) eligió el optimizador en cada combinación de tablas, y proponé
15: reescrituras y/o índices que lo mejoren. Justificá cada propuesta con el nodo de join concreto del plan:
16: qué nodo ataca y por qué esperás que cambie.
17: 
18: Consultas (cada una se ejecutó primero una vez, para calentar la caché):
19: 
20: ```sql
21: -- Q1 · Facturación por categoría y mes (últimos 6 meses)
22: SELECT c.nombre AS categoria, date_trunc('month', p.fecha)::date AS mes,
23:        COUNT(DISTINCT p.id_pedido) AS pedidos, SUM(d.cantidad * d.precio_unitario) AS facturado
24:   FROM pedido p
25:   JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
26:   JOIN producto pr ON pr.id_producto = d.id_producto
27:   JOIN categoria c ON c.id_categoria = pr.id_categoria
28:  WHERE p.fecha >= date_trunc('month', now()) - INTERVAL '6 months'
29:  GROUP BY c.nombre, date_trunc('month', p.fecha)
30:  ORDER BY mes, facturado DESC;
31: 
32: -- Q2 · Ranking de clientes por gasto en los últimos 90 días (los 20 primeros puestos)
33: SELECT puesto, id_cliente, cliente, pedidos, gastado FROM (
34:     SELECT c.id_cliente, c.nombre || ' ' || c.apellido AS cliente,
35:            COUNT(DISTINCT p.id_pedido) AS pedidos,
36:            SUM(d.cantidad * d.precio_unitario) AS gastado,
37:            RANK() OVER (ORDER BY SUM(d.cantidad * d.precio_unitario) DESC) AS puesto
38:       FROM cliente c
39:       JOIN pedido p ON p.id_cliente = c.id_cliente
40:       JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
41:      WHERE p.fecha >= now() - INTERVAL '90 days'
42:      GROUP BY c.id_cliente, c.nombre, c.apellido
43: ) r
44:  WHERE puesto <= 20
45:  ORDER BY puesto, id_cliente;
46: 
47: ```
48: 
49: Planes reales:
50: 
51: ```
52: ######## Q1 · Facturación por categoría y mes (últimos 6 meses)
53: 
54:                                                                                        QUERY PLAN                                                                                        
55:  Sort  (cost=43321.41..43591.63 rows=108086 width=61) (actual time=579.613..579.621 rows=35.00 loops=1)
56:    Sort Key: (((date_trunc('month'::text, p.fecha)))::date), (sum(((d.cantidad)::numeric * d.precio_unitario))) DESC
57:    Sort Method: quicksort  Memory: 27kB
58:    Buffers: shared hit=4138, temp read=791 written=793
59:    ->  GroupAggregate  (cost=26164.21..30217.44 rows=108086 width=61) (actual time=508.386..579.529 rows=35.00 loops=1)
60:          Group Key: c.nombre, (date_trunc('month'::text, p.fecha))
61:          Buffers: shared hit=4132, temp read=791 written=793
62:          ->  Sort  (cost=26164.21..26434.43 rows=108086 width=43) (actual time=506.226..539.802 rows=108616.00 loops=1)
63:                Sort Key: c.nombre, (date_trunc('month'::text, p.fecha)), p.id_pedido
64:                Sort Method: external merge  Disk: 6328kB
65:                Buffers: shared hit=4132, temp read=791 written=793
66:                ->  Hash Join  (cost=4340.12..13802.24 rows=108086 width=43) (actual time=35.277..256.847 rows=108616.00 loops=1)
67:                      Hash Cond: (pr.id_categoria = c.id_categoria)
68:                      Buffers: shared hit=4123
69:                      ->  Hash Join  (cost=4339.00..13006.70 rows=108086 width=34) (actual time=35.212..206.788 rows=108616.00 loops=1)
70:                            Hash Cond: (d.id_producto = pr.id_producto)
71:                            Buffers: shared hit=4122
72:                            ->  Hash Join  (cost=2697.78..11081.72 rows=108086 width=34) (actual time=19.350..139.102 rows=108616.00 loops=1)
73:                                  Hash Cond: (d.id_pedido = p.id_pedido)
74:                                  Buffers: shared hit=3606
75:                                  ->  Seq Scan on detalle_pedido d  (cost=0.00..7333.94 rows=399994 width=26) (actual time=0.040..26.447 rows=399994.00 loops=1)
76:                                        Buffers: shared hit=3334
77:                                  ->  Hash  (cost=2022.21..2022.21 rows=54045 width=16) (actual time=19.143..19.144 rows=54309.00 loops=1)
78:                                        Buckets: 65536  Batches: 1  Memory Usage: 3058kB
79:                                        Buffers: shared hit=272
80:                                        ->  Index Only Scan using idx_pedido_fecha on pedido p  (cost=0.43..2022.21 rows=54045 width=16) (actual time=0.045..9.307 rows=54309.00 loops=1)
81:                                              Index Cond: (fecha >= (date_trunc('month'::text, now()) - '6 mons'::interval))
82:                                              Heap Fetches: 0
83:                                              Index Searches: 1
84:                                              Buffers: shared hit=272
85:                            ->  Hash  (cost=1016.10..1016.10 rows=50010 width=16) (actual time=15.744..15.745 rows=50010.00 loops=1)
86:                                  Buckets: 65536  Batches: 1  Memory Usage: 2857kB
87:                                  Buffers: shared hit=516
88:                                  ->  Seq Scan on producto pr  (cost=0.00..1016.10 rows=50010 width=16) (actual time=0.016..7.419 rows=50010.00 loops=1)
89:                                        Buffers: shared hit=516
90:                      ->  Hash  (cost=1.05..1.05 rows=5 width=17) (actual time=0.047..0.048 rows=5.00 loops=1)
91:                            Buckets: 1024  Batches: 1  Memory Usage: 9kB
92:                            Buffers: shared hit=1
93:                            ->  Seq Scan on categoria c  (cost=0.00..1.05 rows=5 width=17) (actual time=0.031..0.033 rows=5.00 loops=1)
94:                                  Buffers: shared hit=1
95:  Planning:
96:    Buffers: shared hit=75
97:  Planning Time: 1.159 ms
98:  Execution Time: 582.079 ms
99: (44 filas)
100: 
101: ######## Q2 · Ranking de clientes por gasto en los últimos 90 días (los 20 primeros puestos)
102: 
103:                                                                                              QUERY PLAN                                                                                             
104:  Sort  (cost=18862.07..18912.08 rows=20005 width=88) (actual time=169.457..169.462 rows=20.00 loops=1)
105:    Sort Key: r.puesto, r.id_cliente
106:    Sort Method: quicksort  Memory: 26kB
107:    Buffers: shared hit=3688, temp read=396 written=397
108:    ->  Subquery Scan on r  (cost=16782.76..17432.91 rows=20005 width=88) (actual time=169.423..169.449 rows=20.00 loops=1)
109:          Buffers: shared hit=3688, temp read=396 written=397
110:          ->  WindowAgg  (cost=16782.76..17232.86 rows=20005 width=112) (actual time=169.422..169.444 rows=20.00 loops=1)
111:                Window: w1 AS (ORDER BY (sum(((d.cantidad)::numeric * d.precio_unitario))) ROWS UNBOUNDED PRECEDING)
112:                Run Condition: (rank() OVER w1 <= 20)
113:                Storage: Memory  Maximum Storage: 17kB
114:                Buffers: shared hit=3688, temp read=396 written=397
115:                ->  Sort  (cost=16782.74..16832.76 rows=20005 width=72) (actual time=169.399..169.404 rows=21.00 loops=1)
116:                      Sort Key: (sum(((d.cantidad)::numeric * d.precio_unitario))) DESC
117:                      Sort Method: quicksort  Memory: 1331kB
118:                      Buffers: shared hit=3688, temp read=396 written=397
119:                      ->  GroupAggregate  (cost=14352.59..15353.58 rows=20005 width=72) (actual time=134.313..163.856 rows=14226.00 loops=1)
120:                            Group Key: c.id_cliente
121:                            Buffers: shared hit=3688, temp read=396 written=397
122:                            ->  Sort  (cost=14352.59..14477.74 rows=50062 width=50) (actual time=134.297..140.698 rows=49623.00 loops=1)
123:                                  Sort Key: c.id_cliente, p.id_pedido
124:                                  Sort Method: external merge  Disk: 3168kB
125:                                  Buffers: shared hit=3688, temp read=396 written=397
126:                                  ->  Hash Join  (cost=1929.50..10444.89 rows=50062 width=50) (actual time=12.365..101.544 rows=49623.00 loops=1)
127:                                        Hash Cond: (p.id_cliente = c.id_cliente)
128:                                        Buffers: shared hit=3688
129:                                        ->  Hash Join  (cost=1251.38..9635.33 rows=50062 width=26) (actual time=6.481..81.576 rows=49623.00 loops=1)
130:                                              Hash Cond: (d.id_pedido = p.id_pedido)
131:                                              Buffers: shared hit=3460
132:                                              ->  Seq Scan on detalle_pedido d  (cost=0.00..7333.94 rows=399994 width=18) (actual time=0.015..22.937 rows=399994.00 loops=1)
133:                                                    Buffers: shared hit=3334
134:                                              ->  Hash  (cost=938.48..938.48 rows=25032 width=16) (actual time=6.389..6.390 rows=24810.00 loops=1)
135:                                                    Buckets: 32768  Batches: 1  Memory Usage: 1419kB
136:                                                    Buffers: shared hit=126
137:                                                    ->  Index Only Scan using idx_pedido_fecha on pedido p  (cost=0.42..938.48 rows=25032 width=16) (actual time=0.027..3.070 rows=24810.00 loops=1)
138:                                                          Index Cond: (fecha >= (now() - '90 days'::interval))
139:                                                          Heap Fetches: 0
140:                                                          Index Searches: 1
141:                                                          Buffers: shared hit=126
142:                                        ->  Hash  (cost=428.05..428.05 rows=20005 width=32) (actual time=5.808..5.808 rows=20005.00 loops=1)
143:                                              Buckets: 32768  Batches: 1  Memory Usage: 1524kB
144:                                              Buffers: shared hit=228
145:                                              ->  Seq Scan on cliente c  (cost=0.00..428.05 rows=20005 width=32) (actual time=0.023..2.338 rows=20005.00 loops=1)
146:                                                    Buffers: shared hit=228
147:  Planning:
148:    Buffers: shared hit=28
149:  Planning Time: 0.735 ms
150:  Execution Time: 171.783 ms
151: (47 filas)
152: 
153: ```

(End of file - total 153 lines)
</content>
```

---

## Assistant (Plan · Big Pickle · 217.7s)

_Thinking:_

The user asks to read the prompt and answer what it asks. No file modifications. In plan mode, so I just produce the answer as text. The prompt asks: for each query, identify which join algorithm the optimizer chose in each table combination, and propose rewrites and/or indexes. Justify each proposal with the concrete join node from the plan: which node it attacks and why you expect it to change.

Let me analyze carefully.

Q1 plan:
- Hash Join #1 (bottom): Hash Cond (d.id_pedido = p.id_pedido). Outer: Seq Scan on detalle_pedido d (400k rows). Inner: Hash built from Index Only Scan idx_pedido_fecha on pedido (54,309 rows, 16 bytes width). So Nested loop? No, Hash Join. Algorithm: Hash Join with detalle_pedido as probe side (full 400k seq scan) and pedido filtered by date as hash build.
- Hash Join #2: Hash Cond (d.id_producto = pr.id_producto). Outer: previous hash join (108,616 rows). Inner: Hash from Seq Scan producto (50,010 rows).
- Hash Join #3: Hash Cond (pr.id_categoria = c.id_categoria). Inner: Seq Scan categoria 5 rows.
- Then Sort (external merge 6328kB, temp read/written ~791 blocks) sorting by c.nombre, mes, p.id_pedido — needed for GroupAggregate which computes COUNT(DISTINCT p.id_pedido) requiring sorted input. Then GroupAggregate, then final Sort for ORDER BY.

Key insight: the big cost is 400k row seq scan of detalle_pedido + hash join with only 54k pedidos, then 108k rows, then external merge sort to disk due to COUNT(DISTINCT) grouping. Wait — the sort key includes p.id_pedido because COUNT(DISTINCT p.id_pedido) requires unique input. GroupAggregate with count distinct needs sorted by group keys + distinct expr.

Proposals:
1. The fundamental issue: date filter selectivity. Q1 last 6 months = 54,309 of 200,000 pedidos (27%). Because the range is large, a nested loop from pedido to detalle_pedido would be 54k index lookups × ~2 rows = 108k rows... Actually 400k/200k = 2 lines per order. Nested loop with index on detalle_pedido(id_pedido) would do 54k index scans and ~108k heap fetches, which at random_page_cost=4 might be considered expensive, but the hash join scans 400k rows (3334 buffers) and builds hash with 54k. Hash join cost estimate 11081. Creating index on detalle_pedido(id_pedido) INCLUDE (id_producto, cantidad, precio_unitario) would enable index-only nested loop or at least reduce... Hmm.

Actually with random_page_cost=4, the planner preferred hash join because seq scan of 400k is cheap (3334 pages sequential). A nested loop from 54k pedidos doing 54k index probes... cost per probe ~4 + ... maybe ~250k cost vs hash join 11k. Not chosen. But measured, hash join is 139ms which isn't terrible.

The real bottleneck: external merge sort of 108k rows (539ms of 582ms total is cumulative by that point; sort itself ~ 506→539, and GroupAggregate 508→579). Sort spills to disk 6.3MB. To avoid spill: increase work_mem, or reduce rows before sort.

Rewrites:
- Aggregate detalle_pedido per (id_pedido) first? No — COUNT(DISTINCT p.id_pedido) can be computed per group directly if we join product/category first. Alternative rewrite: replace COUNT(DISTINCT p.id_pedido) with COUNT(DISTINCT d.id_pedido) — same value, but still distinct. Actually better: since (id_pedido, id_producto) is unique in detalle_pedido, and id_pedido is already unique in pedido, could compute count distinct at subquery level: group detalle by id_pedido, id_categoria first, then join to categoria and group by month/category summing quantity*price and counting orders. Wait — number of distinct orders per category-month: count distinct p.id_pedido where the order has a line in that category. Pre-aggregating per (id_pedido, id_categoria): SELECT p.id_pedido, p.fecha, pr.id_categoria, SUM(...) FROM ... GROUP BY p.id_pedido, pr.id_categoria. Then outer: group by categoria, month: COUNT(*) as pedidos (no DISTINCT needed because each (order, category) is unique), SUM(linea_total). This removes COUNT(DISTINCT) and thus removes the need to sort by id_pedido, allowing HashAggregate instead of GroupAggregate+external sort. That's a key rewrite: eliminate COUNT(DISTINCT) so GroupAggregate's sort (6328kB disk) disappears.

Also filtering detalle early: since categories are only 5 and all products... If the query is about all categories, no filter. But we could restructure join order: filter pedido by date first (already), then nested loop.

Another rewrite: use date_trunc month on p.fecha only after. Fine.

- Index proposal: index on detalle_pedido (id_pedido) INCLUDE (id_producto, cantidad, precio_unitario) — enables a Nested Loop with the filtered pedido as outer side, visiting only ~108k detail rows via index-only scan instead of Seq Scan 400k rows. But planner might still pick hash join because 27% selectivity. Also this index helps Q2 (90 days = 24,810 pedidos, 12% → ~50k lines). The node it attacks: Seq Scan on detalle_pedido (line 75) → Index Only Scan on detalle_pedido. Expected change: Hash Join node (d.id_pedido = p.id_pedido) becomes Nested Loop with pedido outer and detalle_pedido index-only inner. But note: current join order has hash side = pedido, probe = detalle full scan. Index would allow NL.

Wait, actually detalle_pedido has PK on id_detalle and UNIQUE (id_pedido, id_producto). The UNIQUE index on (id_pedido, id_producto) already can serve lookups by id_pedido prefix! So an index on id_pedido already exists implicitly. But it doesn't include cantidad/precio_unitario/id_producto... it includes id_producto as second key column. Not cantidad/precio. So index-only scan would need heap fetch. The prompt says "Índices actuales: las PK, los UNIQUE" — so unique (id_pedido, id_producto) exists. So propose replacing/augmenting with (id_pedido) INCLUDE (id_producto, cantidad, precio_unitario) to enable index-only.

Hmm, but is that the right recommendation? Let's think about measured: Seq Scan detalle 26ms for Q1 (3334 buffers). Filtering 54k pedidos via NL would need ~54k probes, maybe 20-50ms. Marginal. The bigger win is removing the sort.

- Also hash join #2 with Seq Scan producto (50k rows) — could be avoided with nested loop on PK pr.id_producto? The plan chooses hash because of 108k rows. Alternatively, narrow producto scan using index on id_categoria WHERE activo? Not helpful since all categories needed. Could add index on producto(id_producto) INCLUDE (id_categoria) — PK already exists. So hash join on producto is fine; or if query pushed category aggregation... Actually one proposal: join producto→categoria before detalle, or precompute. Not needed.

- Hash join with categoria (5 rows) is trivially fine.

- For Q1, since it's GROUP BY category (5) × month (6) = max 30 groups (actual 35 due to date_trunc boundaries), hash aggregate would be tiny. So the external sort is pure waste caused by COUNT(DISTINCT). Also, another approach: increase work_mem to avoid spill (6.3MB needed), but that's a config change not index; can mention as complement.

Also note the plan does not use the existing index producto(id_categoria, precio) WHERE activo — because it needs all products including inactive? Q only joins category name. Could filter pr.activo? Business semantics. Could propose partial index or index-only scan on producto id_categoria... Producto seq scan is only 15ms and 50k rows, hash build 2.8MB. Fine.

Q2 plan:
- Hash Join #1: Hash Cond (d.id_pedido = p.id_pedido), outer Seq Scan detalle_pedido (400k, 3334 buffers), inner Hash from Index Only Scan idx_pedido_fecha (24,810 pedidos last 90 days).
- Hash Join #2: Hash Cond (p.id_cliente = c.id_cliente), outer previous (49,623 rows), inner Hash from Seq Scan cliente (20k rows).
- Sort by c.id_cliente, p.id_pedido (external merge 3168kB) — needed for GroupAggregate + COUNT(DISTINCT p.id_pedido).
- GroupAggregate (14,226 groups), Sort by gastado DESC (1.3MB memory), WindowAgg with Run Condition rank()<=20 (top-N short circuit — good), Subquery Scan, Sort for ORDER BY puesto, id_cliente.

Proposals Q2:
- Same rewrite: eliminate COUNT(DISTINCT p.id_pedido) by pre-aggregating at order level: since pedido rows are unique, count distinct orders = count(*) of distinct pedido rows. Since joining detalle 1:N and each pedido has multiple lines, COUNT(DISTINCT p.id_pedido) = number of pedidos. Pre-aggregate detalle by id_pedido: SELECT id_pedido, SUM(cantidad*precio) FROM detalle_pedido GROUP BY id_pedido, then join to filtered pedido and cliente, group by client: COUNT(*) (each order once), SUM(total). This removes the need to sort by id_pedido too — first HashAggregate over detalle (400k→200k groups) or index-only scan on detalle_pedido(id_pedido) INCLUDE(cantidad, precio_unitario) to get sorted input for GroupAggregate without disk sort. Actually grouping detalle by id_pedido: an index on (id_pedido) INCLUDE (cantidad, precio_unitario) enables index-only scan already ordered by id_pedido → GroupAggregate with no sort. Then join to pedido (filtered by date) via hash or merge join on id_pedido, then group by cliente. But the date filter reduces which orders matter; pre-aggregating all 200k orders is more work. Alternative: semi-join / nested loop from 24,810 pedidos to detalle via index on (id_pedido) INCLUDE (cantidad, precio_unitario): 24,810 index probes returning ~49,623 rows (~12% of 400k) instead of seq scanning 400k. That's a clear Index Only Scan vs Seq Scan on detalle_pedido attack. Expected: Hash Join (d.id_pedido=p.id_pedido) node → Nested Loop with Index Only Scan on detalle_pedido. Cost estimate: 24,810 probes × ~4 random_page_cost... plus 49k rows. With random_page_cost=4, planner might need help; consider lowering random_page_cost (since data likely cached, and measured earlier) or the index makes it cheaper enough. Mention: with random_page_cost=4 in effect, planner may still prefer hash join; if so, drop random_page_cost to 1.1 or use a CTE MATERIALIZED with pre-aggregated detail.

Hmm. The prompt says context: random_page_cost = 4 default and parallel workers slower than without. So recommendations should account: (a) lower random_page_cost to ~1.1-2 to favor index nested loops, since this is an OLTP-ish workload and cache warm; (b) disable parallel? Actually "planes con workers paralelos tardaron más que sin ellos" → suggest setting max_parallel_workers_per_gather=0 for these analytic queries or parallel setup cost. But the plans shown have no parallel nodes (rows=... loops=1, no Gather). Hmm, the plans do not show Gather. So perhaps parallel was disabled already. Mention not needed, or note that the plans here are serial.

- Index on cliente? Not needed; 20k seq scan fine.
- Index on pedido(id_cliente) already exists; could be used for join to cliente if NL. But hash join with 20k client table is cheap.
- The WindowAgg with Run Condition rank()<=20 already stops early after 21 rows; good. But the inner sort by gastado DESC takes 1.3MB in memory; fine. Could use LIMIT 20 outside but RANK semantics with ties require careful handling; the run condition is already efficient.

- Merge Join possibility: sort by id_pedido then Merge Join between pedido and detalle? Not likely.

Now let me be precise about "identificá qué algoritmo de join eligió el optimizador en cada combinación de tablas".

Q1 combos:
1. pedido ⋈ detalle_pedido → Hash Join (hash on pedido's index-only scan, probe detalle_pedido seq scan).
2. (pedido⋈detalle) ⋈ producto → Hash Join (hash on producto seq scan, probe intermediate).
3. (…) ⋈ categoria → Hash Join (hash on categoria seq scan, probe intermediate).
No Nested Loop, no Merge Join.

Q2 combos:
1. pedido ⋈ detalle_pedido → Hash Join.
2. (pedido⋈detalle) ⋈ cliente → Hash Join.
No NL/MJ.

Now proposals with concrete nodes.

Let me structure the answer in Spanish. Should be reasonably concise but this is a detailed analytical task; the user asked to "respondé lo que pide" — need a complete answer. Plan mode says produce plan and answer; but this is a Q&A/analysis task, not implementation. No edits. I'll give the full answer.

Let me think about the best technical recommendations and costs to be credible.

Q1 analysis detail:
- Total 582ms. Seq Scan detalle 26ms; Sort external merge ~33ms (506→539) but caused temp IO 791 blocks read + 793 written; GroupAggregate from 508→579 (~71ms cumulative after sort). Actually the sort node time 506.226..539.802, so ~33.6ms, but external merge with temp read/write. Total buffers temp = 791 read + 793 written ~ 6.3MB each way. At disk speeds could be worse; here cached temp.
- The plan estimates 108,086 rows but actual 108,616 — good estimate.
- group rows 35.

Key: external sort happens because GroupAggregate needs input sorted by (c.nombre, mes, p.id_pedido) for COUNT(DISTINCT p.id_pedido). If we remove COUNT(DISTINCT), we get HashAggregate or GroupAggregate sorted only by (c.nombre, mes) which is far cheaper (35 groups, ~108k rows still sorted but smaller key; still external? 43 bytes width × 108k ≈ 4.6MB, might still spill at default work_mem 4MB). Pre-aggregation to 200k... hmm.

Better rewrite for Q1:
```sql
WITH lineas AS (
  SELECT d.id_pedido, pr.id_categoria,
         SUM(d.cantidad * d.precio_unitario) AS importe
    FROM detalle_pedido d
    JOIN producto pr ON pr.id_producto = d.id_producto
   GROUP BY d.id_pedido, pr.id_categoria
)
SELECT c.nombre, date_trunc('month', p.fecha)::date AS mes,
       COUNT(*) AS pedidos, SUM(l.importe) AS facturado
  FROM pedido p
  JOIN lineas l ON l.id_pedido = p.id_pedido
  JOIN categoria c ON c.id_categoria = l.id_categoria
 WHERE p.fecha >= ...
 GROUP BY c.nombre, date_trunc('month', p.fecha)
 ORDER BY mes, facturado DESC;
```
But that aggregates all 400k lines for all orders (200k groups), worse if most orders are older than 6 months. Better filter pedidos first:
```sql
WITH pedidos_periodo AS (
  SELECT id_pedido, date_trunc('month', fecha)::date AS mes
    FROM pedido
   WHERE fecha >= ...
),
lineas AS (
  SELECT p.id_pedido, p.mes, pr.id_categoria,
         SUM(d.cantidad * d.precio_unitario) AS importe
    FROM pedidos_periodo p
    JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
    JOIN producto pr ON pr.id_producto = d.id_producto
   GROUP BY p.id_pedido, p.mes, pr.id_categoria
)
SELECT c.nombre, l.mes, COUNT(*) AS pedidos, SUM(l.importe) AS facturado
  FROM lineas l JOIN categoria c ON c.id_categoria = l.id_categoria
 GROUP BY c.nombre, l.mes ORDER BY l.mes, facturado DESC;
```
This way: no COUNT(DISTINCT), the per-order-per-category subquery yields at most 108k rows but typically one row per order×category (~maybe 55-80k), then outer group by 35 groups. The inner grouping requires sort/hash on (id_pedido, mes, id_categoria) — 108k rows, HashAggregate could do it in memory (width maybe 40 bytes → 4.3MB, borderline). Still removes the sort by id_pedido for DISTINCT. Hmm, but the inner HashAggregate over 108k rows also costs memory.

Alternatively simpler: replace COUNT(DISTINCT p.id_pedido) with COUNT(DISTINCT d.id_pedido)? Still distinct. Or exploit: since detalle has UNIQUE(id_pedido,id_producto) and producto→categoria is many-to-one, within a (categoria, mes) group a given id_pedido can appear on multiple lines (multiple products same category), so count distinct needed. Pre-aggregation is the clean fix. Or use `COUNT(DISTINCT p.id_pedido)` → subquery with DISTINCT (id_pedido, categoria, mes) then count(*). Same idea.

Index proposal Q1:
- `CREATE INDEX idx_detalle_pedido_pedido_cover ON detalle_pedido (id_pedido) INCLUDE (id_producto, cantidad, precio_unitario);` Replaces the prefix use of unique (id_pedido,id_producto) and makes an Index Only Scan possible. Attacks Seq Scan on detalle_pedido node and the Hash Join above it: expected Nested Loop (pedido filtered by fecha as outer, detalle as inner index-only). With 54,309 pedidos → ~108k lines: 54k index probes. At random_page_cost=4 this is ~54k*4 = 216k cost vs hash join 11k, so planner won't switch unless random_page_cost lowered to ~1.1-2. So pair with `SET random_page_cost = 1.1` (or 2) given warm cache; then NL expected. Note measured: hash join ~139ms; NL index-only maybe similar or better; main win is avoiding 400k-row scan when selectivity is higher (e.g., narrower date range).

- Alternative targeted index Q1: `CREATE INDEX ... ON detalle_pedido (id_producto) INCLUDE (id_pedido, cantidad, precio_unitario);` already exists detalle_pedido(id_producto) INCLUDE(cantidad). Could extend it; but the join order is pedido→detalle, so id_pedido index is the relevant one.

- For producto hash: existing `producto (id_categoria) WHERE activo` could allow index-only scan if the query only needs id_categoria and id_producto (both in index). But the plan uses Seq Scan producto to build hash of 50k. Seq scan of 50k rows (~1016 cost, 516 buffers, 15ms). An index-only scan over 5 categories? Actually if hash join #2 were replaced by nested loop with the index on id_categoria, you'd have 108k probes — bad. Keep hash. Could propose `producto (id_producto) INCLUDE (id_categoria)` — PK already gives that. So no change. Or push the product→category mapping to a smaller hash: join producto & categoria first? Produces 50k rows still.

- categoria 5 rows: trivial, no proposal.

- The last Sort for ORDER BY (35 rows, quicksort 27kB) is negligible.

- Big lever: work_mem. External merge 6328kB > default 4MB. `SET work_mem = '32MB'` avoids temp I/O (791/793 blocks). Node attacked: Sort (external merge) under GroupAggregate. But this is a config knob, not rewrite/index; mention as complement. Note the measured temp was cached, so gain small here; on cold temp could be significant.

Q2 analysis:
- Total 172ms. Seq Scan detalle 23ms (3334 buffers); hash join #1 from 6.5→81.6ms (~75ms); hash join #2 81.6→101.5 (~20ms); sort external 3.1MB ~6ms (140.7→134? Actually sort node 134.297..140.698 = 6.4ms); GroupAggregate 134→163.9 (~29.6ms); sort by sum in memory 1.3MB (~0ms); WindowAgg run condition cuts to 21 rows. 
- Proposals:
  a) Same COUNT(DISTINCT) removal: pre-aggregate at order level. Since the date filter leaves 24,810 orders, do:
  ```sql
  WITH pedidos_periodo AS (SELECT id_pedido, id_cliente FROM pedido WHERE fecha >= now()-interval '90 days'),
       gasto_pedido AS (SELECT p.id_cliente, p.id_pedido, SUM(d.cantidad*d.precio_unitario) AS importe
                          FROM pedidos_periodo p JOIN detalle_pedido d ON d.id_pedido=p.id_pedido
                         GROUP BY p.id_cliente, p.id_pedido)
  SELECT ... RANK() OVER (ORDER BY SUM(importe) DESC) ...
    FROM cliente c JOIN gasto_pedido g ON g.id_cliente=c.id_cliente
   GROUP BY c.id_cliente, c.nombre, c.apellido
  ```
  Wait, grouping by (id_cliente, id_pedido) then outer group by cliente. Or simply: since each pedido row is unique, COUNT(DISTINCT p.id_pedido) = COUNT(*) if we group detail at order level first. Then outer COUNT(*) counts orders. Removes the sort by p.id_pedido for DISTINCT (Sort external merge 3168kB). But the inner aggregate means hash aggregate over 49,623 lines → 24,810 groups; doable.

  Actually even simpler: `COUNT(DISTINCT p.id_pedido)` in a query joining 1:N — could rewrite as `COUNT(*)` over a distinct set of (cliente,pedido). Use a subquery `SELECT DISTINCT c.id_cliente, p.id_pedido`? That's another sort. Preaggregation is cleanest.

  b) Index: `detalle_pedido (id_pedido) INCLUDE (cantidad, precio_unitario)` enables Nested Loop: outer = 24,810 pedidos (index-only from idx_pedido_fecha), inner = Index Only Scan on detalle_pedido (~49,623 rows, ~2 per order). This avoids Seq Scan of 400k rows (3334 buffers, 23ms) and the hash build. Node attacked: Seq Scan on detalle_pedido (line 132) and Hash Join (d.id_pedido=p.id_pedido) (line 129) → Nested Loop + Index Only Scan. With random_page_cost=4 might not be chosen; lower to 1.1-2.
  c) Join to cliente: Hash Join with Seq Scan cliente 20k (5.8ms) is fine; alternatively use the existing idx? index on pedido(id_cliente) could allow NL from cliente but 20k probes — no. Keep hash.
  d) Merge Join alternative: the pre-aggregated detail sorted by id_pedido could merge join with pedido sorted by id_pedido. Actually if we do index-only scan on detalle_pedido(id_pedido) INCLUDE(...), output is ordered by id_pedido, so `Merge Join` with pedido (needs sort by id_pedido unless we use PK order) becomes possible and avoids hash memory. Could mention: Merge Join between pedido and detalle on id_pedido if both sides sorted; detalle via index, pedido via PK index scan (but date filter means not ordered by id_pedido; would need sort). Not great.
  e) Top-N: WindowAgg already uses Run Condition rank()<=20, so it stops early; the sort by sum(DESC) over 14,226 groups is 1.3MB in memory. Fine. Could reduce work by doing LIMIT 20 with `RANK` ties handled; but current is already efficient. Maybe propose `work_mem` adequate.

  f) Also note grouping by c.id_cliente, c.nombre, c.apellido — since id_cliente is PK, GROUP BY c.id_cliente suffices (functional dependency) and avoids carrying name/apellido; the plan already Group Key: c.id_cliente only! So planner knows. Fine.

- Another Q2 index: `cliente (id_cliente) INCLUDE (nombre, apellido)` — PK already covers. No.

- For Q1, also consider `pedido (fecha) INCLUDE (id_pedido, id_cliente)` already used (index-only). Great, no change.

Important nuance: Q1 index-only scan of idx_pedido_fecha returns 54,309 rows width 16 (id_pedido, id_cliente? width 16 suggests two 8-byte ints). Fine.

Now "proponé reescrituras y/o índices que lo mejoren". I'll give:
For each query: (1) join map, (2) main problem node, (3) rewrites with justification, (4) indexes with justification and which node, (5) config complements (random_page_cost, work_mem, parallel).

I should also note interactions: adding `detalle_pedido(id_pedido) INCLUDE (cantidad, precio_unitario, id_producto)` might make the existing UNIQUE (id_pedido,id_producto) redundant for lookups; but keep for constraint.

Also for Q1, the hash join #2 on producto: if we pre-aggregate lines by (id_pedido, id_categoria), we still join producto. Could instead use existing partial index `producto (id_categoria) WHERE activo`? To map product→category we need each product's category; Seq Scan 50k is cheap. Or use index-only scan on producto(id_categoria?) no. Actually the existing index `producto (id_categoria, precio) WHERE activo` does not include id_producto? Index on (id_categoria, precio) includes key columns id_categoria, precio plus heap TID, not id_producto. So can't index-only map product→category. Could propose `producto (id_producto) INCLUDE (id_categoria)` — PK is id_producto and doesn't include category in index (heap fetch). A covering index would allow index-only nested loop if join order becomes detalle→producto. But with 108k rows, NL probes expensive. Maybe not.

Alternative for Q1: since 5 categories and 50k products, hash join is right. But could reduce join #2/#3 by precomputing category per product in a CTE and letting hash join; no gain.

Let me reconsider the ordering of joins. The optimizer put detalle_pedido first (seq scan all 400k) as probe side, hash pedido (54k) as build. That's fine because it scans detalle once. The main cost is not the join but the sort for COUNT(DISTINCT) — 6.3MB external merge plus it forces all 108k rows + p.id_pedido into sort key width 43. Note: the hash joins themselves are ~200ms cumulative. Hmm, 400k seq scan 26ms, hash joins 139ms, 206ms, 256ms. So hash join #3 (with categoria 5 rows) adds 50ms? That seems like just the 108k probe cost, 0.46µs/row. Fine.

Actually wait: could use Merge Join for pedido↔detalle if both sorted by id_pedido. But pedido filtered by date isn't sorted. A bitmap/index scan... No.

Let me quantify proposals:
- Removing COUNT(DISTINCT) eliminates `Sort Key: c.nombre, mes, p.id_pedido` external merge (6328kB, 791/793 temp blocks) and changes GroupAggregate to HashAggregate (35 groups, tiny). Expected Q1 maybe 582 → ~300ms (the hash joins ~256ms + small aggregate). Also could combine with index NL to avoid scanning 400k: maybe ~150-250ms.
- For Q2, removing COUNT(DISTINCT) eliminates Sort 3168kB external merge and changes GroupAggregate → HashAggregate over 14,226 groups (in memory ~1-2MB). Combined with NL index-only on detalle to avoid 400k seq scan: maybe 172 → ~60-90ms.

I should be careful not to overpromise. Frame expected changes qualitatively.

Also mention `COUNT(DISTINCT p.id_pedido)` can be replaced by `COUNT(*)` after a `DISTINCT` subquery on (id_pedido, categoria, mes) or after preaggregation.

Another possible rewrite for Q1: use `COUNT(DISTINCT p.id_pedido)` → `COUNT(DISTINCT d.id_pedido)` doesn't help. Use `(SELECT count(*) FROM (SELECT DISTINCT ...) x)` maybe.

Also for Q1, could compute separately: aggregation of SUM by month/category, and COUNT of orders by month/category via a separate DISTINCT query then join — avoids the DISTINCT-in-group sort. But two scans. Preaggregation is better.

Now about parallel: "los planes con workers paralelos tardaron más que sin ellos" — recommend for these queries `SET max_parallel_workers_per_gather = 0` (or `SET LOCAL`) to keep serial plans; plans shown are serial so no action, but mention that if the rewrite + indexes cause parallel plans, force serial or lower `parallel_setup_cost`? Actually to avoid parallel, set `max_parallel_workers_per_gather=0`. Or increase `parallel_setup_cost`/`parallel_tuple_cost`. Since measured parallel slower, set to 0 for this session.

random_page_cost: recommend 1.1 (or 2) given warm cache and SSD-ish; this is key to make Nested Loop viable. The prompt explicitly mentions random_page_cost=4, so they want us to reason: the planner prefers hash/seq scans partly due to rpc=4. So propose lowering to 1.1-2 so index nested loops are costed realistically, then the covering index on detalle_pedido gets chosen.

work_mem: default likely 4MB; the sorts need 6.3MB and 3.1MB. Propose `SET work_mem='32MB'` as stopgap before rewrites (attacks the exact Sort nodes). But note it doesn't fix Q1's 6328kB? 32MB would keep in memory, yes. Mention as immediate mitigation measured.

Let me also identify the algorithm on each combination explicitly with node names/line references. I'll reference line numbers from the plan in the prompt file (lines 66-93, 126-146). Since these are plan lines, I can cite as Q1 plan nodes.

Now, should I ask clarifying questions? The task is clear. Plan mode: I should present the answer/plan. Since no modifications are needed (the user says don't modify files), I can just answer. I won't ask questions.

The instruction says be concise <4 lines unless user asks for detail. Here the user explicitly asks for a detailed analytical answer ("respondé lo que pide"), so detail is warranted. I'll use markdown headings.

Let me also mention Q1: the hash join order chosen: detalle seq scan as probe, pedido index-only as build — the optimizer chose to scan the largest table (detalle) fully rather than drive from pedido. That's the node to attack. Proposal: make detalle_pedido accessible by id_pedido in index-only form so a Nested Loop from the 54k pedidos is viable. Justify with buffers: Seq Scan detalle = 3334 buffers + 400k rows vs ~108k index tuples.

Potential objection: 54,309 probes with rpc=4 → high cost. Explain pair with rpc.

Also alternative to index: rewrite Q1 to pre-filter detalle via `JOIN` with CTE `MATERIALIZED`? Postgres can't push date filter into detalle directly without pedido. The existing plan already uses hash join and only keeps matching rows.

Another idea: partitioning detalle by date? Not asked.

Let me also note Q1's `COUNT(DISTINCT p.id_pedido)` is semantically redundant given `(id_pedido,id_producto)` unique? No, because multiple products in same category per order → duplicates across lines. So distinct is needed; preaggregation handles it.

For Q2's `COUNT(DISTINCT p.id_pedido)`: multiple lines per order → same.

Let me write out SQL rewrites carefully and validate semantics.

Q1 rewrite (single statement, no CTE maybe):
```sql
SELECT c.nombre AS categoria, l.mes AS mes,
       COUNT(*) AS pedidos,
       SUM(l.importe) AS facturado
FROM (
  SELECT d.id_pedido,
         date_trunc('month', p.fecha)::date AS mes,
         pr.id_categoria,
         SUM(d.cantidad * d.precio_unitario) AS importe
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
  JOIN producto pr ON pr.id_producto = d.id_producto
  WHERE p.fecha >= date_trunc('month', now()) - INTERVAL '6 months'
  GROUP BY d.id_pedido, date_trunc('month', p.fecha), pr.id_categoria
) l
JOIN categoria c ON c.id_categoria = l.id_categoria
GROUP BY c.nombre, l.mes
ORDER BY l.mes, facturado DESC;
```
Each (id_pedido, id_categoria, mes) row is unique because grouping by id_pedido and id_categoria; so COUNT(*) = distinct orders per category-month. Correct. Note mes is functionally dependent on id_pedido so grouping by it is fine.

Would inner GROUP BY (id_pedido, mes, id_categoria) require sort? 108k rows, width ~ (8+4+4+8)=24 + overhead. HashAggregate ~3-4MB. Or GroupAggregate with sort 108k rows. Could still spill. Alternative: preaggregate only by (id_pedido,id_categoria) from detalle+producto without date, then join pedido and filter date. That aggregates all 400k lines into ~200k*avg categories per order... more rows. Not better.

Better: exploit that date filter is on pedido, so start from filtered pedido (54k) → detalle (108k) → producto → group by (id_pedido, id_categoria) [108k→ maybe 60k] → categoria. The grouping key (id_pedido, id_categoria) with mes derived from id_pedido; can group by (id_pedido, id_categoria) and carry mes via any_value? Postgres requires mes in group by or aggregate; include it. Still 108k input. HashAggregate should fit 4MB? 108k × ~60 bytes = 6.5MB → might spill. Increase work_mem 32MB for the inner agg. Or instead of preaggregating, change COUNT(DISTINCT) to a window/`COUNT(DISTINCT)` still sorts.

Alternative rewrite that avoids inner sort entirely: compute two aggregates separately and join on (mes, categoria):
```sql
WITH filtrado AS (
  SELECT p.id_pedido, date_trunc('month', p.fecha)::date AS mes,
         pr.id_categoria, d.cantidad * d.precio_unitario AS importe
  FROM pedido p JOIN detalle_pedido d USING (id_pedido)
  JOIN producto pr ON pr.id_producto = d.id_producto
  WHERE p.fecha >= ...
)
SELECT ... SUM(importe), COUNT(DISTINCT id_pedido) ...
```
Still count distinct → sort. So preaggregate is the fix. Or use `hashed` DISTINCT? PG can't hash count distinct.

Actually there's a neat trick: `COUNT(DISTINCT id_pedido)` over 108k rows; the sort is on (c.nombre, mes, id_pedido) and external merge 6.3MB. If we make the sort smaller by pre-aggregating to one row per (id_pedido, mes, categoria), and then use `COUNT(*)`, the inner GROUP BY itself sorts by (id_pedido, mes, categoria) — similar size! Hmm, so does preaggregation actually help? It converts COUNT(DISTINCT) sort (width 43, 108k rows, key includes p.id_pedido) into an inner GROUP BY sort (108k rows, width ~24) plus a small outer group. The inner sort could still spill (~4-6MB), but narrower, and the outer is tiny. Plus removes the second-level distinct processing in GroupAggregate. Might not be a huge win by itself. 

Alternative: Use `COUNT(*) FILTER`? no.

What about computing pedidos via a separate scalar subaggregate at a coarser grain? E.g., count distinct orders per category-month = count of (id_pedido, id_categoria) distinct. Could do:
```sql
SELECT c.nombre, mes, COUNT(*) pedidos, SUM(facturado)
FROM (
  SELECT DISTINCT p.id_pedido, pr.id_categoria, date_trunc(...) mes
  FROM ... WHERE ...
) x JOIN categoria ...
```
plus facturado from another aggregate. Two passes. Not obviously better.

Better yet: exploit the fact that detalle has UNIQUE(id_pedido,id_producto) but not id_pedido,categoria. Could create an index on detalle_pedido(id_pedido) INCLUDE(...) and rely on the fact that the number of distinct (id_pedido, category, month) pairs is ~ number of rows for 5 categories. Hmm.

Wait, maybe the biggest win for Q1 is simply: the plan's sort is external because work_mem 4MB; setting work_mem=32MB eliminates the disk I/O and reduces 582→ maybe 400ms. But the GroupAggregate still processes 108k rows sorted by p.id_pedido. Also, count distinct via sorting is inherent.

Alternative counted differently: Since `pedido.id_pedido` is unique and every detalle row belongs to a pedido, if we pre-aggregate detalle to one row per (id_pedido, id_categoria) [no mes needed because mes comes from pedido], the number of rows decreases from 108k only modestly (orders with multiple products in same category). With 50k products/5 categories=10k products per category, and ~2 lines per order, collisions within same category are possible but ~1.1 lines per category per order. So 108k → maybe 90k. Marginal.

So the real Q1 win: reduce the number of rows that reach the sort. Idea: filter by category? No.

Could aggregate at the right grain earlier: Since the outer GROUP BY is (categoria, mes), and facturado is additive, we can aggregate detalle→producto→categoria and sum per (mes, categoria) in one step. Only pedidos (COUNT DISTINCT) needs per-order data. Compute pedidos via a semi-distinct count: 
```sql
SELECT categoria, mes, SUM(importe) facturado,
       COUNT(DISTINCT id_pedido) pedidos
```
That's exactly the original. The DISTINCT forces sort/unique. Alternatively, because 5 categories, we could use `COUNT(DISTINCT ...)` per category via FILTER? Still needs sort per category.

Honestly, the cleanest teaching-point answer: the expensive node is the external-merge Sort under GroupAggregate caused by COUNT(DISTINCT p.id_pedido); two levers: (a) raise work_mem to keep the 6.3MB sort in memory (attacks exactly that node, no semantic change, immediate); (b) rewrite to preaggregate per (id_pedido, id_categoria) so the sort payload shrinks and the outer aggregation becomes a 35-row HashAggregate (removes the DISTINCT from the sort key and the GroupAggregate's distinct tracking). Pair with (c) covering index + rpc to switch the bottom Hash Join to a Nested Loop.

I think that's a fair, accurate analysis. I should not overclaim that preaggregation kills the sort; it reduces width and removes the second distinct pass, and with work_mem it stays in memory. Be honest.

Similarly Q2: preaggregation to order level reduces sort from 49,623 rows keyed by (id_cliente, id_pedido) to 24,810 rows, and then outer grouping 14k clients. And the sort by gastado is over 14k rows in memory. Removal of COUNT(DISTINCT) means the GroupAggregate input no longer needs sorted by p.id_pedido... wait, it groups by c.id_cliente; with COUNT(DISTINCT p.id_pedido), GroupAggregate needs input sorted by (c.id_cliente, p.id_pedido) — that's the external sort. If preaggregated to (id_cliente, id_pedido, importe), outer group by id_cliente with COUNT(*) and SUM(importe) → still GroupAggregate needs sorted by id_cliente, but we can HashAggregate (no distinct) → avoids the external sort entirely! Yes, HashAggregate over 24,810 rows memory ~2MB. That's a real win. For Q1, outer HashAggregate over 108k rows if we don't preaggregate... but count distinct forces sort. With preaggregation the outer can be HashAggregate over ~90k rows × 35 groups, memory ~5MB, still possibly spill but no disk sort (hash agg spills to disk batches too). Hmm.

Actually, for Q1, could do the inner preaggregation with a HashAggregate too (no DISTINCT), avoiding sort, then outer HashAggregate. Two hash aggs, both in memory if work_mem 32MB. So no external sort. Good.

But note: HashAggregate can spill to disk; with 32MB fine.

Let me also consider a much simpler Q1 rewrite: since there are only 5 categories, the `COUNT(DISTINCT p.id_pedido)` could be computed with an `EXISTS`/`LATERAL`? No.

OK, my answer will present these.

Let me also mention Merge Join consideration: In Q1/Q2, a Merge Join between pedido and detalle on id_pedido is only viable if both inputs sorted by id_pedido; with the covering index detalle_pedido(id_pedido) the detalle side is sorted, and pedido filtered by date isn't → would need a sort of 54k/25k rows. A Nested Loop with index is generally better for 2 rows/order. So recommend NL, not MJ. For pedido↔cliente in Q2, hash join is fine (20k build, 49k probe) unless client filter; no change.

For Q1's pedido↔detalle alternative: If planner uses index-only scan on detalle for the 54k orders, it's a Nested Loop. Good.

Also note Q1 hash join with producto: could be a Nested Loop if product were probed per detail row (108k probes) — worse. Hash is correct. But we could reduce producto hash build by using a partial/covering index? Build is 2.8MB, 50k rows; fine. So explicitly say: do NOT replace hash join #2/#3; they're optimal, and any index there wouldn't help. That shows judgment.

Now let me draft the answer in Spanish, structured:

1. Resumen ejecutivo (short).
2. Q1: mapa de joins (table), nodo crítico, propuestas R1/R2/I1/config, justificación.
3. Q2: same.
4. Orden de aplicación sugerido + verification (EXPLAIN again, check for "external merge" gone, Nested Loop present).
5. Nota: no files modified.

Include SQL snippets for rewrites and CREATE INDEX.

Need to be mindful: plan mode, no file changes, and the answer is the deliverable. The system says present a well-researched plan and ask clarifying questions. But the user's actual request is to answer the prompt. I'll answer directly (that's the "plan"/deliverable) and note nothing was modified.

Let me identify exact plan line/node references:
Q1:
- Hash Join #1 lines 72-74: Hash Cond (d.id_pedido = p.id_pedido); outer Seq Scan detalle (line 75); inner Hash over Index Only Scan idx_pedido_fecha (lines 77-83).
- Hash Join #2 lines 69-71: Hash Cond (d.id_producto = pr.id_producto); Hash over Seq Scan producto (lines 85-88).
- Hash Join #3 lines 66-68: Hash Cond (pr.id_categoria = c.id_categoria); Hash over Seq Scan categoria (lines 90-93).
- Sort external merge line 62-65.
- GroupAggregate line 59.
- Final Sort line 55.

Q2:
- Hash Join #1 lines 129-131: Hash Cond (d.id_pedido = p.id_pedido); Seq Scan detalle line 132; Hash over Index Only Scan idx_pedido_fecha lines 134-140.
- Hash Join #2 lines 126-128: Hash Cond (p.id_cliente = c.id_cliente); Hash over Seq Scan cliente lines 142-145.
- Sort external merge lines 122-124.
- GroupAggregate lines 119-120.
- Sort in memory 1.3MB lines 115-117.
- WindowAgg with Run Condition lines 110-113.

Metrics:
Q1: 582ms, buffers shared hit 4138 + temp 791r/793w; detalle seq scan 400k rows/3334 buffers; sort spill 6328kB; rows 108,616 vs est 108,086.
Q2: 172ms, shared hit 3688 + temp 396r/397w; detalle seq scan 400k; sort spill 3168kB; 14,226 groups; window stops at 21.

Good.

Now, expected changes:
- I1 (covering index) + rpc=1.1/2: bottom Hash Join → Nested Loop (outer pedido index-only, inner Index Only Scan detalle). For Q1, 54,309 index probes, ~108k tuples; for Q2, 24,810 probes, ~49,623 tuples. Note the hash build side disappears (Hash node of pedido). Risk: if rpc stays 4, planner keeps hash join.
- R1 (COUNT DISTINCT removal): Sort external merge → gone; GroupAggregate → HashAggregate. Justify: the sort key currently includes p.id_pedido solely to feed count(distinct); preaggregating per order removes that.
- work_mem 32MB: attacks Sort nodes directly (6328kB/3168kB spill), no semantic change.
- max_parallel_workers_per_gather=0: plans already serial; keep to avoid regression.

Also mention: after rewrite, re-check `EXPLAIN (ANALYZE, BUFFERS)` for absence of "external merge Disk" and presence of "Index Only Scan ... detalle_pedido".

One more thing: For Q1, the existing `idx_pedido_fecha` is used optimally (index-only, 272 buffers). Keep. For Q2, same, 126 buffers. So no change on pedido side — note that explicitly (recognize what's already good).

Also, Q1 index option: `CREATE INDEX ON detalle_pedido (id_pedido) INCLUDE (id_producto, cantidad, precio_unitario);`. Consider that UNIQUE (id_pedido,id_producto) already exists but not covering precio/cantidad, and its second column doesn't help index-only for the needed columns. Mention possible redundancy: the new index's leading column duplicates part of the unique index; if space matters, could instead `INCLUDE` on the unique? Can't add include to existing constraint without rebuild; acceptable.

For Q2, the same index serves.

For Q1, could also propose `producto (id_producto) INCLUDE (id_categoria)`? PK already on id_producto, but index-only needs id_categoria in index. Not necessary because hash join scans producto anyway. I'll mention as optional/no.

Let me also mention for Q1 that the `GROUP BY c.nombre` could be `GROUP BY c.id_categoria, c.nombre` or use id for stability; not performance critical but avoids grouping by variable-length name (width 61). Actually grouping by c.nombre means sort/group key includes text; grouping by c.id_categoria first could reduce. With only 5 categories, irrelevant. Mention as micro-optimization optional.

Also Q1: `ORDER BY mes, facturado DESC` final sort 35 rows — irrelevant.

Now write the answer. Length: detailed but not insane. Use tables for join map. Include a "Qué NO tocar" to show discrimination.

I'll write in Spanish (user wrote Spanish). Ensure no file modifications.

Let me draft.

Potential nuance about "sequedad" of the answer: The user wants the answer to the prompt. I'll present it as a complete deliverable.

I'll include expected-plan sketches.

One more consideration: `date_trunc('month', now()) - INTERVAL '6 months'` is volatile-ish (now() stable). Fine.

For the Q1 rewrite inner aggregate, do we need `pr.id_categoria` only; but grouping by id_pedido and id_categoria requires scanning producto. Fine.

Let me also propose alternative for Q1 without CTE to allow predicate pushdown, and note materialization. Actually the original query already is a single block. The rewrite uses a subquery; PostgreSQL will flatten it unless grouped. It's grouped, so it stays as Subquery Scan/GroupAggregate. Predicate on p.fecha is inside subquery, so filter applied early. Good. The outer join to categoria is 5 rows.

For Q2 rewrite:
```sql
WITH pedidos_periodo AS MATERIALIZED (
  SELECT id_pedido, id_cliente
  FROM pedido
  WHERE fecha >= now() - INTERVAL '90 days'
),
gasto_por_pedido AS (
  SELECT p.id_cliente, p.id_pedido,
         SUM(d.cantidad * d.precio_unitario) AS importe
  FROM pedidos_periodo p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
  GROUP BY p.id_cliente, p.id_pedido
)
SELECT puesto, id_cliente, cliente, pedidos, gastado
FROM (
  SELECT c.id_cliente, c.nombre || ' ' || c.apellido AS cliente,
         COUNT(*) AS pedidos,
         SUM(g.importe) AS gastado,
         RANK() OVER (ORDER BY SUM(g.importe) DESC) AS puesto
  FROM cliente c
  JOIN gasto_por_pedido g ON g.id_cliente = c.id_cliente
  GROUP BY c.id_cliente, c.nombre, c.apellido
) r
WHERE puesto <= 20
ORDER BY puesto, id_cliente;
```
COUNT(*) = number of orders per client because gasto_por_pedido has one row per order. Correct.

Note: `MATERIALIZED` optional; might prevent pushdown but keeps filtered set. Actually materialized CTE can help by forcing the index-only scan of pedido once and reusing; but the outer join needs id_cliente. Could skip MATERIALIZED. I'll show without or with note. Since PG12+, CTE inlined by default; materialized could be better for reuse, but used once. I'll present plain CTE (inlined) and mention MATERIALIZED if planner misbehaves.

Wait: with the CTE, pedidos_periodo used once in gasto_por_pedido, so inline is fine.

For Q1 rewrite, similar CTE optional.

Also: in Q1 rewrite, note that grouping by `date_trunc('month', p.fecha)` inside subquery and then `l.mes` outside avoids recomputation.

Now let me also address: "identificá qué algoritmo de join eligió ... en cada combinación de tablas" — I'll say explicitly Nested Loop, Hash Join, or Merge Join for each, and note none used NL/MJ.

Also note the direction of hash join (build/probe) because it matters for index proposal.

Let me write final.

I should keep it readable. Maybe use sections with bold labels.

Also add "Riesgo/verificación" for each.

Let me produce the final answer now.

I need to decide whether to include the exact expected plan changes. Yes: "Hash Join (d.id_pedido = p.id_pedido) → Nested Loop, con Index Only Scan on detalle_pedido como inner; desaparece el nodo Hash sobre idx_pedido_fecha".

One caveat: In the current plan, the hash is built on pedido (54k rows, width 16). If we switch to NL with pedido outer, we still scan idx_pedido_fecha to get 54k pedidos; then 54k probes. Total buffers likely: 272 (pedido index) + index probes + heap/index-only. With index-only, ~ maybe 150-300 buffers for detalle index + visibility map. Actually 54k random index pages ~ maybe 300-600 pages. So buffers drop from 3334 (detalle heap) to a few hundred index pages + heap fetches 0 if all-visible. Good argument: Seq Scan detalle touches 3334 heap pages; index-only detalle touches only the index pages needed plus visibility map. Even if all lines are touched (108k of 400k = 27%), the index-only scan reads fewer pages. For Q2 only 12% → bigger win.

But with 54k probes at rpc=4, cost ~ maybe 54k*(4+...) ≈ 250k vs hash 11k → planner won't pick. With rpc=1.1 → ~80k, still > 11k? Hmm. Let's compute: Index Only Scan cost per probe with rpc=1.1 ≈ 0.005 (index) + 1.1 (page) ≈ 1.1; plus CPU. 54k×~1.3 ≈ 70k. Hash join cost includes seq scan 400k rows (7333) + hash build (2022) + probe ≈ 11k. So even at rpc=1.1, hash join may still be cheaper because scanning 400k sequentially is cheap and it's a single pass. Hmm. But measured: seq scan 400k = 26ms, and hash join total 139ms. NL 54k probes at ~0.005ms each = 270ms? Actually random index probes on cached data ~0.01-0.02ms → 54k×0.015 = 810ms, worse! Wait but only 108k rows returned.

Hmm. So for Q1 with 27% selectivity, hash join is genuinely good. The measured 139ms for the hash join is hard to beat with 54k random probes. Let me reconsider: random page reads on SSD ~0.1ms uncached → 5.4s; cached ~0.005ms → 270ms. So NL might be worse for Q1. For Q2, 24,810 probes → cached ~124ms vs current 75ms; also maybe worse. Hmm.

So maybe the index proposal is not actually the main win, and I should be careful. The covering index helps only if selectivity is lower (e.g., 1 month) or if all data cached and index-only with few pages. Let me analyze more rigorously.

Seq scan detalle: 3334 pages, 400k rows → 26ms (including CPU). Index-only scan on detalle for 54k keys returning 108k rows: index has 400k entries, but an index-only scan with 54k separate probes reads index leaf pages. Index size for (id_pedido, id_producto, cantidad, precio) maybe ~ 400k × ~50 bytes = 20MB = 2500 pages; random access to ~54k probes touching maybe up to 1200 distinct leaf pages (if orders' lines clustered by id_pedido, contiguous) — actually since index is ordered by id_pedido, consecutive pedidos' lines are contiguous, but the probes are for 54k arbitrary pedido ids spread across the whole range (they're the recent 27% of orders, and id_pedido likely correlates with fecha, so they're a contiguous high range!). Ah, important: if id_pedido is serial and fecha correlates, the last 6 months = the highest ~27% of id_pedido → index range scan, not random. Then index-only scan would be sequential over ~27% of index = ~675 pages, cheap. Similarly Q2 last 90 days = recent 12% high ids. Even better.

But the date filter uses fecha, and id_pedido order may correlate with insertion order which usually correlates with fecha. Likely yes in generated data. But not guaranteed. If correlated, NL with index range scan is great. The planner doesn't know correlation for the index on id_pedido vs fecha; it assumes independence.

So the proposal is sound especially if id_pedido correlates with fecha. But I should present it with the caveat: "si id_pedido correlaciona con fecha (típico en datos generados en orden), el barrido es casi secuencial sobre el 27%/12% del índice". And recommend verifying with `EXPLAIN` after `SET random_page_cost`.

Alternatively, better index: `detalle_pedido (id_pedido) INCLUDE (cantidad, precio_unitario, id_producto)` — same.

Actually another approach: create index on `detalle_pedido (id_pedido, id_producto) INCLUDE (cantidad, precio_unitario)`—same as unique but covering. Since unique exists on (id_pedido,id_producto), we could rebuild it as INCLUDE (cantidad, precio_unitario)? Can't add INCLUDE to existing unique without dropping/recreating constraint; but could create a separate index and drop? The constraint needs a unique index; you could recreate the unique index with INCLUDE (Postgres supports INCLUDE on unique indexes? Yes, `UNIQUE (...) INCLUDE (...)` is allowed since PG11 for non-expression? Actually INCLUDE is supported on unique indexes; included columns are not part of uniqueness). So propose:
```sql
ALTER TABLE detalle_pedido DROP CONSTRAINT detalle_pedido_id_pedido_id_producto_key;
ALTER TABLE detalle_pedido ADD CONSTRAINT ... UNIQUE (id_pedido, id_producto) INCLUDE (cantidad, precio_unitario);
```
That avoids a redundant index. But altering constraints is heavier; mentioning as option. Simpler: new covering index.

However, if the unique index already exists on (id_pedido, id_producto), a separate index on (id_pedido) is redundant for lookup ordering but adds INCLUDE columns. We can just recommend the covering index and note the possible redundancy trade-off.

Now, the more certain win remains removing COUNT(DISTINCT)/sorts and work_mem. Let me make those primary, and the index as secondary/conditional with rpc tuning and selectivity. That's honest and defensible.

Let me reconsider Q1 sort elimination magnitude: The Sort external merge is 6328kB, buffers temp 791r/793w. On this machine (likely SSD, temp cached), 791 blocks × 8kB = 6.4MB; at 26ms-ish for 3334 buffers seq... temp read 791 in maybe 5-10ms. The Sort node took 33ms. GroupAggregate took 71ms. So eliminating sort+distinct could save maybe 60-100ms out of 582. The hash joins dominate (~256ms cumulative). So the rewrite alone maybe 582→450ms. Combined with avoiding detalle seq scan (if NL wins) → 582→250ms.

For Q2: sorts are small (3168kB, 6ms; 1.3MB in-memory 0ms); GroupAggregate 30ms; hash joins ~100ms; detalle seq 23ms. The rewrite saves maybe 30-40ms → 172→130ms. Index NL could cut the 75ms hash join to maybe 40ms. So maybe 172→100ms.

I'll present expected improvements qualitatively with rough ranges, clearly labeled as estimates.

Also, I realize for Q1, preaggregating per (id_pedido, id_categoria) then outer HashAggregate over ~? rows (one per order-category) — the outer group by (categoria, mes) is 35 groups, but it still has to scan ~90k rows; HashAggregate does that in one pass with tiny memory. The inner HashAggregate scans 108k rows and outputs ~90k; needs memory ~90k×~50B=4.5MB → borderline at 4MB work_mem, may spill to batches. So set work_mem 32MB. Two hash aggregates ~ no external merge sort. Good.

Alternatively, avoid inner preaggregation for facturado: compute SUM directly in outer over 108k rows, and compute pedidos via a separate DISTINCT count join. But that's two scans. Preaggregation is fine.

Hmm, wait: could we compute `COUNT(DISTINCT p.id_pedido)` more cheaply because categories are few? Trick: use `COUNT(*)` over `SELECT DISTINCT id_pedido, id_categoria, mes` then join to the sum aggregate by (id_categoria, mes). Two aggregates from the same filtered join, then join. This avoids grouping sum by id_pedido. But still distinct sort of 90k rows. Similar.

I'll keep preaggregation.

Also mention for Q1 the existing `categoria` scan (5 rows) and product scan are fine; do not index.

Let me also mention: the final `Sort` for ORDER BY (35 rows) is negligible; no proposal.

I think the answer is ready. Let me write it in Spanish with tables and SQL. Keep it organized.

Also, per plan mode, I should not make changes — confirm.

One more: The user says "Leé prompts/parte1_propuestas_ia.md y respondé lo que pide. No modifiques ningún archivo." So the answer itself should be the response, perhaps intended to be written into some file? No, just answer. Maybe they'd want a deliverable file normally, but explicit no-modify. So respond in chat.

Let me draft the final response.

Structure:

## Q1
### Joins elegidos
table:
| combinación | nodo | algoritmo | build/probe |
- pedido ⋈ detalle_pedido: Hash Join (línea ...), build = Index Only Scan idx_pedido_fecha (54,309), probe = Seq Scan detalle_pedido (399,994)
- ⋈ producto: Hash Join, build Seq Scan producto (50,010)
- ⋈ categoria: Hash Join, build Seq Scan categoria (5)
Sin NL ni MJ.

### Dónde se va el tiempo
- Seq Scan detalle 3334 buffers/26ms
- Hash joins ~256ms acumulado
- Sort external merge 6328kB (791/793 temp) por COUNT(DISTINCT)
- GroupAggregate
- final Sort 35 rows negligible

### Propuestas
R1 rewrite (remove count distinct)
I1 covering index + rpc
C1 work_mem
C2 parallel off
No tocar: hash joins producto/categoria, idx_pedido_fecha.

## Q2 similar.

## Orden de aplicación y verificación.

Let me write it.

For line references, use the plan-lines from the prompt (e.g., "nodo `Hash Join` de la línea 72 del plan"). Maybe better refer to conditions rather than the markdown file line numbers, since the user reads the prompt. I can say "el `Hash Join` con `Hash Cond: (d.id_pedido = p.id_pedido)`". That's unambiguous. I'll avoid file line numbers except maybe for code references. The instructions about file:line references are for codebase; here it's a plan. I'll cite node names.

Let me write with moderate detail. Ensure SQL correctness.

Q1 rewrite final:
```sql
SELECT c.nombre AS categoria, l.mes,
       COUNT(*)          AS pedidos,
       SUM(l.importe)    AS facturado
  FROM (
        SELECT d.id_pedido,
               date_trunc('month', p.fecha)::date AS mes,
               pr.id_categoria,
               SUM(d.cantidad * d.precio_unitario) AS importe
          FROM pedido p
          JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
          JOIN producto pr      ON pr.id_producto = d.id_producto
         WHERE p.fecha >= date_trunc('month', now()) - INTERVAL '6 months'
         GROUP BY d.id_pedido, date_trunc('month', p.fecha), pr.id_categoria
       ) l
  JOIN categoria c ON c.id_categoria = l.id_categoria
 GROUP BY c.nombre, l.mes
 ORDER BY l.mes, facturado DESC;
```
Correct: one row per (order, category, month); COUNT(*) counts distinct orders per category-month. ✓

Q2 rewrite:
```sql
WITH gasto_pedido AS (
  SELECT p.id_cliente, p.id_pedido,
         SUM(d.cantidad * d.precio_unitario) AS importe
    FROM pedido p
    JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
   WHERE p.fecha >= now() - INTERVAL '90 days'
   GROUP BY p.id_cliente, p.id_pedido
)
SELECT puesto, id_cliente, cliente, pedidos, gastado
  FROM (
    SELECT c.id_cliente,
           c.nombre || ' ' || c.apellido AS cliente,
           COUNT(*)      AS pedidos,
           SUM(g.importe) AS gastado,
           RANK() OVER (ORDER BY SUM(g.importe) DESC) AS puesto
      FROM cliente c
      JOIN gasto_pedido g ON g.id_cliente = c.id_cliente
     GROUP BY c.id_cliente, c.nombre, c.apellido
  ) r
 WHERE puesto <= 20
 ORDER BY puesto, id_cliente;
```
Correct: one row per order, COUNT(*) = orders. ✓

Index:
```sql
CREATE INDEX idx_detalle_pedido_cover
    ON detalle_pedido (id_pedido)
    INCLUDE (id_producto, cantidad, precio_unitario);
```
Note id_producto maybe not needed in Q2 but needed Q1. Good.

Config:
```sql
SET random_page_cost = 1.1;   -- o 2 si se prefiere conservador
SET work_mem = '32MB';
SET max_parallel_workers_per_gather = 0;
```

Expected plan changes:
- Q1: `Sort (external merge)` disappears → HashAggregate; bottom `Hash Join` may become `Nested Loop` with `Index Only Scan using idx_detalle_pedido_cover` as inner and `Index Only Scan using idx_pedido_fecha` as outer.
- Q2: the `Sort (external merge)` under `GroupAggregate` disappears → HashAggregate; `Hash Join (d.id_pedido=p.id_pedido)` → Nested Loop + Index Only Scan; WindowAgg Run Condition remains.

Verification: re-run EXPLAIN (ANALYZE, BUFFERS), check no "external merge Disk" and check buffers/Execution Time; compare. Also validate results row-by-row against original (same 35 / 20 rows) to ensure semantics.

Also note: don't add index on producto/categoria; hash joins there are correct (build sides tiny), and replacing them with NL would be 108k/50k probes → worse.

I should also mention the `detalle_pedido (id_producto) INCLUDE (cantidad)` existing index: it's not used in these plans; if we want Q1's join #2 to be index-only (detalle→producto), we'd need id_categoria mapping, but that would be worse. Keep.

Also note `producto (id_categoria, precio) WHERE activo` unused since query doesn't filter activo; if business allows only active products, adding `AND pr.activo AND c.activo` would enable that partial index and shrink the product hash, but changes semantics — mention as optional with caveat.

Good.

Let me write the final answer. Keep it detailed but tight. Use Spanish.

I'll add a brief "Alcance" note that I only read; no files modified. Maybe at the end.

Given the user asked a direct analytical question, I won't ask clarifying questions.

Word count: maybe 900-1200 words. Acceptable for a detailed answer.

Let me finalize.

Leí el prompt. Abajo está la respuesta completa (no modifiqué ningún archivo).

## Q1 · Facturación por categoría y mes

### Algoritmo elegido en cada combinación

| Combinación | Nodo del plan | Algoritmo | Lado build / probe |
|---|---|---|---|
| `pedido ⋈ detalle_pedido` | `Hash Join (Hash Cond: d.id_pedido = p.id_pedido)` | **Hash Join** | build = `Index Only Scan idx_pedido_fecha` (54.309 filas); probe = `Seq Scan detalle_pedido` (399.994 filas) |
| `(…) ⋈ producto` | `Hash Join (Hash Cond: d.id_producto = pr.id_producto)` | **Hash Join** | build = `Seq Scan producto` (50.010) |
| `(…) ⋈ categoria` | `Hash Join (Hash Cond: pr.id_categoria = c.id_categoria)` | **Hash Join** | build = `Seq Scan categoria` (5) |

No hay Nested Loop ni Merge Join en ningún nivel.

### Dónde se va el tiempo
- `Seq Scan detalle_pedido`: 3.334 buffers, 400k filas (26 ms) — se escanea la tabla entera aunque sólo interesan 108.616 líneas.
- La cadena de hash joins acumula ~256 ms.
- **El nodo caro es el `Sort` con `Sort Method: external merge Disk: 6328kB`** (temp read=791 / written=793), que existe sólo para alimentar el `GroupAggregate` con `COUNT(DISTINCT p.id_pedido)`: el `Sort Key` incluye `p.id_pedido` únicamente por el DISTINCT.
- El `Sort` final (35 filas, 27 kB) es despreciable.

### Propuestas

**R1 · Reescribir para eliminar el `COUNT(DISTINCT)`**
```sql
SELECT c.nombre AS categoria, l.mes,
       COUNT(*)       AS pedidos,
       SUM(l.importe) AS facturado
  FROM (
        SELECT d.id_pedido,
               date_trunc('month', p.fecha)::date AS mes,
               pr.id_categoria,
               SUM(d.cantidad * d.precio_unitario) AS importe
          FROM pedido p
          JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
          JOIN producto pr      ON pr.id_producto = d.id_producto
         WHERE p.fecha >= date_trunc('month', now()) - INTERVAL '6 months'
         GROUP BY d.id_pedido, date_trunc('month', p.fecha), pr.id_categoria
       ) l
  JOIN categoria c ON c.id_categoria = l.id_categoria
 GROUP BY c.nombre, l.mes
 ORDER BY l.mes, facturado DESC;
```
- **Nodo que ataca:** el `Sort` external merge y el `GroupAggregate` de arriba.
- **Por qué:** al pre-agregar a una fila por `(id_pedido, id_categoria, mes)`, `COUNT(*)` ya cuenta pedidos distintos (no hay duplicados de pedido dentro del mismo grupo) y el DISTINCT desaparece de la clave de orden. El `GroupAggregate` pasa a `HashAggregate` de 35 grupos; la clave de sort deja de incluir `p.id_pedido` y el payload baja.
- **Cuidado:** el `HashAggregate` interno maneja ~108k filas; con `work_mem` por defecto puede volver a derramar. Va acompañado de C1.

**I1 · Índice covering sobre `detalle_pedido`**
```sql
CREATE INDEX idx_detalle_pedido_cover
    ON detalle_pedido (id_pedido)
    INCLUDE (id_producto, cantidad, precio_unitario);
```
- **Nodo que ataca:** el `Seq Scan on detalle_pedido` y, por consecuencia, el `Hash Join (d.id_pedido = p.id_pedido)`.
- **Por qué esperás el cambio:** hoy el probe recorre las 3.334 páginas del heap de detalle. Con el índice se puede hacer `Nested Loop` con `Index Only Scan idx_pedido_fecha` (54.309 pedidos) como outer y `Index Only Scan idx_detalle_pedido_cover` como inner (~108k tuplas, ~2 por pedido, sin `Heap Fetches`). El `Hash` sobre pedido desaparece. El UNIQUE `(id_pedido, id_producto)` ya existe pero no cubre `cantidad`/`precio_unitario`, así que no permite index-only.
- **Condición para que el planner lo elija:** con `random_page_cost=4` va a seguir prefiriendo el Hash Join (estima ~54k probes aleatorios caros). Hay que bajarlo (C2). Además conviene que `id_pedido` correlacione con `fecha` (típico en datos generados en orden): ahí el rango de pedidos recientes es casi contiguo en el índice y el barrido es prácticamente secuencial sobre el ~27% del índice.

**C1 · `SET work_mem = '32MB'`**
- Ataca directamente el `Sort`/`HashAggregate`: los 6.328 kB hoy no entran en el `work_mem` por defecto (4 MB) y van a disco. Mitigación inmediata, sin cambiar semántica. Los 791/793 bloques temp desaparecen.

**C2 · `SET random_page_cost = 1.1;` (o 2) y `SET max_parallel_workers_per_gather = 0;`**
- El primero habilita el Nested Loop de I1 (la caché ya está caliente, como en la práctica anterior). El segundo mantiene el plan serial, coherente con que los workers paralelos medidos fueron más lentos.

**Qué NO tocar en Q1:** los hash joins con `producto` (50k, build 2,8 MB) y con `categoria` (5 filas) son correctos; reemplazarlos por NL implicaría 108k probes y sería peor. El `Index Only Scan idx_pedido_fecha` (272 buffers) ya es óptimo.

---

## Q2 · Ranking de clientes por gasto (90 días, top 20)

### Algoritmo elegido en cada combinación

| Combinación | Nodo del plan | Algoritmo | Lado build / probe |
|---|---|---|---|
| `pedido ⋈ detalle_pedido` | `Hash Join (Hash Cond: d.id_pedido = p.id_pedido)` | **Hash Join** | build = `Index Only Scan idx_pedido_fecha` (24.810); probe = `Seq Scan detalle_pedido` (399.994) |
| `(…) ⋈ cliente` | `Hash Join (Hash Cond: p.id_cliente = c.id_cliente)` | **Hash Join** | build = `Seq Scan cliente` (20.005) |

Tampoco hay Nested Loop ni Merge Join.

### Dónde se va el tiempo
- `Seq Scan detalle_pedido`: 3.334 buffers, 400k filas (23 ms) para quedarse con 49.623 líneas (12%).
- Hash joins: ~100 ms acumulados.
- `Sort` external merge de 3.168 kB (temp 396/397) por el `COUNT(DISTINCT p.id_pedido)` + `GroupAggregate` de 14.226 grupos.
- El `WindowAgg` con `Run Condition: rank() <= 20` ya corta en 21 filas: está bien y no hay que tocarlo.

### Propuestas

**R2 · Reescribir para eliminar el `COUNT(DISTINCT)`**
```sql
WITH gasto_pedido AS (
  SELECT p.id_cliente, p.id_pedido,
         SUM(d.cantidad * d.precio_unitario) AS importe
    FROM pedido p
    JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
   WHERE p.fecha >= now() - INTERVAL '90 days'
   GROUP BY p.id_cliente, p.id_pedido
)
SELECT puesto, id_cliente, cliente, pedidos, gastado
  FROM (
    SELECT c.id_cliente,
           c.nombre || ' ' || c.apellido AS cliente,
           COUNT(*)       AS pedidos,
           SUM(g.importe) AS gastado,
           RANK() OVER (ORDER BY SUM(g.importe) DESC) AS puesto
      FROM cliente c
      JOIN gasto_pedido g ON g.id_cliente = c.id_cliente
     GROUP BY c.id_cliente, c.nombre, c.apellido
  ) r
 WHERE puesto <= 20
 ORDER BY puesto, id_cliente;
```
- **Nodo que ataca:** el `Sort` external merge (`Sort Key: c.id_cliente, p.id_pedido`) bajo el `GroupAggregate`.
- **Por qué:** `gasto_pedido` devuelve una fila por pedido (24.810), así que `COUNT(*)` equivale al `COUNT(DISTINCT p.id_pedido)`. El segundo `GROUP BY` ya no necesita ordenar por `p.id_pedido` y puede resolverse con `HashAggregate` sobre 14.226 grupos en memoria (~1-2 MB); desaparece el spill de 3.168 kB.

**I2 · Mismo índice covering de I1**
- **Nodo que ataca:** `Seq Scan on detalle_pedido` → `Hash Join (d.id_pedido = p.id_pedido)`.
- **Por qué esperás el cambio:** sólo 24.810 pedidos (12%); con `Nested Loop` + `Index Only Scan idx_detalle_pedido_cover` se leen ~49.623 tuplas en vez de barrer 400k. El ahorro relativo es mayor que en Q1 (selectividad 12% vs 27%). Igual que I1, requiere C2 para que el optimizador no siga eligiendo el hash join con `random_page_cost=4`.

**C3 · `SET work_mem = '32MB'` y mantener el plan serial**
- Elimina el spill restante del `Sort` por `gastado` y del hash aggregate. El top-N ya está resuelto eficientemente por la `Run Condition`, así que no hace falta cambiar `RANK()` por `LIMIT`.

**Qué NO tocar en Q2:** el hash join con `cliente` (20k filas, build 1,5 MB) es correcto; un NL con el índice `pedido(id_cliente)` haría 20k probes. El `Index Only Scan idx_pedido_fecha` (126 buffers) ya es óptimo.

---

## Orden sugerido y verificación

1. `SET work_mem='32MB'; SET random_page_cost=1.1; SET max_parallel_workers_per_gather=0;` → medir de nuevo (mitigación barata).
2. Crear `idx_detalle_pedido_cover` → verificar que el `Hash Join (d.id_pedido = p.id_pedido)` se convierta en `Nested Loop` + `Index Only Scan` sobre detalle.
3. Aplicar R1/R2 → verificar que desaparezcan los `Sort Method: external merge Disk` y que el `GroupAggregate` pase a `HashAggregate`.
4. Re-ejecutar `EXPLAIN (ANALYZE, BUFFERS)` de ambas y comparar `Execution Time`, `Buffers` y que el resultado siga dando 35 y 20 filas respectivamente (validación de semántica).

Mejora esperada (estimación, no medida): Q1 de ~580 ms a ~250-350 ms; Q2 de ~170 ms a ~90-120 ms. El grueso vendrá de eliminar los sorts a disco y, si el planner acepta el NL, de dejar de barrer `detalle_pedido` completo.

---

