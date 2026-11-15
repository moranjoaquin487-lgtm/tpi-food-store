-- Parte 1 · Cambios de configuración que propuso OpenCode (C1, C2 y C3), con el mismo índice.
-- work_mem: memoria para ordenar y agrupar sin ir a disco (por defecto 4 MB).
-- random_page_cost: costo que el planner asigna a cada acceso aleatorio (por defecto 4; 1.1 es el valor
-- recomendado para SSD, como se midió en la Semana 3).
-- max_parallel_workers_per_gather = 0: plan sin workers paralelos, que en esta PC tardaron más.
-- Todo vale solo para esta sesión: no queda guardado en la base ni en el servidor.
SET work_mem = '32MB';
SET random_page_cost = 1.1;
SET max_parallel_workers_per_gather = 0;
SHOW work_mem;
\ir parte1_despues.sql
