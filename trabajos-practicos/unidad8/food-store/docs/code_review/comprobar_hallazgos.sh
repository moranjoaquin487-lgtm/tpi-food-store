#!/usr/bin/env bash
# Food Store — TP8, consigna 3.c: comprueba en la base los hallazgos del code review de OpenCode (agente Plan).
# La numeración (#1 a #34) es la de la revisión de OpenCode (docs/code_review/revision_opencode.md).
#   bash docs/code_review/comprobar_hallazgos.sh          (desde la carpeta food-store/, después de ejecutar_todo.sh)
# Necesita:
#   - foodstore_tp8 armada por ejecutar_todo.sh (las pruebas van entre BEGIN y ROLLBACK: no cambia nada);
#   - tpi_food_store, la base del TPI (./ejecutar_todo.sh en la raíz del repo). Se trabaja sobre una copia que se borra al final;
#   - para #10 y #20, las reglas de la Semana 2 (por defecto ../../unidad1/semana2_laboratorio_concurrencia/food-store).
set -u
cd "$(dirname "$0")/../.."
export PGUSER="${PGUSER:-postgres}" PGCLIENTENCODING=UTF8
TP8=foodstore_tp8
TPI_DB="${TPI_DB:-tpi_food_store}"
COPIA="${TPI_DB}_revision"
REGLAS_DB=foodstore_tp8_reglas
S2_DIR="${S2_DIR:-../../unidad1/semana2_laboratorio_concurrencia/food-store}"
OUT=evidencias/3c_code_review.txt
mkdir -p evidencias
q()   { psql -X -d "$COPIA" "$@"; }    # copia de la base del TPI
tp8() { psql -X -d "$TP8" "$@"; }       # copia de pruebas del TP8
titulo() { printf '\n===== %s =====\n' "$1"; }

