#!/usr/bin/env bash
# Code review U4-U7 — Aplica las correcciones que viven en la base y comprueba los hallazgos
# #1, #5, #7 y #10. Salida: evidencias/code_review_u4_u7.txt. Desde Git Bash, en la raíz del repo:
#   bash docs/comprobar_hallazgos_u4_u7.sh
set -euo pipefail
cd "$(dirname "$0")/.."
export DB="${DB:-foodstore}" PGUSER="${PGUSER:-postgres}"
OUT=evidencias/code_review_u4_u7.txt
mkdir -p evidencias
U5=trabajos-practicos/unidad5_seguridad
{
echo "===== Se aplican las correcciones en la base: 01_auth_funciones.sql (#1) y 01_estado_pedido.sql (#7)"
psql -X -d "$DB" -v ON_ERROR_STOP=1 --single-transaction -q -f "$U5/sql/01_auth_funciones.sql"
psql -X -d "$DB" -v ON_ERROR_STOP=1 --single-transaction -q -f trabajos-practicos/unidad7_nosql/01_estado_pedido.sql
echo
echo "===== #1, #7 y #10 en la base (todo dentro de BEGIN ... ROLLBACK)"
psql -X -d "$DB" -f docs/comprobar_hallazgos_u4_u7.sql
echo
echo "===== #5 Los controles del simulacro, con un log de prueba (en una carpeta temporal)"
t="$(mktemp -d)"; mkdir -p "$t/docs" "$t/evidencias/privado"
sed -n '/^# Los controles cortan/,/^echo ">> Listo/p' "$U5/scripts/simulacro_incidente.sh" > "$t/control.sh"
sed -n '/^echo ">> Control: mails/,/^echo ">> Listo/p' docs/code_review_u4_u7_antes/simulacro_incidente.sh > "$t/control_anterior.sh"
echo "conexión de anon_1234567890@ejemplo.test" > "$t/docs/log_simulacro_anonimizado.txt"
echo "intento de usuario007@foodstore.test"     >> "$t/docs/log_simulacro_anonimizado.txt"
echo "SELECT fn_autenticar('anon', '***')"     > "$t/evidencias/privado/log_simulacro_original.txt"
echo "-- Log de prueba con un mail sin anonimizar. Versión anterior:"
(cd "$t" && bash control_anterior.sh) && echo "   código de salida: 0" || echo "   código de salida: $?"
echo "-- Versión corregida:"
(cd "$t" && bash control.sh) 2>&1 && echo "   código de salida: 0" || echo "   código de salida: $?"
rm -rf "$t"
} > "$OUT" 2>&1
echo ">> Listo: $OUT"
echo ">> Ahora la verificación de permisos completa, con el control nuevo de PUBLIC (#10):"
psql -X -d "$DB" -a -f "$U5/sql/verificacion_permisos.sql" > "$U5/evidencias/A_03_verificacion_permisos.txt" 2>&1
echo ">> Listo: $U5/evidencias/A_03_verificacion_permisos.txt"
