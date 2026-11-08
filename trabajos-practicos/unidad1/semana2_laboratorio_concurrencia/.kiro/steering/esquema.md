# Esquema

Fuente: `food-store/schema.sql`.

## Nombres y claves

- Tablas en singular y `snake_case`.
- Clave primaria: `id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY` en todas las tablas excepto `detalle_pedido`.
- Clave foránea: columna `<tabla>_id` (ej. `categoria_id`, `cliente_id`, `pedido_id`, `producto_id`).
- `detalle_pedido` tiene clave primaria compuesta `(pedido_id, producto_id)`; ninguna otra tabla referencia una línea de detalle.

## Tablas y reglas de negocio

### `categoria`
- `nombre VARCHAR(60) NOT NULL UNIQUE`: clave candidata, no se repiten nombres de categoría.
- `activo BOOLEAN NOT NULL DEFAULT TRUE`: baja lógica (R7); la fila se conserva.

### `producto`
- `precio NUMERIC(10,2) NOT NULL CHECK (precio >= 0)`: precio de lista actual (R5).
- `stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0)`: (R5).
- `activo BOOLEAN NOT NULL DEFAULT TRUE`: baja lógica (R7).
- `categoria_id BIGINT NOT NULL REFERENCES categoria(id) ON DELETE RESTRICT`: `NOT NULL` porque todo producto pertenece a exactamente una categoría (R1); `RESTRICT` porque una categoría con productos no se borra, se da de baja (R7).

### `cliente`
- `apellido VARCHAR(60) NOT NULL`: separado del nombre para ordenar y buscar por apellido.
- `email VARCHAR(254) NOT NULL UNIQUE`: identifica al cliente (R6); 254 es el largo máximo de una dirección de correo.
- `telefono VARCHAR(20)`: opcional.
- `CONSTRAINT email_en_minusculas CHECK (email = lower(email))`: el mail se guarda en minúsculas para que `UNIQUE` no acepte el mismo mail con distintas mayúsculas.
- `CONSTRAINT email_con_arroba CHECK (email LIKE '%_@_%')`.

### `pedido`
- `forma_pago tipo_forma_pago NOT NULL`: dominio cerrado con el ENUM (ver abajo).
- `cliente_id BIGINT NOT NULL REFERENCES cliente(id) ON DELETE RESTRICT`: `NOT NULL` porque todo pedido es de un cliente registrado (R2); `RESTRICT` porque borrar un cliente con pedidos borraría ventas ya facturadas.

### `detalle_pedido`
- Entidad asociativa de la relación N:M entre `pedido` y `producto` (R3), con sus atributos propios (R4).
- `pedido_id ... ON DELETE CASCADE`: una línea no tiene sentido sin su pedido.
- `producto_id ... ON DELETE RESTRICT`: un producto que ya se vendió no se borra, se da de baja (R7).
- `cantidad INTEGER NOT NULL CHECK (cantidad > 0)`.
- `precio_unitario NUMERIC(10,2) NOT NULL CHECK (precio_unitario >= 0)`: precio del momento de la venta; no se deduce de `producto.precio`, que cambia con el tiempo (R4).

## Tipo ENUM

```sql
CREATE TYPE tipo_forma_pago AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA');
```

Dominio cerrado: el motor rechaza cualquier valor distinto de esos tres.

## Baja lógica (R7)

`categoria` y `producto` nunca se borran: se marcan con `activo = FALSE`. Por eso todas las claves foráneas que apuntan a esas tablas usan `ON DELETE RESTRICT`.

## Índices

Los índices adicionales (fuera de PK y UNIQUE) son:

| Índice | Columna(s) | Nota |
|---|---|---|
| `idx_pedido_cliente` | `pedido(cliente_id)` | Historial de pedidos de un cliente |
| `idx_pedido_fecha` | `pedido(fecha)` | Ventas de un período |
| `idx_producto_categoria_activo` | `producto(categoria_id) WHERE activo` | Índice parcial: solo productos activos |
| `idx_detalle_producto` | `detalle_pedido(producto_id)` | Pedidos en los que se vendió un producto |
