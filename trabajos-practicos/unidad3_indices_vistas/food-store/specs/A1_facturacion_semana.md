# spec: A1 · Facturación por día de la última semana

Objetivo: acelerar la consulta del panel de ventas que calcula, por día, la cantidad de pedidos y el monto facturado en los últimos 7 días. Es la consulta que más se ejecuta en la aplicación.

Consulta afectada:
```sql
SELECT DATE(p.fecha) AS dia, COUNT(DISTINCT p.id_pedido) AS pedidos, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
 WHERE p.fecha >= (CURRENT_DATE - 7)::timestamptz
 GROUP BY DATE(p.fecha)
 ORDER BY dia;
```

Frecuencia: panel de ventas; se abre decenas de veces por día cada vez que un operador ingresa al sistema.

Columnas candidatas:

| Columna | Rol en la consulta | Selectividad |
|---|---|---|
| `pedido.fecha` | filtro de rango (`>= CURRENT_DATE - 7`) | alta: ~1 % de las filas (≈ 2 231 de 200 005) |
| `pedido.id_pedido` | clave del JOIN con `detalle_pedido` y de `COUNT(DISTINCT)` | PK, ya indexada |
| `detalle_pedido.id_pedido` | clave del JOIN con `pedido` | ya indexada como parte de la UNIQUE `(id_pedido, id_producto)` |

El cuello de botella es el `Parallel Seq Scan on pedido` que lee las 200 005 filas y descarta 197 774 por el filtro de fecha. Con un índice sobre `pedido.fecha`, el planner puede hacer un `Index Scan` o `Bitmap Index Scan` y entregar directamente las ≈ 2 231 filas del período sin leer la tabla completa. El `detalle_pedido` ya tiene un índice implícito en la UNIQUE por `id_pedido`, por lo que un `Bitmap Heap Scan` vía ese índice es viable para el lado opuesto del JOIN.

Plan actual (mediana de 3 ejecuciones — `evidencias/parteA_antes.txt`):
```
Gather Merge
  Sort (quicksort)
    Parallel Hash Join (Hash Cond: d.id_pedido = p.id_pedido)
      Parallel Seq Scan on detalle_pedido d  — 399 994 filas leídas
      Parallel Hash / Parallel Seq Scan on pedido p
        Filter: fecha >= (CURRENT_DATE - 7)::timestamptz
        Rows Removed by Filter: 197 774
        actual time ≈ 92.231 ms (ejecución total)
```

Criterio de aceptación: el plan reemplaza el `Seq Scan on pedido` por un `Index Scan`, `Index Only Scan` o `Bitmap Heap Scan` usando el nuevo índice sobre `fecha`, **y** la mediana de 3 ejecuciones baja a ≤ 46 ms (menos de la mitad de 92.231 ms). Si alguna de las dos condiciones no se cumple, el índice se rechaza. El nuevo índice no puede repetir cobertura de ningún índice existente (la PK de `pedido`, `idx_pedido_id_cliente`, ni los de `detalle_pedido`).
