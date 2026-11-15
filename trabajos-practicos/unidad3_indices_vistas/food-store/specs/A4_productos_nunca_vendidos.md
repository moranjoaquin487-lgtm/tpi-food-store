# spec: A4 · Productos vigentes nunca vendidos

Objetivo: acelerar la consulta de revisión del catálogo que identifica todos los productos activos que no tienen ningún registro en `detalle_pedido`, para detectar productos sin movimiento.

Consulta afectada:
```sql
SELECT id_producto, nombre, precio, stock
FROM producto
WHERE activo = TRUE
  AND NOT EXISTS (SELECT 1 FROM detalle_pedido WHERE id_producto = producto.id_producto)
ORDER BY nombre;
```

Frecuencia: revisión del catálogo; aproximadamente una vez por semana.

Columnas candidatas:

| Columna | Rol en la consulta | Selectividad |
|---|---|---|
| `producto.activo` | filtro booleano (`= TRUE`) | baja: casi todos los productos son activos (50 009 de 50 010 con `activo = TRUE`, según el plan) |
| `producto.id_producto` | correlación del `NOT EXISTS` | PK, ya indexada |
| `detalle_pedido.id_producto` | clave de la subconsulta correlacionada | ya indexada (`idx_detalle_pedido_id_producto`) |
| `producto.nombre` | `ORDER BY` final | baja selectividad para filtrado; relevante para un `Index Only Scan` si el índice lo incluye |

El plan actual usa un `Hash Right Anti Join`: construye un hash de todos los `id_producto` de `detalle_pedido` (Seq Scan, 399 994 filas) y luego lo cruza con todos los productos activos (Seq Scan on `producto`, 50 009 filas). El `idx_detalle_pedido_id_producto` no está siendo aprovechado porque el planner elige el hash como estrategia más barata para un anti-join masivo.

Una posibilidad de mejora es un índice compuesto `(nombre, id_producto) WHERE activo = TRUE` que permita un `Index Only Scan` sobre `producto` y, combinado con el índice existente en `detalle_pedido.id_producto`, habilite una estrategia de `Nested Loop Anti Join` para los productos sin ventas. Sin embargo, dado que casi todos los productos son activos (selectividad del filtro `activo = TRUE` ≈ 99.998 %), el planner puede preferir seguir con el hash. El criterio de aceptación determinará si el índice es efectivo.

Plan actual (mediana de 3 ejecuciones — `evidencias/parteA_antes.txt`):
```
Sort (Sort Key: nombre, quicksort)
  Hash Right Anti Join (Hash Cond: detalle_pedido.id_producto = producto.id_producto)
    Seq Scan on detalle_pedido  — 399 994 filas leídas  (3 334 buffers)
    Hash
      Seq Scan on producto      — 50 009 filas leídas  (516 buffers)
        Filter: activo
        Rows Removed by Filter: 1
      actual time ≈ 89.943 ms (ejecución total)
```

Criterio de aceptación: el plan reemplaza al menos uno de los `Seq Scan` (el de `producto` o el de `detalle_pedido`) por un `Index Scan`, `Index Only Scan` o `Bitmap Heap Scan` usando el nuevo índice, **y** la mediana de 3 ejecuciones baja a ≤ 44 ms (menos de la mitad de 89.943 ms). Si alguna de las dos condiciones no se cumple, el índice se rechaza. El nuevo índice no puede repetir la cobertura del índice existente `idx_detalle_pedido_id_producto` ni de `idx_producto_categoria_activo`.
