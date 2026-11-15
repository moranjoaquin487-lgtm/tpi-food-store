#!/usr/bin/env bash
# TP Semana 4 (Unidad 2): reportes analíticos asistidos por IA sobre Food Store.
# Trabaja sobre foodstore_s4, una copia del estado final de la Semana 3 (foodstore_tp3). No toca foodstore.
#
# Desde la raíz del repositorio, en Git Bash (usa el pgpass.conf de postgres; no pide ni guarda contraseñas):
#   bash trabajos-practicos/unidad2/semana4_reportes_analiticos_ia/ejecutar_tp4.sh antes
#       Copia de trabajo y planes ANTES (Parte 1 y Parte 4), y el prompt para la IA
#   bash trabajos-practicos/unidad2/semana4_reportes_analiticos_ia/ejecutar_tp4.sh despues
#       Rehace la copia, aplica los cambios aceptados, mide DESPUÉS, corre la Parte 3 y arma el prompt de la
#       Parte 2 (tarda un par de minutos; no hace falta cortarlo)
set -euo pipefail
cd "$(dirname "$0")"
export PGUSER="${PGUSER:-postgres}"
export PGCLIENTENCODING=UTF8          # los scripts están en UTF-8 (en Git Bash, psql puede tomar WIN1252)
DB="${DB:-foodstore_s4}"
ORIGEN="${ORIGEN:-foodstore_tp3}"
case "$DB" in
    foodstore|tpi_food_store|"$ORIGEN") echo "DB tiene que ser una copia de trabajo nueva, no $DB"; exit 1 ;;
esac
mkdir -p evidencias prompts

correr() {  # correr ARCHIVO SALIDA
    psql -X -d "$DB" -v ON_ERROR_STOP=1 -f "$1" > "$2" 2>&1 || { echo "   ERROR (ver $2)"; exit 1; }
}
tiempos() { grep 'Execution Time' "$1" | tr -d '\r' | sed 's/.*: //' | paste -sd ',' - | sed 's/,/, /g'; }
joins() {   # algoritmos de join de cada consulta, en orden de aparición
    awk '/^######## Q/{if (q) print q": "j; q=$2; j=""} /Nested Loop|Hash Join|Merge Join/{
             match($0, /(Parallel )?(Nested Loop|Hash Join|Merge Join)( (Left|Anti|Semi))?( Join)?/);
             j = j (j ? ", " : "") substr($0, RSTART, RLENGTH)} END{if (q) print q": "j}' "$1" | tr -d '\r'
}

