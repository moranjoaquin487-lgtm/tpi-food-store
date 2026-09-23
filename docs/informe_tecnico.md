# Informe técnico — TPI Food Store, primera entrega

**Base de Datos II — UTN, Tecnicatura Universitaria en Programación**
**Alumno:** Moran, Joaquín Leandro
**Alcance:** Unidades 1, 2 y 3
**Entorno de las evidencias:** PostgreSQL 16.15, base `tpi_food_store` creada desde cero con `ejecutar_todo.sh` (50.010 productos, 20.005 clientes, 200.006 pedidos, 399.996 líneas de detalle).

---

## 1. Qué se implementó en cada unidad

| Unidad | Objetivo | Implementación | Archivo |
|---|---|---|---|
| 1 | 1. Modelo ER | 5 entidades más la asociativa Detalle; claves, cardinalidades y participación justificadas con las reglas R1 a R7 | `docs/Diagrama ER.png`, `docs/modelo_ER_relacional_normalizacion.docx` (Parte 1) |
| 1 | 2. ER a relacional | Las 1:N con FK en el lado N; la N:M pedido–producto con la tabla intermedia `detalle_pedido` (clave sustituta + `UNIQUE (id_pedido, id_producto)`) | Mismo documento (Parte 2), `sql/01_schema.sql` |
| 1 | 3. Normalización | Planilla plana llevada a 1FN, 2FN, 3FN y BCNF con cada dependencia funcional explicitada | Mismo documento (Parte 3) |
| 1 | 4. DDL | `IDENTITY`, `TIMESTAMPTZ`, `NUMERIC` para montos, `ENUM` para `forma_pago` y `rol`, PK y FK con `ON DELETE` justificado, `CHECK`, `UNIQUE`, `DEFAULT` e índices comentados | `sql/01_schema.sql` |
| 1 | 7. Reglas de negocio | `CHECK` (precio, stock, cantidad), `UNIQUE` (email, nombre de categoría, producto por pedido) y triggers (no vender productos dados de baja, no vender sin stock) | `sql/01_schema.sql`, `sql/03_restricciones.sql` |
| 1 | 8. Transacciones y concurrencia | Protocolo copia–transacción–respaldo; lectura no repetible, lectura fantasma y espera por bloqueo con dos sesiones; atomicidad, `SAVEPOINT` | `protocolo_seguridad.md`, `docs/unidad1/informe_concurrencia.md`, `sql/08_transacciones.sql` |
| 2 | 5. DML y consultas | Carga masiva; consultas con JOIN, LEFT JOIN, agregación, `GROUP BY`/`HAVING`, subconsultas correlacionadas (`NOT EXISTS`) y escalares, `RANK` y `ROW_NUMBER` con `PARTITION BY` | `sql/02b_carga_masiva_rapida.sql`, `sql/07_consultas.sql` |
| 2 | Optimización | Planes medidos con `EXPLAIN ANALYZE` antes y después de índices y reescrituras (ver sección 4) | `docs/unidad2/` |
| 3 | 6. Vistas | 5 vistas (entre ellas `vista_usuario_reportes`, que expone `usuario` sin la columna `contrasena`) y la vista materializada `mv_facturacion_cat_mes` con índice único para `REFRESH CONCURRENTLY` | `sql/05_vistas.sql`, `sql/05b_materializadas.sql` |
| 3 | 6. Funciones y procedimientos | `fn_total_pedido` (función `STABLE`) y `sp_registrar_pedido` (procedimiento invocado con `CALL`, recibe los ítems en `JSONB`) | `sql/06_funciones_procedimientos.sql` |
| 3 | 7. Trigger con tablas de transición | Auditoría de cambios de precio por sentencia (`REFERENCING OLD TABLE / NEW TABLE`) guardada en `JSONB` | `sql/10_auditoria_precios.sql` |
| 3 | 9. Borrado lógico | Columna `activo` en producto y categoría, índice parcial `WHERE activo = TRUE`, vistas de vigentes, `ON DELETE RESTRICT` que impide el borrado físico | `sql/01_schema.sql`, `sql/05_vistas.sql`, `sql/09_soft_delete.sql` |

