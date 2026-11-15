#!/usr/bin/env bash
# TP Semana 3 (Unidad 2): optimización asistida por IA sobre Food Store.
# Trabaja sobre una copia de prueba (foodstore_tp3), nunca sobre foodstore.
#
# Desde la raíz del repositorio, en Git Bash (usa el pgpass.conf de postgres; no pide ni guarda contraseñas):
#   bash trabajos-practicos/unidad2/semana3_optimizacion_ia/ejecutar_tp3.sh antes
#       Parte 1 (copia, respaldo, carga masiva en una transacción, verificación) y planes ANTES
#   bash trabajos-practicos/unidad2/semana3_optimizacion_ia/ejecutar_tp3.sh despues
#       Aplica los cambios aceptados de la Parte 2 y la Parte 5, mide DESPUÉS y corre la Parte 4
#   bash trabajos-practicos/unidad2/semana3_optimizacion_ia/ejecutar_tp3.sh sin_paralelo
#       Vuelve a medir la Parte 2 sin procesos paralelos, para comprobar de dónde sale la espera del Gather
set -euo pipefail
cd "$(dirname "$0")"
RAIZ="$(cd ../../.. && pwd)"
export PGUSER="${PGUSER:-postgres}"
export PGCLIENTENCODING=UTF8          # los scripts están en UTF-8 (en Git Bash, psql puede tomar WIN1252)
DB="${DB:-foodstore_tp3}"
case "$DB" in
    foodstore|tpi_food_store) echo "DB tiene que ser una copia de prueba, no $DB"; exit 1 ;;
esac
mkdir -p evidencias backups prompts

cargar() {
    PGOPTIONS="-c client_min_messages=warning" psql -X -q -d "$DB" -v ON_ERROR_STOP=1 \
        --single-transaction -f "$1" > /dev/null || { echo "   ERROR en $1"; exit 1; }
}
correr() {  # correr ARCHIVO SALIDA
    psql -X -d "$DB" -v ON_ERROR_STOP=1 -f "$1" > "$2" 2>&1 || { echo "   ERROR (ver $2)"; exit 1; }
}
a_utf8() {  # los mensajes propios de psql (\timing) salen en WIN1252 en Windows: se pasan a UTF-8 sin cambiar el texto
    command -v iconv > /dev/null || return 0
    if ! iconv -f UTF-8 -t UTF-8 "$1" > /dev/null 2>&1; then
        { iconv -f WINDOWS-1252 -t UTF-8 "$1" > "$1.tmp" && mv "$1.tmp" "$1"; } || rm -f "$1.tmp"
    fi
    return 0
}
tiempos() { grep 'Execution Time' "$1" | tr -d '\r' | sed 's/.*: //' | paste -sd ',' - | sed 's/,/, /g'; }

case "${1:-}" in
antes)
    echo ">> Copia de prueba $DB: esquema y datos iniciales del proyecto"
    dropdb --if-exists "$DB"
    createdb "$DB"
    cargar "$RAIZ/sql/01_schema.sql"
    cargar "$RAIZ/sql/02_data.sql"

    echo ">> Protocolo: respaldo de la copia antes de la carga (backups/, no se sube)"
    pg_dump -Fc -d "$DB" -f backups/foodstore_tp3_antes_de_la_carga.dump
    pg_restore --list backups/foodstore_tp3_antes_de_la_carga.dump > /dev/null

    echo ">> Parte 1: carga masiva en una sola transacción (si algo falla, no queda nada a medias)"
    psql -X -d "$DB" -v ON_ERROR_STOP=1 --single-transaction -c '\timing on' \
        -f "$RAIZ/sql/02b_carga_masiva_rapida.sql" > evidencias/parte1_carga_masiva.txt 2>&1 \
        || { echo "   ERROR en la carga (ver evidencias/parte1_carga_masiva.txt)"; exit 1; }
    a_utf8 evidencias/parte1_carga_masiva.txt
    correr sql/parte1_verificacion.sql evidencias/parte1_verificacion.txt

    echo ">> Parte 2: planes ANTES de cualquier cambio"
    correr sql/parte2_antes.sql evidencias/parte2_antes.txt
    echo ">> Parte 5: consulta de la competencia ANTES"
    correr sql/parte5_competencia.sql evidencias/parte5_antes.txt

    {
        echo "# Prompt de la Parte 2: planes reales para que la IA proponga cambios"
        echo
        echo 'Base de PostgreSQL de Food Store: pedido (id_pedido, fecha TIMESTAMPTZ, forma_pago, id_cliente),'
        echo 'detalle_pedido (id_detalle, id_pedido, id_producto, cantidad, precio_unitario, UNIQUE (id_pedido, id_producto)),'
        echo 'producto (id_producto, nombre, precio, stock, activo, id_categoria), cliente y categoria.'
        echo 'Índices actuales: las PK, los UNIQUE, pedido (id_cliente), detalle_pedido (id_producto) y'
        echo 'producto (id_categoria) WHERE activo. Volumen: 200 000 pedidos, 400 000 líneas, 50 000 productos.'
        echo
        echo 'Para cada consulta, con su plan real de EXPLAIN (ANALYZE, BUFFERS), proponé reescrituras y/o índices'
        echo 'que lo mejoren. Justificá cada propuesta con el propio plan: qué nodo ataca y por qué esperás que cambie.'
        echo
        echo 'Consultas (cada una se ejecutó primero una vez, para calentar la caché):'
        echo
        echo '```sql'
        awk '/^\\echo/{sub(/^\\echo .######## /,"-- "); sub(/.$/,""); print; next}
             /^EXPLAIN/{f=1; next} f{print} /;$/{if(f) print ""; f=0}' sql/parte2_antes.sql | tr -d '\r'
        echo '```'
        echo
        echo 'Planes reales:'
        echo
        echo '```'
        grep -v '^ filas\|^-------\|^ *[0-9]\+$\|^(1 fila)\|^(1 row)' evidencias/parte2_antes.txt | tr -d '\r'
        echo '```'
    } > prompts/parte2_propuestas_ia.md

    echo
    echo "================ Resumen ================"
    echo "Parte 1, restricciones (se espera 0 en todas):"
    grep -A2 'check_producto' evidencias/parte1_verificacion.txt | tail -1 | tr -d '\r' | tr -s ' '
    echo "Parte 2, tiempos ANTES (Q1, Q2, Q3): $(tiempos evidencias/parte2_antes.txt)"
    echo "Parte 5, tiempo ANTES: $(tiempos evidencias/parte5_antes.txt)"
    echo "Evidencias en trabajos-practicos/unidad2/semana3_optimizacion_ia/evidencias/"
    ;;

