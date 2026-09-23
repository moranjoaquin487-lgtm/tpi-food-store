# Modelo ER, modelo relacional y normalización

Desarrollo de las Partes 1 a 3 del modelado de Food Store. El DDL resultante (Parte 4) es [`sql/01_schema.sql`](../sql/01_schema.sql).

## Parte 1 — Modelo entidad-relación

![Diagrama entidad-relación de Food Store](Diagrama%20ER.png)

Notación: pata de gallo (Crow's Foot), sostenida en todo el diagrama.

### Diccionario de entidades y atributos

| Entidad | Atributo | Tipo conceptual | Observaciones |
|---|---|---|---|
| **Categoría** | `id_categoria` (PK) | numérico | Clave sustituta |
| | `nombre` | texto | Clave candidata alternativa (único) |
| | `activo` | booleano | Baja lógica (R7) |
| | `created_at` | fecha/hora | Fecha de alta, automática |
| **Producto** | `id_producto` (PK) | numérico | Clave sustituta |
| | `nombre` | texto | No es único: puede repetirse entre categorías |
| | `descripcion` | texto | Atributo adicional, opcional |
| | `precio` | numérico | Precio de lista vigente, no negativo (R5) |
| | `stock` | numérico | No negativo (R5) |
| | `activo` | booleano | Baja lógica (R7) |
| | `created_at` | fecha/hora | Fecha de alta, automática |
| **Cliente** | `id_cliente` (PK) | numérico | Clave sustituta |
| | `nombre`, `apellido` | texto | Nombre completo descompuesto (ver preguntas guía) |
| | `email` | texto | Clave candidata alternativa (R6) |
| | `telefono` | texto | Atributo adicional, opcional |
| | `created_at` | fecha/hora | Fecha de alta, automática |
| **Pedido** | `id_pedido` (PK) | numérico | Clave sustituta |
| | `fecha` | fecha/hora | Con zona horaria |
| | `forma_pago` | texto (dominio cerrado) | EFECTIVO · TARJETA · TRANSFERENCIA |
| **Detalle** (asociativa) | `id_detalle` (PK) | numérico | Clave sustituta |
| | `cantidad` | numérico | Mayor que cero |
| | `precio_unitario` | numérico | Congela el precio del momento de la venta (R4) |

### Relaciones

| Relación | Cardinalidad | Participación | Regla |
|---|---|---|---|
| Categoría agrupa Producto | 1:N | Categoría parcial · Producto total | R1 |
| Cliente realiza Pedido | 1:N | Cliente parcial · Pedido total | R2 |
| Pedido contiene Producto (vía Detalle) | N:M con atributos propios | Pedido total · Producto parcial | R3, R4 |

Categoría es parcial porque una categoría recién creada puede no tener productos todavía; Producto es total porque todo producto pertenece exactamente a una categoría (R1). Lo mismo con Cliente y Pedido: un cliente puede no haber pedido nunca, pero no existe pedido sin cliente (R2).

### Preguntas guía

**¿Por qué la relación entre producto y pedido no puede resolverse como una 1:N?**
Porque un pedido incluye varios productos y un producto se vende en muchos pedidos (R3): las dos puntas son "muchos". Forzar una 1:N poniendo `id_pedido` dentro de producto obligaría a duplicar la fila del producto en cada venta. Además se perderían los atributos que pertenecen al cruce de ambos: la cantidad y, sobre todo, el `precio_unitario` del momento (R4). Sin ese cruce, lo facturado en marzo se recalcularía con el precio de abril.

**¿Qué entidad tiene participación parcial con categoría y cuál total?**
Categoría es la parcial y Producto la total. Invertir la lectura obligaría a que toda categoría tenga al menos un producto (no se podría crear una categoría vacía) y permitiría productos sin categoría, con `id_categoria` nulo, lo que rompe R1 y deja huérfanos en los reportes por categoría.

**¿Algún atributo podría descomponerse?**
Sí, el nombre del cliente: se separó en `nombre` y `apellido` porque ordenar y buscar por apellido son operaciones habituales, y con un único campo habría que partir el texto en cada consulta. El teléfono quedó como un solo campo porque ninguna consulta necesita sus partes por separado.

## Parte 2 — Derivación al modelo relacional

PK en **negrita** · FK marcada con `→`

- categoria (**id_categoria**, nombre, activo, created_at)
- cliente (**id_cliente**, nombre, apellido, email, telefono, created_at)
- producto (**id_producto**, nombre, descripcion, precio, stock, activo, id_categoria → categoria, created_at)
- pedido (**id_pedido**, fecha, forma_pago, id_cliente → cliente)
- detalle_pedido (**id_detalle**, cantidad, precio_unitario, id_pedido → pedido, id_producto → producto) · `UNIQUE (id_pedido, id_producto)`

Las dos relaciones 1:N se resolvieron llevando la clave del lado "1" como clave foránea al lado "N", sin tablas nuevas. La N:M entre pedido y producto se resolvió con la tabla intermedia `detalle_pedido`, que guarda además los atributos propios de la relación: `cantidad` y `precio_unitario`.

**Clave de la tabla intermedia.** Se eligió una clave sustituta (`id_detalle`) en lugar de la compuesta (`id_pedido`, `id_producto`), porque una línea se referencia desde la aplicación con un solo valor para editarla o anularla. La regla que garantizaba la clave compuesta no se pierde: queda declarada como `UNIQUE (id_pedido, id_producto)`.

### Preguntas guía

**¿Qué pasaría si la tabla intermedia no tuviera ambas FK como NOT NULL?**
Podrían existir líneas huérfanas: una cantidad y un precio que no pertenecen a ningún pedido o a ningún producto. No se pueden interpretar y además descuadran los reportes: un `SUM` de facturación por categoría las descarta en el `JOIN`, pero un `COUNT` de líneas las cuenta, y dos reportes sobre los mismos datos dejan de coincidir.

**Si un pedido pudiera existir sin productos, ¿cambia la participación?**
Sí: la participación de Pedido en la relación con el detalle pasa de total a parcial. No cambia ninguna restricción del DDL, porque "todo pedido tiene al menos una línea" nunca se pudo expresar con una FK, pero sí cambia cómo se escriben los reportes: un `JOIN` interno deja afuera los pedidos vacíos y para contarlos hace falta `LEFT JOIN`.

## Parte 3 — Normalización hasta 3FN/BCNF

Se parte de la planilla plana de ventas, con una fila por línea de producto vendido:

| N.º pedido | Fecha | Cliente | Producto | Categoría | Precio unit. | Cant. | Subtotal | Forma de pago |
|---:|---|---|---|---|---:|---:|---:|---|
| 1 | 01/03/2026 | Ana Gómez | Muzzarella | Pizzas | 1000.00 | 2 | 2000.00 | EFECTIVO |
| 1 | 01/03/2026 | Ana Gómez | Coca 1.5L | Bebidas | 800.00 | 1 | 800.00 | EFECTIVO |
| 2 | 01/03/2026 | Luis Paz | Napolitana | Pizzas | 1500.00 | 1 | 1500.00 | TARJETA |
| 3 | 05/03/2026 | Ana Gómez | Muzzarella | Pizzas | 1050.00 | 3 | 3150.00 | TRANSFERENCIA |
| 4 | 06/03/2026 | Marta Ruiz | Coca 1.5L | Bebidas | 800.00 | 4 | 3200.00 | EFECTIVO |
| 4 | 06/03/2026 | Marta Ruiz | Napolitana | Pizzas | 1500.00 | 2 | 3000.00 | EFECTIVO |
| 5 | 07/03/2026 | Luis Paz | Muzzarella | Pizzas | 1050.00 | 1 | 1050.00 | TARJETA |

### Paso 1 — Clave

Una fila queda identificada por el pedido y el producto vendido en esa línea, porque dentro de un pedido un producto no se repite. Ningún atributo alcanza solo: el pedido 1 tiene dos líneas y la Muzzarella aparece en tres pedidos.

```
Clave candidata: {nro_pedido, producto}
```

### Paso 2 — Dependencias funcionales

```
DF1: nro_pedido                  → fecha, cliente, forma_pago
DF2: producto                    → categoria
DF3: {nro_pedido, producto}      → cantidad, precio_unitario, subtotal
DF4: {cantidad, precio_unitario} → subtotal
```

DF1 sale de la regla "cada pedido tiene una única fecha, cliente y forma de pago", y se ve en los datos: el pedido 4 aparece dos veces, siempre con la misma fecha, Marta Ruiz y EFECTIVO. DF2 sale de "cada producto pertenece a una única categoría". DF4 es aritmética: 1000,00 × 2 = 2000,00.

**`precio_unitario` no depende solo del producto:** la Muzzarella vale 1000,00 en el pedido 1 y 1050,00 en el pedido 3. La dependencia correcta es `{nro_pedido, producto} → precio_unitario`, y por eso el precio vive en la línea de detalle y no en el producto.

### Paso 3 — Primera forma normal

La relación ya está en 1FN: todas las celdas son atómicas y cada producto vendido ocupa su propia fila. El nombre del cliente se separa en nombre y apellido en el modelo definitivo, pero para estas dependencias se trata como un atributo.

### Paso 4 — Segunda forma normal

Hay dos dependencias parciales de la clave compuesta:

- **DF1:** fecha, cliente y forma_pago dependen solo de nro_pedido y se repiten en cada línea del pedido.
- **DF2:** categoria depende solo de producto y se repite en cada venta del producto.

```
pedido   (nro_pedido, fecha, cliente, forma_pago)
producto (producto, categoria)
detalle  (nro_pedido, producto, cantidad, precio_unitario, subtotal)
```

### Paso 5 — Tercera forma normal

En `detalle` queda DF4: `subtotal` depende de `cantidad` y `precio_unitario`, que no son clave. Es una dependencia transitiva y viola 3FN. Se resuelve quitando `subtotal`, que es derivado.

En `pedido` no hay transitivas con estos atributos. Al conciliar con el modelo ER, el cliente pasa a tener email y teléfono, y ahí `cliente → email` sí sería transitiva: por eso cliente termina como tabla propia referenciada por clave foránea.

### Paso 6 — BCNF

BCNF exige que en toda DF no trivial X → Y, X sea clave candidata:

| Tabla | Único determinante | ¿Es clave candidata? |
|---|---|---|
| pedido | nro_pedido | Sí |
| producto | producto | Sí |
| detalle | {nro_pedido, producto} | Sí |

No hay excepciones: las tres tablas están en BCNF. Acá 3FN y BCNF coinciden porque no hay ningún determinante que sea parte de una clave sin ser una clave entera, que es el caso que las distingue.

### Paso 7 — Tablas finales

```
pedido   (nro_pedido, fecha, cliente, forma_pago)       PK: nro_pedido
producto (producto, categoria)                          PK: producto
detalle  (nro_pedido, producto, cantidad, precio_unitario)  PK: {nro_pedido, producto}
```

### Preguntas de integración

**Correspondencia con el modelo ER.** `pedido` corresponde a la entidad Pedido (con el cliente, que en el ER es una entidad aparte); `producto` corresponde a Producto junto con su relación con Categoría, que en el ER es una entidad con clave propia; `detalle` corresponde a la entidad asociativa Detalle.

**Atributos que no estaban en la planilla.** El email y el teléfono del cliente, la descripción y el stock del producto, las marcas `activo` y las claves sustitutas. La planilla registra lo necesario para facturar, no para operar el negocio. Normalizar datos históricos revela la estructura que ya tienen, pero solo llega hasta donde llegó el registro; modelar desde el negocio agrega lo que el sistema va a necesitar (R6, R7, el stock). El esquema final concilia las dos.

**¿Conviene almacenar el subtotal?** En la planilla viola 3FN y por eso se eliminó. Guardarlo en una tabla ya normalizada sería otra decisión: redundancia controlada por rendimiento. En Food Store no se justifica, porque es una multiplicación entre columnas de la misma fila. La trazabilidad histórica ya la da `precio_unitario`, que sí se almacena porque no se puede deducir del estado actual de la base (R4).
