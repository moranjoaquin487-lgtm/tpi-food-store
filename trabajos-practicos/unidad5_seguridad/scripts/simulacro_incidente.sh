#!/usr/bin/env bash
# U5 · Parte C — Simulacro de incidente (SOLO contra la base propia de desarrollo).
#  1. Ejecuta sql/simulacro_incidente.sql conectado como app_web.
#  2. Verifica, como postgres, si el escalamiento falló.
#  3. Extrae el log de toda la secuencia y lo anonimiza.
# El log original (con mails) queda en evidencias/privado/, que no se sube al repositorio.
set -euo pipefail
cd "$(dirname "$0")/.."
export DB="${DB:-foodstore}" PGUSER="${PGUSER:-postgres}"
APP_HOST="${APP_HOST:-localhost}"
# El primer Python que funciona de verdad: en Windows, python3 puede ser el acceso directo a la Microsoft Store.
PY=""; for c in python3 python py; do "$c" -c "import sys" >/dev/null 2>&1 && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "   ERROR: no se encontró Python"; exit 1; }
mkdir -p evidencias/privado docs

if [ -z "${APP_WEB_PASS+x}" ]; then read -r -s -p "Contraseña de app_web (Enter = usar pgpass.conf): " APP_WEB_PASS; echo; fi

VERIF="SELECT pg_has_role('app_web', 'admin_datos', 'MEMBER')         AS app_web_es_admin,
              pg_has_role('rol_app_lectura', 'admin_datos', 'MEMBER') AS rol_app_lectura_es_admin,
              (SELECT COUNT(*) FROM pg_auth_members WHERE roleid = 'admin_datos'::regrole) AS miembros_de_admin_datos;"

{ echo "===== Antes del simulacro ====="; psql -X -d "$DB" -c "$VERIF"; } > evidencias/C_simulacro_verificacion.txt

marca="simulacro_$(date +%Y%m%d_%H%M%S)"
psql -X -d "$DB" -qc "DO \$\$ BEGIN RAISE LOG 'MARCA INICIO $marca'; END \$\$;"

echo ">> Ejecutando la secuencia como app_web"
PGPASSWORD="$APP_WEB_PASS" psql -X -h "$APP_HOST" -U app_web -d "$DB" -a -f sql/simulacro_incidente.sql \
    > evidencias/C_simulacro_salida.txt 2>&1

sleep 1
psql -X -d "$DB" -qc "DO \$\$ BEGIN RAISE LOG 'MARCA FIN $marca'; END \$\$;"
sleep 1

{ echo; echo "===== Después del simulacro ====="; psql -X -d "$DB" -c "$VERIF"
  echo "===== Intentos registrados en auditoria_seguridad durante el simulacro ====="
  psql -X -d "$DB" -c "SELECT evento, exito, rol_bd, COUNT(*) AS intentos
                         FROM auditoria_seguridad
                        WHERE momento > now() - interval '5 minutes'
                        GROUP BY 1, 2, 3 ORDER BY 1, 2;"
} >> evidencias/C_simulacro_verificacion.txt

"$PY" scripts/extraer_log.py "$marca" > evidencias/privado/log_simulacro_original.txt
"$PY" scripts/anonimizar_log.py < evidencias/privado/log_simulacro_original.txt > docs/log_simulacro_anonimizado.txt

# Los controles cortan el script si fallan (code review U4-U7, hallazgo #5): antes solo
# mostraban el número, y una falla en la anonimización podía pasar sin que nadie la viera.
echo ">> Control: mails sin anonimizar en el log anonimizado (se espera 0)"
mails=$({ grep -oE "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}" docs/log_simulacro_anonimizado.txt || true; } | { grep -vc "@ejemplo\.test$" || true; })
echo "$mails"
echo ">> Control: contraseñas probadas que llegaron al log ORIGINAL (se espera 0)"
claves=$(grep -cE "'(123456|password|foodstore|Prueba-0[0-9]{2})'" evidencias/privado/log_simulacro_original.txt || true)
echo "$claves"
if [ "$mails" != "0" ] || [ "$claves" != "0" ]; then
    echo "   ERROR: el log anonimizado tiene mails reales o el original tiene contraseñas. No se lo des a la IA." >&2
    exit 1
fi
echo ">> Listo: docs/log_simulacro_anonimizado.txt y evidencias/C_simulacro_verificacion.txt"
