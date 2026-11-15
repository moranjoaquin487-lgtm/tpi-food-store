# spec: B2 · Vista `v_pedidos_cliente`

Objetivo: ofrecer una vista que combine cada pedido con los datos básicos de identificación de su cliente, eliminando la necesidad de hacer el JOIN en cada reporte que necesite saber quién realizó un pedido.

Consulta afectada:
```sql
-- Consulta equivalente que la vista debe replicar exactamente:
SELECT p.id_pedido,
       p.fecha,
       p.forma_pago,
       p.id_cliente,
       c.nombre,
       c.apellido
FROM pedido p
JOIN cliente c ON c.id_cliente = p.id_cliente;
```

Frecuencia: reportes de pedidos con datos del cliente; varias veces por día.

Columnas a exponer (en orden):

| # | Columna | Origen | Alias |
|---|---|---|---|
| 1 | `id_pedido` | `pedido.id_pedido` | — |
| 2 | `fecha` | `pedido.fecha` | — |
| 3 | `forma_pago` | `pedido.forma_pago` | — |
| 4 | `id_cliente` | `pedido.id_cliente` | — |
| 5 | `nombre` | `cliente.nombre` | — |
| 6 | `apellido` | `cliente.apellido` | — |

Filtro de vigencia: ninguno. `pedido` y `cliente` no tienen borrado lógico (`activo` / `eliminado`), por lo que todos los registros son relevantes y no corresponde filtrar.

Columnas ocultas:

| Columna | Razón |
|---|---|
| `cliente.email` | Dato de contacto personal; los reportes de pedidos no lo necesitan y su exposición innecesaria amplía la superficie de datos sensibles. |
| `cliente.telefono` | Igual que `email`: dato de contacto que los reportes de pedidos no consumen. |
| `cliente.created_at` | Metadato de auditoría; no es un dato de negocio para reportes de pedidos. |

Criterio de aceptación: ejecutar la consulta equivalente directa y la misma consulta sobre la vista; hacer `EXCEPT` en ambos sentidos. Ambos `EXCEPT` deben devolver 0 filas, confirmando que el resultado es idéntico.

```sql
-- Verificación:
(SELECT id_pedido, fecha, forma_pago, id_cliente, nombre, apellido FROM v_pedidos_cliente)
EXCEPT
(SELECT p.id_pedido, p.fecha, p.forma_pago, p.id_cliente, c.nombre, c.apellido
   FROM pedido p JOIN cliente c ON c.id_cliente = p.id_cliente);

(SELECT p.id_pedido, p.fecha, p.forma_pago, p.id_cliente, c.nombre, c.apellido
   FROM pedido p JOIN cliente c ON c.id_cliente = p.id_cliente)
EXCEPT
(SELECT id_pedido, fecha, forma_pago, id_cliente, nombre, apellido FROM v_pedidos_cliente);
```

Ambas consultas deben retornar 0 filas.
