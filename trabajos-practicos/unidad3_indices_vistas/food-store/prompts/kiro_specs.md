# Prompt para Kiro: specs de la Unidad 3 (índices, vistas y vista materializada)

Necesito las especificaciones de cada pieza del trabajo **antes** de generar el SQL. Escribí un archivo Markdown por pieza en la carpeta `specs/` de esta carpeta (`food-store/`). No generes SQL ni modifiques otros archivos.

## Contexto

- Base: Food Store en PostgreSQL 18. El esquema está en `schema.sql` y **no se puede modificar**: solo se agregan índices y vistas.
- Tablas: `categoria` (5 filas), `producto` (50 010), `cliente` (20 005), `pedido` (200 005, con `fecha TIMESTAMPTZ` repartida en los últimos 2 años y `forma_pago` con 3 valores), `detalle_pedido` (399 994, `UNIQUE (id_pedido, id_producto)`) y `usuario` (cuentas de la aplicación, con `contrasena`).
- Índices actuales: las PK, los UNIQUE, `pedido (id_cliente)`, `producto (id_categoria) WHERE activo = TRUE` y `detalle_pedido (id_producto)`.
- Borrado lógico: `categoria.activo`, `producto.activo` y `usuario.eliminado`. `cliente`, `pedido` y `detalle_pedido` no tienen.

## Formato de cada spec

Como el ejemplo de la cátedra:

```
# spec: <nombre>
Objetivo: …
Consulta afectada: (el SQL exacto)
Frecuencia: …
Columnas candidatas: (las que participan del filtro, del JOIN o del ORDER BY, con su selectividad)
Plan actual: (nodos Seq Scan, filas y tiempo, según la medición de abajo)
Criterio de aceptación: …
```

Para las vistas, en lugar de «Columnas candidatas» y «Plan actual»: **Columnas a exponer** (en orden), **Filtro de vigencia**, **Columnas ocultas** (y por qué) y **Criterio de aceptación**.

## Parte A · Una spec por consulta

Las consultas exactas y su plan actual están al final de este archivo.

| Archivo | Consulta | Frecuencia esperada |
|---|---|---|
| `specs/A1_facturacion_semana.md` | C1 · facturación por día de la última semana | Panel de ventas: cada vez que se abre, decenas de veces por día |
| `specs/A2_top_clientes_30_dias.md` | C2 · los 10 clientes que más gastaron en 30 días | Reporte de clientes destacados: varias veces por día |
| `specs/A3_top_productos_30_dias.md` | C3 · los 10 productos que más facturaron en 30 días | Reporte de compras y reposición: varias veces por día |
| `specs/A4_productos_nunca_vendidos.md` | C4 · productos vigentes nunca vendidos | Revisión del catálogo: una vez por semana |

Criterio de aceptación para las cuatro: el plan deja el `Seq Scan` sobre la tabla grande y pasa a `Index Scan`, `Index Only Scan` o `Bitmap Heap Scan`, **y** la mediana de 3 ejecuciones baja al menos a la mitad. Si no se cumple, el índice se rechaza. Además, ningún índice puede repetir lo que ya cubre un índice existente.

## Parte B · Una spec por vista

| Archivo | Vista | Qué tiene que cumplir |
|---|---|---|
| `specs/B1_v_productos_vigentes.md` | `v_productos_vigentes` | Productos vigentes con su categoría: `id_producto`, `producto` (nombre), `precio`, `stock`, `id_categoria`, `categoria` (nombre). Vigencia: producto **y** categoría activos |
| `specs/B2_v_pedidos_cliente.md` | `v_pedidos_cliente` | Pedidos con los datos del cliente: `id_pedido`, `fecha`, `forma_pago`, `id_cliente`, `nombre`, `apellido`. Sin filtro de vigencia. Ocultar `email` y `telefono`: los reportes no los necesitan |
| `specs/B3_v_detalle_pedido.md` | `v_detalle_pedido` | Detalle de un pedido con el nombre del producto: `id_pedido`, `id_detalle`, `id_producto`, `producto` (nombre), `cantidad`, `precio_unitario`, `subtotal` (`cantidad * precio_unitario`). **Sin** filtro de vigencia: un producto dado de baja tiene que seguir apareciendo en los pedidos viejos |
| `specs/B4_v_usuario_publico.md` | `v_usuario_publico` | Seguridad: `usuario` **sin** `contrasena` (ni `celular`, que los reportes no usan): `id`, `nombre`, `apellido`, `mail`, `rol`. Solo usuarios con `eliminado = FALSE`. Un rol de solo lectura `rol_reportes` tiene `SELECT` sobre la vista y ningún permiso sobre la tabla `usuario` |

