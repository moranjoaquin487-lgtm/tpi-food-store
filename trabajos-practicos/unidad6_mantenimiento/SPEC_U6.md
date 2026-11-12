# SPEC_U6 — Plan de mantenimiento de Food Store

**Base principal:** `foodstore`, en PostgreSQL 16+. **Base de restauración:** `foodstore_restore_test`. **Objetivos:** RPO ≤ 24 h y RTO ≤ 15 min.

## Tareas

| Tarea | Script | Frecuencia | Termina bien si… |
|---|---|---|---|
| Respaldo | `backup_foodstore.sh` | Diaria, 02:00 (tarea programada) | Sale con código 0, existe `backups/foodstore_AAAAMMDD_HHMMSS.dump`, `pg_restore --list` lo lee sin error y `logs/backup.log` tiene la línea `OK` |
| Chequeo de salud | `health_check.sql` | Diaria, después del respaldo | Corre sin errores y deja la salida en `logs/` |
| Revisión de mantenimiento | `maintenance.sql` | Semanal, domingos | Muestra tuplas muertas, autovacuum y estadísticas. Solo aplica `VACUUM (ANALYZE)` o `ANALYZE` a las tablas que cumplen el criterio observado. La verificación de integridad (`amcheck` y el resumen de la U4) da 0 problemas |
| Restauración de prueba | `restore_test.sh` | Semanal, después del respaldo del domingo | `foodstore_restore_test` queda con las mismas filas que se contaron antes del respaldo, y 0 productos y 0 detalles inválidos. Registra RTO y RPO |

## Reglas de seguridad

1. **Ninguna contraseña en los scripts ni en el repositorio.** La autenticación sale de `pgpass.conf` (`%APPDATA%\postgresql\pgpass.conf` en Windows), que está fuera del repositorio.
2. `backups/` y `logs/` están en `.gitignore`: los `.dump` no se suben.
3. **La restauración solo apunta a `foodstore_restore_test`.** `restore_test.sh` se niega a correr si el destino es `foodstore`. La base principal nunca se borra ni se reemplaza.
4. **Respaldo en formato custom** (`-Fc`), para restaurar con `pg_restore`.
5. **Sin `VACUUM FULL` periódico.** Bloquea la tabla entera y reescribe todo. El mantenimiento usa `VACUUM (ANALYZE)` común, solo cuando la observación previa lo justifica.
6. **Revisión antes de ejecutar.** Todo script generado o modificado con OpenCode se lee y se prueba manualmente antes de programarlo.

## Criterio de mantenimiento (`maintenance.sql`)

| Acción | Cuándo se aplica |
|---|---|
| `VACUUM (ANALYZE)` | Tablas con más de 1000 tuplas muertas y más del 10 % de tuplas muertas sobre vivas. Es el umbral por defecto de autovacuum (`autovacuum_vacuum_scale_factor = 0.2`) a la mitad: se adelanta un poco a autovacuum |
| `ANALYZE` | Tablas con más filas modificadas desde el último análisis que el 10 % de sus filas vivas, y más de 50. Es el mismo piso que usa autovacuum (`autovacuum_analyze_threshold = 50`): evita analizar tablas chicas por cada cambio |
| Ninguna | Si ninguna tabla cumple el criterio. Que no haga nada también es un resultado válido |

## Programación

**Windows**, una sola vez, en cmd y desde esta carpeta:

```
programar_respaldo.cmd
```

Crea la tarea `FoodStore\Respaldo` (diaria, 02:00), la deja correr aunque la notebook esté a batería o, si la PC estaba apagada, apenas se prenda, y la ejecuta una vez para probarla. La tarea llama a `respaldo_tarea.cmd`, que corre `backup_foodstore.sh` con Git Bash y guarda la salida en `logs/tarea_programada.log`.

La primera versión de esta sección era una sola línea de `schtasks` con comillas simples dentro de `/TR`. En la prueba no funcionó: Windows no reconoce las comillas simples y, además, no inicia tareas programadas a batería.

**Linux**, con cron: `0 2 * * * cd /ruta/unidad6_mantenimiento && ./backup_foodstore.sh`.
