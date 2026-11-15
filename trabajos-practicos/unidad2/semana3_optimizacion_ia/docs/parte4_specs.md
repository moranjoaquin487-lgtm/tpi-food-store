# Parte 4 · Especificaciones precisas

Las dos specs fijan tablas, filtro de borrado lógico, columnas de salida, orden y corte. A partir de cada spec, Claude generó dos versiones con distinta estructura, sin ver una solución previa (`sql/parte4_consultas.sql`). La equivalencia se comprueba con `EXCEPT` en los dos sentidos.

Borrado lógico en este esquema: `categoria.activo` y `producto.activo`. `cliente`, `pedido` y `detalle_pedido` no tienen borrado lógico.

## Spec 1 · Consulta de resumen (agregación)

- **Pregunta:** cómo está cada categoría vigente en catálogo y en ventas recientes.
- **Tablas:** `categoria`, `producto`, `pedido`, `detalle_pedido`.
- **Filtro de borrado lógico:** solo categorías con `activo = TRUE`; solo productos con `activo = TRUE`, tanto para contar y promediar como para sumar unidades vendidas.
- **Período:** las unidades vendidas cuentan solo líneas de pedidos con `fecha >= now() - INTERVAL '90 days'`.
- **Columnas de salida, en este orden:**
  1. `categoria`: nombre de la categoría.
  2. `productos_vigentes`: cantidad de productos vigentes de la categoría; 0 si no tiene.
  3. `precio_promedio`: promedio de `precio` de esos productos, redondeado a 2 decimales; `NULL` si no tiene productos vigentes.
  4. `unidades_90_dias`: suma de `cantidad` vendida de esos productos en el período; 0 si no vendió.
- **Incluir** las categorías vigentes sin productos vigentes o sin ventas en el período.
- **Orden:** `unidades_90_dias` descendente y, a igualdad, `categoria` ascendente.
- **Corte:** ninguno. **Prohibido** `SELECT *`.
- **Cuidado pedido explícitamente:** no multiplicar filas al unir productos con sus ventas antes de contar productos (fan-out del join).

## Spec 2 · Consulta con subconsulta

- **Pregunta:** qué clientes gastan bastante más que el cliente promedio.
- **Tablas:** `cliente`, `pedido`, `detalle_pedido`.
- **Gasto de un cliente:** suma de `cantidad * precio_unitario` de todas las líneas de todos sus pedidos.
- **Promedio de referencia:** promedio del gasto entre los clientes que tienen al menos un pedido con líneas, calculado con una subconsulta.
- **Filtro:** clientes cuyo gasto supera en más de un 50 % ese promedio (`gasto > 1.5 * promedio`).
- **Columnas de salida, en este orden:** `id_cliente`, `nombre`, `apellido`, `pedidos` (pedidos distintos del cliente), `gasto_total` (redondeado a 2 decimales).
- **Orden:** `gasto_total` descendente y, a igualdad, `id_cliente` ascendente, para que el corte sea determinista.
- **Corte:** `LIMIT 15`.

## Versiones generadas

| Spec | Versión A | Versión B |
|---|---|---|
| 1 | Agregaciones previas en CTE (`prod`, `vendidas`) y `LEFT JOIN` desde `categoria` | Subconsultas escalares correlacionadas, una por columna |
| 2 | `GROUP BY` con la subconsulta del promedio en el `HAVING` | CTE con el gasto por cliente y el promedio con `AVG() OVER ()` |
