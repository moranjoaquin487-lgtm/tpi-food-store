-- Parte 2 · Comprobación: mismos índices y random_page_cost por defecto, pero sin procesos paralelos.
-- En los planes DESPUÉS de Q1 y Q2, los procesos paralelos terminan su parte a los ~31 ms, pero el Gather
-- recién entrega filas a los ~114 ms. Si esa espera es el arranque y la coordinación de los workers,
-- sin paralelismo las mismas consultas tienen que tardar cerca de lo que tardan sus nodos.
-- Se cambia solo para esta sesión: no queda guardado en la base ni en el servidor.
SET max_parallel_workers_per_gather = 0;
SHOW max_parallel_workers_per_gather;
\ir parte2_despues.sql