case "${1:-}" in
antes)
    psql -X -d postgres -Atc "SELECT 1 FROM pg_database WHERE datname = '$ORIGEN'" | grep -q 1 \
        || { echo "No existe $ORIGEN: primero hay que correr la Semana 3 (antes y despues)"; exit 1; }
    echo ">> Copia de trabajo $DB, desde el estado final de la Semana 3 ($ORIGEN)"
    dropdb --if-exists "$DB"
    createdb -T "$ORIGEN" "$DB"
    psql -X -q -d "$DB" -c 'VACUUM (ANALYZE)'
    psql -X -d "$DB" -c '\di' > evidencias/parte1_indices_iniciales.txt 2>&1

    echo ">> Parte 1: planes ANTES de cualquier cambio"
    correr sql/parte1_antes.sql evidencias/parte1_antes.txt
    echo ">> Parte 4: consulta de la competencia ANTES"
    correr sql/parte4_competencia.sql evidencias/parte4_antes.txt

    {
        echo "# Prompt de la Parte 1: planes reales de dos consultas analíticas para que la IA proponga cambios"
        echo
        echo 'Base PostgreSQL de Food Store: pedido (id_pedido, fecha TIMESTAMPTZ, forma_pago, id_cliente),'
        echo 'detalle_pedido (id_detalle, id_pedido, id_producto, cantidad, precio_unitario, UNIQUE (id_pedido, id_producto)),'
        echo 'producto (id_producto, nombre, precio, stock, activo, id_categoria), categoria (id_categoria, nombre, activo)'
        echo 'y cliente (id_cliente, nombre, apellido, email). Volumen: 200 000 pedidos, 400 000 líneas, 50 000 productos,'
        echo '20 000 clientes y 5 categorías. Índices actuales: las PK, los UNIQUE, pedido (id_cliente),'
        echo 'pedido (fecha) INCLUDE (id_pedido, id_cliente), detalle_pedido (id_producto) INCLUDE (cantidad),'
        echo 'producto (id_categoria) WHERE activo y producto (id_categoria, precio) WHERE activo.'
        echo 'Contexto medido en esta misma PC en la práctica anterior: random_page_cost está en 4 (valor por defecto)'
        echo 'y los planes con workers paralelos tardaron más que sin ellos.'
        echo
        echo 'Para cada consulta, con su plan real de EXPLAIN (ANALYZE, BUFFERS): identificá qué algoritmo de join'
        echo '(Nested Loop, Hash Join o Merge Join) eligió el optimizador en cada combinación de tablas, y proponé'
        echo 'reescrituras y/o índices que lo mejoren. Justificá cada propuesta con el nodo de join concreto del plan:'
        echo 'qué nodo ataca y por qué esperás que cambie.'
        echo
        echo 'Consultas (cada una se ejecutó primero una vez, para calentar la caché):'
        echo
        echo '```sql'
        awk '/^\\echo/{sub(/^\\echo .######## /,"-- "); sub(/.$/,""); print; next}
             /^EXPLAIN/{f=1; next} f{print} /;$/{if(f) print ""; f=0}' sql/parte1_antes.sql | tr -d '\r'
        echo '```'
        echo
        echo 'Planes reales:'
        echo
        echo '```'
        grep -v '^ filas\|^-------\|^ *[0-9]\+$\|^(1 fila)\|^(1 row)' evidencias/parte1_antes.txt | tr -d '\r'
        echo '```'
    } > prompts/parte1_propuestas_ia.md

    echo
    echo "================ Resumen ================"
    echo "Parte 1, tiempos ANTES (Q1, Q2): $(tiempos evidencias/parte1_antes.txt)"
    echo "Parte 1, joins ANTES:"; joins evidencias/parte1_antes.txt | sed 's/^/  /'
    echo "Parte 4, tiempo ANTES: $(tiempos evidencias/parte4_antes.txt)"
    echo "Siguiente paso: prompts/parte1_propuestas_ia.md en OpenCode"
    ;;

