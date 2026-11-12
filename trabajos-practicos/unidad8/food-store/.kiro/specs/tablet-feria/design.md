# Design Document — Food Store en la feria

## Flujo

```
PostgreSQL de pruebas (foodstore_tp8)            Tablet (SQLite, foodstore_movil.db)
┌──────────────────────────────┐   \copy  ┌──────────────────────┐  .import   ┌────────────────────┐
│ producto + categoria         │ ───────► │ servidor_snapshot.csv │ ─────────► │ snapshot_servidor  │
│ v_snapshot_movil (parada 5)  │          └──────────────────────┘            │  └─ UPSERT ─► producto_cache
└──────────────────────────────┘                                              │ pedido_borrador     │
            ▲ nunca se escribe desde la tablet                                │ item_borrador       │
            └──────────── (en un sistema real: API con clave de idempotencia) │ cola_sync ◄ semáforo│
                                                                              └────────────────────┘
```

## Componentes

| Archivo | Responsabilidad | Requisitos |
|---|---|---|
| `servidor/v_snapshot_movil.sql` | Vista con lo que viaja: id, nombre, precio en centavos, stock, `disponible`, `eliminado` (lápida) y la fecha de la copia | REQ-04, REQ-08 |
| `movil/schema_sqlite.sql` | Tablas `STRICT`, `CHECK`, claves foráneas y tres reglas con triggers e índice parcial | REQ-01, REQ-02, REQ-06, REQ-07 |
| `movil/cargar_snapshot.sql` | Reemplaza `snapshot_servidor` dentro de una transacción y actualiza `producto_cache` sin borrar filas | REQ-08 |
| `movil/semaforo.sql` | Un `UPDATE ... FROM` que agrupa por solicitud y cuenta ítems con problemas | REQ-03, REQ-04, REQ-05, REQ-07 |
| `ejecutar_todo.sh` | Arma todo desde cero, corre las pruebas y los casos, y guarda la salida en `evidencias/` | REQ-01, REQ-02, REQ-03, REQ-04, REQ-05, REQ-06, REQ-07, REQ-08 |

## Decisiones

- **Centavos en `INTEGER`.** `precio NUMERIC(10,2)` del servidor viaja como `ROUND(precio * 100)`: no hay redondeos binarios al comparar el precio visto con el actual.
- **`STRICT`.** SQLite deja de aceptar un texto en una columna `INTEGER`; los booleanos son `0`/`1` con `CHECK`.
- **UUID como texto.** `id_local` y `solicitud_uuid` se generan en la tablet, sin servidor; un `CHECK` controla el formato v4.
- **Lápidas en vez de borrar.** La vista incluye los productos dados de baja. La carga del catálogo nunca borra filas de `producto_cache`: así no se rompen las claves foráneas de los borradores viejos.
- **Instantánea cruda y catálogo aparte.** `snapshot_servidor` guarda el CSV tal cual (con `t`/`f`); `producto_cache` es lo que usa la tablet.
- **Prioridad del semáforo.** Rojo (`RECHAZADO`) antes que amarillo (`CONFLICTO`) antes que verde (`SIMULADO_APROBADO`).
- **Idempotencia.** `solicitud_uuid` es clave primaria; el semáforo filtra `estado = 'PENDIENTE'` y un trigger impide cambiar el estado de una solicitud ya evaluada.

## Manejo de errores

- Instantánea vacía o importación fallida: la carga se hace en una transacción y el semáforo no evalúa nada si `snapshot_servidor` está vacía.
- Columnas del CSV en otro orden o faltantes: `.import` llena por posición, así que el CSV entra en una tabla de paso creada desde el encabezado y se copia por nombre; si falta una columna, la carga falla y no cambia nada (corrección del code review, H7).
- Borrador sin ítems: `RECHAZADO` con motivo, para que no quede `PENDIENTE` para siempre.
- Ítems de un borrador con una solicitud `PENDIENTE`: no se pueden cambiar (lo que se envió es lo que se evalúa).

## Estrategia de prueba

Cada requisito tiene su caso (ver `requirements.md`). `pruebas_sqlite.sql` cubre C1 y C7; `ejecutar_todo.sh` prepara C2 a C6 cambiando la copia del servidor, exporta una instantánea nueva por caso, corre el semáforo y termina con una consulta en PostgreSQL que compara pedidos y stock con la foto tomada al empezar.
