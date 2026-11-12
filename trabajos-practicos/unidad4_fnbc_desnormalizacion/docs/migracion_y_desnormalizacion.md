# Migración reversible y desnormalización controlada

## 1. Migración a BCNF

### Cómo se ejecuta

`sql/03_migracion_fnbc.sql` hace todo dentro de **una sola transacción**. Termina con `COMMIT` o con `ROLLBACK` según la variable `accion`:

| Paso | Qué hace | Si falla |
|---|---|---|
| 0 | Comprueba que exista la tabla heredada y que la DF2 se cumpla en los datos | Aborta antes de tocar nada |
| 1–2 | Crea `responsable_deposito` y `control_lote` con sus claves e índices | Aborta |
| 3 | Copia los datos con `INSERT … SELECT` | Aborta |
| 4 | Renombra la tabla original a `control_lote_almacen_respaldo` y crea la vista `v_control_lote_almacen` | Aborta |
| 5 | Crea el trigger que protege la DF1 | Aborta |
| 6 | Compara la reunión con la tabla original (`EXCEPT` en los dos sentidos) | `RAISE EXCEPTION`: se deshace todo |

### Ensayo antes de aplicar

1. **Ensayo:** se corre sin variables. Todo se ejecuta, se verifica y termina en `ROLLBACK`. El estado final muestra que la tabla heredada sigue intacta y que las nuevas no existen.
2. **Aplicación:** se corre con `-v accion=COMMIT`.
3. **Ensayo de la reversión:** `04_reversion_fnbc.sql` sin variables. Prueba que el plan de vuelta funciona, sin aplicarlo.

### Plan de reversión

`sql/04_reversion_fnbc.sql`, con `-v accion=COMMIT`, revierte la migración:

- Recrea `control_lote_almacen` con su PK desde la **reunión actual**, no desde el respaldo, para no perder lo que cambió después de migrar.
- Los responsables sin lotes no entran en la tabla heredada (es la anomalía de inserción). Se guardan en `reversion_responsables_sin_lote` para no perderlos.
- Verifica que la cantidad de filas coincida y, si no coincide, aborta.
- Quita la vista, las tablas nuevas, el trigger y el respaldo viejo.

**Cuándo revertir:** si una consulta o un proceso que leía la tabla heredada falla con el esquema nuevo y no se puede adaptar a tiempo. La vista `v_control_lote_almacen` cubre las lecturas, pero no las escrituras.

**Cuándo borrar el respaldo:** `control_lote_almacen_respaldo` se conserva hasta confirmar que ningún proceso escribe en la tabla vieja. Después se elimina con `DROP TABLE`. Mientras exista, sirve como punto de comparación.

## 2. Desnormalización controlada

### Cuándo y por qué

| | |
|---|---|
| **Consulta** | Top 5 de categorías por facturación, para el tablero de ventas |
| **Problema** | Normalizada, recorre todo `detalle_pedido` (≈ 400.000 líneas) y lo une con `producto` y `categoria` cada vez que se abre el tablero |
| **Patrón de uso** | Se lee muchas veces por día; las ventas nuevas llegan de a pocas líneas |
| **Decisión** | Tabla `resumen_ventas_categoria`, con una fila por categoría y sus totales ya calculados |
| **Qué NO se desnormalizó** | Los precios y las cantidades de cada venta siguen solo en `detalle_pedido`, que es la fuente de verdad. El resumen se puede reconstruir desde ahí en cualquier momento |

### Salvaguardas

1. **Misma transacción.** Tres triggers por sentencia sobre `detalle_pedido` (`INSERT`, `UPDATE` y `DELETE`, con tablas de transición) y uno sobre `producto`, por si cambia de categoría. Si la venta se deshace, la actualización del resumen se deshace con ella.
2. **Verificación.** `fn_verificar_resumen_categoria()` devuelve las categorías cuyo resumen no coincide con el cálculo real. Vacía significa consistente. Es una tarea del plan de mantenimiento de la U6.
3. **Reparación.** `CALL sp_recalcular_resumen_categoria()` reconstruye el resumen completo bajo un candado.
4. **Restricciones.** `CHECK (unidades >= 0)` y `CHECK (facturacion >= 0)`.
5. **Acceso.** Los reportes leen la vista `v_top5_categorias`. Solo los triggers escriben en la tabla.
6. **Reversión.** `sql/09_reversion_desnormalizacion.sql` quita todo y los reportes vuelven a la consulta normalizada.

### Costo aceptado

- **En las escrituras:** cada `INSERT` en `detalle_pedido` paga una actualización del resumen. Ver la medición en `evidencias/08_mediciones.txt`.
- **En la concurrencia:** dos ventas simultáneas de la misma categoría esperan una a la otra en la fila del resumen. Es aceptable porque son 5 filas y la actualización es corta. Con mucho volumen de ventas, convendría una vista materializada refrescada cada cierto tiempo, a cambio de leer datos un poco atrasados.

### Error encontrado en las pruebas

La primera versión de `fn_resumen_aplicar` usaba un único `INSERT … ON CONFLICT DO UPDATE`. Al borrar un pedido, la variación negativa hacía fallar el `CHECK (facturacion >= 0)`: PostgreSQL controla los `CHECK` sobre la fila propuesta antes de detectar el conflicto. Se corrigió en dos pasos: primero `UPDATE` de las categorías existentes y después `INSERT` de las nuevas. La prueba `07_pruebas_desnormalizacion.sql` cubre el caso del `DELETE` en cascada.

### Mediciones

Salida completa en `evidencias/08_mediciones.txt`.

| Medición | Normalizada | Con resumen |
|---|---|---|
| Top 5 categorías (`Execution Time`) | 304,774 ms | 0,120 ms |
| Insertar 1000 líneas de detalle | 44,530 ms sin el trigger | 62,855 ms con el trigger (el trigger del resumen, `trg_resumen_detalle_ins`, tarda 14,599 ms) |
| Mismo resultado en los dos caminos | — | 0 diferencias |
