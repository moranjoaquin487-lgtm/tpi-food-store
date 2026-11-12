#!/usr/bin/env bash
# Food Store — TP8: prueba la versión de OpenCode (opencode/, la que se entrega en movil/) y la primera versión,
# hecha con Claude y descartada (docs/opencode/version_claude/), con las MISMAS pruebas y casos.
#   bash docs/opencode/comparar_versiones.sh        (desde la carpeta food-store/, después de ejecutar_todo.sh)
# Solo usa SQLite: repite el lado de la tablet con las instantáneas guardadas en evidencias/instantaneas/.
# No toca PostgreSQL ni movil/foodstore_movil.db: cada versión corre en una carpeta temporal.
set -u
cd "$(dirname "$0")/../.."
INST=evidencias/instantaneas
for f in opencode/schema_sqlite.sql opencode/semaforo.sql docs/opencode/version_claude/schema_sqlite.sql docs/opencode/version_claude/semaforo.sql "$INST/0_inicial.csv" "$INST/C6.csv"; do
  [ -f "$f" ] || { echo "Falta $f"; exit 1; }
done

probar() {   # $1 = etiqueta, $2 = carpeta con schema_sqlite.sql y semaforo.sql
  local T; T=$(mktemp -d)
  cp "$2/schema_sqlite.sql" "$2/semaforo.sql" movil/cargar_snapshot.sql movil/pruebas_sqlite.sql "$T"/ \
    && cp -r movil/casos "$T"/casos || { echo "No se pudieron copiar los archivos de $2"; rm -rf "$T"; exit 1; }   # code review #29
  cd "$T"
  carga() { cp "$OLDPWD/$INST/$1.csv" servidor_snapshot.csv; sqlite3 -bail t.db < cargar_snapshot.sql > /dev/null 2>&1 || echo "!! falló la carga de $1"; }
  paso()  { printf '\n$ sqlite3 -header -table t.db < %s\n' "$1"; sqlite3 -header -table t.db < "$1" 2>&1; }
  echo "################ Versión: $1 ($2) · sqlite3 $(sqlite3 -version | cut -d' ' -f1) ################"
  echo "===== schema_sqlite.sql (si hay errores, aparecen acá) ====="
  sqlite3 t.db < schema_sqlite.sql 2>&1 | grep -i -E "error|near" || echo "sin errores"
  sqlite3 -header -table t.db "SELECT type AS tipo, name AS nombre FROM sqlite_schema WHERE type IN ('trigger', 'index') AND name NOT LIKE 'sqlite_%' ORDER BY type, name;"
  carga 0_inicial
  echo; echo "===== 1.c · pruebas_sqlite.sql ====="; paso pruebas_sqlite.sql
  echo; echo "===== C2 ====="; paso casos/c2_borrador.sql > /dev/null; carga C2; paso semaforo.sql
                                paso casos/c2_acepta.sql > /dev/null; paso semaforo.sql
  echo; echo "===== C3 ====="; paso casos/c3_borrador.sql > /dev/null; carga C3; paso semaforo.sql
  echo; echo "===== C4 ====="; paso casos/c4_borrador.sql > /dev/null; carga C4; paso semaforo.sql; paso casos/c4_catalogo.sql
  echo; echo "===== C5 ====="; paso casos/c5_borrador.sql > /dev/null; carga C5; paso semaforo.sql
  echo; echo "===== C6 ====="; paso casos/c6_reenvio.sql; carga C6; paso semaforo.sql
  echo; echo "===== Controles extra ====="
  printf '\n-- UUID que no es hexadecimal y usuario con mail (tienen que fallar):\n'
  sqlite3 t.db "PRAGMA foreign_keys = ON; INSERT INTO pedido_borrador (id_local, usuario, forma_pago) VALUES ('zzzzzzzz-zzzz-4zzz-8zzz-zzzzzzzzzzzz', 'feria-01', 'EFECTIVO');" 2>&1 || true
  sqlite3 t.db "PRAGMA foreign_keys = ON; INSERT INTO pedido_borrador (id_local, usuario, forma_pago) VALUES ('d0000000-0000-4000-8000-000000000000', 'ana.gomez@mail.com', 'EFECTIVO');" 2>&1 || true
  sqlite3 -header -table t.db "SELECT id_local, usuario FROM pedido_borrador WHERE id_local LIKE 'zzzz%' OR usuario LIKE '%@%';"
  printf '\n-- Cambiar el motivo de una solicitud ya evaluada (tiene que fallar):\n'
  sqlite3 t.db "UPDATE cola_sync SET motivo = 'cambiado a mano' WHERE solicitud_uuid LIKE 'a0c30001%';" 2>&1 || true
  sqlite3 -header -table t.db "SELECT substr(solicitud_uuid, 1, 8) AS solicitud, estado, motivo FROM cola_sync WHERE solicitud_uuid LIKE 'a0c30001%';"
  echo; echo "===== Estado final de la cola ====="
  sqlite3 -header -table t.db "SELECT substr(solicitud_uuid, 1, 8) AS solicitud, estado FROM cola_sync ORDER BY rowid;"
  cd - > /dev/null; rm -rf "$T"
}

OUT=evidencias/5_comparacion_opencode_final.txt
{ probar "OpenCode (la que se entrega en movil/)" opencode; echo; echo; probar "Claude (primera versión, descartada)" docs/opencode/version_claude; } > "$OUT" 2>&1
echo ">> Listo: $OUT"
grep -A12 "Estado final de la cola" "$OUT"