Criterio de aceptación de las vistas: una consulta equivalente escrita a mano da exactamente el mismo resultado (`EXCEPT` en los dos sentidos, 0 y 0 filas). Para B4, además: con `SET ROLE rol_reportes`, `SELECT` sobre la vista funciona y `SELECT` sobre `usuario` falla por permisos.

## Parte C · Vista materializada

`specs/C1_mv_facturacion_categoria_mes.md`: vista materializada `mv_facturacion_categoria_mes` de la consulta 7.4 de `queries.sql` (facturación por categoría y mes; columnas `id_categoria`, `categoria`, `mes`, `cantidad_pedidos`, `facturacion_total`). `WITH DATA` y un índice único sobre `(id_categoria, mes)` que permita `REFRESH MATERIALIZED VIEW CONCURRENTLY`. Uso esperado: la gerencia consulta el reporte varias veces por día y le alcanza con datos hasta el cierre del día anterior. Criterio: el reporte desde la vista materializada da lo mismo que la consulta original y tarda mucho menos.

## Medición actual (mediana de 3 ejecuciones, después de calentar la caché)

Volumen: categoria 5, producto 50010, cliente 20005, pedido 200005, detalle_pedido 399994, usuario 3

- C1 92.231 ms
- C2 132.009 ms
- C3 133.836 ms
- C4 89.943 ms

Nodos de cada plan:

- C1: Gather Merge, Parallel Hash Join, Parallel Seq Scan on detalle_pedido, Parallel Seq Scan on pedido
- C2: Gather, Hash Join, Parallel Hash Join, Parallel Seq Scan on detalle_pedido, Parallel Seq Scan on pedido, Seq Scan on cliente
- C3: Gather, Hash Join, Hash Join, Parallel Hash Join, Parallel Seq Scan on detalle_pedido, Parallel Seq Scan on pedido, Seq Scan on producto, Seq Scan on categoria
- C4: Hash Right Anti Join, Seq Scan on detalle_pedido, Seq Scan on producto

## Consultas exactas

```sql
-- C1 · Facturación por día de la última semana (S3.1)
SELECT DATE(p.fecha) AS dia, COUNT(DISTINCT p.id_pedido) AS pedidos, SUM(d.cantidad * d.precio_unitario) AS facturado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
 WHERE p.fecha >= (CURRENT_DATE - 7)::timestamptz
 GROUP BY DATE(p.fecha)
 ORDER BY dia;

-- C2 · Los 10 clientes que más gastaron en los últimos 30 días (S3.2)
SELECT c.id_cliente, c.nombre, c.apellido, SUM(d.cantidad * d.precio_unitario) AS gastado
  FROM pedido p
  JOIN detalle_pedido d ON d.id_pedido = p.id_pedido
  JOIN cliente c ON c.id_cliente = p.id_cliente
 WHERE p.fecha >= now() - INTERVAL '30 days'
 GROUP BY c.id_cliente, c.nombre, c.apellido
 ORDER BY gastado DESC
 LIMIT 10;

-- C3 · Los 10 productos que más facturaron en los últimos 30 días (S4.3)
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

-- C4 · Productos vigentes nunca vendidos (7.3)
SELECT id_producto, nombre, precio, stock
FROM producto
WHERE activo = TRUE
  AND NOT EXISTS (SELECT 1 FROM detalle_pedido WHERE id_producto = producto.id_producto)
ORDER BY nombre;

```

Planes completos de la medición: `evidencias/parteA_antes.txt`.