## 2. Cómo se probó

- **Ejecución completa y reproducible.** `ejecutar_todo.sh` recrea la base y corre los 15 scripts en orden. Los de construcción corren en una sola transacción con `ON_ERROR_STOP`, así que si la ejecución termina, todo el esquema quedó creado sin errores. Los de prueba se corren con `psql -a` y su salida queda en `evidencias/`.
- **Casos válidos e inválidos.** Cada regla se prueba con al menos un caso que el motor debe aceptar y uno que debe rechazar (`03b`, `08`, `09`). En los inválidos se verifica el mensaje de error y, además, que el estado de la base no haya cambiado.
- **Dos sesiones concurrentes.** Los escenarios de aislamiento se reprodujeron con dos sesiones de `psql` abiertas a la vez (evidencias `08b` y `08c`, e informe de concurrencia de la Unidad 1).
- **Equivalencia de resultados.** Cada vista se comparó contra su consulta manual con `EXCEPT` en los dos sentidos (`docs/unidad3/informe_mediciones.md`), igual que las reescrituras de consultas de la Unidad 2.
- **Mediciones.** `EXPLAIN (ANALYZE, BUFFERS)` antes y después de cada cambio, con la base poblada y `ANALYZE` corrido.

## 3. Resultados obtenidos

**Atomicidad (`08_transacciones`).** El `CALL` válido creó el pedido 200.006 con sus dos líneas y descontó el stock (producto 20: 195 → 193; producto 21: 85 → 84). El `CALL` inválido pide 9.999 unidades en el segundo ítem: el trigger de stock lo rechaza y **se revierte todo**, incluida la primera línea, que era válida. La cantidad de pedidos siguió en 200.006 y el stock no se movió.

**COMMIT, ROLLBACK y SAVEPOINT.** Un aumento del 10 % dentro de la transacción se vio (186,68 → 205,35) y desapareció con `ROLLBACK`. En la prueba de `SAVEPOINT`, el segundo paso violó el `CHECK (precio >= 0)`; `ROLLBACK TO SAVEPOINT` deshizo solo ese paso y el `COMMIT` confirmó el primero (stock 147 → 146, precio intacto en 511,67).

**Aislamiento (`08b`, `08c`).** Mientras la sesión B confirmaba un pedido nuevo del cliente 10:

| Nivel | 1.ª lectura | 2.ª lectura | Resultado |
|---|---:|---:|---|
| READ COMMITTED | 14 | 15 | Lectura fantasma: el conteo cambió dentro de la misma transacción |
| REPEATABLE READ | 15 | 15 | La transacción trabaja sobre su foto inicial: no hay fantasma |

**Reglas de negocio (`03b`).** Se rechazó la venta de un producto dado de baja y la de 50 unidades de un producto con stock 1; los casos válidos se insertaron y se revirtieron con `ROLLBACK`.

**Borrado lógico (`09_soft_delete`).**

- El `DELETE` físico de un producto vendido falla por la FK con `ON DELETE RESTRICT`: el historial queda protegido.
- Al darlo de baja lógicamente, deja de aparecer en `vista_productos_vigentes` (0 filas), conserva sus 8 líneas de venta para los reportes históricos y el trigger impide volver a venderlo.
- Impacto en los índices: con `activo = TRUE` en el `WHERE`, el optimizador usa el índice parcial (`Bitmap Index Scan on idx_producto_categoria_activo`, 1,96 ms). Sin ese filtro no puede usarlo y recorre la tabla (`Seq Scan`, 3,72 ms), además de devolver productos dados de baja. Olvidar el filtro de vigencia da un resultado incorrecto y más lento.

**Auditoría con tablas de transición (`10_auditoria_precios`).** Un único `UPDATE` que subió un 5 % cinco precios disparó el trigger **una sola vez** y generó 5 registros `JSONB` con el precio anterior, el nuevo y la variación. Un `UPDATE` que solo tocó el stock no generó ningún registro.

## 4. Consultas optimizadas: antes y después

