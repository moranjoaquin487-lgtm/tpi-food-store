# Informe técnico — TPI Food Store

**Base de Datos II · UTN · Primera entrega (Unidades 1, 2 y 3)**

- **Alumno:** Moran, Joaquín Leandro
- **Motor:** PostgreSQL 18.6 en Windows, base creada desde cero con `ejecutar_todo.sh`
- **Volumen de prueba:** 50.010 productos · 20.005 clientes · 200.005 pedidos · 399.994 líneas de detalle

## Resumen

Food Store es un sistema de pedidos para un negocio de comidas. La entrega cubre los nueve objetivos pedidos: cada uno tiene un script que lo implementa y una evidencia que muestra que funciona.

| # | Objetivo | Estado | Dónde verlo |
|:-:|---|:-:|---|
| 1 | Modelo ER | ✅ | [`modelo_ER_relacional_normalizacion.md`](modelo_ER_relacional_normalizacion.md) |
| 2 | Paso a modelo relacional | ✅ | Mismo documento, Parte 2 |
| 3 | Normalización hasta BCNF | ✅ | Mismo documento, Parte 3 |
| 4 | DDL completo | ✅ | `sql/01_schema.sql` |
| 5 | Consultas (JOIN, agregación, subconsultas, HAVING, ventana) | ✅ | `sql/07_consultas.sql` |
| 6 | Vistas, funciones y procedimientos | ✅ | `sql/05_vistas.sql`, `sql/05b_materializadas.sql`, `sql/06_funciones_procedimientos.sql` |
| 7 | Reglas de negocio (CHECK, UNIQUE, triggers) | ✅ | `sql/03_restricciones.sql`, `sql/10_auditoria_precios.sql` |
| 8 | Transacciones y concurrencia | ✅ | `sql/08_transacciones.sql`, evidencias `08b`, `08c` y `08d` |
| 9 | Borrado lógico | ✅ | `sql/09_soft_delete.sql` |

---

## 1. Qué se implementó

### Unidad 1 — Integridad, transacciones y concurrencia

- **El esquema** con cinco tablas del negocio (categoría, producto, cliente, pedido y su detalle) más los usuarios del sistema. Usa claves autogeneradas (`IDENTITY`), montos con precisión fija (`NUMERIC`), fechas con zona horaria (`TIMESTAMPTZ`) y tipos cerrados (`ENUM`) para la forma de pago y el rol.
- **Reglas de negocio en el motor**, para que no dependan de que la aplicación se acuerde de validarlas: precios y stock nunca negativos (`CHECK`), email y nombre de categoría únicos (`UNIQUE`), y dos triggers que impiden vender un producto dado de baja o sin stock suficiente.
- **Transacciones**: un pedido se registra entero o no se registra (atomicidad), y `SAVEPOINT` permite deshacer solo una parte.
- **Concurrencia**: se reprodujeron, con dos sesiones abiertas a la vez, una lectura fantasma y una espera por bloqueo, para ver qué nivel de aislamiento o qué bloqueo las controla.

### Unidad 2 — Optimización de consultas

- **Carga masiva** del volumen de arriba, para que las diferencias de rendimiento se puedan medir.
- **Consultas de negocio** que combinan varias tablas: historial de un cliente, facturación por categoría y mes, productos nunca vendidos, clientes frecuentes (`HAVING`) y rankings con funciones de ventana (`RANK`, `ROW_NUMBER`).
- **Optimización medida**: cada consulta lenta se midió con `EXPLAIN ANALYZE` con y sin su índice (ver sección 4).

### Unidad 3 — Índices, vistas y objetos programables

- **Vistas** para los reportes habituales, entre ellas una que muestra los usuarios **sin la contraseña**, para dar acceso de lectura sin exponer la tabla original.
- **Vista materializada** con la facturación por categoría y mes, que guarda el resultado ya calculado.
- **Función** `fn_total_pedido`: calcula el total de un pedido en un solo lugar.
- **Procedimiento** `sp_registrar_pedido`: registra un pedido completo con sus productos (recibidos en `JSONB`) y se invoca con `CALL`.
- **Auditoría de precios**: un trigger guarda cada cambio de precio, con el valor anterior y el nuevo.
- **Borrado lógico**: los productos y categorías no se borran, se marcan como inactivos (`activo = FALSE`) para no perder el historial de ventas.

---

## 2. Cómo se probó

1. **Todo desde cero y en orden.** `ejecutar_todo.sh` crea una base nueva y corre los 15 scripts. Si algún script de construcción falla, se detiene sin dejar nada a medias.
2. **Un caso válido y uno inválido por regla.** En los inválidos se comprueba el error y también que la base quede igual que antes.
3. **Dos sesiones al mismo tiempo** para las pruebas de concurrencia: el mismo script abre dos conexiones de `psql` en paralelo, con la segunda arrancando un segundo después.
4. **Mediciones con `EXPLAIN ANALYZE`**, siempre después de actualizar las estadísticas con `ANALYZE`. Para medir "sin índice", el índice se borra dentro de `BEGIN ... ROLLBACK`, así vuelve solo al terminar.

La salida completa de cada prueba está en la carpeta `evidencias/`.

---

## 3. Resultados

