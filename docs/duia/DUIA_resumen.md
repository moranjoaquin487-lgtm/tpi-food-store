# Declaración de Uso de IA (DUIA)

**TPI Food Store · Base de Datos II · UTN**

- **Alumno:** Moran, Joaquín Leandro
- **Alcance:** Unidades 1, 2 y 3, y la primera entrega del TPI

## Criterio

La IA propone y el motor decide. Ninguna propuesta se aceptó por lo convincente de la explicación: cada una se probó en una base de prueba y se aceptó solo si el resultado (un error esperado, un plan de ejecución, un tiempo medido o una comparación de resultados) lo confirmaba.

## Herramientas

| Herramienta | Para qué se usó |
|---|---|
| **Kiro** | Escribir la especificación antes de generar código |
| **OpenCode** | Generar y revisar SQL a partir de esa especificación, y explicar planes de ejecución |
| **Claude** (Anthropic) | Explicar conceptos, reconstruir escenarios de concurrencia y, en el TPI, revisar el proyecto, generar scripts y redactar la documentación |

---



## Unidad 1 — Integridad, transacciones y concurrencia

**Reglas de negocio** · Kiro + OpenCode
- ✅ Dos triggers (producto activo y stock suficiente), porque un `CHECK` no puede consultar otra tabla.
- ✏️ Se pidió separar las pruebas en su propio archivo, cada una dentro de `BEGIN ... ROLLBACK`.

**Escenarios de concurrencia** · Claude
- ✅ Las secuencias de comandos para cada sesión y la explicación de cada anomalía.
- ❌ La IA concluyó que la espera por bloqueo no se había reproducido. Midiendo con `\timing on` se comprobó que sí: más de 30 segundos bloqueada contra 0,3 ms sin bloqueo.

**Lectura crítica de scripts peligrosos** · Claude
- ✅ La explicación de por qué `NOT IN` falla con valores `NULL` y la alternativa con `NOT EXISTS`.

## Unidad 2 — Optimización de consultas

**Carga masiva** · Kiro, OpenCode y Claude
- ✅ El diagnóstico de por qué la selección al azar no variaba entre filas: el motor evaluaba la subconsulta una sola vez.
- ❌ Una fórmula que dejaba a tres de cada cuatro clientes sin pedidos, y un `CROSS JOIN` que generaba 10.000 millones de filas.
- ✏️ Se corrigieron un `LIMIT`, una confusión entre líneas de pedido y unidades, y un casteo de tipo faltante.

**Índices y planes de ejecución** · OpenCode
- ✅ Los índices por cliente y por producto, que llevaron dos consultas de decenas de milisegundos a menos de medio milisegundo.
- ❌ Tres índices compuestos: se midieron y no mejoraban ningún plan.
- ❌ De nueve afirmaciones de la IA al explicar un plan, cinco eran incorrectas; se documentaron contra el plan real.

**Consultas y reescrituras** · OpenCode
- ✅ Rankings con funciones de ventana, subconsultas y una reescritura que mejoró un 40 %.
- ❌ Otra reescritura con la misma idea más que duplicó el tiempo y se descartó.

## Unidad 3 — Índices, vistas y objetos programables

**Plan de indexado** · Kiro + OpenCode
- ✅ Mantener los índices existentes.
- ❌ Los tres candidatos nuevos: dos no mejoraban ningún plan y el tercero era redundante con los índices existentes.

**Vistas y vista materializada** · Kiro + OpenCode
- ✅ Cinco vistas, entre ellas la que muestra los usuarios sin la contraseña, y la vista materializada de facturación.
- ✏️ Cada vista se aceptó recién después de comprobar con `EXCEPT` que devolvía lo mismo que la consulta escrita a mano.

---

## Primera entrega del TPI

En esta entrega usé **Claude** para:

**Revisar el proyecto contra los nueve objetivos**
- ✅ El diagnóstico de lo que faltaba: `HAVING`, un procedimiento con `CALL`, las pruebas de atomicidad y `SAVEPOINT`, un trigger con tablas de transición y la evidencia del borrado lógico.

**Generar los scripts 06 a 11 y `ejecutar_todo.sh`**
- ✅ El procedimiento con `JSONB`, la auditoría por sentencia y las pruebas automáticas con dos sesiones.
- ✏️ El ticket promedio se calculaba por línea y no por pedido.
- ✏️ El top 3 por categoría devolvía decenas de filas por los empates: se cambió `DENSE_RANK` por `ROW_NUMBER`.
- ✏️ El trigger de auditoría usaba una sintaxis que PostgreSQL no admite con tablas de transición.
- ✏️ La medición del costo de sobreindexar daba resultados que se invertían entre corridas, porque los triggers tapaban el costo del índice: se pasó a una tabla sin triggers.

**Acelerar la carga masiva**
- ✏️ La primera versión repetía casi siempre los mismos 11 productos; se detectó al revisar la distribución y se reescribió.

**Ordenar y limpiar los scripts**
- ✅ Numerarlos en orden de ejecución y reducir los comentarios a un título por archivo y una línea por bloque.

**Generar y corregir las evidencias**
- ✏️ Las evidencias de construcción (`01` a `06`) quedaban vacías porque esos scripts corrían en modo silencioso: se agregó una consulta que muestra qué quedó creado.
- ✏️ Al correrlo en mi PC con Windows, la evidencia `08d` salió con los acentos rotos: se convirtió a UTF-8 y la espera pasó a medirse con SQL (`clock_timestamp() - now()`) en lugar de `\timing`.

**Rehacer el diagrama ER**
- ✅ Un diagrama dibujado a partir de `01_schema.sql`, con los tipos reales y la cardinalidad en pata de gallo.
- ✏️ Pedí sacar el título, la tabla `usuario` y las referencias para dejar solo el dominio de ventas.

**Redactar los documentos de la entrega**
- ✅ El informe técnico, el README, el documento de modelado y esta declaración. Verifiqué cada dato contra los scripts y contra las evidencias generadas en mi PC.

---

✅ aceptado · ✏️ corregido · ❌ descartado
