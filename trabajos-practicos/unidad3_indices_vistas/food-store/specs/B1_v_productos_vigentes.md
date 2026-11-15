# spec: B1 · Vista `v_productos_vigentes`

Objetivo: ofrecer una vista que exponga solo los productos vigentes junto con el nombre de su categoría, eliminando la necesidad de repetir el doble filtro `producto.activo = TRUE AND categoria.activo = TRUE` en cada consulta del catálogo.

Consulta afectada:
```sql
-- Consulta equivalente que la vista debe replicar exactamente:
SELECT p.id_producto,
       p.nombre      AS producto,
       p.precio,
       p.stock,
       p.id_categoria,
       c.nombre      AS categoria
FROM producto p
JOIN categoria c ON c.id_categoria = p.id_categoria
WHERE p.activo = TRUE
  AND c.activo = TRUE;
```

Frecuencia: varias veces por día desde el catálogo de productos, reportes de stock y cualquier consulta que necesite la lista de productos activos con su categoría.

Columnas a exponer (en orden):

| # | Columna | Origen | Alias |
|---|---|---|---|
| 1 | `id_producto` | `producto.id_producto` | — |
| 2 | `producto` | `producto.nombre` | `producto` |
| 3 | `precio` | `producto.precio` | — |
| 4 | `stock` | `producto.stock` | — |
| 5 | `id_categoria` | `producto.id_categoria` | — |
| 6 | `categoria` | `categoria.nombre` | `categoria` |

Filtro de vigencia: `producto.activo = TRUE AND categoria.activo = TRUE`. Se aplica al crear la vista para que los consumidores no necesiten repetirlo.

Columnas ocultas:

| Columna | Razón |
|---|---|
| `producto.activo` | Siempre `TRUE` dentro de la vista; exponerla sería redundante y confuso. |
| `producto.descripcion` | Texto libre de longitud variable; no se necesita en listados ni reportes de catálogo. |
| `producto.created_at` | Metadato de auditoría; no es un dato de negocio que consuman los reportes. |
| `categoria.activo` | Siempre `TRUE` dentro de la vista; igual que `producto.activo`. |
| `categoria.created_at` | Metadato de auditoría. |

Criterio de aceptación: ejecutar la consulta equivalente directa y la misma consulta sobre la vista sin cláusulas adicionales; hacer `EXCEPT` en ambos sentidos. Ambos `EXCEPT` deben devolver 0 filas, confirmando que el resultado es idéntico.

```sql
-- Verificación:
(SELECT id_producto, producto, precio, stock, id_categoria, categoria FROM v_productos_vigentes)
EXCEPT
(SELECT p.id_producto, p.nombre, p.precio, p.stock, p.id_categoria, c.nombre
   FROM producto p JOIN categoria c ON c.id_categoria = p.id_categoria
  WHERE p.activo = TRUE AND c.activo = TRUE);

(SELECT p.id_producto, p.nombre, p.precio, p.stock, p.id_categoria, c.nombre
   FROM producto p JOIN categoria c ON c.id_categoria = p.id_categoria
  WHERE p.activo = TRUE AND c.activo = TRUE)
EXCEPT
(SELECT id_producto, producto, precio, stock, id_categoria, categoria FROM v_productos_vigentes);
```

Ambas consultas deben retornar 0 filas.
