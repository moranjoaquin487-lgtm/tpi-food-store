#!/usr/bin/env bash
# Crea la plantilla (esquema + datos iniciales) y la copia de trabajo, como indica protocolo_seguridad.md.
# Ojo: borra y vuelve a crear las dos bases; lo aplicado sobre la copia se pierde.
set -u
cd "$(dirname "$0")/.."
export PGUSER="${PGUSER:-postgres}" PGCLIENTENCODING=UTF8 PGOPTIONS="-c client_min_messages=warning"
PLANTILLA=foodstore_plantilla
TRABAJO=foodstore_trabajo
mkdir -p evidencias
{
  echo "===== Plantilla: $PLANTILLA (esquema + datos iniciales; no se modifica) ====="
  dropdb --if-exists "$TRABAJO" && dropdb --if-exists "$PLANTILLA" && createdb "$PLANTILLA" || exit 1
  psql -d "$PLANTILLA" -q -v ON_ERROR_STOP=1 -f food-store/schema.sql -f food-store/data.sql || exit 1
  echo
  echo "===== Copia de trabajo: createdb -T $PLANTILLA $TRABAJO ====="
  createdb -T "$PLANTILLA" "$TRABAJO" || exit 1
  psql -d "$TRABAJO" -c "SELECT current_database();" \
       -c "SELECT 'categoria' AS tabla, COUNT(*) AS filas FROM categoria
           UNION ALL SELECT 'producto', COUNT(*) FROM producto
           UNION ALL SELECT 'cliente', COUNT(*) FROM cliente
           UNION ALL SELECT 'pedido', COUNT(*) FROM pedido
           UNION ALL SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido;"
} 2>&1 | tee evidencias/00_base.txt
