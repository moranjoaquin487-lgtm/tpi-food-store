#!/usr/bin/env bash
# Food Store — TP8: arma todo desde cero, en orden, y guarda la salida de cada paso en evidencias/.
#   read -s -p "Contraseña de postgres: " PGPASSWORD; echo; export PGPASSWORD
#   bash ejecutar_todo.sh
# Ojo: borra y vuelve a crear la copia de pruebas foodstore_tp8 y movil/foodstore_movil.db.
# No toca ninguna otra base. Otro usuario de PostgreSQL: PGUSER=mi_usuario bash ejecutar_todo.sh
set -u
cd "$(dirname "$0")"
export PGUSER="${PGUSER:-postgres}" PGCLIENTENCODING=UTF8 PGOPTIONS="-c client_min_messages=warning"
DB=foodstore_tp8                  # copia de pruebas, con datos inventados
TABLET=foodstore_movil.db         # vive en movil/
EV=evidencias

# --- Requisitos ---------------------------------------------------------------
for c in psql createdb dropdb sqlite3; do
  command -v "$c" >/dev/null || { echo "Falta '$c' en el PATH (ver README)."; exit 1; }
done
v=$(sqlite3 -version | cut -d' ' -f1)
[ "$(printf '%s\n3.37.0\n' "$v" | sort -V | head -1)" = "3.37.0" ] \
  || { echo "sqlite3 $v es viejo: las tablas STRICT necesitan 3.37 o más."; exit 1; }

