#!/usr/bin/env bash
# TP Unidad 4 (Semana 8): FNBC y desnormalización controlada.
# Arma una copia de prueba de Food Store desde cero y corre los dos scripts del TP.
# La salida queda en evidencias/. No toca la base foodstore.
#
# Desde la raíz del repositorio, en Git Bash:
#   bash trabajos-practicos/unidad4_tp_semana8/ejecutar_tp_u4.sh
# Usa el pgpass.conf de postgres de la segunda entrega: no pide ni guarda contraseñas.
set -euo pipefail
cd "$(dirname "$0")"
RAIZ="$(cd ../.. && pwd)"
export PGUSER="${PGUSER:-postgres}"
# Los scripts están en UTF-8. En Git Bash, psql puede tomar la página de códigos de la consola
# (WIN1252) y cargar «Almacén» como «AlmacÃ©n»: se fija la codificación.
export PGCLIENTENCODING=UTF8
DB="${DB:-foodstore_tp4}"
case "$DB" in
    foodstore|tpi_food_store) echo "DB tiene que ser una copia de prueba, no $DB"; exit 1 ;;
esac
mkdir -p evidencias

cargar() {
    PGOPTIONS="-c client_min_messages=warning" psql -X -q -d "$DB" -v ON_ERROR_STOP=1 \
        --single-transaction -f "$1" > /dev/null || { echo "   ERROR en $1"; exit 1; }
}

echo ">> Copia de prueba $DB, armada con los scripts del proyecto"
dropdb --if-exists "$DB"
createdb "$DB"
for s in 01_schema 02_data 02b_carga_masiva_rapida 03_restricciones; do
    echo "   sql/$s.sql"
    cargar "$RAIZ/sql/$s.sql"
done
echo "   trabajos-practicos/unidad7_nosql/01_estado_pedido.sql (estado del pedido)"
cargar "$RAIZ/trabajos-practicos/unidad7_nosql/01_estado_pedido.sql"

echo ">> Parte 1: FNBC sobre control_lote_almacen"
psql -X -d "$DB" -a -f sql/tp_fnbc_control_lote.sql > evidencias/parte1_fnbc_control_lote.txt 2>&1 \
    || { echo "   ERROR (ver evidencias/parte1_fnbc_control_lote.txt)"; exit 1; }

echo ">> Parte 2: top 5 de categorías con desnormalización controlada"
psql -X -d "$DB" -a -f sql/tp_desnormalizacion_top_categorias.sql > evidencias/parte2_desnormalizacion_top_categorias.txt 2>&1 \
    || { echo "   ERROR (ver evidencias/parte2_desnormalizacion_top_categorias.txt)"; exit 1; }

# Resumen para controlar de un vistazo (psql en Windows escribe con CRLF)
p1=evidencias/parte1_fnbc_control_lote.txt
p2=evidencias/parte2_desnormalizacion_top_categorias.txt
valor() { grep -A2 -- "$2" "$1" | tail -1 | tr -d '\r' | tr -s ' ' | sed 's/^ //'; }
echo
echo "================ Resumen ================"
echo "Parte 1"
echo "  errores (se espera 2: inserción en el esquema original y DF1 en el nuevo): $(grep -c '^psql.*ERROR' "$p1" || true)"
echo "  tuplas perdidas | espurias (se espera 0 | 0): $(valor "$p1" 'tuplas_perdidas | tuplas_espurias')"
echo "Parte 2"
echo "  pedidos | líneas | pedidos de hoy | hoy: $(valor "$p2" 'pedidos | lineas')"
echo "  tiempos (antes, después): $(grep 'Execution Time' "$p2" | tr -d '\r' | sed 's/.*: //' | paste -sd ',' -)"
echo "  errores (se espera 0): $(grep -c '^psql.*ERROR' "$p2" || true)"
echo "  auditoría sobre la base migrada (se espera 0 filas): $(grep -A6 'Auditoría sobre la base migrada' "$p2" | grep -oE '\([0-9]+ (rows?|filas?)\)' | head -1)"
echo "  diferencias entre los dos caminos (se espera 0): $(valor "$p2" ' diferencias')"
echo "  auditorías tras cada prueba (se espera 0 0 0 0 0): $(grep -A2 '^ auditoria_tras' "$p2" | grep -E '^ +[0-9]+' | tr -d '\r ' | paste -sd ' ' -)"
echo "Evidencias: trabajos-practicos/unidad4_tp_semana8/evidencias/"
