# spec: C1 · Vista materializada `mv_facturacion_categoria_mes`

Objetivo: pre-calcular la facturación por categoría y mes para que los reportes gerenciales se sirvan desde datos ya agregados en lugar de recalcular el join de cuatro tablas en cada consulta. La gerencia tolera datos hasta el cierre del día anterior; la vista se refresca una vez por día.

Consulta base (consulta 7.4 de `queries.sql`):
```sql
SELECT c.nombre AS categoria,
       DATE_TRUNC('month', pe.fecha) AS mes,
       COUNT(DISTINCT pe.id_pedido) AS cantidad_pedidos,
       SUM(dp.cantidad * dp.precio_unitario) AS facturacion_total
FROM categoria c
JOIN producto p        ON p.id_categoria = c.id_categoria
JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
JOIN pedido pe         ON pe.id_pedido = dp.id_pedido
WHERE c.activo = TRUE AND p.activo = TRUE
GROUP BY c.id_categoria, c.nombre, DATE_TRUNC('month', pe.fecha)
ORDER BY mes, facturacion_total DESC;
```

Frecuencia: la gerencia consulta el reporte varias veces por día. Con la vista materializada, cada consulta sobre ella es un simple `SELECT` sobre una tabla pre-calculada de pocas filas (5 categorías × ~24 meses ≈ 120 filas), en lugar de agregar ~400 000 filas de `detalle_pedido`.

Columnas de la vista materializada (en orden):

| # | Columna | Origen | Tipo |
|---|---|---|---|
| 1 | `id_categoria` | `categoria.id_categoria` | `BIGINT` |
| 2 | `categoria` | `categoria.nombre` | `VARCHAR` |
| 3 | `mes` | `DATE_TRUNC('month', pedido.fecha)` | `TIMESTAMPTZ` |
| 4 | `cantidad_pedidos` | `COUNT(DISTINCT pedido.id_pedido)` | `BIGINT` |
| 5 | `facturacion_total` | `SUM(detalle_pedido.cantidad * detalle_pedido.precio_unitario)` | `NUMERIC` |

Nota sobre `id_categoria`: la consulta 7.4 no incluye `id_categoria` en el `SELECT`, pero la spec pide que figure en la vista materializada (es necesario para el índice único que permite el `REFRESH CONCURRENTLY`). Se agrega al `SELECT` y al `GROUP BY`.

Índice requerido: un índice único sobre `(id_categoria, mes)` para permitir `REFRESH MATERIALIZED VIEW CONCURRENTLY`. Sin un índice único, PostgreSQL no puede hacer el refresh concurrente.

```sql
-- Índice a crear después de la vista:
CREATE UNIQUE INDEX ON mv_facturacion_categoria_mes (id_categoria, mes);
```

Opciones de creación:
- `WITH DATA`: la vista se puebla inmediatamente al crearla.
- `REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes`: permite refrescar sin bloquear lecturas (requiere el índice único).

Estrategia de refresco: una vez por día, en horario de baja carga (por ejemplo, a las 00:30), ejecutar `REFRESH MATERIALIZED VIEW CONCURRENTLY mv_facturacion_categoria_mes`. Los datos expuestos durante el día corresponderán al cierre del día anterior, lo que es aceptable para el uso gerencial.

Criterio de aceptación (dos partes):

**1. Equivalencia de datos:** el resultado de consultar la vista materializada debe ser idéntico al de ejecutar la consulta original en el mismo momento.

```sql
-- Verificación de equivalencia (tras un REFRESH):
(SELECT id_categoria, categoria, mes, cantidad_pedidos, facturacion_total
   FROM mv_facturacion_categoria_mes)
EXCEPT
(SELECT c.id_categoria, c.nombre, DATE_TRUNC('month', pe.fecha),
        COUNT(DISTINCT pe.id_pedido), SUM(dp.cantidad * dp.precio_unitario)
   FROM categoria c
   JOIN producto p        ON p.id_categoria = c.id_categoria
   JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
   JOIN pedido pe         ON pe.id_pedido = dp.id_pedido
  WHERE c.activo = TRUE AND p.activo = TRUE
  GROUP BY c.id_categoria, c.nombre, DATE_TRUNC('month', pe.fecha));

-- Y el EXCEPT en el sentido inverso.
```

Ambos `EXCEPT` deben retornar 0 filas.

**2. Rendimiento:** la consulta del reporte gerencial sobre la vista materializada debe tardar significativamente menos que la consulta original sobre las tablas base. Con ~120 filas pre-calculadas, se espera un tiempo de respuesta por debajo de 5 ms, frente a los ~130-175 ms de la consulta base (medidos en `evidencias/parteA_antes.txt` para consultas similares de cuatro tablas).
