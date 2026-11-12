PRAGMA foreign_keys = ON;
-- C6 · Tablet: se corta la señal y la tablet reenvía la solicitud de C5 con el mismo UUID.
SELECT COUNT(*) AS solicitudes_antes FROM cola_sync;

-- Error esperado: la clave primaria (solicitud_uuid) no deja duplicarla
INSERT INTO cola_sync (solicitud_uuid, id_local)
VALUES ('a0c50001-0000-4000-8000-000000000000', 'b0c50000-0000-4000-8000-000000000000');

SELECT COUNT(*) AS solicitudes_despues FROM cola_sync;

-- Tampoco se puede volver a poner en PENDIENTE para que se reevalúe (trigger de estado final)
UPDATE cola_sync SET estado = 'PENDIENTE', motivo = NULL, evaluada_con = NULL
 WHERE solicitud_uuid = 'a0c50001-0000-4000-8000-000000000000';

SELECT substr(solicitud_uuid, 1, 8) AS solicitud, estado FROM cola_sync ORDER BY rowid;
