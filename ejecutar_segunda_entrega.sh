#!/usr/bin/env bash
# Segunda entrega del TPI (Unidades 4 a 8): arma la base y corre todo en orden.
# Cada paso guarda su salida en la carpeta evidencias/ de su unidad.
#
# Antes de correrlo, una sola vez (ver PASOS):
#   - pgpass.conf con la contraseña de postgres
#   - en psql:  \password app_web   (la contraseña nunca se escribe en un archivo)
#
# Variables opcionales:
#   DB=foodstore      base principal (la U6 exige este nombre)
#   NUEVA=1           recrea la base desde cero con los scripts de la primera entrega
#   MONGO_URI=...     conexión a MongoDB (por defecto mongodb://localhost:27017)
# La U8 (TP8) ya está hecha en trabajos-practicos/unidad8/food-store y tiene su propio script.
#   APP_WEB_PASS=...  contraseña de app_web; si no está, se pide por teclado
set -euo pipefail
cd "$(dirname "$0")"
RAIZ="$(pwd)"
export DB="${DB:-foodstore}" PGUSER="${PGUSER:-postgres}"
TP="$RAIZ/trabajos-practicos"

paso() { echo; echo "================ $* ================"; }
# construccion ARCHIVO SALIDA: en una sola transacción y sin errores
construccion() { PGOPTIONS="-c client_min_messages=warning" psql -X -d "$DB" -v ON_ERROR_STOP=1 --single-transaction -a -f "$1" > "$2" 2>&1 \
                 || { echo "   ERROR en $1 (ver $2)"; exit 1; }; }
# prueba ARCHIVO SALIDA [args]: muestra cada sentencia; incluye errores esperados
prueba() { local f="$1" o="$2"; shift 2; psql -X -d "$DB" -a "$@" -f "$f" > "$o" 2>&1 || true; }

if [ -z "${APP_WEB_PASS+x}" ]; then
    read -r -s -p "Contraseña de app_web (Enter = usar pgpass.conf): " APP_WEB_PASS; echo
fi
export APP_WEB_PASS

# ---------------------------------------------------------------------------------------
paso "Base $DB"
if [ "${NUEVA:-0}" = "1" ] || ! psql -X -d "$DB" -c "SELECT 1" >/dev/null 2>&1; then
    echo ">> Se crea $DB desde cero con los scripts de la primera entrega (en una carpeta temporal,"
    echo "   para no pisar las evidencias de la primera entrega)"
    tmp="$(mktemp -d)"; cp -r sql ejecutar_todo.sh "$tmp/"
    (cd "$tmp" && DB="$DB" ./ejecutar_todo.sh > /dev/null) || { echo "   ERROR al crear la base"; exit 1; }
    rm -rf "$tmp"
fi

# ---------------------------------------------------------------------------------------
paso "U4 · FNBC, migración reversible y desnormalización"
cd "$TP/unidad4_fnbc_desnormalizacion"; mkdir -p evidencias
construccion sql/01_esquema_heredado.sql            evidencias/01_esquema_heredado.txt
prueba       sql/02_validar_dependencias.sql        evidencias/02_validar_dependencias.txt
prueba       sql/03_migracion_fnbc.sql              evidencias/03a_ensayo_migracion.txt
psql -X -d "$DB" -a -v accion=COMMIT -f sql/03_migracion_fnbc.sql > evidencias/03b_migracion_aplicada.txt 2>&1 \
    || { echo "   ERROR en la migración (ver evidencias/03b_migracion_aplicada.txt)"; exit 1; }
prueba       sql/04_reversion_fnbc.sql              evidencias/04_ensayo_reversion.txt
prueba       sql/05_pruebas_esquema_nuevo.sql       evidencias/05_pruebas_esquema_nuevo.txt
construccion sql/06_desnormalizacion_top_categorias.sql evidencias/06_desnormalizacion.txt
prueba       sql/07_pruebas_desnormalizacion.sql    evidencias/07_pruebas_desnormalizacion.txt
prueba       sql/08_mediciones.sql                  evidencias/08_mediciones.txt
prueba       sql/09_reversion_desnormalizacion.sql  evidencias/09_ensayo_reversion_desnormalizacion.txt

# ---------------------------------------------------------------------------------------
paso "U5 · Roles, auditoría, simulacro y anonimización"
cd "$TP/unidad5_seguridad"; mkdir -p evidencias docs
construccion sql/00_usuarios_prueba.sql   evidencias/A_00_usuarios_prueba.txt
construccion sql/01_auth_funciones.sql    evidencias/A_01_auth_funciones.txt
construccion sql/roles.sql                evidencias/A_02_roles.txt
psql -X -d "$DB" -c "SELECT rolname FROM pg_authid WHERE rolname = 'app_web' AND rolpassword IS NULL" -At \
    | grep -q app_web && echo "   AVISO: app_web no tiene contraseña. Poné una con \\password app_web (ver PASOS)"
