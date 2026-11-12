-- Food Store — schema.sql (TP1, Parte 4)
-- Crea el esquema que resulta de conciliar el modelo relacional (Parte 2) con la normalización (Parte 3).
-- Se puede ejecutar más de una vez. Los DROP no usan CASCADE: si otro objeto depende de estas
-- tablas, el script se detiene en vez de borrarlo sin avisar.

DROP TABLE IF EXISTS detalle_pedido, pedido, producto, cliente, categoria;
DROP TYPE IF EXISTS tipo_forma_pago;

-- Forma de pago: dominio cerrado (los tres valores de la planilla); el ENUM rechaza cualquier otro.
CREATE TYPE tipo_forma_pago AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA');

CREATE TABLE categoria (
    id          BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(60)  NOT NULL UNIQUE,         -- clave candidata: no se repiten nombres de categoría
    activo      BOOLEAN      NOT NULL DEFAULT TRUE,   -- R7: baja lógica, la fila se conserva
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);

CREATE TABLE producto (
    id            BIGINT         GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre        VARCHAR(100)   NOT NULL,
    descripcion   TEXT,
    precio        NUMERIC(10,2)  NOT NULL CHECK (precio >= 0),              -- R5; precio de lista actual
    stock         INTEGER        NOT NULL DEFAULT 0 CHECK (stock >= 0),     -- R5
    activo        BOOLEAN        NOT NULL DEFAULT TRUE,                     -- R7
    -- NOT NULL: participación total, todo producto está en exactamente una categoría (R1).
    -- RESTRICT: una categoría con productos no se borra; se da de baja (R7).
    categoria_id  BIGINT         NOT NULL REFERENCES categoria (id) ON DELETE RESTRICT,
    created_at    TIMESTAMPTZ    NOT NULL DEFAULT now()
);

CREATE TABLE cliente (
    id          BIGINT        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(60)   NOT NULL,
    apellido    VARCHAR(60)   NOT NULL,             -- separado del nombre: se ordena y se busca por apellido
    -- R6: el mail identifica al cliente. 254 es el largo máximo de una dirección de correo.
    email       VARCHAR(254)  NOT NULL UNIQUE,
    telefono    VARCHAR(20),                        -- opcional
    created_at  TIMESTAMPTZ   NOT NULL DEFAULT now(),
    -- En minúsculas, para que UNIQUE no acepte el mismo mail escrito con otras mayúsculas.
    CONSTRAINT email_en_minusculas CHECK (email = lower(email)),
    CONSTRAINT email_con_arroba    CHECK (email LIKE '%_@_%')
);

CREATE TABLE pedido (
    id          BIGINT           GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha       TIMESTAMPTZ      NOT NULL DEFAULT now(),
    forma_pago  tipo_forma_pago  NOT NULL,
    -- NOT NULL: todo pedido es de un cliente registrado (R2).
    -- RESTRICT: borrar un cliente con pedidos borraría ventas ya facturadas.
    cliente_id  BIGINT           NOT NULL REFERENCES cliente (id) ON DELETE RESTRICT
);

-- Entidad asociativa de la relación N:M entre pedido y producto (R3), con sus atributos propios (R4).
CREATE TABLE detalle_pedido (
    -- CASCADE: una línea no tiene sentido sin su pedido.
    pedido_id        BIGINT         NOT NULL REFERENCES pedido (id) ON DELETE CASCADE,
    -- RESTRICT: un producto que ya se vendió no se borra; se da de baja (R7).
    producto_id      BIGINT         NOT NULL REFERENCES producto (id) ON DELETE RESTRICT,
    cantidad         INTEGER        NOT NULL CHECK (cantidad > 0),
    -- R4: el precio del momento de la venta. No se deduce de producto.precio, que cambia con el tiempo.
    precio_unitario  NUMERIC(10,2)  NOT NULL CHECK (precio_unitario >= 0),
    -- Clave compuesta: un producto aparece una sola vez por pedido, y ninguna otra tabla referencia una línea.
    PRIMARY KEY (pedido_id, producto_id)
);

-- Índices. Las claves primarias y los UNIQUE ya crean el suyo.
-- Historial de pedidos de un cliente.
CREATE INDEX idx_pedido_cliente ON pedido (cliente_id);
-- Ventas de un período, como «lo que se facturó en marzo».
CREATE INDEX idx_pedido_fecha ON pedido (fecha);
-- Productos vigentes de una categoría (el menú): índice parcial, solo con los activos.
CREATE INDEX idx_producto_categoria_activo ON producto (categoria_id) WHERE activo;
-- Pedidos en los que se vendió un producto: la clave de detalle_pedido empieza por pedido_id y no sirve para esta búsqueda.
CREATE INDEX idx_detalle_producto ON detalle_pedido (producto_id);