{
echo "===== Comprobaciones del code review de OpenCode · PostgreSQL $(psql -X -d "$TP8" -tAc 'SHOW server_version') · sqlite3 $(sqlite3 -version | cut -d' ' -f1) ====="

# ------------------------------------------------------------------ TPI (Unidades 1 a 3)
if dropdb --if-exists "$COPIA" && createdb -T "$TPI_DB" "$COPIA" 2>/dev/null; then

titulo "#1 · U2 · sql/07_consultas.sql (7.2) y 05b: la facturación pierde las ventas de un producto dado de baja · ACEPTADO"
q -a <<'SQL'
BEGIN;
-- El producto ACTIVO con más ventas (si ya estuviera inactivo, no habría diferencia que mostrar).
SELECT p.id_producto, p.nombre, c.nombre AS categoria, SUM(dp.cantidad * dp.precio_unitario) AS sus_ventas
  FROM producto p JOIN detalle_pedido dp USING (id_producto) JOIN categoria c USING (id_categoria)
 WHERE p.activo
 GROUP BY 1, 2, 3 ORDER BY 4 DESC LIMIT 1 \gset
CREATE TEMP VIEW facturacion_7_2 AS
SELECT c.nombre AS categoria, COALESCE(SUM(dp.cantidad * dp.precio_unitario), 0) AS facturado
  FROM categoria c
  LEFT JOIN producto p        ON p.id_categoria = c.id_categoria AND p.activo = TRUE
  LEFT JOIN detalle_pedido dp ON dp.id_producto = p.id_producto
 WHERE c.activo = TRUE GROUP BY c.nombre;
CREATE TEMP TABLE antes AS SELECT * FROM facturacion_7_2;
UPDATE producto SET activo = FALSE WHERE id_producto = :id_producto;   -- baja lógica (09_soft_delete)
SELECT a.categoria, a.facturado AS antes_de_la_baja, d.facturado AS despues_de_la_baja,
       a.facturado - d.facturado AS ventas_que_desaparecen
  FROM antes a JOIN facturacion_7_2 d USING (categoria) WHERE a.facturado <> d.facturado;
SELECT COUNT(*) AS lineas_de_venta_que_siguen_en_detalle_pedido FROM detalle_pedido WHERE id_producto = :id_producto;
ROLLBACK;
SQL

titulo "#2 · U1 · sql/01_schema.sql: los CASCADE borran vistas, la materializada y el procedimiento sin avisar · ACEPTADO"
q -a <<'SQL'
SELECT (SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'public') AS vistas,
       (SELECT COUNT(*) FROM pg_matviews) AS materializadas,
       (SELECT COUNT(*) FROM pg_proc WHERE proname = 'sp_registrar_pedido') AS procedimiento;
BEGIN;
SET client_min_messages = warning;   -- como lo corre ejecutar_todo.sh del TPI: no se ve ningún aviso
DROP TABLE IF EXISTS detalle_pedido CASCADE;
DROP TABLE IF EXISTS pedido CASCADE;
DROP TABLE IF EXISTS producto CASCADE;
DROP TABLE IF EXISTS categoria CASCADE;
DROP TABLE IF EXISTS cliente CASCADE;
SELECT 'después de los DROP TABLE' AS momento,
       (SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'public') AS vistas,
       (SELECT COUNT(*) FROM pg_matviews) AS materializadas,
       (SELECT COUNT(*) FROM pg_proc WHERE proname = 'sp_registrar_pedido') AS procedimiento;
DROP TYPE IF EXISTS forma_pago_enum CASCADE;   -- el parámetro de sp_registrar_pedido es de este tipo
DROP TABLE IF EXISTS usuario CASCADE;
SELECT 'después del DROP TYPE' AS momento,
       (SELECT COUNT(*) FROM information_schema.views WHERE table_schema = 'public') AS vistas,
       (SELECT COUNT(*) FROM pg_matviews) AS materializadas,
       (SELECT COUNT(*) FROM pg_proc WHERE proname = 'sp_registrar_pedido') AS procedimiento;
ROLLBACK;
SQL

titulo "#3 · U1 · sql/03 y sql/06: el trigger de stock valida pero no descuenta; con dos ventas a la vez frena el CHECK · ACEPTADO"
echo "(a) Un UPDATE de una línea ya vendida no toca el stock:"
q -a <<'SQL'
BEGIN;
SELECT dp.id_detalle, dp.id_producto, dp.cantidad, p.stock AS stock_antes
  FROM detalle_pedido dp JOIN producto p USING (id_producto)
 WHERE p.activo AND p.stock > 5 ORDER BY dp.id_detalle LIMIT 1 \gset
UPDATE detalle_pedido SET cantidad = cantidad + 1 WHERE id_detalle = :id_detalle;
SELECT :cantidad AS cantidad_antes, cantidad AS cantidad_ahora, :stock_antes AS stock_antes,
       (SELECT stock FROM producto WHERE id_producto = :id_producto) AS stock_ahora
  FROM detalle_pedido WHERE id_detalle = :id_detalle;
ROLLBACK;
SQL
P=$(q -tAc "SELECT id_producto FROM producto WHERE activo AND stock BETWEEN 5 AND 60 ORDER BY id_producto LIMIT 1 OFFSET 3")
S=$(q -tAc "SELECT stock FROM producto WHERE id_producto = $P")
PED=$(q -tAc "SELECT COUNT(*) FROM pedido")
echo; echo "(b) Dos sesiones piden las $S unidades del producto $P; la B arranca 0,5 s después:"
( printf "BEGIN;\nCALL sp_registrar_pedido(10, 'EFECTIVO', '[{\"id_producto\": %s, \"cantidad\": %s}]');\nSELECT pg_sleep(2);\nCOMMIT;\n" "$P" "$S" \
    | q -a > /tmp/c3_a.txt 2>&1 ) &
sleep 0.5
printf "CALL sp_registrar_pedido(11, 'TARJETA', '[{\"id_producto\": %s, \"cantidad\": %s}]');\n" "$P" "$S" | q -a > /tmp/c3_b.txt 2>&1
wait
echo "----- SESIÓN A -----"; cat /tmp/c3_a.txt
echo "----- SESIÓN B -----"; grep -v -E '^(CONTEXT|PL/pgSQL|  |DETAIL)' /tmp/c3_b.txt
q -c "SELECT id_producto, stock AS stock_final FROM producto WHERE id_producto = $P" \
  -c "SELECT COUNT(*) - $PED AS pedidos_nuevos FROM pedido"
dropdb "$COPIA"

else
  echo; echo "!! No está la base $TPI_DB: corré ./ejecutar_todo.sh en la raíz del repo tpi-food-store. Se saltean #1 a #3."
fi

# ------------------------------------------------------------------ Semana 2 (Unidad 1)
titulo "#9 · U1 · crear_base.sh: el código de salida de un bloque con | tee es el de tee · ACEPTADO"
bash -c '{ echo "algo falla adentro"; exit 1; } 2>&1 | tee /dev/null > /dev/null; echo "sin pipefail, código de salida: $?"'
bash -c 'set -o pipefail; { echo "algo falla adentro"; exit 1; } 2>&1 | tee /dev/null > /dev/null; echo "con pipefail, código de salida: $?"'

if [ -f "$S2_DIR/restricciones.sql" ]; then
  dropdb --if-exists "$REGLAS_DB" && createdb "$REGLAS_DB" \
    && psql -X -q -d "$REGLAS_DB" -v ON_ERROR_STOP=1 -f servidor/schema.sql -f servidor/data.sql -f "$S2_DIR/restricciones.sql" > /dev/null 2>&1

  titulo "#10 · U1 · semana2/restricciones.sql: la Regla A deja cambiar el producto de una línea con el precio congelado · ACEPTADO"
  psql -X -d "$REGLAS_DB" -a <<'SQL'
BEGIN;
SELECT d.pedido_id FROM detalle_pedido d JOIN producto p ON p.id = d.producto_id
 WHERE p.nombre = 'Muzzarella'
   AND NOT EXISTS (SELECT 1 FROM detalle_pedido x JOIN producto q ON q.id = x.producto_id
                    WHERE x.pedido_id = d.pedido_id AND q.nombre = 'Napolitana')
 LIMIT 1 \gset
UPDATE detalle_pedido SET producto_id = (SELECT id FROM producto WHERE nombre = 'Napolitana')
 WHERE pedido_id = :pedido_id AND producto_id = (SELECT id FROM producto WHERE nombre = 'Muzzarella');
SELECT d.pedido_id, p.nombre AS producto_ahora, d.precio_unitario, p.precio AS precio_de_lista
  FROM detalle_pedido d JOIN producto p ON p.id = d.producto_id
 WHERE d.pedido_id = :pedido_id AND p.nombre = 'Napolitana';
ROLLBACK;
SQL

  titulo "#20 · U8 · servidor del TP8 sin las reglas A, B y C: con las reglas cargadas, la instantánea final es la misma · DESCARTADO"
  psql -X -q -d "$REGLAS_DB" -v ON_ERROR_STOP=1 -f servidor/v_snapshot_movil.sql \
       -f servidor/casos/c2_subir_precio.sql -f servidor/casos/c4_baja_logica.sql > /dev/null 2>&1 \
    && echo "Las preparaciones de C2 (precio) y C4 (baja lógica) pasan con las reglas A, B y C activas."
  psql -X -d "$REGLAS_DB" -tAc "SELECT tgname FROM pg_trigger WHERE NOT tgisinternal ORDER BY 1" | sed 's/^/  trigger: /'
  CONSULTA="SELECT id, nombre, precio_centavos, stock, disponible, eliminado FROM v_snapshot_movil ORDER BY id"
  if diff <(psql -X -d "$TP8" -tA -c "$CONSULTA") <(psql -X -d "$REGLAS_DB" -tA -c "$CONSULTA") > /tmp/dif_reglas.txt; then
    echo "diff de v_snapshot_movil entre $TP8 (sin reglas) y $REGLAS_DB (con reglas): sin diferencias"
  else
    echo "diff de v_snapshot_movil: HAY DIFERENCIAS"; cat /tmp/dif_reglas.txt
  fi
  dropdb "$REGLAS_DB"
else
  echo; echo "!! No está $S2_DIR/restricciones.sql: se saltean #10 y #20."
fi

# ------------------------------------------------------------------ TP8 (Unidad 8), servidor
titulo "#13 · U8 · servidor/v_snapshot_movil.sql: centavos en INTEGER desbordan con un precio alto · CORREGIDO"
echo "Antes (::INTEGER):"
tp8 -a -c "SELECT ROUND(25000000.00 * 100)::INTEGER AS precio_centavos;" 2>&1
echo "Ahora (::BIGINT, en la vista):"
tp8 -a <<'SQL'
BEGIN;
UPDATE producto SET precio = 25000000.00 WHERE nombre = 'Flan casero';
SELECT nombre, precio_centavos, pg_typeof(precio_centavos) AS tipo FROM v_snapshot_movil WHERE nombre = 'Flan casero';
ROLLBACK;
SQL

titulo "#18 · U8 · servidor/verificacion_final.sql: no detectaba un producto nuevo ni un cambio que no mueve los totales · CORREGIDO"
tp8 -q <<'SQL'
BEGIN;
INSERT INTO producto (nombre, precio, stock, activo, categoria_id)
VALUES ('Producto nuevo', 100, 0, TRUE, (SELECT id FROM categoria WHERE nombre = 'Postres'));
\echo '--- Versión anterior (docs/code_review/antes/verificacion_final.sql): no ve el producto nuevo'
\i docs/code_review/antes/verificacion_final.sql
\echo '--- Versión corregida (servidor/verificacion_final.sql): lo detecta'
\i servidor/verificacion_final.sql
ROLLBACK;
SQL

titulo "#26 · U8 · v_snapshot_movil: eliminado no mira la categoría · DESCARTADO (una categoría inactiva ya da disponible = false)"
tp8 -a <<'SQL'
BEGIN;
UPDATE categoria SET activo = FALSE WHERE nombre = 'Bebidas';
SELECT nombre, disponible, eliminado FROM v_snapshot_movil WHERE nombre = 'Coca 1.5L';
ROLLBACK;
SQL
echo "En semaforo.sql, disponible = 'f' es motivo de RECHAZADO («no está disponible»), igual que una baja."

titulo "#31 · U1 · data.sql: row_number() OVER (ORDER BY fecha) sería ambiguo con fechas repetidas · DESCARTADO"
tp8 -a -c "SELECT fecha, COUNT(*) AS pedidos_con_esa_fecha FROM pedido GROUP BY fecha HAVING COUNT(*) > 1;"

# ------------------------------------------------------------------ TP8 (Unidad 8), tablet
T=$(mktemp -d)
cp movil/schema_sqlite.sql movil/cargar_snapshot.sql movil/semaforo.sql "$T"/
cp docs/code_review/antes/cargar_snapshot.sql "$T"/cargar_snapshot_antes.sql
cp evidencias/instantaneas/0_inicial.csv "$T"/completa.csv
head -6 "$T"/completa.csv > "$T"/cortada.csv     # encabezado y 5 de las 12 filas

titulo "#4 · U8 · movil/cargar_snapshot.sql: un CSV cortado dejaba como lápidas los productos que faltan · CORREGIDO"
( cd "$T"
  sqlite3 t.db < schema_sqlite.sql > /dev/null
  cp completa.csv servidor_snapshot.csv && sqlite3 -bail t.db < cargar_snapshot.sql > /dev/null
  sqlite3 -header -table t.db "SELECT 'carga completa' AS momento, COUNT(*) AS productos, SUM(eliminado = 1) AS lapidas FROM producto_cache;"
  echo; echo "CSV cortado: $(($(wc -l < cortada.csv) - 1)) filas de 12."
  cp cortada.csv servidor_snapshot.csv
  echo "Versión anterior (docs/code_review/antes/cargar_snapshot.sql):"
  cp t.db antes.db && sqlite3 -bail antes.db < cargar_snapshot_antes.sql > /dev/null 2>&1
  sqlite3 -header -table antes.db "SELECT 'después del CSV cortado' AS momento, COUNT(*) AS productos, SUM(eliminado = 1) AS lapidas FROM producto_cache;"
  echo "Versión corregida (movil/cargar_snapshot.sql):"
  sqlite3 -bail t.db < cargar_snapshot.sql 2>&1 | grep -i -E "error|constraint"
  sqlite3 -header -table t.db "SELECT 'después del CSV cortado' AS momento, COUNT(*) AS productos, SUM(eliminado = 1) AS lapidas FROM producto_cache;" )

titulo "#5 · U8 · movil/semaforo.sql: dos solicitudes del mismo producto se evalúan por separado · ACEPTADO (límite documentado)"
( cd "$T" && rm -f t.db && cp completa.csv servidor_snapshot.csv \
  && sqlite3 t.db < schema_sqlite.sql > /dev/null && sqlite3 -bail t.db < cargar_snapshot.sql > /dev/null \
  && sqlite3 -header -table t.db <<'SQL'
PRAGMA foreign_keys = ON;
INSERT INTO pedido_borrador (id_local, usuario, forma_pago) VALUES
  ('b0000001-0000-4000-8000-000000000000', 'feria-01', 'EFECTIVO'),
  ('b0000002-0000-4000-8000-000000000000', 'feria-02', 'EFECTIVO');
INSERT INTO item_borrador SELECT 'b0000001-0000-4000-8000-000000000000', id, 10, precio_centavos FROM producto_cache WHERE nombre = 'Flan casero';
INSERT INTO item_borrador SELECT 'b0000002-0000-4000-8000-000000000000', id, 10, precio_centavos FROM producto_cache WHERE nombre = 'Flan casero';
INSERT INTO cola_sync (solicitud_uuid, id_local) VALUES
  ('a0000001-0000-4000-8000-000000000000', 'b0000001-0000-4000-8000-000000000000'),
  ('a0000002-0000-4000-8000-000000000000', 'b0000002-0000-4000-8000-000000000000');
SELECT stock AS stock_del_flan_en_la_instantanea FROM snapshot_servidor WHERE nombre = 'Flan casero';
.read semaforo.sql
SQL
)
rm -rf "$T"

titulo "#19 · U8 · movil/pruebas_sqlite.sql: la solicitud de 1.c queda PENDIENTE hasta C2 · DESCARTADO"
echo "La pide la consigna (borrador completo guardado con BEGIN … COMMIT). Se evalúa en la primera corrida del semáforo,"
echo "con la misma instantánea que C2, y no cambia el resultado de C2 porque cada caso tiene su propia solicitud:"
(cd movil && sqlite3 -header -table foodstore_movil.db \
  "SELECT substr(solicitud_uuid, 1, 8) AS solicitud, estado, evaluada_con FROM cola_sync
    WHERE solicitud_uuid LIKE 'a001c001%' OR solicitud_uuid LIKE 'a0c20001%' ORDER BY rowid;")
} > "$OUT" 2>&1
echo ">> Listo: $OUT"
