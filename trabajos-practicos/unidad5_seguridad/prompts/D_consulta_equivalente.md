# Prompt para OpenCode — Parte D.2: consulta equivalente

Abrí OpenCode en `trabajos-practicos/unidad5_seguridad` y pegá:

```
En PostgreSQL 16 tengo la tabla usuario_anon (id_anon, nombre, apellido, mail, rol,
eliminado, mes_alta DATE) y la tabla real usuario (id, nombre, apellido, mail, celular,
contrasena, rol, eliminado, created_at TIMESTAMPTZ).
1. Escribí una consulta sobre usuario_anon que devuelva la cantidad de usuarios por rol y
   por mes de alta, con el mes en formato YYYY-MM, ordenada por rol y mes.
2. Escribí la consulta equivalente sobre usuario, que tiene que devolver exactamente los
   mismos grupos y conteos.
No ejecutes nada.
```

Guardá la respuesta en `docs/respuestas_ia/D_consultas.md`. Compará las dos consultas de OpenCode con las de `sql/equivalencia_agregados.sql`:
- La consulta sobre `usuario` tiene que truncar `created_at` al mes. Si agrupa por `created_at` sin truncar, no coincide.
- Si agrega `WHERE NOT eliminado` en una sola de las dos, tampoco coincide.

Corré las dos consultas de OpenCode y anotá en la bitácora si dieron lo mismo que las de referencia.
