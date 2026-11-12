-- U4 · 09 — Reversión de la desnormalización
-- Quita la tabla resumen, sus triggers y funciones. Los reportes vuelven a la consulta normalizada.
-- Uso: sin variables = ensayo (ROLLBACK); con -v accion=COMMIT = revierte de verdad.

\set ON_ERROR_STOP on
\if :{?accion}
\else
  \set accion ROLLBACK
\endif
\echo '== Modo de ejecución:' :accion

BEGIN;
DROP VIEW IF EXISTS v_top5_categorias;
DROP TRIGGER trg_resumen_detalle_ins ON detalle_pedido;
DROP TRIGGER trg_resumen_detalle_upd ON detalle_pedido;
DROP TRIGGER trg_resumen_detalle_del ON detalle_pedido;
DROP TRIGGER trg_resumen_cambio_categoria ON producto;
DROP FUNCTION fn_resumen_detalle();
DROP FUNCTION fn_resumen_cambio_categoria();
DROP FUNCTION fn_resumen_aplicar(JSONB);
DROP FUNCTION fn_verificar_resumen_categoria();
DROP PROCEDURE sp_recalcular_resumen_categoria();
DROP TABLE resumen_ventas_categoria;

\echo '== Triggers que quedan sobre detalle_pedido'
SELECT tgname FROM pg_trigger WHERE tgrelid = 'detalle_pedido'::regclass AND NOT tgisinternal ORDER BY 1;
:accion;

SELECT to_regclass('public.resumen_ventas_categoria') AS tabla_resumen;