mkdir -p "$EV/instantaneas"
rm -f "$EV"/1*.txt "$EV"/2*.txt "$EV"/instantaneas/*.csv   # 3c_* y 5_* los generan otros scripts

# --- Ayudas: cada paso deja el comando y su salida -----------------------------
en_servidor() {   # $1 = script .sql (PostgreSQL de pruebas)
  printf '\n$ psql -d %s -a -f %s\n' "$DB" "$1"
  psql -d "$DB" -a -v ON_ERROR_STOP=1 -f "$1" 2>&1
}
en_tablet() {     # $1 = script .sql relativo a movil/ · el resto, opciones de sqlite3
  local f="$1"; shift
  printf '\n$ cd movil && sqlite3 %s %s < %s\n' "$*" "$TABLET" "$f"
  (cd movil && sqlite3 "$@" "$TABLET" < "$f") 2>&1
}
exportar() {      # instantánea nueva: servidor -> movil/servidor_snapshot.csv (copia en evidencias/instantaneas/$1.csv)
  printf '\n$ psql -d %s -c "\\copy (SELECT * FROM v_snapshot_movil ORDER BY id) TO '\''movil/servidor_snapshot.csv'\'' CSV HEADER"\n' "$DB"
  psql -d "$DB" -v ON_ERROR_STOP=1 \
       -c "\copy (SELECT * FROM v_snapshot_movil ORDER BY id) TO 'movil/servidor_snapshot.csv' CSV HEADER" 2>&1 || return 1
  cp movil/servidor_snapshot.csv "$EV/instantaneas/$1.csv"
}
recargar_y_semaforo() {   # 2.a + 2.b en la tablet
  en_tablet cargar_snapshot.sql -bail -header -table || return 1
  en_tablet semaforo.sql -bail -header -table || return 1
}
fallo() { echo "   ERROR en $1 (ver $EV/$1.txt)"; exit 1; }

# --- 1. Servidor de pruebas -----------------------------------------------------
echo ">> Servidor: copia de pruebas $DB, vista v_snapshot_movil y foto inicial"
{
  echo "===== Servidor de pruebas: $DB (schema.sql y data.sql del TP1) ====="
  printf '\n$ dropdb --if-exists %s && createdb %s\n' "$DB" "$DB"
  dropdb --if-exists "$DB" && createdb "$DB" || exit 1
  printf '\n$ psql -d %s -q -f servidor/schema.sql -f servidor/data.sql\n' "$DB"
  psql -d "$DB" -q -v ON_ERROR_STOP=1 -f servidor/schema.sql -f servidor/data.sql 2>&1 || exit 1
  en_servidor servidor/v_snapshot_movil.sql || exit 1
  en_servidor servidor/foto_inicial.sql || exit 1
  printf '\n$ psql -d %s -c "SELECT id, nombre, precio_centavos, stock, disponible, eliminado FROM v_snapshot_movil ORDER BY id"\n' "$DB"
  psql -d "$DB" -c "SELECT id, nombre, precio_centavos, stock, disponible, eliminado FROM v_snapshot_movil ORDER BY id" 2>&1
} > "$EV/1_servidor.txt" 2>&1 || fallo 1_servidor

# --- 1.b Base de la tablet ------------------------------------------------------
echo ">> 1.b Tablet: schema_sqlite.sql"
{
  echo "===== 1.b · Base de la tablet desde cero ====="
  printf '\n$ rm -f movil/%s\n' "$TABLET"
  rm -f "movil/$TABLET"
  en_tablet schema_sqlite.sql -bail -header -table || exit 1
  printf '\n$ cd movil && sqlite3 -header -table %s "SELECT type, name, tbl_name FROM sqlite_schema ..."\n' "$TABLET"
  (cd movil && sqlite3 -header -table "$TABLET" \
     "SELECT type AS tipo, name AS nombre, tbl_name AS tabla FROM sqlite_schema
       WHERE name NOT LIKE 'sqlite_%'
       ORDER BY CASE type WHEN 'table' THEN 1 WHEN 'index' THEN 2 ELSE 3 END, name;") 2>&1
  echo "(PRAGMA foreign_keys vale por conexión: cada script de la tablet lo activa en su primera línea.)"
} > "$EV/1b_schema_sqlite.txt" 2>&1 || fallo 1b_schema_sqlite

# --- 2.a Primera instantánea ----------------------------------------------------
echo ">> 2.a Instantánea: exportar a CSV e importar en la tablet"
{
  echo "===== 2.a · Instantánea del servidor y carga de producto_cache ====="
  exportar 0_inicial || exit 1
  printf '\n$ cat movil/servidor_snapshot.csv\n'; cat movil/servidor_snapshot.csv
  en_tablet cargar_snapshot.sql -bail -header -table || exit 1
} > "$EV/2a_instantanea.txt" 2>&1 || fallo 2a_instantanea

# --- 1.c Pruebas de la tablet ---------------------------------------------------
echo ">> 1.c Pruebas: BEGIN/COMMIT, ROLLBACK, C1 y C7"
{
  echo "===== 1.c · pruebas_sqlite.sql (los errores de C7 son el resultado esperado) ====="
  en_tablet pruebas_sqlite.sql -header -table -echo
  echo
  echo "===== C1 sin señal: el servidor no responde y el catálogo igual sale ====="
  printf '\n$ PGCONNECT_TIMEOUT=3 psql -h feria-sin-senal.invalid -d %s -c "SELECT 1"\n' "$DB"
  PGCONNECT_TIMEOUT=3 psql -h feria-sin-senal.invalid -d "$DB" -c "SELECT 1" 2>&1
  printf '\n$ cd movil && sqlite3 -header -table %s "SELECT nombre, ... FROM producto_cache WHERE disponible = 1 AND eliminado = 0"\n' "$TABLET"
  (cd movil && sqlite3 -header -table "$TABLET" \
     "SELECT nombre, printf('%.2f', precio_centavos / 100.0) AS precio, stock_visto
        FROM producto_cache WHERE disponible = 1 AND eliminado = 0 ORDER BY nombre;") 2>&1
} > "$EV/1c_pruebas_sqlite.txt" 2>&1

# --- 2.c Casos ------------------------------------------------------------------
# Cada caso: borrador en la tablet -> cambio en la copia del servidor (si corresponde)
#            -> instantánea nueva -> recarga del catálogo -> semáforo.
echo ">> 2.c C2: sube el precio -> CONFLICTO; el cliente acepta -> SIMULADO_APROBADO"
{
  echo "===== C2 · Cambio de precio ====="
  en_tablet casos/c2_borrador.sql -header -table -echo
  en_servidor servidor/casos/c2_subir_precio.sql || exit 1
  exportar C2 || exit 1
  recargar_y_semaforo || exit 1
  echo; echo "----- El cliente acepta el precio nuevo: solicitud nueva -----"
  en_tablet casos/c2_acepta.sql -bail -header -table -echo || exit 1
  en_tablet semaforo.sql -bail -header -table || exit 1
} > "$EV/2c_C2.txt" 2>&1 || fallo 2c_C2

echo ">> 2.c C3: más unidades de las que quedan -> RECHAZADO"
{
  echo "===== C3 · Stock insuficiente ====="
  en_tablet casos/c3_borrador.sql -bail -header -table -echo || exit 1
  exportar C3 || exit 1
  recargar_y_semaforo || exit 1
} > "$EV/2c_C3.txt" 2>&1 || fallo 2c_C3

echo ">> 2.c C4: baja lógica -> RECHAZADO; la fila queda como lápida"
{
  echo "===== C4 · Producto dado de baja ====="
  en_tablet casos/c4_borrador.sql -bail -header -table -echo || exit 1
  en_servidor servidor/casos/c4_baja_logica.sql || exit 1
  exportar C4 || exit 1
  recargar_y_semaforo || exit 1
  echo; echo "----- Catálogo recargado -----"
  en_tablet casos/c4_catalogo.sql -bail -header -table -echo || exit 1
} > "$EV/2c_C4.txt" 2>&1 || fallo 2c_C4

echo ">> 2.c C5: sin cambios -> SIMULADO_APROBADO"
{
  echo "===== C5 · Sin cambios ====="
  en_tablet casos/c5_borrador.sql -bail -header -table -echo || exit 1
  exportar C5 || exit 1
  recargar_y_semaforo || exit 1
} > "$EV/2c_C5.txt" 2>&1 || fallo 2c_C5

echo ">> 2.c C6: reenvío con el mismo UUID y semáforo repetido"
{
  echo "===== C6 · Reenvío (idempotencia). Los dos errores son el resultado esperado ====="
  en_tablet casos/c6_reenvio.sql -header -table -echo
  echo; echo "----- Se repite la simulación con una instantánea nueva: no reevalúa nada -----"
  exportar C6 || exit 1
  recargar_y_semaforo || exit 1
} > "$EV/2c_C6.txt" 2>&1 || fallo 2c_C6

# --- Verificación final en PostgreSQL --------------------------------------------
echo ">> Verificación: pedidos y stock del servidor"
{
  echo "===== Verificación final en PostgreSQL: la simulación no creó pedidos ni tocó el stock ====="
  en_servidor servidor/verificacion_final.sql || exit 1
} > "$EV/2c_verificacion_servidor.txt" 2>&1 || fallo 2c_verificacion_servidor

echo ">> Listo. Estado final de la cola en la tablet:"
(cd movil && sqlite3 -header -table "$TABLET" \
  "SELECT substr(solicitud_uuid, 1, 8) AS solicitud, substr(id_local, 1, 8) AS borrador, estado FROM cola_sync ORDER BY rowid;")
echo "   Revisá la carpeta $EV/."
