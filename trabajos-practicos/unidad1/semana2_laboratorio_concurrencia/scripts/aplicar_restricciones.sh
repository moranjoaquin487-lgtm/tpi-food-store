#!/usr/bin/env bash
# Parte 1: aplica food-store/restricciones.sql sobre la copia de trabajo, siguiendo el protocolo.
#   bash scripts/aplicar_restricciones.sh              prueba: BEGIN, aplica, corre los casos y hace ROLLBACK
#   bash scripts/aplicar_restricciones.sh --confirmar  respaldo, aplica con COMMIT y vuelve a correr los casos
set -u
cd "$(dirname "$0")/.."
export PGUSER="${PGUSER:-postgres}" PGCLIENTENCODING=UTF8 PGOPTIONS="-c client_min_messages=warning"
DB=foodstore_trabajo
mkdir -p evidencias backups
for f in food-store/restricciones.sql food-store/pruebas_restricciones.sql; do
  [ -f "$f" ] || { echo "Falta $f (lo genera OpenCode en la Parte 1)."; exit 1; }
done

if [ "${1:-}" = "--confirmar" ]; then
  RESPALDO="backups/${DB}_$(date +%Y%m%d_%H%M).dump"
  pg_dump -F c -f "$RESPALDO" "$DB" || { echo "No se pudo respaldar: no se aplica nada."; exit 1; }
  echo ">> Respaldo: $RESPALDO"
  psql -d "$DB" -a -v ON_ERROR_STOP=1 > evidencias/parte1_2_aplicado.txt 2>&1 <<'SQL'
SELECT current_database();
BEGIN;
\i food-store/restricciones.sql
COMMIT;
SQL
  if [ $? -ne 0 ]; then echo "Falló la aplicación: no se confirmó nada (ver evidencias/parte1_2_aplicado.txt)."; exit 1; fi
  # Los casos corren dentro de BEGIN ... ROLLBACK para no dejar datos de prueba.
  psql -d "$DB" -a -v ON_ERROR_ROLLBACK=on > evidencias/parte1_3_pruebas.txt 2>&1 <<'SQL'
BEGIN;
\i food-store/pruebas_restricciones.sql
ROLLBACK;
SQL
  echo ">> Aplicado con COMMIT. Casos de prueba: evidencias/parte1_3_pruebas.txt"
else
  # ON_ERROR_ROLLBACK: psql pone un SAVEPOINT antes de cada sentencia, así un caso que falla
  # (como se espera en los inválidos) no aborta la transacción entera.
  psql -d "$DB" -a -v ON_ERROR_ROLLBACK=on > evidencias/parte1_1_prueba_con_rollback.txt 2>&1 <<'SQL'
SELECT current_database();
BEGIN;
\i food-store/restricciones.sql
\i food-store/pruebas_restricciones.sql
ROLLBACK;
SQL
  echo ">> Prueba terminada con ROLLBACK: evidencias/parte1_1_prueba_con_rollback.txt"
  echo "   Si cada caso dio lo que dice la spec, corré: bash scripts/aplicar_restricciones.sh --confirmar"
fi
