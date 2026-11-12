#!/usr/bin/env bash
# U6 — Respaldo de foodstore en formato custom.
# Uso: ./backup_foodstore.sh   (variables opcionales: PGHOST, PGPORT, PGUSER, DB)
# La contraseña NO va acá: se toma de pgpass.conf.
set -euo pipefail
cd "$(dirname "$0")"

DB="${DB:-foodstore}"
export PGHOST="${PGHOST:-localhost}" PGPORT="${PGPORT:-5432}" PGUSER="${PGUSER:-postgres}"
mkdir -p backups logs

marca="$(date +%Y%m%d_%H%M%S)"
dump="backups/${DB}_${marca}.dump"
conteos="backups/${DB}_${marca}.conteos.txt"
log="logs/backup.log"

registrar() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" | tee -a "$log"; }

registrar "INICIO respaldo de $DB en $PGHOST:$PGPORT -> $dump"

# Filas por tabla en el momento del respaldo: la restauración de prueba las compara.
if ! psql -X -d "$DB" -At -F ' ' -v ON_ERROR_STOP=1 -c "
    SELECT 'categoria', COUNT(*) FROM categoria
    UNION ALL SELECT 'cliente', COUNT(*) FROM cliente
    UNION ALL SELECT 'producto', COUNT(*) FROM producto
    UNION ALL SELECT 'pedido', COUNT(*) FROM pedido
    UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido;" > "$conteos"; then
    registrar "ERROR no se pudo conectar a $DB para contar filas"
    exit 1
fi

inicio=$(date +%s)
if ! pg_dump -d "$DB" -Fc -f "$dump" 2>> "$log"; then
    registrar "ERROR pg_dump falló (ver líneas anteriores de $log)"
    rm -f "$dump"
    exit 1
fi
fin=$(date +%s)

# El archivo tiene que poder leerse: si pg_restore no puede listarlo, el respaldo no sirve.
if ! objetos=$(pg_restore --list "$dump" 2>> "$log" | grep -vc '^;'); then
    registrar "ERROR el archivo $dump no se puede leer con pg_restore"
    exit 1
fi

tamano=$(du -h "$dump" | cut -f1)
registrar "OK $dump  tamaño=$tamano  objetos=$objetos  duración=$((fin - inicio))s"
