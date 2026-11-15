# TP Semana 4 (Unidad 2) — Reportes analíticos asistidos por IA sobre Food Store

- **Alumno:** Moran, Joaquín Leandro. Trabajo individual.
- **Base:** `foodstore_s4` (PostgreSQL 18), copia del estado final de la Semana 3 (`foodstore_tp3`): carga masiva e índices de esa práctica. No se toca `foodstore`.
- **Informe para el campus:** [`docs/Informe_TP_Semana4_Moran.pdf`](docs/Informe_TP_Semana4_Moran.pdf).

## Entregables

| Entregable | Archivo | Evidencia |
|---|---|---|
| Tabla comparativa con los planes antes y después y el algoritmo de join (Parte 1) | [`sql/parte1_antes.sql`](sql/parte1_antes.sql), [`sql/parte1_cambios.sql`](sql/parte1_cambios.sql), [`sql/parte1_despues.sql`](sql/parte1_despues.sql), [`sql/parte1_ajuste.sql`](sql/parte1_ajuste.sql), [`sql/parte1_alternativa.sql`](sql/parte1_alternativa.sql) | `evidencias/parte1_*.txt`; prompt y respuesta de OpenCode en `prompts/parte1_propuestas_ia.md` y `docs/respuestas_ia/parte1_propuestas_opencode.md` |
| Tabla de lectura crítica (Parte 2) | Informe, sección 2 | `prompts/parte2_explicar_plan.txt`, `docs/respuestas_ia/parte2_explicacion_opencode.md` |
| Ranking y subconsulta bajo spec, con su equivalencia (Parte 3) | [`docs/parte3_specs.md`](docs/parte3_specs.md), [`sql/parte3_consultas.sql`](sql/parte3_consultas.sql) | `evidencias/parte3_equivalencia.txt` |
| Registro de la competencia (Parte 4) | [`sql/parte4_competencia.sql`](sql/parte4_competencia.sql), [`sql/parte4_cambio.sql`](sql/parte4_cambio.sql) | `evidencias/parte4_antes.txt`, `evidencias/parte4_despues.txt` |
| DUIA | Informe, sección 5 | — |

## Cómo se corre

Primero tiene que existir `foodstore_tp3` (Semana 3, `antes` y `despues`). Desde la raíz del repositorio, en Git Bash (usa el `pgpass.conf` de postgres; no pide ni guarda contraseñas):

```bash
bash trabajos-practicos/unidad2/semana4_reportes_analiticos_ia/ejecutar_tp4.sh antes    # copia de trabajo y planes ANTES
bash trabajos-practicos/unidad2/semana4_reportes_analiticos_ia/ejecutar_tp4.sh despues  # cambios, planes DESPUÉS, Partes 3 y 4
```

`antes` copia `foodstore_tp3` en `foodstore_s4`, mide las consultas de las Partes 1 y 4 y arma `prompts/parte1_propuestas_ia.md`. Entre `antes` y `despues` va el paso de la IA: OpenCode recibe ese prompt y se deciden los cambios. `despues` rehace la copia desde el mismo estado, aplica el índice en una transacción y mide las consultas originales, las reescrituras, la configuración (solo en la sesión) y la alternativa propia. Después corre las Partes 3 y 4, verifica todas las equivalencias con `EXCEPT` y arma `prompts/parte2_explicar_plan.txt`, que OpenCode explica desde una carpeta vacía, sin otro contexto.

## Resultados

| Consulta | Antes | Mejor después | Qué funcionó |
|---|---|---|---|
| Q1 · facturación por categoría y mes | 582,1 ms | 247,5 ms | Agrupar por `id_categoria` y unir `categoria` al final (alternativa propia). Las propuestas de OpenCode no cambiaron los Hash Join |
| Q2 · ranking de clientes por gasto | 171,8 ms | 118,2 ms | Reescritura R2 de OpenCode + `work_mem` en la sesión |
| Competencia · top 10 de productos en 30 días | 165,3 ms | 32,4 ms | Agregar antes de unir + índice cubriente: de Hash Join en paralelo a Nested Loop |

## Adaptaciones

- La consigna habla de `queries.sql`: las consultas son propias, sobre el modelo, del tipo que pide (facturación por categoría y mes, ranking de clientes por gasto).
- La consigna dice «usuarios»: en Food Store los compradores están en `cliente`, y `usuario` son las cuentas de la aplicación.
- La competencia de la Parte 4 es entre equipos y se hace en clase con la consulta que fija la cátedra. Este TP es individual: el registro es el mío, con una consulta del mismo tipo.
- Borrado lógico del esquema: `categoria.activo` y `producto.activo`. `cliente`, `pedido` y `detalle_pedido` no tienen.
- Kiro no se usó en este TP.
