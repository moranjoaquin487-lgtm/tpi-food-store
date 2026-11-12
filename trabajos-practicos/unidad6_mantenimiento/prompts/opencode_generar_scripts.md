# Prompt para OpenCode — Unidad 6

OpenCode genera su versión de los scripts a partir de `SPEC_U6.md` y `AGENTS.md`. Después se la compara con los scripts de referencia de esta carpeta, que ya están revisados y probados.

1. Abrí OpenCode en `trabajos-practicos/unidad6_mantenimiento` y pegá:

```
Leé SPEC_U6.md y AGENTS.md. Generá en la carpeta opencode/ los archivos
backup_foodstore.sh, health_check.sql, maintenance.sql y restore_test.sh que cumplan la
especificación. No ejecutes ningún comando contra la base.
```

2. **Sin ejecutar nada**, compará cada archivo con el de referencia:
   `diff opencode/backup_foodstore.sh backup_foodstore.sh` (y lo mismo con los otros).
3. Revisá en especial:
   - ¿Escribió alguna contraseña o un `PGPASSWORD=` fijo?
   - ¿Usa `VACUUM FULL`, o un `VACUUM` sin observar antes las tablas?
   - ¿`restore_test.sh` podría restaurar sobre `foodstore`?
   - ¿El script de respaldo sale con error si falla `pg_dump`?
   - ¿El cronómetro arranca justo antes de `createdb`, como pide la consigna?
4. Anotá en `evidencias/revision_opencode.md` qué propuso, qué aceptaste (y lo pasaste al script de referencia) y qué descartaste, con el motivo.
