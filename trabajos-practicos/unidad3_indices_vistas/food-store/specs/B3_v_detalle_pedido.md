# spec: B3 · Vista `v_detalle_pedido`

Objetivo: ofrecer una vista que enriquezca cada línea de `detalle_pedido` con el nombre del producto y el subtotal calculado, eliminando el JOIN y el cálculo repetido en cada consulta que muestre el contenido de un pedido.

Consulta afectada:
```sql
-- Consulta equivalente que la vista debe replicar exactamente:
SELECT dp.id_pedido,
       dp.id_detalle,
       dp.id_producto,
       pr.nombre                          AS producto,
       dp.cantidad,
       dp.precio_unitario,
       dp.cantidad * dp.precio_unitario   AS subtotal
FROM detalle_pedido dp
JOIN producto pr ON pr.id_producto = dp.id_producto;
```

Frecuencia: cada vez que se abre o imprime un pedido; varias veces por día.

Columnas a exponer (en orden):

| # | Columna | Origen | Alias |
|---|---|---|---|
| 1 | `id_pedido` | `detalle_pedido.id_pedido` | — |
| 2 | `id_detalle` | `detalle_pedido.id_detalle` | — |
| 3 | `id_producto` | `detalle_pedido.id_producto` | — |
| 4 | `producto` | `producto.nombre` | `producto` |
| 5 | `cantidad` | `detalle_pedido.cantidad` | — |
| 6 | `precio_unitario` | `detalle_pedido.precio_unitario` | — |
| 7 | `subtotal` | `detalle_pedido.cantidad * detalle_pedido.precio_unitario` | `subtotal` |

Filtro de vigencia: ninguno. Un producto dado de baja (`activo = FALSE`) debe seguir apareciendo en los pedidos históricos que lo incluyeron; filtrar por `producto.activo` haría desaparecer esas líneas y rompería la integridad del historial. El JOIN se hace sin condición sobre `activo`.

Columnas ocultas:

| Columna | Razón |
|---|---|
| `producto.activo` | No relevante para el detalle de un pedido; el estado actual del producto no afecta a lo que se vendió. |
| `producto.descripcion` | Texto libre; no se necesita en la vista del pedido. |
| `producto.precio` | El precio actual del producto puede diferir del `precio_unitario` registrado en el detalle; exponerlo generaría confusión. |
| `producto.stock` | Dato operativo del catálogo; no forma parte del contenido de un pedido. |
| `producto.id_categoria` | No es necesario en el contexto de la vista del detalle; se puede obtener uniendo con `producto` si se requiere. |
| `producto.created_at` | Metadato de auditoría. |

Criterio de aceptación: ejecutar la consulta equivalente directa y la misma consulta sobre la vista; hacer `EXCEPT` en ambos sentidos. Ambos `EXCEPT` deben devolver 0 filas, confirmando que el resultado es idéntico.

```sql
-- Verificación:
(SELECT id_pedido, id_detalle, id_producto, producto, cantidad, precio_unitario, subtotal
   FROM v_detalle_pedido)
EXCEPT
(SELECT dp.id_pedido, dp.id_detalle, dp.id_producto, pr.nombre,
        dp.cantidad, dp.precio_unitario, dp.cantidad * dp.precio_unitario
   FROM detalle_pedido dp JOIN producto pr ON pr.id_producto = dp.id_producto);

(SELECT dp.id_pedido, dp.id_detalle, dp.id_producto, pr.nombre,
        dp.cantidad, dp.precio_unitario, dp.cantidad * dp.precio_unitario
   FROM detalle_pedido dp JOIN producto pr ON pr.id_producto = dp.id_producto)
EXCEPT
(SELECT id_pedido, id_detalle, id_producto, producto, cantidad, precio_unitario, subtotal
   FROM v_detalle_pedido);
```

Ambas consultas deben retornar 0 filas.
