# Parte 3 · Especificaciones precisas

A partir de cada spec, Claude generó dos versiones con distinta estructura, sin ver una solución previa (`sql/parte3_consultas.sql`). La equivalencia se comprueba con `EXCEPT` en los dos sentidos.

Borrado lógico en este esquema: `categoria.activo` y `producto.activo`. `cliente`, `pedido` y `detalle_pedido` no tienen borrado lógico, así que no llevan filtro.

## Spec A · Ranking con función de ventana

- **Pregunta:** cuáles son los productos más vendidos de cada categoría en los últimos 90 días.
- **Tablas y borrado lógico:** `categoria` (solo `activo = TRUE`, aplicado en el `JOIN`), `producto` (solo `activo = TRUE`), `detalle_pedido` y `pedido` (sin borrado lógico).
- **Período:** líneas de pedidos con `fecha >= now() - INTERVAL '90 days'`.
- **Medida:** `unidades` = suma de `cantidad`. Los productos sin ventas en el período no participan.
- **Ranking:** `puesto` dentro de cada categoría (partición por categoría), de mayor a menor `unidades`. **Desempate:** los empates comparten puesto y el siguiente puesto no salta (`DENSE_RANK`).
- **Corte:** solo los puestos 1 a 3 de cada categoría (puede haber más de 3 filas por categoría si hay empates).
- **Columnas de salida, en este orden:** `categoria` (nombre), `puesto`, `id_producto`, `producto` (nombre), `unidades`.
- **Orden de presentación:** `categoria`, `puesto`, `id_producto`. Sin `SELECT *`.

## Spec B · Consulta con subconsulta correlacionada

- **Pregunta:** qué clientes dejaron de comprar.
- **Tablas y borrado lógico:** `cliente` y `pedido` (ninguna tiene borrado lógico).
- **Condición:** clientes con al menos un pedido, cuyo último pedido (`MAX(fecha)`) es anterior a `now() - INTERVAL '60 days'`.
- **Columnas de salida, en este orden:** `id_cliente`, `cliente` (`nombre || ' ' || apellido`), `ultima_compra` (fecha del último pedido, como `date`), `pedidos` (cantidad total de pedidos del cliente).
- **Orden:** `ultima_compra` ascendente y, a igualdad, `id_cliente` ascendente, para que el corte sea determinista.
- **Corte:** `LIMIT 20`.

## Versiones generadas

| Spec | Versión 1 | Versión 2 |
|---|---|---|
| A | CTE de ventas y `DENSE_RANK() OVER (PARTITION BY id_categoria ORDER BY unidades DESC)` | Puesto calculado con una subconsulta correlacionada: 1 + cantidad de valores distintos de `unidades` mayores dentro de la categoría, contados sobre los niveles distintos de cada categoría |
| B | Subconsultas correlacionadas en el `SELECT` y en el `WHERE`, con `EXISTS` | `JOIN` + `GROUP BY` + `HAVING MAX(fecha) < …` |

## Corrección de la versión A2

La primera A2 calculaba el puesto de cada producto comparándolo con todos los productos vendidos de su categoría (`COUNT(DISTINCT v2.unidades)` sobre el CTE completo). Con unos 26 000 productos vendidos en 90 días eso son cientos de millones de comparaciones: tardó cerca de 2 minutos en la prueba previa y en la PC del TP hubo que cancelarla. Como en cada categoría hay pocas decenas de valores distintos de `unidades`, la versión final calcula el puesto sobre esos niveles y después une cada producto con el puesto de su nivel. El resultado es el mismo y la subconsulta sigue siendo correlacionada.