despues)
    a_utf8 evidencias/parte1_carga_masiva.txt
    for f in sql/parte2_cambios.sql sql/parte2_despues.sql sql/parte2_ajuste.sql sql/parte5_cambio.sql sql/parte4_consultas.sql; do
        [ -f "$f" ] || { echo "Falta $f: primero hay que decidir los cambios de la Parte 2"; exit 1; }
    done
    echo ">> Parte 2: cambios aceptados, en una transacción, y ANALYZE"
    psql -X -d "$DB" -v ON_ERROR_STOP=1 --single-transaction -a -f sql/parte2_cambios.sql \
        > evidencias/parte2_cambios_aplicados.txt 2>&1 || { echo "   ERROR (ver evidencias/parte2_cambios_aplicados.txt)"; exit 1; }
    psql -X -q -d "$DB" -v ON_ERROR_STOP=1 -c 'VACUUM (ANALYZE) pedido' -c 'VACUUM (ANALYZE) detalle_pedido' \
        >> evidencias/parte2_cambios_aplicados.txt 2>&1
    echo "VACUUM (ANALYZE) pedido y detalle_pedido: hecho" >> evidencias/parte2_cambios_aplicados.txt
    echo ">> Parte 2: planes DESPUÉS"
    correr sql/parte2_despues.sql evidencias/parte2_despues.txt
    echo ">> Parte 2: mismos índices, con random_page_cost = 1.1 solo en la sesión"
    correr sql/parte2_ajuste.sql evidencias/parte2_ajuste.txt
    echo ">> Parte 5: cambio de la competencia y plan DESPUÉS"
    correr sql/parte5_cambio.sql evidencias/parte5_despues.txt
    echo ">> Parte 4: consultas generadas por la IA y verificación de equivalencia"
    correr sql/parte4_consultas.sql evidencias/parte4_equivalencia.txt

    # Parte 3: el prompt tiene solo el pedido y el texto del plan (Q1 ya con su índice), sin ningún otro contexto
    {
        echo 'Explicá en lenguaje natural, nodo por nodo, qué hace este plan de ejecución de PostgreSQL y por qué tarda lo que tarda.'
        echo
        awk '/######## Q1/{f=1} /######## Q2/{f=0} f' evidencias/parte2_despues.txt | tr -d '\r' \
            | sed -n '/QUERY PLAN/,/Execution Time/p' | sed '1,2d'
    } > prompts/parte3_explicar_plan.txt

    echo
    echo "================ Resumen ================"
    echo "Parte 2, tiempos DESPUÉS (Q1, Q2, Q3): $(tiempos evidencias/parte2_despues.txt)"
    echo "Parte 2, con random_page_cost 1.1 (Q1, Q2, Q3): $(tiempos evidencias/parte2_ajuste.txt)"
    echo "Parte 5, tiempo DESPUÉS: $(tiempos evidencias/parte5_despues.txt)"
    echo "Parte 4, diferencias (se espera 0 en todas):"
    grep -A2 'diferencias_a_menos_b' evidencias/parte4_equivalencia.txt | grep -E '^ +[0-9]' | tr -d '\r' | tr -s ' ' || true
    echo "Siguiente paso: prompts/parte3_explicar_plan.txt en OpenCode, desde una carpeta vacía"
    ;;

sin_paralelo)
    echo ">> Parte 2: mismos índices, sin procesos paralelos (solo en la sesión)"
    correr sql/parte2_sin_paralelo.sql evidencias/parte2_sin_paralelo.txt
    echo "Parte 2, sin paralelismo (Q1, Q2, Q3): $(tiempos evidencias/parte2_sin_paralelo.txt)"
    ;;

*)
    echo "Uso: bash $0 antes | despues | sin_paralelo"; exit 1 ;;
esac