Mediciones realizadas durante la cursada sobre la base poblada (detalle completo en `docs/unidad2/` y `docs/unidad3/`).

| Consulta | Antes | Cambio | Después | Resultado |
|---|---|---|---|---|
| C2 — Historial de pedidos de un cliente | `Parallel Seq Scan` sobre pedido, **39,008 ms** | Índice `idx_pedido_id_cliente` | `Bitmap Index Scan`, **0,147 ms** | −99,6 % |
| C3 — Pedidos donde se vendió un producto | `Parallel Seq Scan` sobre detalle_pedido, **43,847 ms** | Índice `idx_detalle_pedido_id_producto` | `Bitmap Index Scan`, **0,407 ms** | −99,1 % |
| C1 — Productos vigentes de una categoría | `Seq Scan`, 7,630 ms | Índice parcial por categoría | `Bitmap Heap Scan`, 8,816 ms | Sin mejora: el filtro devuelve el 20 % de la tabla |
| Ranking de clientes por gasto | `Hash Join` + `Hash Join`, 1.682 ms | Reescritura: preagregar por pedido | `Merge Join` + `Hash Join`, 1.004 ms | −40 %, aceptada |
| Facturación por categoría y mes | `Hash Join` + `Parallel Hash Join`, 1.367 ms | Reescritura: preagregar por categoría y pedido | 3.150 ms | Empeoró: rechazada |
| Facturación por categoría y mes (reporte) | Consulta sin materializar, **870,172 ms** (con `Sort` a disco) | Vista materializada con índice único | `Seq Scan` sobre la vista, **0,070 ms** | Unas 12.000 veces más rápida, a cambio de datos al último `REFRESH` |

Lo que se aprendió de estas diferencias:

- Un índice ayuda cuando el filtro es **selectivo** (C2 y C3 devuelven menos del 0,02 % de las filas). Con el 20 % de la tabla (C1), leer por índice cuesta lo mismo o más que recorrerla.
- En la Unidad 3 se evaluaron tres índices compuestos candidatos y se **descartaron los tres**: no mejoraban el plan o eran redundantes con los existentes, y uno de ellos aumentaba el tiempo de una carga de escritura de 28,7 a 46,7 ms.
- No toda reescritura "más prolija" es más rápida: una de las dos preagregaciones mejoró y la otra duplicó el tiempo. La decisión se tomó con la medición, no con la intuición.

## 5. Uso de herramientas de IA

Durante la cursada se usaron las herramientas de la cátedra, **OpenCode** y **Kiro**, con el registro de cada uso en `docs/duia/`.

Para esta entrega se usó además **Claude (Anthropic)**, con estas finalidades:

| Finalidad | Qué se aceptó | Qué se modificó o descartó, y por qué |
|---|---|---|
| Revisar el proyecto contra los 9 objetivos y detectar faltantes | El diagnóstico: faltaban `HAVING`, un procedimiento con `CALL`, la demostración de atomicidad y `SAVEPOINT`, un trigger con tablas de transición y evidencia del impacto del borrado lógico | — |
| Generar los scripts `06` a `10` y `ejecutar_todo.sh` | La estructura de los scripts, el procedimiento con `JSONB` y la auditoría por sentencia | Se corrigió la consulta del ticket promedio, que comparaba contra el promedio por **línea** y no por **pedido**. Se reemplazó `DENSE_RANK` por `ROW_NUMBER` en el top 3 por categoría, porque con empates devolvía decenas de filas por categoría. Se sacó la lista de columnas del trigger de auditoría (`AFTER UPDATE OF precio`), que PostgreSQL no admite junto con tablas de transición |
| Carga masiva rápida (`02b`) | Generar el mismo volumen sin `ORDER BY random()` por fila | Una primera versión repetía casi siempre los mismos productos (11 distintos en 400.000 líneas); se detectó al verificar la distribución y se reescribió |
| Redactar el documento de modelado y normalización y este informe | La organización y la redacción | Se verificó cada dependencia funcional y cada número contra los scripts y las evidencias |

Ningún script se aplicó sin ejecutarlo primero sobre una base de prueba, siguiendo `protocolo_seguridad.md`.
