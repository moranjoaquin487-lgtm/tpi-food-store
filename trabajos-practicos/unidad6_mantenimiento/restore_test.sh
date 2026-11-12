#!/usr/bin/env bash
# U6 — Simulacro de desastre contra reloj: restaura el último respaldo en
# foodstore_restore_test, valida y mide RTO y RPO.
# La base principal no se toca. La contraseña sale de pgpass.conf.
# JOBS=4 ./restore_test.sh restaura en paralelo (mejora propuesta en el informe).
set -euo pipefail
cd "$(dirname "$0")"

ORIGEN="${DB:-foodstore}"
DESTINO="foodstore_restore_test"
export PGHOST="${PGHOST:-localhost}" PGPORT="${PGPORT:-5432}" PGUSER="${PGUSER:-postgres}"
mkdir -p logs evidencias

if [ "$DESTINO" = "$ORIGEN" ]; then echo "El destino no puede ser la base principal" >&2; exit 1; fi

dump="$(ls -t backups/"${ORIGEN}"_*.dump 2>/dev/null | head -1 || true)"
if [ -z "$dump" ]; then echo "No hay respaldos en backups/. Corré antes ./backup_foodstore.sh" >&2; exit 1; fi
conteos="${dump%.dump}.conteos.txt"

# Fecha del respaldo, tomada del nombre del archivo (AAAAMMDD_HHMMSS)
sello="$(basename "$dump" .dump)"; sello="${sello#"${ORIGEN}"_}"
fecha_respaldo="${sello:0:4}-${sello:4:2}-${sello:6:2} ${sello:9:2}:${sello:11:2}:${sello:13:2}"
reporte="evidencias/restore_test_$(date +%Y%m%d_%H%M%S).txt"

{
echo "Simulacro de restauración de $ORIGEN"
echo "Respaldo usado:        $dump"
echo "Fecha del respaldo:    $fecha_respaldo"
echo "Tamaño del respaldo:   $(du -h "$dump" | cut -f1)"
echo "Restauración en paralelo: ${JOBS:-no (1 proceso)}"
echo

# Preparación (fuera del cronómetro): si quedó una base de prueba de un simulacro anterior, se borra.
dropdb --if-exists "$DESTINO"

echo "== Cronómetro: INICIO $(date '+%Y-%m-%d %H:%M:%S')"
t0=$(date +%s%N)

createdb "$DESTINO"
pg_restore -d "$DESTINO" --no-owner --no-privileges --exit-on-error ${JOBS:+--jobs="$JOBS"} "$dump"
t_restore=$(date +%s%N)

echo
echo "== Validación 1: filas por tabla (respaldo vs restaurada)"
psql -X -d "$DESTINO" -At -F ' ' -c "
    SELECT 'categoria', COUNT(*) FROM categoria
    UNION ALL SELECT 'cliente', COUNT(*) FROM cliente
    UNION ALL SELECT 'producto', COUNT(*) FROM producto
    UNION ALL SELECT 'pedido', COUNT(*) FROM pedido
    UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido;" > /tmp/conteos_restaurada.txt
printf "%-16s %12s %12s %s\n" tabla respaldo restaurada coincide
ok_filas=1
# psql en Windows termina las líneas con \r\n: se quita el \r antes de comparar.
while read -r tabla n_resp; do
    n_resp="${n_resp//$'\r'/}"
    n_rest=$(awk -v t="$tabla" '$1 == t {print $2}' /tmp/conteos_restaurada.txt | tr -d '\r')
    if [ "$n_resp" = "$n_rest" ]; then c="sí"; else c="NO"; ok_filas=0; fi
    printf "%-16s %12s %12s %s\n" "$tabla" "$n_resp" "$n_rest" "$c"
done < "$conteos"

echo
echo "== Validación 2: restricciones lógicas (se espera 0 y 0)"
invalidos=$(psql -X -d "$DESTINO" -At -F ' ' -c "
    SELECT (SELECT COUNT(*) FROM producto WHERE precio < 0 OR stock < 0),
           (SELECT COUNT(*) FROM detalle_pedido WHERE cantidad <= 0 OR precio_unitario < 0);" | tr -d '\r')
echo "productos_invalidos detalles_invalidos"
echo "$invalidos"

t1=$(date +%s%N)
echo
echo "== Cronómetro: FIN $(date '+%Y-%m-%d %H:%M:%S')"

rto_ms=$(( (t1 - t0) / 1000000 ))
restore_ms=$(( (t_restore - t0) / 1000000 ))
edad_s=$(( $(date +%s) - $(date -d "$fecha_respaldo" +%s) ))

echo
echo "== Resultado"
echo "RTO observado (createdb + pg_restore + validaciones): $((rto_ms / 1000)),$(printf '%03d' $((rto_ms % 1000))) s"
echo "   de los cuales createdb + pg_restore:               $((restore_ms / 1000)),$(printf '%03d' $((restore_ms % 1000))) s"
echo "RPO observado (antigüedad del respaldo al restaurar):  $((edad_s / 3600)) h $(( (edad_s % 3600) / 60 )) min $((edad_s % 60)) s"
if [ "$ok_filas" = 1 ] && [ "$invalidos" = "0 0" ]; then
    echo "Validaciones: OK"
else
    echo "Validaciones: FALLARON"
fi
echo "La base $ORIGEN no se modificó durante el simulacro."
} 2>&1 | tee "$reporte"

grep -q "Validaciones: OK" "$reporte"
