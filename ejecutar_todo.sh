#!/usr/bin/env bash
# Recrea la base $DB (por defecto tpi_food_store), corre todos los scripts en orden y guarda la salida en evidencias/.
set -u
DB="${DB:-tpi_food_store}"
export PGUSER="${PGUSER:-postgres}"
cd "$(dirname "$0")"
mkdir -p evidencias

echo ">> Recreando la base $DB"
dropdb --if-exists "$DB" && createdb "$DB" || exit 1

# Construcción: sin errores y en una sola transacción.
estrictos=(01_schema 02_data 02b_carga_masiva_rapida 03_restricciones 04_indices 05_vistas 05b_materializadas 06_funciones_procedimientos)
for s in "${estrictos[@]}"; do
  echo ">> $s"
  psql -d "$DB" -q -v ON_ERROR_STOP=1 --single-transaction -f "sql/$s.sql" \
       > "evidencias/$s.txt" 2>&1 || { echo "   ERROR en $s (ver evidencias/$s.txt)"; exit 1; }
done

# Pruebas: incluyen errores esperados, se muestran con eco (-a).
pruebas=(02c_verificacion_carga_masiva 03b_pruebas_restricciones 07_consultas 08_transacciones 09_soft_delete 10_auditoria_precios)
for s in "${pruebas[@]}"; do
  echo ">> $s"
  psql -d "$DB" -a -f "sql/$s.sql" > "evidencias/$s.txt" 2>&1
done

echo ">> Listo. Revisá la carpeta evidencias/."
