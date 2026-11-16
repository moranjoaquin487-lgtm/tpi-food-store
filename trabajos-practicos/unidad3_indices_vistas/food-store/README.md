# TP Unidad 3 (Semana 5) — Índices, vistas y vistas materializadas en Food Store

- **Alumno:** Moran, Joaquín Leandro. Trabajo individual.
- **Flujo:** specs en Kiro → SQL con OpenCode → medición y decisión → un commit por pieza (punto 5 de la consigna).
- **Informe para el campus:** [`docs/Informe_TP_U3_Moran.pdf`](docs/Informe_TP_U3_Moran.pdf). El mismo contenido está en [`informe_mediciones.md`](informe_mediciones.md) y [`duia.md`](duia.md).

## Estructura (la que pide la consigna, más las carpetas de trabajo)

| Archivo o carpeta | Qué es |
|---|---|
| `schema.sql` | Heredado sin modificar: es `sql/01_schema.sql` del proyecto |
| `data.sql` | Heredado y ampliado: datos semilla (`sql/02_data.sql`) más la carga masiva de la Semana 3 (`sql/02b_carga_masiva_rapida.sql`), sin cambios |
| `queries.sql` | Heredado: las consultas del proyecto (`sql/07_consultas.sql`) y las de las Semanas 3 y 4. Las que se indexan están marcadas `[Parte A · Cn]` |
| `indices.sql` | Parte A: los 2 índices aceptados, comentados |
| `views.sql` | Parte B: las 4 vistas y `rol_reportes` |
| `materializadas.sql` | Parte C: la vista materializada y su índice único |
| `specs/` | Las 9 specs que escribió Kiro |
| `duia.md` | Declaración de uso de IA y bitácora |
| `informe_mediciones.md` | `EXPLAIN ANALYZE` antes y después, escrituras, índice descartado, verificación de las vistas y vista materializada |
| `propuestas/` | Lo que generó OpenCode, tal cual (ronda 1 y ronda 2) |
| `consultas_manuales.sql` | Las consultas con las que se verifica cada vista |
| `mediciones/` | Los scripts de medición y verificación |
| `prompts/` | Los prompts para Kiro y OpenCode |
| `docs/respuestas_ia/` | Las respuestas completas de OpenCode, sin las fechas del export. Las dos rondas se hicieron en la misma sesión; el archivo de la ronda 2 tiene solo esa parte |
| `evidencias/` | Las salidas de todas las corridas |

## Cómo reproducir las pruebas

En Git Bash, desde esta carpeta (usa el `pgpass.conf` de postgres; no pide ni guarda contraseñas):

```bash
bash ejecutar_u3.sh antes          # crea foodstore_u3 desde schema.sql y data.sql, mide antes y arma el prompt para Kiro
bash ejecutar_u3.sh probar propuestas/indices_opencode.sql propuestas/indices_opencode_ronda2.sql
                                   # prueba índices propuestos: mide sin y con en la misma corrida y los vuelve a borrar
bash ejecutar_u3.sh despues        # medición final: sin y con indices.sql, índice descartado, vistas y vista materializada
bash ejecutar_u3.sh diagnostico    # costos de los dos planes posibles de C1 y C1 con random_page_cost = 1.1
```

Todo corre sobre `foodstore_u3`: el script se niega a usar `foodstore`. Los cambios de configuración son solo de la sesión. Las escrituras de prueba se hacen dentro de transacciones que se deshacen. `rol_reportes` es un rol del servidor (los roles no son de una base): se crea solo si no existe y no tiene `LOGIN`.

## Resultados

| Parte | Resultado |
|---|---|
| A · C1, facturación de la semana | Con los dos índices: −92 % cuando el planner elige Nested Loop (ronda 2, y siempre con `random_page_cost = 1.1`). En la medición final eligió Hash Join: los dos planes empatan en costo estimado |
| A · C2 y C3, 30 días | `pedido` pasa a Index Only Scan, pero no bajan a la mitad: no cumplen el criterio |
| A · C4 | Sin índice: el Hash Anti Join es el plan correcto |
| A · descarte | `producto (nombre, id_producto) WHERE activo` (sugerido por Kiro): la condición no filtra (99,998 % activos) y el planner ni lo usa |
| B · vistas | Las 4 coinciden con su consulta manual (0 y 0). `rol_reportes` lee la vista y no la tabla `usuario` |
| C · vista materializada | ~1071 ms → 0,12 ms, mismo resultado. Se refresca una vez por día con `CONCURRENTLY` (~1 s) |

## Historial de commits (un commit por pieza)

`git log --oneline` muestra el flujo: base y medición antes → specs de Kiro → propuestas de OpenCode y su medición → ronda 2 → un commit por índice (y el descartado) → uno por vista → la vista materializada → verificación → consultas manuales → informe.

## Adaptaciones

- La consigna nombra «usuario» como comprador. En este esquema los compradores están en `cliente` y `usuario` son las cuentas de la aplicación, que tienen `contrasena`: la vista de pedidos usa `cliente` y la vista de seguridad, `usuario`.
- Los índices de la Semana 3 del enunciado (`idx_producto_categoria`, `idx_pedido_usuario`, `idx_producto_nombre_vig`) son de su esquema de ejemplo. El punto de partida de este trabajo son los índices de `schema.sql`: `pedido (id_cliente)`, `producto (id_categoria) WHERE activo` y `detalle_pedido (id_producto)`.
