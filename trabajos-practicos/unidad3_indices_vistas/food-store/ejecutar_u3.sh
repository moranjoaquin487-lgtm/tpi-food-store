#!/usr/bin/env bash
# TP Unidad 3 (Semana 5): índices, vistas y vistas materializadas en Food Store.
# Trabaja sobre una copia de prueba (foodstore_u3), armada desde schema.sql y data.sql. No toca foodstore.
#
# Desde esta carpeta (food-store/), en Git Bash (usa el pgpass.conf de postgres; no pide ni guarda contraseñas):
#   bash ejecutar_u3.sh antes     Copia de prueba, planes y escrituras ANTES, y el prompt para Kiro
#   bash ejecutar_u3.sh despues   Índices aceptados de a uno con su medición, escrituras DESPUÉS,
#                                 vistas con su verificación y la vista materializada
set -euo pipefail
cd "$(dirname "$0")"
export PGUSER="${PGUSER:-postgres}"
export PGCLIENTENCODING=UTF8          # los scripts están en UTF-8 (en Git Bash, psql puede tomar WIN1252)
DB="${DB:-foodstore_u3}"
case "$DB" in
    foodstore|tpi_food_store|foodstore_tp3|foodstore_s4) echo "DB tiene que ser una copia de prueba nueva, no $DB"; exit 1 ;;
esac
mkdir -p evidencias prompts

cargar() {
    PGOPTIONS="-c client_min_messages=warning" psql -X -q -d "$DB" -v ON_ERROR_STOP=1 \
        --single-transaction -f "$1" > /dev/null || { echo "   ERROR en $1"; exit 1; }
}
correr() {  # correr ARCHIVO SALIDA
    psql -X -d "$DB" -v ON_ERROR_STOP=1 -f "$1" > "$2" 2>&1 || { echo "   ERROR (ver $2)"; exit 1; }
}
medianas() {  # mediana de las 3 ejecuciones de cada consulta de un archivo de evidencia
    tr -d '\r' < "$1" | awk '/^######## C/{q=$2} /Execution Time/{t[q]=t[q] " " $3}
        END{for (q in t) {n=split(t[q], v, " "); for (i=1;i<=n;i++) for (j=i+1;j<=n;j++) if (v[j]+0<v[i]+0) {x=v[i]; v[i]=v[j]; v[j]=x}
            printf "%s %s ms\n", q, v[int((n+1)/2)]}}' | sort
}
nodos() {  # nodos de lectura y de join del último plan de cada consulta
    tr -d '\r' < "$1" | awk '/^######## C/{if (q) print q": "u; q=$2; u=""; next}
        /QUERY PLAN/{u=""} /(Seq Scan|Index Scan|Index Only Scan|Bitmap Heap Scan|Nested Loop|Hash Join|Hash Anti Join|Hash Right Anti Join|Merge Join|Gather)/{
            match($0, /(Parallel )?(Seq Scan|Index Only Scan|Index Scan|Bitmap Heap Scan|Nested Loop( Anti Join)?|Hash (Right )?(Anti )?Join|Merge Join|Gather( Merge)?)( on [a-z_]+| using [a-z_]+)?/)
            u = u (u ? ", " : "") substr($0, RSTART, RLENGTH)} END{if (q) print q": "u}'
}
mediana_escritura() { tr -d '\r' < "$1" | awk '/Mediana/{f=1} f && /^ *[0-9.]+ *$/{print $1; exit}'; }

case "${1:-}" in
antes)
    echo ">> Copia de prueba $DB desde schema.sql y data.sql (datos semilla + carga masiva de la Semana 3)"
    PGOPTIONS="-c client_min_messages=warning" dropdb --if-exists "$DB"
    createdb "$DB"
    cargar schema.sql
    cargar data.sql
    psql -X -q -d "$DB" -c 'VACUUM (ANALYZE)'
    psql -X -d "$DB" -c "SELECT tablename, indexname, indexdef FROM pg_indexes WHERE schemaname = 'public' ORDER BY 1, 2" > evidencias/indices_iniciales.txt 2>&1
    # Solo ASCII en los argumentos de psql: en Windows, la línea de comandos llega en WIN1252
    psql -X -d "$DB" -Atc "SELECT 'categoria '||(SELECT count(*) FROM categoria)||', producto '||(SELECT count(*) FROM producto)||', cliente '||(SELECT count(*) FROM cliente)||', pedido '||(SELECT count(*) FROM pedido)||', detalle_pedido '||(SELECT count(*) FROM detalle_pedido)||', usuario '||(SELECT count(*) FROM usuario)" > evidencias/volumen.txt

    echo ">> Parte A: planes ANTES (3 ejecuciones por consulta)"
    correr mediciones/parteA_consultas.sql evidencias/parteA_antes.txt
    echo ">> Parte A: escrituras ANTES (500 INSERT por ronda, en una transacción que se deshace)"
    correr mediciones/parteA_escritura.sql evidencias/escritura_antes.txt

    {
        cat prompts/kiro_specs_base.md | tr -d '\r'
        echo
        echo "## Medición actual (mediana de 3 ejecuciones, después de calentar la caché)"
        echo
        echo "Volumen: $(cat evidencias/volumen.txt | tr -d '\r')"
        echo
        medianas evidencias/parteA_antes.txt | sed 's/^/- /'
        echo
        echo "Nodos de cada plan:"
        echo
        nodos evidencias/parteA_antes.txt | sed 's/^/- /'
        echo
        echo "## Consultas exactas"
        echo
        echo '```sql'
        tr -d '\r' < mediciones/parteA_consultas.sql | awk '/^\\echo/{sub(/^\\echo .######## /,"-- "); sub(/.$/,""); print; n=0; next}
            /^EXPLAIN/{n++; if (n==1) f=1; next} f{print} /;$/{if (f) print ""; f=0}'
        echo '```'
        echo
        echo "Planes completos de la medición: \`evidencias/parteA_antes.txt\`."
    } > prompts/kiro_specs.md

    echo
    echo "================ Resumen ================"
    echo "Volumen: $(cat evidencias/volumen.txt)"
    echo "Parte A, medianas ANTES:"; medianas evidencias/parteA_antes.txt | sed 's/^/  /'
    echo "Parte A, nodos ANTES:"; nodos evidencias/parteA_antes.txt | sed 's/^/  /'
    echo "Escritura ANTES (500 INSERT en detalle_pedido, mediana de 15 rondas): $(mediana_escritura evidencias/escritura_antes.txt) ms"
    echo "Siguiente paso: prompts/kiro_specs.md en Kiro"
    ;;

*)
    echo "Uso: bash $0 antes"; exit 1 ;;
esac
