# TP Unidad 4 (Semana 8) — FNBC y desnormalización controlada en Food Store

- **Alumno:** Moran, Joaquín Leandro. Trabajo individual.
- **Base:** copia de prueba `foodstore_tp4` (PostgreSQL), armada desde cero con los scripts del proyecto. No se toca `foodstore`.

## Entregables

| Entregable | Archivo | Evidencia |
|---|---|---|
| 1. Parte 1: esquema original, instancia, tablas descompuestas, vista de compatibilidad y migración verificada | [`sql/tp_fnbc_control_lote.sql`](sql/tp_fnbc_control_lote.sql) | [`evidencias/parte1_fnbc_control_lote.txt`](evidencias/parte1_fnbc_control_lote.txt) |
| 2. Parte 2: estructura desnormalizada, sincronización, consulta 5.2(d) y auditoría 5.2(e) | [`sql/tp_desnormalizacion_top_categorias.sql`](sql/tp_desnormalizacion_top_categorias.sql) | [`evidencias/parte2_desnormalizacion_top_categorias.txt`](evidencias/parte2_desnormalizacion_top_categorias.txt) |
| 3. Informe breve | [`docs/Informe_TP_U4_Moran.pdf`](docs/Informe_TP_U4_Moran.pdf) | — |

## Cómo se corre

Desde la raíz del repositorio, en Git Bash (usa el `pgpass.conf` de postgres; no pide ni guarda contraseñas):

```bash
bash trabajos-practicos/unidad4_tp_semana8/ejecutar_tp_u4.sh
```

Recrea `foodstore_tp4` con `sql/01_schema.sql`, `02_data.sql`, `02b_carga_masiva_rapida.sql` (200 000 pedidos de los últimos dos años), `03_restricciones.sql` y el estado del pedido de la U7. Después corre los dos scripts y deja la salida en `evidencias/`. Los dos scripts se pueden volver a correr. Los errores de la Parte 1 son a propósito: son la anomalía de inserción y la regla {lote, depósito} → responsable que el esquema nuevo tiene que rechazar.

## Adaptaciones al esquema real

La consulta de la consigna usa nombres genéricos. En Food Store:

- No hay `dp.subtotal`: el monto de una línea es `cantidad * precio_unitario`.
- Las claves se llaman `id_producto`, `id_categoria` e `id_pedido`.
- `pedido` y `detalle_pedido` no tienen borrado lógico. Lo que no cuenta como venta es un pedido `CANCELADO` (columna `estado`, agregada en la U7).
- `pedido.fecha` es `TIMESTAMPTZ`: «el día» es la fecha en la hora de Argentina (`tp4.dia_venta` y `tp4.hoy`).
- Las maestras `lote` y `deposito` que la consigna da por existentes se crean en el esquema `tp4` con lo mínimo. Los responsables 801, 802 y 803 son usuarios de prueba con datos inventados.

El caso `control_lote_almacen` también está resuelto, con más datos, en la U4 del TPI ([`../unidad4_fnbc_desnormalizacion`](../unidad4_fnbc_desnormalizacion)). Este TP responde la guía de la Semana 8 con la instancia de ejemplo de la consigna y los dos scripts que pide como entregables.

## Declaración de uso de IA (DUIA)

| Campo | Detalle |
|---|---|
| Herramienta | Claude (Anthropic), desde claude.ai. |
| Prompt utilizado | La guía del TP en PDF y el esquema de Food Store del repositorio. |
| Qué generó | Los dos scripts SQL, `ejecutar_tp_u4.sh`, este README y el borrador del informe, escrito con los números de mis evidencias. |
| Qué se aceptó | Los scripts, después de probarlos en un entorno con PostgreSQL 16 y de correrlos en mi PC. |
| Qué se modificó o descartó, y por qué | La consulta de la consigna se adaptó al esquema real (ver arriba). Se descartó `INSERT ... ON CONFLICT` para las restas del resumen: PostgreSQL controla el `CHECK` sobre la fila propuesta antes de detectar el conflicto, el mismo error que apareció en la U4 del TPI. |
| Verificación realizada | Corrí `ejecutar_tp_u4.sh` en mi PC y controlé el resumen: 0 tuplas perdidas y 0 espurias en la Parte 1; en la Parte 2, auditoría vacía sobre la base migrada, el mismo top 5 por los dos caminos y la auditoría en 0 después de cada prueba de sincronización. Nunca le pasé a la IA datos personales ni contraseñas. |
