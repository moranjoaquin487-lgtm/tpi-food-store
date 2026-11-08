#!/usr/bin/env bash
# Parte 2, verificación extra: la alternativa que propuso la IA para el escenario 2.
# La sesión A sigue en READ COMMITTED pero toma LOCK TABLE pedido IN SHARE MODE antes de contar.
#   bash scripts/verificar_lock_table.sh
set -u
cd "$(dirname "$0")/.."
export PGUSER="${PGUSER:-postgres}" PGCLIENTENCODING=UTF8 PGOPTIONS="-c client_min_messages=warning"
DB=foodstore_trabajo
OUT=evidencias/e2_verificacion_lock_table.txt
mkdir -p evidencias
base=$(psql -d "$DB" -tAc "SELECT current_database()" 2>/dev/null)
[ "$base" = "$DB" ] || { echo "No hay conexión con $DB: cargá PGPASSWORD."; exit 1; }
maximo=$(psql -d "$DB" -tAc "SELECT max(id) FROM pedido")
ta=$(mktemp); tb=$(mktemp)
psql -d "$DB" -a > "$ta" 2>&1 <<'SQL' &
-- Sesión A: READ COMMITTED con LOCK TABLE pedido IN SHARE MODE.
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
LOCK TABLE pedido IN SHARE MODE;
SELECT COUNT(*) AS primer_conteo FROM pedido p JOIN cliente c ON c.id = p.cliente_id WHERE c.email = 'ana.gomez@mail.com';
SELECT pg_sleep(1.5);  -- mientras tanto, la sesión B intenta registrar un pedido nuevo de Ana
SELECT COUNT(*) AS segundo_conteo FROM pedido p JOIN cliente c ON c.id = p.cliente_id WHERE c.email = 'ana.gomez@mail.com';
COMMIT;
SQL
sleep 0.5
psql -d "$DB" -a > "$tb" 2>&1 <<'SQL'
-- Sesión B: el mismo INSERT del escenario 2; se mide cuánto tarda.
\timing on
\i food-store/concurrencia/e2_B.sql
SQL
wait
{
  echo "===== Escenario 2 · Lectura fantasma · READ COMMITTED con LOCK TABLE pedido IN SHARE MODE ====="
  echo
  echo "----- SESIÓN A -----"; cat "$ta"
  echo
  echo "----- SESIÓN B (arranca 0,5 s después) -----"; cat "$tb"
} > "$OUT"
rm -f "$ta" "$tb"
psql -d "$DB" -tAc "DELETE FROM pedido WHERE id > $maximo" >/dev/null
echo "(Después del escenario se borró el pedido que agregó la sesión B)" >> "$OUT"
echo ">> $OUT"