echo ">> Parte B: configuración de la auditoría"
# ALTER SYSTEM no puede ir dentro de una transacción: va sin --single-transaction, pero con
# ON_ERROR_STOP, para que un error corte acá (code review U4-U7, hallazgo #4).
psql -X -d "$DB" -v ON_ERROR_STOP=1 -a -f sql/configurar_auditoria.sql > evidencias/B_configuracion.txt 2>&1 \
    || { echo "   ERROR en la configuración de la auditoría (ver evidencias/B_configuracion.txt)"; exit 1; }
DB="$DB" scripts/correr_auditoria_test.sh
echo ">> Parte C: simulacro de incidente"
DB="$DB" scripts/simulacro_incidente.sh
echo ">> Parte D: usuario_anon y equivalencia"
construccion sql/usuario_anon.sql         evidencias/D_usuario_anon.txt
prueba       sql/equivalencia_agregados.sql evidencias/D_equivalencia.txt
prueba       sql/D_comprobar_consultas_ia.sql evidencias/D_comprobacion_consultas_ia.txt
{
  echo "# Parte D — Verificación de equivalencia de agregados"
  echo
  echo "Consulta: cantidad de usuarios por rol y por mes de alta, sobre \`usuario_anon\` y sobre \`usuario\` (\`sql/equivalencia_agregados.sql\`)."
  echo
  echo "## Resultados lado a lado"
  echo
  echo '```'
  psql -X -d "$DB" -f sql/equivalencia_agregados.sql 2>&1 | sed -n '/== Lado a lado/,$p'
  echo '```'
  echo
  cat <<'TEXTO'
## Qué no debería salir nunca hacia un asistente de IA sin anonimizar

Los mails, nombres, apellidos y celulares de `usuario` y de `cliente`, y los hashes de `usuario.contrasena`. Tampoco las IP y los mails del log de auditoría, que están en `auditoria_seguridad` y en el log del servidor, ni cualquier volcado de `pedido` unido a `cliente`, que liga a una persona con lo que compró. Para pedirle ayuda a la IA alcanza con la estructura de las tablas (`\d usuario`) o con `usuario_anon`: los agregados dan lo mismo, como muestra la tabla de arriba.
TEXTO
} > docs/verificacion_equivalencia.md
echo ">> Verificación final de permisos (incluye usuario_anon)"
prueba sql/verificacion_permisos.sql evidencias/A_03_verificacion_permisos.txt
echo ">> Comprobación de los hallazgos de OpenCode sobre roles.sql (BEGIN ... ROLLBACK)"
prueba sql/comprobar_auditoria_ia.sql evidencias/A_04_comprobacion_auditoria_ia.txt

# ---------------------------------------------------------------------------------------
paso "U7 · Estado del pedido, exportación y MongoDB"
cd "$TP/unidad7_nosql"; mkdir -p evidencias
construccion 01_estado_pedido.sql      evidencias/01_estado_pedido.txt
prueba       02_exportar_pedidos.sql   evidencias/02_exportar_pedidos.txt
prueba       consultas_postgresql.sql  evidencias/consultas_postgresql.txt
if command -v mongosh >/dev/null 2>&1; then
    M="${MONGO_URI:-mongodb://localhost:27017}"
    mongosh "$M" --quiet --file cargar_mongodb.js             > evidencias/carga_mongodb.txt 2>&1 \
        || { echo "   ERROR en la carga a MongoDB (ver evidencias/carga_mongodb.txt)"; exit 1; }
    mongosh "$M" --quiet --file consultas_mongodb.js          > evidencias/consultas_mongodb.txt 2>&1 || true
    mongosh "$M" --quiet --file pruebas_integridad_mongodb.js > evidencias/pruebas_integridad.txt 2>&1 || true
    mongosh "$M" --quiet --file pruebas_afirmaciones_ia.js    > evidencias/pruebas_afirmaciones_ia.txt 2>&1 || true
    MONGO_URI="$M" ./verificar_consultas.sh > /dev/null
else
    echo "   AVISO: no está mongosh. Instalá MongoDB + mongosh y corré después: ./ejecutar_segunda_entrega.sh"
fi

# ---------------------------------------------------------------------------------------
paso "U8 · Base de la tablet (TP8, ya entregado)"
echo "   La U8 está en trabajos-practicos/unidad8/food-store, con su propio ejecutar_todo.sh"
echo "   (copia de pruebas foodstore_tp8). No se vuelve a correr acá para no pisar sus evidencias."

# ---------------------------------------------------------------------------------------
paso "U6 · Respaldo, chequeo, mantenimiento y simulacro de desastre"
cd "$TP/unidad6_mantenimiento"; mkdir -p evidencias
DB="$DB" ./backup_foodstore.sh
psql -X -d "$DB" -f health_check.sql > evidencias/health_check.txt 2>&1
psql -X -d "$DB" -f maintenance.sql  > evidencias/maintenance.txt 2>&1
{ echo "== Respaldos"; ls -l backups/; echo; echo "== logs/backup.log"; cat logs/backup.log; } > evidencias/respaldos.txt
echo ">> Simulacro contra reloj (1 proceso)"
DB="$DB" ./restore_test.sh | tail -6
echo ">> Simulacro con restauración en paralelo (mejora propuesta)"
DB="$DB" JOBS=4 ./restore_test.sh | tail -6

paso "Listo. Revisá la carpeta evidencias/ de cada unidad."
