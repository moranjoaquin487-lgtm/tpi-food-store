# spec: A3 · Top 10 productos que más facturaron en los últimos 30 días

Objetivo: acelerar el reporte de compras y reposición que agrega facturación por producto filtrando pedidos de los últimos 30 días, uniendo cuatro tablas y devolviendo los 10 primeros.

Consulta afectada:
```sql
SELECT pr.id_producto, pr.nombre AS producto, c.nombre AS categoria,
       SUM(d.cantidad) AS unidades, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM detalle_pedido d
  JOIN pedido p ON p.id_pedido = d.id_pedido
  JOIN producto pr ON pr.id_producto = d.id_producto
  JOIN categoria c ON c.id_categoria = pr.id_categoria
 WHERE p.fecha >= now() - INTERVAL '30 days'
 GROUP BY pr.id_producto, pr.nombre, c.nombre
 ORDER BY facturado DESC, pr.id_producto
 LIMIT 10;
```

Frecuencia: reporte de compras y reposición; varias veces por día.

Columnas candidatas:

| Columna | Rol en la consulta | Selectividad |
|---|---|---|
| `pedido.fecha` | filtro de rango (`>= now() - 30 days`) | alta: ~4 % de las filas (≈ 8 369 de 200 005) |
| `pedido.id_pedido` | clave del JOIN con `detalle_pedido` | PK, ya indexada |
| `detalle_pedido.id_pedido` | clave del JOIN con `pedido` | ya indexada (UNIQUE `(id_pedido, id_producto)`) |
| `detalle_pedido.id_producto` | clave del JOIN con `producto` | ya indexada (`idx_detalle_pedido_id_producto`) |
| `producto.id_categoria` | clave del JOIN con `categoria` | ya indexada (`idx_producto_categoria_activo`, parcial WHERE activo = TRUE) |
| `producto.id_producto` | clave del JOIN y del `GROUP BY` | PK, ya indexada |
| `categoria.id_categoria` | clave del JOIN | PK, ya indexada |

El cuello de botella es el `Parallel Seq Scan on pedido` que lee las 200 005 filas y descarta 191 636 por el filtro de fecha. El `Seq Scan on producto` (50 010 filas, 1 548 buffers) y el `Seq Scan on categoria` (5 filas) son baratos en comparación. Un índice sobre `pedido.fecha` permite al planner acortar la búsqueda de pedidos del período y reducir el hash que alimenta el join con `detalle_pedido`.

Nota: las columnas de join en `detalle_pedido` y `producto` ya están cubiertas por índices existentes; el único gap es el filtro de fecha en `pedido`.

Plan actual (mediana de 3 ejecuciones — `evidencias/parteA_antes.txt`):
```
Limit (10 filas)
  Sort top-N heapsort
    HashAggregate (Group Key: pr.id_producto, c.nombre)
      Gather (Workers: 2)
        Hash Join (pr.id_categoria = c.id_categoria)
          Hash Join (d.id_producto = pr.id_producto)
            Parallel Hash Join (d.id_pedido = p.id_pedido)
              Parallel Seq Scan on detalle_pedido d  — 399 994 filas leídas
              Parallel Hash / Parallel Seq Scan on pedido p
                Filter: fecha >= now() - '30 days'
                Rows Removed by Filter: 191 636
            Seq Scan on producto pr  — 50 010 filas leídas
          Seq Scan on categoria c  — 5 filas leídas
        actual time ≈ 133.836 ms (ejecución total)
```

Criterio de aceptación: el plan reemplaza el `Seq Scan on pedido` por un `Index Scan`, `Index Only Scan` o `Bitmap Heap Scan` usando el nuevo índice sobre `fecha`, **y** la mediana de 3 ejecuciones baja a ≤ 66 ms (menos de la mitad de 133.836 ms). Si alguna de las dos condiciones no se cumple, el índice se rechaza. El nuevo índice no puede repetir la cobertura de ningún índice existente (en particular, no puede solaparse con `idx_pedido_id_cliente`).