| Prueba | Qué se esperaba | Qué pasó | Evidencia |
|---|---|---|---|
| Registrar un pedido válido con `CALL` | Se crea el pedido y baja el stock | Pedido creado; stock 167 → 165 y 149 → 148 | `08_transacciones` |
| Registrar un pedido con un ítem sin stock | Se rechaza **todo**, incluso los ítems válidos | Error del trigger; la cantidad de pedidos y el stock no cambiaron | `08_transacciones` |
| Aumentar un precio y hacer `ROLLBACK` | El cambio se descarta | 438,10 → 481,91 dentro de la transacción; vuelve a 438,10 | `08_transacciones` |
| `SAVEPOINT` con un paso inválido | Se deshace solo ese paso | Stock 79 → 78 confirmado; el precio inválido se descartó | `08_transacciones` |
| Contar pedidos mientras otra sesión inserta (READ COMMITTED) | El conteo cambia (lectura fantasma) | 9 → 10 | `08b_sesiones_read_committed` |
| Lo mismo en REPEATABLE READ | El conteo no cambia | 10 → 10 | `08c_sesiones_repeatable_read` |
| Dos sesiones piden el mismo producto con `FOR UPDATE` | La segunda espera a que la primera termine | La segunda esperó 919 ms y ya vio el stock actualizado por la primera | `08d_sesiones_for_update` |
| Vender un producto dado de baja o sin stock | Rechazo | Ambos rechazados por los triggers | `03b_pruebas_restricciones` |
| Borrar físicamente un producto vendido | Rechazo, para proteger el historial | Error de clave foránea | `09_soft_delete` |
| Dar de baja lógica un producto | Sale del catálogo, conserva sus ventas | 0 filas en la vista de vigentes; 8 ventas conservadas | `09_soft_delete` |
| Subir 5 precios en un solo `UPDATE` | 5 registros de auditoría | 5 registros en `JSONB`; el trigger corrió una sola vez | `10_auditoria_precios` |

**Impacto del borrado lógico en los índices.** El índice de productos por categoría solo incluye los productos activos. Cuando la consulta filtra `activo = TRUE`, el motor lo usa (2,02 ms). Cuando no filtra, no puede usarlo, recorre toda la tabla (3,45 ms) y además devuelve productos dados de baja. Olvidarse del filtro da un resultado incorrecto y más lento.

---

## 4. Consultas optimizadas

Cada caso se midió en la misma base con `EXPLAIN ANALYZE` (evidencia completa en `11_optimizacion`).

| Consulta | Sin optimizar | Optimizada | Mejora |
|---|--:|--:|---|
| **C2** · Pedidos de un cliente | 30,28 ms · `Parallel Seq Scan` | 0,067 ms · índice por cliente | ✅ 452 veces más rápida |
| **C3** · Pedidos en los que se vendió un producto | 32,70 ms · `Parallel Seq Scan` | 0,089 ms · índice por producto | ✅ 367 veces más rápida |
| **C4** · Facturación por categoría y mes | 432 ms · calculada en el momento | 0,024 ms · vista materializada | ✅ Casi instantánea, con datos al último refresco |
| **C1** · Productos vigentes de una categoría | 8,20 ms · `Seq Scan` | 4,99 ms · índice parcial | ⚠️ Solo 39 % |
| **C5** · 20.000 altas de pedidos con un índice de más | 143 ms | 262 ms | ❌ 84 % más lentas |

**Qué se aprendió:**

- **Un índice sirve cuando la consulta trae pocas filas.** C2 y C3 devuelven unas pocas filas de cientos de miles, y bajan de decenas de milisegundos a menos de 0,1 ms. C1 trae el 20 % de la tabla: el índice ayuda, pero poco, porque igual hay que leer miles de filas.
- **Materializar es la mejora más grande, con un costo.** El reporte de C4 pasa de casi medio segundo a instantáneo porque ya está calculado, pero muestra los datos del último `REFRESH`, no los de este momento.
- **Indexar de más tiene costo.** Un índice extra sobre `pedido (id_cliente, fecha)` no aporta a las consultas, porque `id_cliente` ya está indexado, y hace más lentas todas las inserciones: cada alta tiene que actualizar un índice más.

---

## 5. Uso de inteligencia artificial

En las unidades se usaron las herramientas de la cátedra, **OpenCode** y **Kiro**, junto con **Claude**. El resumen de cada uso está en [`duia/DUIA_resumen.md`](duia/DUIA_resumen.md).

Para esta entrega usé **Claude (Anthropic)** para:

- **Revisar el proyecto contra los nueve objetivos.** Acepté el diagnóstico de lo que faltaba: `HAVING`, un procedimiento con `CALL`, las pruebas de atomicidad y `SAVEPOINT`, un trigger con tablas de transición y la evidencia del borrado lógico.
- **Generar los scripts 06 a 11 y `ejecutar_todo.sh`**, incluidas las pruebas automáticas con dos sesiones. Tres propuestas se corrigieron al probarlas: el ticket promedio se calculaba por línea en vez de por pedido; el top 3 por categoría devolvía decenas de filas por los empates (se cambió `DENSE_RANK` por `ROW_NUMBER`); y el trigger de auditoría usaba una sintaxis que PostgreSQL no admite con tablas de transición.
- **Medir el costo de sobreindexar.** La primera versión medía inserciones en `detalle_pedido`, donde el tiempo de los triggers tapaba el del índice y el resultado se invertía de una corrida a otra; se pasó a `pedido`, que no tiene triggers.
- **Acelerar la carga masiva.** La primera versión repetía casi siempre los mismos 11 productos; se detectó al revisar la distribución y se reescribió.
- **Redactar los documentos de la entrega.** Verifiqué cada dato contra los scripts y las evidencias.

Ningún script se aplicó sin probarlo antes en una base de prueba, según `protocolo_seguridad.md`.
