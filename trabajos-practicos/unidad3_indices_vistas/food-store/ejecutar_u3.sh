#!/usr/bin/env bash
# TP Unidad 3 (Semana 5): índices, vistas y vistas materializadas en Food Store.
# Trabaja sobre una copia de prueba (foodstore_u3), armada desde schema.sql y data.sql. No toca foodstore.
#
# Desde esta carpeta (food-store/), en Git Bash (usa el pgpass.conf de postgres; no pide ni guarda contraseñas):
#   bash ejecutar_u3.sh antes     Copia de prueba, planes y escrituras ANTES, y el prompt para Kiro
#   bash ejecutar_u3.sh probar ARCHIVO.sql [...]
#                                 Prueba índices propuestos: los crea sobre la base limpia, mide las 4 consultas
#                                 y las escrituras, y los vuelve a borrar. Arma el prompt de la ronda siguiente
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
limpiar_indices() {  # borra los índices agregados en pruebas anteriores: deja solo los de schema.sql y los de restricciones
    psql -X -q -d "$DB" -v ON_ERROR_STOP=1 > /dev/null <<'SQL'
DO $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT i.indexrelid::regclass AS idx
               FROM pg_index i
               JOIN pg_class t ON t.oid = i.indrelid AND t.relkind = 'r'
               JOIN pg_namespace n ON n.oid = t.relnamespace AND n.nspname = 'public'
              WHERE NOT EXISTS (SELECT 1 FROM pg_constraint k WHERE k.conindid = i.indexrelid)
                AND i.indexrelid::regclass::text NOT IN
                    ('idx_pedido_id_cliente', 'idx_producto_categoria_activo', 'idx_detalle_pedido_id_producto')
    LOOP
        EXECUTE 'DROP INDEX ' || r.idx;
    END LOOP;
END $$;
SQL
}
criterio() {  # criterio de las specs: mediana DESPUÉS <= mitad de la mediana ANTES
    join <(medianas "$1" | sort) <(medianas "$2" | sort) | awk '{a=$2; d=$4; printf "  %s: %s -> %s ms (%+.0f %%) %s\n", $1, a, d, (d-a)/a*100, (d <= a/2 ? "cumple el tiempo" : "NO cumple el tiempo")}'
}
mediana_escritura() { tr -d '\r' < "$1" | awk '/Mediana \(ms\)/{f=1} f && /^ *[0-9.]+ *$/{print $1; exit}'; }
mediana_pedido() { tr -d '\r' < "$1" | awk '/Mediana pedido/{f=1} f && /^ *[0-9.]+ *$/{print $1; exit}'; }

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

