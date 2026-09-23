#!/usr/bin/env bash
# Recrea la base $DB (por defecto tpi_food_store), corre todos los scripts en orden y guarda la salida en evidencias/.
set -u
DB="${DB:-tpi_food_store}"
export PGUSER="${PGUSER:-postgres}"
cd "$(dirname "$0")"
mkdir -p evidencias

echo ">> Recreando la base $DB"
dropdb --if-exists "$DB" && createdb "$DB" || exit 1

# Construcción: sin errores y en una sola transacción.
estrictos=(01_schema 02_data 02b_carga_masiva_rapida 03_restricciones 04_indices 05_vistas 05b_materializadas 06_funciones_procedimientos)
for s in "${estrictos[@]}"; do
  echo ">> $s"
  psql -d "$DB" -q -v ON_ERROR_STOP=1 --single-transaction -f "sql/$s.sql" \
       > "evidencias/$s.txt" 2>&1 || { echo "   ERROR en $s (ver evidencias/$s.txt)"; exit 1; }
done

# Pruebas: incluyen errores esperados, se muestran con eco (-a).
pruebas=(02c_verificacion_carga_masiva 03b_pruebas_restricciones 07_consultas 08_transacciones 09_soft_delete 10_auditoria_precios 11_optimizacion)
for s in "${pruebas[@]}"; do
  echo ">> $s"
  psql -d "$DB" -a -f "sql/$s.sql" > "evidencias/$s.txt" 2>&1
done

# Concurrencia: dos sesiones reales. La sesión B arranca 1 s después que la A.
dos_sesiones() {  # $1 = archivo de salida, $2 = título, $3 = comandos de A (separados por |pausa|), $4 = comandos de B
  local out="evidencias/$1.txt" a1="${3%%|pausa|*}" a2="${3#*|pausa|}"
  { echo "$a1"; sleep 2; echo "$a2"; } | psql -d "$DB" -a > /tmp/sesion_a.txt 2>&1 &
  sleep 1
  echo "$4" | psql -d "$DB" -a > /tmp/sesion_b.txt 2>&1
  wait
  { echo "===== $2 ====="; echo; echo "----- SESIÓN A -----"; cat /tmp/sesion_a.txt
    echo; echo "----- SESIÓN B (arranca 1 s después) -----"; cat /tmp/sesion_b.txt; } > "$out"
}
echo ">> 08b / 08c / 08d (dos sesiones)"
CONTAR="SELECT COUNT(*) AS pedidos_cliente_10 FROM pedido WHERE id_cliente = 10;"
INSERTAR="INSERT INTO pedido (forma_pago, id_cliente) VALUES ('EFECTIVO', 10);"
dos_sesiones 08b_sesiones_read_committed "Lectura fantasma en READ COMMITTED" \
  "BEGIN ISOLATION LEVEL READ COMMITTED; $CONTAR|pausa|$CONTAR COMMIT;" "$INSERTAR"
dos_sesiones 08c_sesiones_repeatable_read "La misma prueba en REPEATABLE READ" \
  "BEGIN ISOLATION LEVEL REPEATABLE READ; $CONTAR|pausa|$CONTAR COMMIT;" "$INSERTAR"
dos_sesiones 08d_sesiones_for_update "Espera por bloqueo con FOR UPDATE" \
  "BEGIN; SELECT id_producto, stock FROM producto WHERE id_producto = 20 FOR UPDATE;|pausa|UPDATE producto SET stock = stock - 1 WHERE id_producto = 20; COMMIT;" \
  "\\timing on
BEGIN;
SELECT id_producto, stock FROM producto WHERE id_producto = 20 FOR UPDATE;
COMMIT;"

echo ">> Listo. Revisá la carpeta evidencias/."
