# Tareas — U4 · Migración a BCNF

- [x] 1. Cargar el esquema heredado con datos de prueba (`01_esquema_heredado.sql`). _Requisitos: REQ-01_
- [x] 2. Validar DF1, DF2, L → D y L → R sobre los datos (`02_validar_dependencias.sql`). _Requisitos: REQ-01_
- [x] 3. Migración en una transacción con verificación previa, control de la reunión, trigger de DF1, respaldo y vista; ensayo con `ROLLBACK` y aplicación con `COMMIT` (`03_migracion_fnbc.sql`). _Requisitos: REQ-02, REQ-03, REQ-04, REQ-05, REQ-06, REQ-08_
- [x] 4. Plan de reversión desde los datos actuales, ensayado con `ROLLBACK` (`04_reversion_fnbc.sql`). _Requisitos: REQ-07, REQ-09_
- [x] 5. Repetir las anomalías y probar el trigger de DF1 sobre el esquema nuevo, dentro de `BEGIN … ROLLBACK` (`05_pruebas_esquema_nuevo.sql`). _Requisitos: REQ-06, REQ-08_