probar)
    shift
    [ $# -ge 1 ] || { echo "Uso: bash $0 probar ARCHIVO.sql [ARCHIVO.sql ...]"; exit 1; }
    ETIQ="$(basename "${@: -1}" .sql)"
    echo ">> Base limpia: solo los índices de schema.sql"
    limpiar_indices
    echo ">> Escrituras sin los índices propuestos, en esta misma corrida (base de comparación)"
    correr mediciones/parteA_escritura.sql "evidencias/prueba_${ETIQ}_escritura_sin.txt"
    : > "evidencias/prueba_${ETIQ}_aplicado.txt"
    for f in "$@"; do
        echo ">> Aplica $f en una transacción"
        psql -X -d "$DB" -v ON_ERROR_STOP=1 --single-transaction -a -f "$f" >> "evidencias/prueba_${ETIQ}_aplicado.txt" 2>&1 \
            || { echo "   ERROR (ver evidencias/prueba_${ETIQ}_aplicado.txt)"; exit 1; }
    done
    psql -X -q -d "$DB" -c 'VACUUM (ANALYZE)'
    psql -X -d "$DB" -c "SELECT indexname, pg_size_pretty(pg_relation_size(('public.' || indexname)::regclass)) AS tamano, indexdef FROM pg_indexes WHERE schemaname = 'public' ORDER BY tablename, indexname" >> "evidencias/prueba_${ETIQ}_aplicado.txt" 2>&1
    echo ">> Parte A: planes con los índices propuestos"
    correr mediciones/parteA_consultas.sql "evidencias/prueba_${ETIQ}_planes.txt"
    echo ">> Parte A: escrituras con los índices propuestos"
    correr mediciones/parteA_escritura.sql "evidencias/prueba_${ETIQ}_escritura.txt"
    echo ">> Vuelve a dejar la base limpia"
    limpiar_indices

    {
        echo "# Ronda siguiente para OpenCode: resultado medido de tus índices"
        echo
        echo "Probé tus propuestas ($*) sobre la copia de prueba, con la configuración por defecto"
        echo "(random_page_cost = 4, hasta 2 workers paralelos por consulta). Cada consulta se ejecutó una vez para"
        echo "calentar la caché y después 3 veces; abajo van las medianas y el último plan de cada una."
        echo
        echo "Criterio de las specs: el plan deja el Seq Scan sobre la tabla grande y la mediana baja al menos a la mitad."
        echo
        echo '```'
        criterio evidencias/parteA_antes.txt "evidencias/prueba_${ETIQ}_planes.txt"
        echo '```'
        echo
        echo "Escrituras, 500 INSERT de a uno (mediana de 15 rondas, en la misma corrida) sin -> con tus índices:"
        echo "detalle_pedido $(mediana_escritura "evidencias/prueba_${ETIQ}_escritura_sin.txt") -> $(mediana_escritura "evidencias/prueba_${ETIQ}_escritura.txt") ms;"
        echo "pedido $(mediana_pedido "evidencias/prueba_${ETIQ}_escritura_sin.txt") -> $(mediana_pedido "evidencias/prueba_${ETIQ}_escritura.txt") ms."
        echo
        echo "Leé las specs de specs/ otra vez y estos planes. Para las consultas que no cumplen el criterio, decí qué nodo"
        echo "del plan medido es ahora el cuello de botella y proponé el ajuste: un índice adicional, un reemplazo o"
        echo "ninguno, si creés que ningún índice puede cumplirlo. Escribí las propuestas en"
        echo "propuestas/indices_opencode_ronda2.sql, con el mismo formato de comentarios (spec, nodo que ataca, por qué"
        echo "esperás que cambie). No repitas lo que ya cubre un índice existente o uno tuyo de la ronda anterior."
        echo "No ejecutes nada contra la base y no modifiques otros archivos."
        echo
        echo "Índices de la base durante la prueba:"
        echo
        echo '```'
        tr -d '\r' < "evidencias/prueba_${ETIQ}_aplicado.txt" | sed -n '/indexname/,/filas)/p'
        echo '```'
        echo
        echo "Planes medidos (la última de las 3 ejecuciones):"
        echo
        echo '```'
        tr -d '\r' < "evidencias/prueba_${ETIQ}_planes.txt" | awk '/^######## C/{print; n=0; next} /QUERY PLAN/{n++} n==3{print}' \
            | grep -v -e '^ *QUERY PLAN' -e '^-----' -e '^ *filas *$' -e '^([0-9]* filas*)$'
        echo '```'
    } > prompts/opencode_ronda2.md

    echo
    echo "================ Resumen ================"
    echo "Archivos probados: $*"
    echo "Medianas ANTES -> con los índices (criterio: bajar al menos a la mitad):"
    criterio evidencias/parteA_antes.txt "evidencias/prueba_${ETIQ}_planes.txt"
    echo "Nodos con los índices:"; nodos "evidencias/prueba_${ETIQ}_planes.txt" | sed 's/^/  /'
    echo "Escritura, 500 INSERT (mediana de 15 rondas), sin -> con los índices:"
    echo "  detalle_pedido: $(mediana_escritura "evidencias/prueba_${ETIQ}_escritura_sin.txt") -> $(mediana_escritura "evidencias/prueba_${ETIQ}_escritura.txt") ms"
    echo "  pedido:         $(mediana_pedido "evidencias/prueba_${ETIQ}_escritura_sin.txt") -> $(mediana_pedido "evidencias/prueba_${ETIQ}_escritura.txt") ms"
    echo "Siguiente paso: prompts/opencode_ronda2.md en OpenCode"
    ;;

*)
    echo "Uso: bash $0 antes | probar ARCHIVO.sql [...]"; exit 1 ;;
esac
