# Requirements Document — Food Store en la feria (tablet offline)

## Introducción

El food truck de Food Store vende en una feria sin señal. Una tablet guarda en SQLite una copia del catálogo y arma borradores de pedido. Cuando hay conexión, cada borrador viaja como una solicitud y se compara con una instantánea del servidor (semáforo). La regla de oro: **el móvil propone, el servidor dispone**. La tablet consulta y arma borradores; precio, stock y ventas los decide PostgreSQL. `SIMULADO_APROBADO` no es una venta.

## Glosario

| Término | Significado |
|---|---|
| Instantánea | Resultado de `v_snapshot_movil`, exportado a `servidor_snapshot.csv` e importado en `snapshot_servidor` |
| Lápida | Fila de un producto dado de baja: viaja con `eliminado = true` y en la tablet queda con `eliminado = 1` |
| Solicitud | Fila de `cola_sync` que pide al servidor evaluar un borrador; su clave es `solicitud_uuid` |
| Semáforo | `semaforo.sql`: evalúa las solicitudes `PENDIENTE` contra `snapshot_servidor` |

## Requisitos (EARS)

| ID | Requisito | Se prueba con |
|---|---|---|
| REQ-01 | THE SYSTEM SHALL responder la consulta del catálogo leyendo solo `producto_cache`, sin conectarse al servidor, y mostrar solo los productos con `disponible = 1` y `eliminado = 0`. | C1 |
| REQ-02 | IF un ítem tiene cantidad menor o igual a 0 o un producto que no está en `producto_cache`, THEN THE SYSTEM SHALL rechazar la operación sin dejar filas nuevas. | C7 |
| REQ-03 | WHILE la solicitud no tenga ningún motivo de rechazo, WHEN el precio actual de algún ítem sea distinto del precio visto, THE SYSTEM SHALL marcar la solicitud como `CONFLICTO` y guardar el motivo. | C2 |
| REQ-04 | IF algún producto de la solicitud no existe, no está disponible, fue dado de baja o no alcanza el stock, THEN THE SYSTEM SHALL marcar la solicitud como `RECHAZADO` y guardar el motivo. | C3, C4 |
| REQ-05 | WHEN todos los ítems coinciden con la instantánea, THE SYSTEM SHALL marcar la solicitud como `SIMULADO_APROBADO` sin crear pedidos ni cambiar el stock ni el precio del servidor. | C5 y la verificación final en PostgreSQL |
| REQ-06 | IF llega una solicitud con un `solicitud_uuid` ya registrado, THEN THE SYSTEM SHALL rechazarla por clave primaria sin agregar filas a `cola_sync`. | C6 |
| REQ-07 | WHEN se ejecuta el semáforo, THE SYSTEM SHALL evaluar solo las solicitudes `PENDIENTE` y dejar sin cambios las ya evaluadas. | C6 (segunda corrida del semáforo) |
| REQ-08 | WHILE un producto esté dado de baja en el servidor, THE SYSTEM SHALL conservar su fila en `producto_cache` con `eliminado = 1`. | C4 |

## Fuera de alcance

- Una app de celular, una interfaz o una API: todo se hace con SQL en SQLite y en PostgreSQL.
- Confirmar ventas, descontar stock o cambiar precios en el servidor desde la tablet.
- Datos personales reales: la tablet identifica a quien carga el pedido con un código (`feria-01`), sin mails ni contraseñas.