despues)
    for f in sql/parte1_cambios.sql sql/parte1_despues.sql sql/parte1_ajuste.sql sql/parte1_alternativa.sql \
             sql/parte4_cambio.sql sql/parte3_consultas.sql; do
        [ -f "$f" ] || { echo "Falta $f: primero hay que decidir los cambios de la Parte 1"; exit 1; }
    done
    # Copia limpia en cada corrida: parte del mismo estado que midió "antes" y se puede repetir sin errores.
    echo ">> Copia de trabajo limpia $DB, desde $ORIGEN (el mismo estado que midió 'antes')"
    dropdb --if-exists "$DB"
    createdb -T "$ORIGEN" "$DB"
    psql -X -q -d "$DB" -c 'VACUUM (ANALYZE)'
    echo ">> Parte 1: cambios aceptados, en una transacción, y VACUUM (ANALYZE)"
    psql -X -d "$DB" -v ON_ERROR_STOP=1 --single-transaction -a -f sql/parte1_cambios.sql \
        > evidencias/parte1_cambios_aplicados.txt 2>&1 || { echo "   ERROR (ver evidencias/parte1_cambios_aplicados.txt)"; exit 1; }
    psql -X -q -d "$DB" -v ON_ERROR_STOP=1 -c 'VACUUM (ANALYZE)' >> evidencias/parte1_cambios_aplicados.txt 2>&1
    echo "VACUUM (ANALYZE): hecho" >> evidencias/parte1_cambios_aplicados.txt
    echo ">> Parte 1: planes DESPUÉS (índice de OpenCode; consultas originales y reescrituras)"
    correr sql/parte1_despues.sql evidencias/parte1_despues.txt
    echo ">> Parte 1: lo mismo con work_mem, random_page_cost y sin paralelismo (solo en la sesión)"
    correr sql/parte1_ajuste.sql evidencias/parte1_ajuste.txt
    echo ">> Parte 1: alternativa propia para Q1"
    correr sql/parte1_alternativa.sql evidencias/parte1_alternativa.txt
    echo ">> Parte 4: estrategia de la competencia y plan DESPUÉS"
    correr sql/parte4_cambio.sql evidencias/parte4_despues.txt
    echo ">> Parte 3: consultas bajo spec y verificación de equivalencia"
    correr sql/parte3_consultas.sql evidencias/parte3_equivalencia.txt

    # Parte 2: el prompt tiene solo el pedido y el texto de un plan con al menos dos joins, sin otro contexto
    # Plan para la Parte 2: por defecto el de la Parte 4 después del cambio (tres Nested Loop y un LIMIT).
    # Con PLAN_PARTE2="Q1 ·" (u otro marcador de parte1_despues.txt) se usa ese plan.
    PLAN="${PLAN_PARTE2:-parte4}"
    {
        echo 'Explicá en lenguaje natural, nodo por nodo, qué hace este plan de ejecución de PostgreSQL y por qué tarda lo que tarda.'
        echo
        if [ "$PLAN" = parte4 ]; then
            tr -d '\r' < evidencias/parte4_despues.txt | sed -n '/QUERY PLAN/,/Execution Time/p' | sed '1,2d'
        else
            awk -v q="######## $PLAN" 'index($0, q) == 1 {f=1; next} /^######## Q/{f=0} f' evidencias/parte1_despues.txt \
                | tr -d '\r' | sed -n '/QUERY PLAN/,/Execution Time/p' | sed '1,2d'
        fi
    } > prompts/parte2_explicar_plan.txt

    echo
    echo "================ Resumen ================"
    echo "Parte 1, DESPUÉS (Q1, Q1R, Q2, Q2R): $(tiempos evidencias/parte1_despues.txt)"
    echo "Parte 1, con la configuración (Q1, Q1R, Q2, Q2R): $(tiempos evidencias/parte1_ajuste.txt)"
    echo "Parte 1, alternativa Q1A: $(tiempos evidencias/parte1_alternativa.txt)"
    echo "Parte 1, joins DESPUÉS:"; joins evidencias/parte1_despues.txt | sed 's/^/  /'
    echo "Parte 1, joins con la configuración:"; joins evidencias/parte1_ajuste.txt | sed 's/^/  /'
    echo "Reescrituras iguales a las originales (se espera 0 en todas):"
    grep -A2 -E 'q1_menos_q1r|q2_menos_q2r|q1_menos_q1a|original_menos_nueva' evidencias/parte1_despues.txt \
        evidencias/parte1_alternativa.txt evidencias/parte4_despues.txt | grep -E ' [0-9]+ +\| +[0-9]+' \
        | sed 's/^[^-]*-//' | tr -d '\r' | tr -s ' ' || true
    echo "Parte 4, tiempo DESPUÉS: $(tiempos evidencias/parte4_despues.txt)"
    echo "Parte 3, diferencias (se espera 0 en todas):"
    grep -A2 'diferencias_a_menos_b' evidencias/parte3_equivalencia.txt | grep -E '^ +[0-9]' | tr -d '\r' | tr -s ' ' || true
    echo "Siguiente paso: prompts/parte2_explicar_plan.txt en OpenCode, desde una carpeta vacía"
    ;;

*)
    echo "Uso: bash $0 antes | despues"; exit 1 ;;
esac
