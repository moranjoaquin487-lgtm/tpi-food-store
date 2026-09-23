# Declaración de Uso de IA (DUIA) — Resumen del proyecto

**Proyecto:** TPI Food Store — Base de Datos II (UTN)
**Alumno:** Moran, Joaquín Leandro
**Alcance:** Unidades 1, 2 y 3, y la primera entrega del TPI

Este documento resume qué herramientas de IA se usaron en cada unidad, para qué, y qué se aceptó o descartó. El criterio fue siempre el mismo: la IA propone, y la decisión se toma con el resultado del motor (errores, planes de `EXPLAIN ANALYZE`, tiempos y comparaciones con `EXCEPT`), nunca por lo convincente de la explicación.

## Herramientas

| Herramienta | Uso principal |
|---|---|
| **OpenCode** (agente de terminal) | Generar y revisar SQL a partir de specs; explicar planes de ejecución |
| **Kiro** | Escribir las specs antes de generar código; steering docs del esquema |
| **Claude (Anthropic)** | Explicaciones conceptuales, reconstrucción de escenarios de concurrencia y, en el TPI, revisión del proyecto y generación de scripts |

## Unidad 1 — Integridad, transacciones y concurrencia

| Uso | Herramienta | Qué se aceptó | Qué se corrigió o descartó |
|---|---|---|---|
| Restricciones de integridad desde una spec | Kiro + OpenCode (modo Plan) | Dos triggers `BEFORE ... FOR EACH ROW` (producto activo y stock suficiente), porque un `CHECK` no puede leer otra tabla | Se le pidió separar las pruebas en su propio archivo, cada caso en `BEGIN ... ROLLBACK` |
| Escenarios de concurrencia con dos sesiones | Claude | Las secuencias de comandos y las explicaciones de cada anomalía | La IA concluyó que la espera por bloqueo no se había reproducido; se demostró lo contrario con `\timing on` (31.170 ms bloqueado contra 0,3 ms sin bloqueo). Su afirmación sobre Repeatable Read y los fantasmas se verificó aparte antes de darla por válida |
| Lectura crítica de scripts peligrosos | Claude | Explicación de `NOT IN` frente a `NULL` y de la alternativa `NOT EXISTS` | La conclusión de que el `DELETE` del script contradice la baja lógica del proyecto salió del análisis del modelo, no de la IA |

## Unidad 2 — Optimización de consultas

| Uso | Herramienta | Qué se aceptó | Qué se corrigió o descartó |
|---|---|---|---|
| Carga masiva (50.000 / 20.000 / 200.000) | OpenCode, Kiro y Claude | El diagnóstico del `InitPlan` (un subquery no correlacionado se evalúa una sola vez) y su corrección | Se descartó una fórmula de Kiro que dejaba ~3/4 de los clientes sin pedidos; un `CROSS JOIN` de OpenCode de 10.000 millones de filas; y una variante que prometía una mejora estructural y midió solo 1,4x. Se corrigieron un `LIMIT`, una confusión entre líneas y cantidad, y un casteo de `ENUM` faltante |
| Índices a partir de planes reales | OpenCode | Los índices sobre `pedido.id_cliente` y `detalle_pedido.id_producto` (de 39 ms a 0,15 ms y de 44 ms a 0,41 ms) | Tres índices compuestos propuestos: se midieron y se descartaron por no mejorar el plan |
| Explicación de un plan nodo por nodo | OpenCode | Cuatro afirmaciones correctas | Cinco afirmaciones incorrectas detectadas y documentadas |
| Consultas bajo spec y reescrituras (TP4) | OpenCode | Ranking con ventana, subconsultas y la reescritura del ranking de clientes (de 1.682 ms a 1.004 ms) | La reescritura de la facturación por categoría y mes: empeoró de 1.367 ms a 3.150 ms |

## Unidad 3 — Índices, vistas y objetos programables

| Uso | Herramienta | Qué se aceptó | Qué se corrigió o descartó |
|---|---|---|---|
| Plan de indexado | Kiro (specs) + OpenCode | Mantener los índices existentes | Los tres candidatos: dos por no mejorar y uno por redundancia (sobreindexación); uno además hacía un 62,5 % más lenta la escritura |
| Vistas | Kiro + OpenCode | Cinco vistas, incluida la que expone `usuario` sin la contraseña | Cada vista se aceptó recién después de dar 0 filas con `EXCEPT` en los dos sentidos contra la consulta manual |
| Vista materializada | Kiro + OpenCode | `mv_facturacion_cat_mes` con índice único para `REFRESH CONCURRENTLY` (de 870 ms a 0,07 ms) | — |

## Primera entrega del TPI

En esta entrega usé **Claude** para:

| Uso | Qué acepté | Qué se corrigió o descartó |
|---|---|---|
| Revisar el proyecto contra los 9 objetivos | El diagnóstico de lo que faltaba: `HAVING`, un procedimiento con `CALL`, la prueba de atomicidad, `SAVEPOINT`, un trigger con tablas de transición y la evidencia del borrado lógico | — |
| Generar los scripts `06` a `10` y `ejecutar_todo.sh` | La estructura de los scripts, el procedimiento con `JSONB` y la auditoría por sentencia | La consulta del ticket promedio comparaba contra el promedio por línea y no por pedido; `DENSE_RANK` devolvía decenas de filas por categoría y se cambió por `ROW_NUMBER`; el trigger de auditoría no puede usar `AFTER UPDATE OF precio` con tablas de transición |
| Carga masiva rápida | Generar el mismo volumen sin ordenar tablas por cada fila | La primera versión repetía casi siempre los mismos productos (11 distintos en 400.000 líneas); se detectó al verificar la distribución y se reescribió |
| Redacción del documento de normalización, el informe técnico y este resumen | La organización y la redacción | Verifiqué cada dato contra los scripts y las evidencias |

Todos los scripts se ejecutaron primero sobre una base de prueba, siguiendo `protocolo_seguridad.md`. El detalle completo de cada unidad está en los demás archivos de esta carpeta.
