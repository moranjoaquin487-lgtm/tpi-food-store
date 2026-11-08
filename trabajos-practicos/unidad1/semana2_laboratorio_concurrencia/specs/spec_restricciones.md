# Spec — Reglas de negocio garantizadas por el motor

Parte 1 de la Semana 2. Esquema: `food-store/schema.sql`. Motor: PostgreSQL 18.

Son tres reglas que hoy dependen de que la aplicación se acuerde de validarlas. La spec se escribió antes de generar el código con OpenCode; la redacté con ayuda de Claude (ver la DUIA de la Parte 1).

## Regla A — Precio congelado al vender

Al insertar una fila en `detalle_pedido`, `precio_unitario` tiene que ser igual a `producto.precio` del producto vendido en ese momento. Una vez registrada la fila, `precio_unitario` no se puede modificar.

## Regla B — Baja de una categoría

`categoria.activo` no puede pasar de `TRUE` a `FALSE` mientras la categoría tenga al menos un producto con `producto.activo = TRUE`.

## Regla C — Fecha de un pedido

`pedido.fecha` no puede ser posterior al momento en que se inserta o se modifica la fila.

## Casos de prueba

| # | Regla | Caso | Resultado esperado |
|:-:|:-:|---|---|
| 1 | A | Agregar la Napolitana al pedido de Jorge Díaz con `precio_unitario` igual a su precio actual | Se inserta |
| 2 | A | Agregar la Cerveza 1L al pedido de Jorge Díaz con un `precio_unitario` distinto del actual | Error |
| 3 | A | Cambiar el `precio_unitario` de una línea ya registrada | Error |
| 4 | A | Cambiar `producto.precio` de la Muzzarella, que ya tiene ventas | Se acepta, y las líneas vendidas conservan su precio |
| 5 | B | Dar de baja la categoría Promociones, que no tiene productos | Se acepta |
| 6 | B | Dar de baja la categoría Pizzas, que tiene productos activos | Error |
| 7 | C | Registrar un pedido con la fecha de este momento | Se inserta |
| 8 | C | Registrar un pedido con fecha de mañana | Error |

## Fuera de alcance

- Los datos cargados antes de crear las reglas no se revisan: tienen precios históricos, como la Muzzarella a 1000,00 en el primer pedido (R4).
- Dar de alta un producto activo en una categoría que ya está dada de baja: la Regla B controla solo la baja de la categoría.
- El stock no forma parte de estas reglas.
