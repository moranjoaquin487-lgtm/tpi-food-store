# Implementation Plan — Food Store en la feria

- [x] 1. Servidor de pruebas y vista de la instantánea
  - Crear la copia `foodstore_tp8` con `schema.sql` y `data.sql` del TP1.
  - Crear `v_snapshot_movil` (precio en centavos, `disponible`, `eliminado`, fecha de la copia) y guardar una foto de pedidos y stock.
  - _Requisitos: REQ-04, REQ-05, REQ-08_
  - _Nota: La vista es el insumo con el que el semáforo evalúa REQ-03, REQ-04, REQ-05 y REQ-08._

- [x] 2. Esquema de la tablet (`movil/schema_sqlite.sql`)
  - Empezar con `PRAGMA foreign_keys = ON;`. Crear `producto_cache`, `pedido_borrador`, `item_borrador` y `cola_sync` como `STRICT`, más `snapshot_servidor`.
  - `CHECK` de centavos, 0/1, forma de pago, estados, cantidad > 0 y formato UUID; claves foráneas; índice parcial de una solicitud `PENDIENTE` por borrador; triggers de estado final y de ítems bloqueados.
  - _Requisitos: REQ-01, REQ-02, REQ-06, REQ-07_

- [x] 3. Carga de la instantánea (`movil/cargar_snapshot.sql`)
  - Vaciar e importar `snapshot_servidor` en una transacción; `UPSERT` en `producto_cache`; marcar como eliminado lo que ya no viene.
  - _Requisitos: REQ-08_

- [x] 4. Pruebas de la tablet (`movil/pruebas_sqlite.sql`)
  - Borrador completo con `BEGIN … COMMIT`, otra operación con `ROLLBACK`, C1 (catálogo sin servidor) y C7 (cantidad 0 y producto inexistente).
  - _Requisitos: REQ-01, REQ-02_

- [x] 5. Semáforo (`movil/semaforo.sql`)
  - Evaluar solo `PENDIENTE` contra `snapshot_servidor`, con `LEFT JOIN` y conteos por solicitud; guardar estado y motivo.
  - _Requisitos: REQ-03, REQ-04, REQ-05, REQ-07_

- [x] 6. Casos C2 a C6 y verificación final
  - Un borrador por caso, el cambio en la copia del servidor que corresponda, una instantánea nueva y el semáforo; al final, una consulta en PostgreSQL que muestre que pedidos y stock no cambiaron.
  - _Requisitos: REQ-03, REQ-04, REQ-05, REQ-06, REQ-07, REQ-08_

- [x] 7. `ejecutar_todo.sh` y `README.md`
  - Orden para crear todo desde cero y guardar cada salida en `evidencias/`.
  - _Requisitos: REQ-01, REQ-02, REQ-03, REQ-04, REQ-05, REQ-06, REQ-07, REQ-08_
