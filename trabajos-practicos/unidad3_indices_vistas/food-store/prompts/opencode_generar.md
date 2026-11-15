# Prompt para OpenCode: generar el SQL a partir de las specs de Kiro

Sos el agente de codificación de este trabajo. Leé las specs de la carpeta `specs/` (escritas en Kiro), `schema.sql` y los planes medidos en `evidencias/parteA_antes.txt`. No leas otros archivos del repositorio.

Generá estos tres archivos en la carpeta `propuestas/`, **sin ejecutar nada contra la base**:

1. `propuestas/indices_opencode.sql`: para cada spec de la Parte A (`specs/A*.md`), el índice que proponés (tipo, columnas y orden en un índice compuesto, `INCLUDE` o condición de índice parcial si corresponde). Antes de cada `CREATE INDEX`, un comentario con: la spec que atiende, el nodo del plan actual que ataca y por qué esperás que el plan cambie. Si para alguna consulta creés que no conviene ningún índice, o que alcanza con uno que ya existe, decilo en un comentario y no lo crees.
2. `propuestas/views_opencode.sql`: las vistas de las specs de la Parte B (`specs/B*.md`), con las columnas en el orden de la spec, más el rol `rol_reportes` y los `GRANT`/`REVOKE` que pide `specs/B4_v_usuario_publico.md`. Creá el rol solo si no existe.
3. `propuestas/materializada_opencode.sql`: la vista materializada de `specs/C1_mv_facturacion_categoria_mes.md`, con `WITH DATA`, su índice único y la sentencia de `REFRESH MATERIALIZED VIEW CONCURRENTLY`.

Reglas: no modifiques `schema.sql` ni ningún otro archivo; solo creá esos tres. Usá `CREATE INDEX`, `CREATE OR REPLACE VIEW` y `CREATE MATERIALIZED VIEW` sin `IF NOT EXISTS` en los índices. Al terminar, resumí en la respuesta qué propusiste para cada spec.
