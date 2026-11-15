-- 01 — Esquema de Food Store (DDL)
DROP TABLE IF EXISTS detalle_pedido CASCADE;
DROP TABLE IF EXISTS pedido CASCADE;
DROP TABLE IF EXISTS producto CASCADE;
DROP TABLE IF EXISTS categoria CASCADE;
DROP TABLE IF EXISTS cliente CASCADE;
DROP TYPE IF EXISTS forma_pago_enum CASCADE;
-- Tipos enumerados
CREATE TYPE forma_pago_enum AS ENUM ('EFECTIVO', 'TARJETA', 'TRANSFERENCIA');

-- CATEGORIA
CREATE TABLE categoria (
    id_categoria    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre          VARCHAR(80)     NOT NULL UNIQUE,
    activo          BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- CLIENTE: email es clave candidata (R6)
CREATE TABLE cliente (
    id_cliente      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre          VARCHAR(80)     NOT NULL,
    apellido        VARCHAR(80)     NOT NULL,
    email           VARCHAR(150)    NOT NULL UNIQUE,
    telefono        VARCHAR(30),
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- PRODUCTO
CREATE TABLE producto (
    id_producto     BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre          VARCHAR(120)    NOT NULL,
    descripcion     TEXT,
    precio          NUMERIC(10,2)   NOT NULL CHECK (precio >= 0),
    stock           INTEGER         NOT NULL DEFAULT 0 CHECK (stock >= 0),
    activo          BOOLEAN         NOT NULL DEFAULT TRUE,
    id_categoria    BIGINT          NOT NULL
                        REFERENCES categoria (id_categoria)
                        ON DELETE RESTRICT,
    created_at      TIMESTAMPTZ     NOT NULL DEFAULT now()
);

-- PEDIDO
CREATE TABLE pedido (
    id_pedido       BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    fecha           TIMESTAMPTZ     NOT NULL DEFAULT now(),
    forma_pago      forma_pago_enum NOT NULL,
    id_cliente      BIGINT          NOT NULL
                        REFERENCES cliente (id_cliente)
                        ON DELETE RESTRICT
);

-- DETALLE_PEDIDO (tabla intermedia N:M entre PEDIDO y PRODUCTO)
CREATE TABLE detalle_pedido (
    id_detalle      BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cantidad        INTEGER         NOT NULL CHECK (cantidad > 0),
    precio_unitario NUMERIC(10,2)   NOT NULL CHECK (precio_unitario >= 0),
    id_pedido       BIGINT          NOT NULL
                        REFERENCES pedido (id_pedido)
                        ON DELETE CASCADE,
    id_producto     BIGINT          NOT NULL
                        REFERENCES producto (id_producto)
                        ON DELETE RESTRICT,
    UNIQUE (id_pedido, id_producto)
);

-- Índices

-- Acelera el historial de pedidos de un cliente.
CREATE INDEX idx_pedido_id_cliente ON pedido (id_cliente);

-- Acelera el listado de productos vigentes de una categoría.
CREATE INDEX idx_producto_categoria_activo ON producto (id_categoria) WHERE activo = TRUE;

-- Acelera la búsqueda de las ventas de un producto.
CREATE INDEX idx_detalle_pedido_id_producto ON detalle_pedido (id_producto);

-- USUARIO + tipo ENUM rol
DROP TABLE IF EXISTS usuario CASCADE;
DROP TYPE  IF EXISTS rol     CASCADE;

CREATE TYPE rol AS ENUM ('USUARIO', 'ADMIN');

CREATE TABLE usuario (
    id          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      VARCHAR(80)  NOT NULL,
    apellido    VARCHAR(80)  NOT NULL,
    mail        VARCHAR(120) NOT NULL UNIQUE,
    celular     VARCHAR(30),
    contrasena  VARCHAR(255) NOT NULL,
    rol         rol          NOT NULL DEFAULT 'USUARIO',
    eliminado   BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMPTZ  NOT NULL DEFAULT now()
);
