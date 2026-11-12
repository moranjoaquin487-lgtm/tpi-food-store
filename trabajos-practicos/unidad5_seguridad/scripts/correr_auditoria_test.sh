#!/usr/bin/env bash
# U5 · Parte B — Ejecuta auditoria_test.sql como app_web, provoca un inicio de sesión
# fallido y guarda el fragmento de log correspondiente en docs/log_auditoria_prueba.txt.
#
# Requisitos: haber corrido configurar_auditoria.sql y haberle puesto contraseña a app_web.
# La contraseña de app_web no se escribe en ningún archivo: se toma de APP_WEB_PASS,
# de pgpass.conf o se pide por teclado.
set -euo pipefail
cd "$(dirname "$0")/.."
export DB="${DB:-foodstore}" PGUSER="${PGUSER:-postgres}"
APP_HOST="${APP_HOST:-localhost}"
# El primer Python que funciona de verdad: en Windows, python3 puede ser el acceso directo a la Microsoft Store.
PY=""; for c in python3 python py; do "$c" -c "import sys" >/dev/null 2>&1 && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "   ERROR: no se encontró Python"; exit 1; }
mkdir -p evidencias docs

if [ -z "${APP_WEB_PASS+x}" ]; then read -r -s -p "Contraseña de app_web (Enter = usar pgpass.conf): " APP_WEB_PASS; echo; fi

marca="auditoria_test_$(date +%Y%m%d_%H%M%S)"
psql -X -d "$DB" -qc "DO \$\$ BEGIN RAISE LOG 'MARCA INICIO $marca'; END \$\$;"

echo ">> Secuencia de prueba como app_web"
PGPASSWORD="$APP_WEB_PASS" psql -X -h "$APP_HOST" -U app_web -d "$DB" -a -f sql/auditoria_test.sql \
    > evidencias/B_auditoria_test_salida.txt 2>&1

echo ">> Intento de inicio de sesión con contraseña incorrecta (se espera que falle)"
PGPASSWORD="contrasena-incorrecta" psql -X -h "$APP_HOST" -U app_web -d "$DB" -c "SELECT 1" \
    >> evidencias/B_auditoria_test_salida.txt 2>&1 || true

sleep 1
psql -X -d "$DB" -qc "DO \$\$ BEGIN RAISE LOG 'MARCA FIN $marca'; END \$\$;"
sleep 1

"$PY" scripts/extraer_log.py "$marca" > docs/log_auditoria_prueba.txt
echo ">> Listo: docs/log_auditoria_prueba.txt ($(wc -l < docs/log_auditoria_prueba.txt) líneas)"
