#!/usr/bin/env bash
# Parte 2: escenarios con dos sesiones concurrentes sobre la copia de trabajo.
#   bash scripts/laboratorio_concurrencia.sh reproducir   paso 1: reproduce los cuatro escenarios
#   bash scripts/laboratorio_concurrencia.sh verificar    paso 3: los repite con cada nivel o mecanismo que puede evitarlos
# Las dos sesiones son dos conexiones de psql abiertas a la vez; la B arranca 0,5 s después que la A.
set -u
cd "$(dirname "$0")/.."
export PGUSER="${PGUSER:-postgres}" PGCLIENTENCODING=UTF8 PGOPTIONS="-c client_min_messages=warning"
DB=foodstore_trabajo
C=food-store/concurrencia
MODO="${1:-reproducir}"
mkdir -p evidencias prompts

base=$(psql -d "$DB" -tAc "SELECT current_database()" 2>/dev/null)
[ "$base" = "$DB" ] || { echo "No hay conexión con $DB: corré scripts/crear_base.sh y cargá PGPASSWORD."; exit 1; }
valor() { psql -d "$DB" -tAc "$1"; }

# $1 evidencia · $2 título · $3 líneas que cada sesión corre antes del escenario · $4 sesión A · $5 sesión B
sesiones() {
  local out="evidencias/$1.txt" ta tb
  ta=$(mktemp); tb=$(mktemp)
  printf '%b\n\\i %s\n' "$3" "$C/$4" | psql -d "$DB" -a > "$ta" 2>&1 &
  sleep 0.5
  printf '%b\n\\i %s\n' "$3" "$C/$5" | psql -d "$DB" -a > "$tb" 2>&1
  wait
  # Se quita la línea LOCATION (UBICACIÓN en español), que solo indica el archivo fuente del servidor
  # donde se generó el error y que psql en Windows escribe con otra codificación.
  {
    echo "===== $2 ====="
    echo
    echo "----- SESIÓN A -----"; grep -a -v -E '^(LOCATION|UBICACI)' "$ta"
    echo
    echo "----- SESIÓN B (arranca 0,5 s después) -----"; grep -a -v -E '^(LOCATION|UBICACI)' "$tb"
  } > "$out"
  rm -f "$ta" "$tb"
  echo ">> $out"
}

# Cada escenario deja los datos como estaban (precio, pedidos y stock).
e1() {  # $1 evidencia · $2 nivel de la sesión A
  local precio; precio=$(valor "SELECT precio FROM producto WHERE nombre = 'Muzzarella'")
  sesiones "$1" "Escenario 1 · Lectura no repetible · $2" "\\\\set nivel '$2'" e1_A.sql e1_B.sql
  valor "UPDATE producto SET precio = $precio WHERE nombre = 'Muzzarella'" >/dev/null
  echo "(Después del escenario se restauró el precio original: $precio)" >> "evidencias/$1.txt"
}
e2() {  # $1 evidencia · $2 nivel de la sesión A
  local maximo; maximo=$(valor "SELECT max(id) FROM pedido")
  sesiones "$1" "Escenario 2 · Lectura fantasma · $2" "\\\\set nivel '$2'" e2_A.sql e2_B.sql
  valor "DELETE FROM pedido WHERE id > $maximo" >/dev/null
  echo "(Después del escenario se borró el pedido que agregó la sesión B)" >> "evidencias/$1.txt"
}
e3() {  # $1 evidencia · $2 título · $3 modo de FOR UPDATE ('', NOWAIT o SKIP LOCKED) · $4 sentencia previa (opcional)
  local stock; stock=$(valor "SELECT stock FROM producto WHERE nombre = 'Coca 1.5L'")
  sesiones "$1" "Escenario 3 · $2" "\\\\set modo '$3'\n\\\\set ON_ERROR_ROLLBACK on${4:+\n$4}" e3_A.sql e3_B.sql
  valor "UPDATE producto SET stock = $stock WHERE nombre = 'Coca 1.5L'" >/dev/null
  echo "(Después del escenario se restauró el stock original: $stock)" >> "evidencias/$1.txt"
}
e4() {  # $1 evidencia · $2 título · $3 primera fila de B · $4 segunda fila de B · $5 sentencia previa (opcional)
  sesiones "$1" "Escenario 4 · $2" "\\\\set primero '$3'\n\\\\set segundo '$4'${5:+\n$5}" e4_A.sql e4_B.sql
}
SERIALIZABLE="SET default_transaction_isolation = 'serializable';"

case "$MODO" in
  reproducir)
    e1 e1_no_repetible_read_committed "READ COMMITTED"
    e2 e2_fantasma_read_committed "READ COMMITTED"
    e3 e3_espera_por_bloqueo "Espera por bloqueo · FOR UPDATE" ""
    e4 e4_interbloqueo_orden_cruzado "Interbloqueo · orden cruzado (A: Napolitana → Fugazzeta, B: Fugazzeta → Napolitana)" "Fugazzeta" "Napolitana"
    # Un pedido de explicación por escenario, con los comandos y la salida real, para pasarle a la IA.
    n=0
    for f in e1_no_repetible_read_committed e2_fantasma_read_committed e3_espera_por_bloqueo e4_interbloqueo_orden_cruzado; do
      n=$((n + 1)); f="evidencias/$f.txt"
      {
        echo "Hice este experimento en PostgreSQL 18 con dos sesiones concurrentes sobre mi base Food Store."
        echo "La sesión B arrancó medio segundo después que la A. Abajo están los comandos exactos de cada sesión y lo que devolvió cada uno."
        echo
        echo "Explicame qué pasó y qué nivel de aislamiento o qué mecanismo de bloqueo evitaría este comportamiento."
        echo "Respondé solo con la explicación: no crees ni modifiques archivos."
        echo
        echo '```'
        # Sin el título ni la nota de restauración: la IA solo ve los comandos y lo que devolvieron.
        tail -n +3 "$f" | grep -v '^(Después del escenario'
        echo '```'
      } > "prompts/explicacion_escenario_$n.md"
    done
    echo ">> Pedidos para la IA: prompts/explicacion_escenario_1.md a 4.md"
    ;;
  verificar)
    e1 e1_verificacion_repeatable_read "REPEATABLE READ"
    e1 e1_verificacion_serializable "SERIALIZABLE"
    e2 e2_verificacion_repeatable_read "REPEATABLE READ"
    e2 e2_verificacion_serializable "SERIALIZABLE"
    e3 e3_verificacion_nowait "FOR UPDATE NOWAIT" "NOWAIT"
    e3 e3_verificacion_skip_locked "FOR UPDATE SKIP LOCKED" "SKIP LOCKED"
    e3 e3_verificacion_lock_timeout "FOR UPDATE con lock_timeout de 1 s" "" "SET lock_timeout = '1s';"
    e3 e3_verificacion_serializable "FOR UPDATE con las dos sesiones en SERIALIZABLE" "" "$SERIALIZABLE"
    e4 e4_verificacion_mismo_orden "Mismo orden en las dos sesiones (Napolitana → Fugazzeta)" "Napolitana" "Fugazzeta"
    e4 e4_verificacion_serializable "Orden cruzado con las dos sesiones en SERIALIZABLE" "Fugazzeta" "Napolitana" "$SERIALIZABLE"
    ;;
  *) echo "Uso: bash scripts/laboratorio_concurrencia.sh reproducir|verificar"; exit 1 ;;
esac
