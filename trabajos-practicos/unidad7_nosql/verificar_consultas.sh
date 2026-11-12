#!/usr/bin/env bash
# U7 · Consigna 5 — Compara cantidad e IDs de las consultas b) y c) en PostgreSQL y MongoDB
# y escribe la tabla de verificación en evidencias/tabla_verificacion.md.
set -euo pipefail
cd "$(dirname "$0")"
DB="${DB:-foodstore}"
MONGO_URI="${MONGO_URI:-mongodb://localhost:27017}"
mkdir -p evidencias

mongo_ids() {  # $1 = filtro de find()
    mongosh "$MONGO_URI" --quiet --eval \
      "db = db.getSiblingDB('foodstore'); print(JSON.stringify(db.pedidos.find($1, {_id: 1}).sort({_id: 1}).toArray().map(p => p._id)))"
}
pg_ids() {  # $1 = condición extra sobre p
    psql -X -d "$DB" -At -c "SELECT COALESCE(json_agg(p.id_pedido ORDER BY p.id_pedido), '[]')
                               FROM pedido p
                              WHERE p.id_pedido IN (SELECT id_pedido FROM v_pedidos_migrados_mongo) AND $1" | tr -d ' '
}
cantidad() { python_cmd -c "import json,sys; print(len(json.loads(sys.argv[1])))" "$1"; }
# El primer Python que funciona de verdad: en Windows, python3 puede ser el acceso directo a la Microsoft Store.
PY=""; for c in python3 python py; do "$c" -c "import sys" >/dev/null 2>&1 && { PY="$c"; break; }; done
python_cmd() { "$PY" "$@"; }

pg_b=$(pg_ids "p.estado = 'CANCELADO'")
mg_b=$(mongo_ids "{estado: 'CANCELADO'}")
pg_c=$(pg_ids "EXISTS (SELECT 1 FROM detalle_pedido dp JOIN producto pr ON pr.id_producto = dp.id_producto
                        WHERE dp.id_pedido = p.id_pedido AND pr.nombre = 'Yerba mate 1kg')")
mg_c=$(mongo_ids "{'lineas.producto': 'Yerba mate 1kg'}")

fila() { if [ "$2" = "$3" ]; then c="Sí"; else c="No"; fi
         echo "| $1 | $(cantidad "$2") | $(cantidad "$3") | $c |"; }
{
echo "| Consulta | Cantidad en PostgreSQL | Cantidad en MongoDB | Coinciden los IDs |"
echo "|---|--:|--:|:-:|"
fila "b) Estado CANCELADO" "$pg_b" "$mg_b"
fila "c) Producto «Yerba mate 1kg»" "$pg_c" "$mg_c"
echo
echo "IDs b) PostgreSQL: \`$pg_b\`"
echo
echo "IDs b) MongoDB: \`$mg_b\`"
echo
echo "IDs c) PostgreSQL: \`$pg_c\`"
echo
echo "IDs c) MongoDB: \`$mg_c\`"
} | tee evidencias/tabla_verificacion.md
