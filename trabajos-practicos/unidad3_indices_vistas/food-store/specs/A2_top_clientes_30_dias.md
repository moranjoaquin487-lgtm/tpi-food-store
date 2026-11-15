# spec: A2 · Top 10 clientes que más gastaron en los últimos 30 días

Objetivo: acelerar el reporte de clientes destacados que agrega gasto por cliente filtrando pedidos de los últimos 30 días, uniendo tres tablas y devolviendo los 10 primeros.

Consulta afectada:
```sql
SELECT c.id_cliente, c.nombre, c.apellido, SUM(d.cantidad * d.precio_unitario) AS gastado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
  JOIN cliente c ON c.id_cliente = p.id_cliente
 WHERE p.fecha >= now() - INTERVAL '30 days'
 GROUP BY c.id_cliente, c.nombre, c.apellido
 ORDER BY gastado DESC
 LIMIT 10;
```

Frecuencia: reporte de clientes destacados; varias veces por día.

Columnas candidatas:

| Columna | Rol en la consulta | Selectividad |
|---|---|---|
| `pedido.fecha` | filtro de rango (`>= now() - 30 days`) | alta: ~4 % de las filas (≈ 8 369 de 200 005) |
| `pedido.id_cliente` | clave del JOIN con `cliente` | ya indexada (`idx_pedido_id_cliente`) |
| `pedido.id_pedido` | clave del JOIN con `detalle_pedido` | PK, ya indexada |
| `detalle_pedido.id_pedido` | clave del JOIN con `pedido` | ya indexada (UNIQUE `(id_pedido, id_producto)`) |
| `cliente.id_cliente` | clave del JOIN y del `GROUP BY` | PK, ya indexada |

El cuello de botella es el `Parallel Seq Scan on pedido` que lee las 200 005 filas y descarta 191 636 por el filtro de fecha. El `Seq Scan on cliente` lee 20 005 filas sin filtro, pero es relativamente barato (684 buffers). Con un índice sobre `pedido.fecha`, el planner puede acortar drásticamente la búsqueda de pedidos recientes.

Nota: `pedido.id_cliente` ya está indexado por `idx_pedido_id_cliente`, pero ese índice no cubre el filtro por rango de fecha. Un índice compuesto `(fecha, id_cliente)` incluiría ambas columnas, pero la variante más simple `(fecha)` suele ser suficiente porque la selectividad del filtro temporal ya es alta.

Plan actual (mediana de 3 ejecuciones — `evidencias/parteA_antes.txt`):
```
Limit (10 filas)
  Sort top-N heapsort
    HashAggregate (Group Key: c.id_cliente)
      Gather (Workers: 2)
        Hash Join (p.id_cliente = c.id_cliente)
          Parallel Hash Join (d.id_pedido = p.id_pedido)
            Parallel Seq Scan on detalle_pedido d  — 399 994 filas leídas
            Parallel Hash / Parallel Seq Scan on pedido p
              Filter: fecha >= now() - '30 days'
              Rows Removed by Filter: 191 636
          Seq Scan on cliente c  — 20 005 filas leídas
        actual time ≈ 132.009 ms (ejecución total)
```

Criterio de aceptación: el plan reemplaza el `Seq Scan on pedido` por un `Index Scan`, `Index Only Scan` o `Bitmap Heap Scan` usando el nuevo índice sobre `fecha`, **y** la mediana de 3 ejecuciones baja a ≤ 66 ms (menos de la mitad de 132.009 ms). Si alguna de las dos condiciones no se cumple, el índice se rechaza. El nuevo índice no puede repetir la cobertura de `idx_pedido_id_cliente` ni de ningún otro índice existente.
