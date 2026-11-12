#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

DB_ORIG="foodstore"
DB_TEST="foodstore_restore_test"
BACKUP_DIR="backups"
LOG_DIR="logs"
LOG_FILE="$LOG_DIR/restore_test.log"

if [[ "$DB_TEST" == "$DB_ORIG" ]]; then
  echo "ERROR: restauración prohibida sobre la base principal ($DB_ORIG)." >&2
  exit 1
fi

mkdir -p "$LOG_DIR"

LATEST_DUMP="$(ls -1t "$BACKUP_DIR"/${DB_ORIG}_*.dump 2>/dev/null | head -n 1 || true)"
if [[ -z "$LATEST_DUMP" ]]; then
  echo "ERROR: no se encontró un dump en $BACKUP_DIR" >&2
  exit 1
fi

START_TS="$(date +%s)"
RPO_SOURCE_TS="$(basename "$LATEST_DUMP" | sed -E 's/^foodstore_([0-9]{8}_[0-9]{6})\.dump$/\1/')"
echo "[$(date -Is)] Inicio restauración de prueba desde $LATEST_DUMP hacia $DB_TEST" >> "$LOG_FILE"

# Conteos previos en la base principal (referencia para verificar igualdad de filas)
COUNT_PRODUCTS_ORIG="$(psql -d "$DB_ORIG" -Atc 'SELECT count(*) FROM products;')"
COUNT_ORDERS_ORIG="$(psql -d "$DB_ORIG" -Atc 'SELECT count(*) FROM orders;')"
COUNT_DETAILS_ORIG="$(psql -d "$DB_ORIG" -Atc 'SELECT count(*) FROM order_details;')"
COUNT_CUSTOMERS_ORIG="$(psql -d "$DB_ORIG" -Atc 'SELECT count(*) FROM customers;')"

# Recrear base de prueba (nunca la principal)
psql -d postgres -v ON_ERROR_STOP=1 -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DB_TEST' AND pid <> pg_backend_pid();" >/dev/null
psql -d postgres -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS \"$DB_TEST\";"
psql -d postgres -v ON_ERROR_STOP=1 -c "CREATE DATABASE \"$DB_TEST\";"

pg_restore -d "$DB_TEST" --clean --if-exists --no-owner --no-privileges "$LATEST_DUMP" >/dev/null 2>&1 || pg_restore -d "$DB_TEST" --no-owner --no-privileges "$LATEST_DUMP" >/dev/null

# Conteos en base restaurada
COUNT_PRODUCTS_TEST="$(psql -d "$DB_TEST" -Atc 'SELECT count(*) FROM products;')"
COUNT_ORDERS_TEST="$(psql -d "$DB_TEST" -Atc 'SELECT count(*) FROM orders;')"
COUNT_DETAILS_TEST="$(psql -d "$DB_TEST" -Atc 'SELECT count(*) FROM order_details;')"
COUNT_CUSTOMERS_TEST="$(psql -d "$DB_TEST" -Atc 'SELECT count(*) FROM customers;')"

INVALID_PRODUCTS="$(psql -d "$DB_TEST" -Atc "SELECT count(*) FROM products WHERE product_id IS NULL OR price < 0;")"
INVALID_DETAILS="$(psql -d "$DB_TEST" -Atc "SELECT count(*) FROM order_details WHERE order_id IS NULL OR product_id IS NULL OR quantity <= 0 OR unit_price < 0;")"

END_TS="$(date +%s)"
RTO_SECONDS=$((END_TS - START_TS))
NOW_TS="$(date +"%Y%m%d_%H%M%S")"

echo "Conteos origen: products=$COUNT_PRODUCTS_ORIG orders=$COUNT_ORDERS_ORIG order_details=$COUNT_DETAILS_ORIG customers=$COUNT_CUSTOMERS_ORIG" >> "$LOG_FILE"
echo "Conteos restaurados: products=$COUNT_PRODUCTS_TEST orders=$COUNT_ORDERS_TEST order_details=$COUNT_DETAILS_TEST customers=$COUNT_CUSTOMERS_TEST" >> "$LOG_FILE"
echo "Invalidos: productos=$INVALID_PRODUCTS detalles=$INVALID_DETAILS" >> "$LOG_FILE"
echo "RTO (segundos)=$RTO_SECONDS" >> "$LOG_FILE"
echo "RPO (timestamp dump)=$RPO_SOURCE_TS ; verificación ejecutada=$NOW_TS" >> "$LOG_FILE"

if [[ "$COUNT_PRODUCTS_ORIG" -ne "$COUNT_PRODUCTS_TEST" || \
      "$COUNT_ORDERS_ORIG" -ne "$COUNT_ORDERS_TEST" || \
      "$COUNT_DETAILS_ORIG" -ne "$COUNT_DETAILS_TEST" || \
      "$COUNT_CUSTOMERS_ORIG" -ne "$COUNT_CUSTOMERS_TEST" ]]; then
  echo "[$(date -Is)] ERROR: diferencias de filas entre $DB_ORIG y $DB_TEST" >> "$LOG_FILE"
  exit 1
fi

if [[ "$INVALID_PRODUCTS" -ne 0 || "$INVALID_DETAILS" -ne 0 ]]; then
  echo "[$(date -Is)] ERROR: se encontraron productos/detalles inválidos en $DB_TEST" >> "$LOG_FILE"
  exit 1
fi

echo "[$(date -Is)] OK restauración de prueba verificada. RTO=${RTO_SECONDS}s RPO_dump=$RPO_SOURCE_TS" >> "$LOG_FILE"
exit 0
