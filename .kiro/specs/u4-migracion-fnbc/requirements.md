# Requisitos — U4 · Migración de `control_lote_almacen` a BCNF

Esquema heredado: `control_lote_almacen (lote_id, deposito_id, responsable_control_id)`, PK `(lote_id, deposito_id)`.
Reglas de negocio: **DF1** {lote, depósito} → responsable y **DF2** responsable → depósito. DF2 viola BCNF.
Abreviaturas: L = `lote_id`, D = `deposito_id`, R = `responsable_control_id`.

| ID | Requisito (EARS) | Se prueba con |
|---|---|---|
| REQ-01 | WHEN se validan los datos heredados, THE SYSTEM SHALL comprobar fila por fila que DF1 y DF2 se cumplen y que L → D y L → R no se cumplen. | `02_validar_dependencias.sql` |
| REQ-02 | IF algún responsable aparece en más de un depósito, THEN THE SYSTEM SHALL cancelar la migración antes de crear cualquier tabla. | `03_migracion_fnbc.sql`, verificación previa |
| REQ-03 | WHEN se ejecuta la migración, THE SYSTEM SHALL crear `responsable_deposito` (R, D; clave R) y `control_lote` (L, R; clave {L, R}) y copiar los datos dentro de una sola transacción. | `03_migracion_fnbc.sql` con `accion=COMMIT` (evidencia: `03b_migracion_aplicada.txt`) |
| REQ-04 | IF la reunión de las dos tablas tiene tuplas perdidas o espurias respecto de la tabla original, THEN THE SYSTEM SHALL deshacer la migración completa. | `03_migracion_fnbc.sql` con `accion=COMMIT` (evidencia: `03b_migracion_aplicada.txt`: 0 y 0) |
| REQ-05 | WHERE la migración se corre sin `accion=COMMIT`, THE SYSTEM SHALL ejecutar todos los pasos y terminar con `ROLLBACK`, sin dejar cambios. | `03_migracion_fnbc.sql` sin `-v accion=COMMIT` (evidencia: `03a_ensayo_migracion.txt`) |
| REQ-06 | WHILE DF1 no esté preservada por la descomposición, WHEN se inserta o modifica un control o el depósito de un responsable, THE SYSTEM SHALL rechazar un segundo responsable del mismo depósito para el mismo lote. | `05_pruebas_esquema_nuevo.sql` |
| REQ-07 | WHEN se ejecuta el plan de reversión, THE SYSTEM SHALL reconstruir `control_lote_almacen` a partir de los datos actuales de las tablas nuevas. | `04_reversion_fnbc.sql` (evidencia: `04_ensayo_reversion.txt`) |
| REQ-08 | THE SYSTEM SHALL conservar la tabla original como `control_lote_almacen_respaldo` y ofrecer la vista `v_control_lote_almacen` para las lecturas viejas. | `03_migracion_fnbc.sql` con `accion=COMMIT` (evidencia: `03b_migracion_aplicada.txt`), `05_pruebas_esquema_nuevo.sql` |
| REQ-09 | WHEN se ejecuta el plan de reversión, IF hay responsables que no controlan ningún lote, THEN THE SYSTEM SHALL guardarlos en una tabla separada para no perderlos. | `04_reversion_fnbc.sql` (evidencia: `04_ensayo_reversion.txt`) |
