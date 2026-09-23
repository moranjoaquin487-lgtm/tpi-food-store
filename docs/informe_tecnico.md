# Informe técnico — TPI Food Store

**Base de Datos II · UTN · Primera entrega (Unidades 1, 2 y 3)**

- **Alumno:** Moran, Joaquín Leandro
- **Motor:** PostgreSQL 16.15, base creada desde cero con `ejecutar_todo.sh`
- **Volumen de prueba:** 50.010 productos · 20.005 clientes · 200.006 pedidos · 399.996 líneas de detalle

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
| 8 | Transacciones y concurrencia | ✅ | `sql/08_transacciones.sql`, evidencias `08b` y `08c` |
| 9 | Borrado lógico | ✅ | `sql/09_soft_delete.sql` |

---

## 1. Qué se implementó

### Unidad 1 — Integridad, transacciones y concurrencia

- **El esquema** con cinco tablas del negocio (categoría, producto, cliente, pedido y su detalle) más los usuarios del sistema. Usa claves autogeneradas (`IDENTITY`), montos con precisión fija (`NUMERIC`), fechas con zona horaria (`TIMESTAMPTZ`) y tipos cerrados (`ENUM`) para la forma de pago y el rol.
- **Reglas de negocio en el motor**, para que no dependan de que la aplicación se acuerde de validarlas: precios y stock nunca negativos (`CHECK`), email y nombre de categoría únicos (`UNIQUE`), y dos triggers que impiden vender un producto dado de baja o sin stock suficiente.
- **Transacciones**: un pedido se registra entero o no se registra (atomicidad), y `SAVEPOINT` permite deshacer solo una parte.
- **Concurrencia**: se reprodujeron anomalías con dos sesiones abiertas a la vez para ver qué nivel de aislamiento las evita.

### Unidad 2 — Optimización de consultas

- **Carga masiva** del volumen de arriba, para que las diferencias de rendimiento se puedan medir.
- **Consultas de negocio** que combinan varias tablas: historial de un cliente, facturación por categoría y mes, productos nunca vendidos, clientes frecuentes (`HAVING`) y rankings con funciones de ventana (`RANK`, `ROW_NUMBER`).
- **Optimización medida**: cada consulta lenta se midió con `EXPLAIN ANALYZE` antes y después de agregar un índice o reescribirla (ver sección 4).

### Unidad 3 — Índices, vistas y objetos programables

- **Vistas** para los reportes habituales, entre ellas una que muestra los usuarios **sin la contraseña**, para dar acceso de lectura sin exponer la tabla original.
- **Vista materializada** con la facturación por categoría y mes, que guarda el resultado ya calculado.
- **Función** `fn_total_pedido`: calcula el total de un pedido en un solo lugar.
- **Procedimiento** `sp_registrar_pedido`: registra un pedido completo con sus productos (recibidos en `JSONB`) y se invoca con `CALL`.
- **Auditoría de precios**: un trigger guarda cada cambio de precio, con el valor anterior y el nuevo.
- **Borrado lógico**: los productos y categorías no se borran, se marcan como inactivos (`activo = FALSE`) para no perder el historial de ventas.

---

## 2. Cómo se probó

1. **Todo desde cero y en orden.** `ejecutar_todo.sh` crea una base nueva y corre los 14 scripts. Si algún script de construcción falla, se detiene sin dejar nada a medias.
2. **Un caso válido y uno inválido por regla.** En los inválidos se comprueba el error y también que la base quede igual que antes.
3. **Dos sesiones al mismo tiempo** para las pruebas de concurrencia, abriendo dos ventanas de `psql`.
4. **Comparación de resultados** con `EXCEPT` para confirmar que cada vista y cada reescritura devuelven exactamente lo mismo que la consulta original.
5. **Mediciones con `EXPLAIN ANALYZE`**, siempre después de actualizar las estadísticas con `ANALYZE`.

La salida completa de cada prueba está en la carpeta `evidencias/`.

---

## 3. Resultados

| Prueba | Qué se esperaba | Qué pasó | Evidencia |
|---|---|---|---|
| Registrar un pedido válido con `CALL` | Se crea el pedido y baja el stock | Pedido creado; stock 195 → 193 y 85 → 84 | `08_transacciones` |
| Registrar un pedido con un ítem sin stock | Se rechaza **todo**, incluso los ítems válidos | Error del trigger; la cantidad de pedidos y el stock no cambiaron | `08_transacciones` |
| Aumentar un precio y hacer `ROLLBACK` | El cambio se descarta | 186,68 → 205,35 dentro de la transacción; vuelve a 186,68 | `08_transacciones` |
| `SAVEPOINT` con un paso inválido | Se deshace solo ese paso | Stock 147 → 146 confirmado; el precio inválido se descartó | `08_transacciones` |
| Contar pedidos mientras otra sesión inserta (READ COMMITTED) | El conteo cambia (lectura fantasma) | 14 → 15 | `08b_sesiones_read_committed` |
| Lo mismo en REPEATABLE READ | El conteo no cambia | 15 → 15 | `08c_sesiones_repeatable_read` |
| Vender un producto dado de baja o sin stock | Rechazo | Ambos rechazados por los triggers | `03b_pruebas_restricciones` |
| Borrar físicamente un producto vendido | Rechazo, para proteger el historial | Error de clave foránea | `09_soft_delete` |
| Dar de baja lógica un producto | Sale del catálogo, conserva sus ventas | 0 filas en la vista de vigentes; 8 ventas conservadas | `09_soft_delete` |
| Subir 5 precios en un solo `UPDATE` | 5 registros de auditoría | 5 registros en `JSONB`; el trigger corrió una sola vez | `10_auditoria_precios` |

**Impacto del borrado lógico en los índices.** El índice de productos por categoría solo incluye los productos activos. Cuando la consulta filtra `activo = TRUE`, el motor lo usa (1,96 ms). Cuando no filtra, no puede usarlo, recorre toda la tabla (3,72 ms) y además devuelve productos dados de baja. Olvidarse del filtro da un resultado incorrecto y más lento.

---

## 4. Consultas optimizadas

Mediciones realizadas durante la cursada (detalle en `docs/unidad2` y `docs/unidad3`).

| Consulta | Qué se cambió | Antes | Después | Resultado |
|---|---|--:|--:|---|
| Pedidos de un cliente | Índice por cliente | 39,0 ms | 0,15 ms | ✅ 265 veces más rápida |
| Pedidos donde se vendió un producto | Índice por producto | 43,8 ms | 0,41 ms | ✅ 108 veces más rápida |
| Ranking de clientes por gasto | Agrupar por pedido antes de unir | 1.682 ms | 1.004 ms | ✅ 40 % menos |
| Reporte de facturación por categoría y mes | Vista materializada | 870 ms | 0,07 ms | ✅ Casi instantánea, con datos al último refresco |
| Productos vigentes de una categoría | Índice parcial | 7,6 ms | 8,8 ms | ❌ Sin mejora |
| Facturación por categoría y mes | Agrupar antes de unir | 1.367 ms | 3.150 ms | ❌ Empeoró, se descartó |

**Qué se aprendió:**

- **Un índice sirve cuando la consulta trae pocas filas.** Los dos primeros casos devuelven menos del 0,02 % de la tabla. El de productos vigentes trae el 20 %, y ahí leer por índice cuesta lo mismo que recorrer todo.
- **No toda reescritura mejora.** Dos consultas se reescribieron con la misma idea: una mejoró y la otra duplicó el tiempo. La decisión la tomó la medición.
- **Indexar de más tiene costo.** Se evaluaron tres índices compuestos adicionales y se descartaron: no mejoraban ninguna consulta y uno hacía más lentas las inserciones (de 28,7 a 46,7 ms).

---

## 5. Uso de inteligencia artificial

En las unidades se usaron las herramientas de la cátedra, **OpenCode** y **Kiro**, junto con **Claude**. El resumen de cada uso está en [`duia/DUIA_resumen.md`](duia/DUIA_resumen.md).

Para esta entrega usé **Claude (Anthropic)** para:

- **Revisar el proyecto contra los nueve objetivos.** Acepté el diagnóstico de lo que faltaba: `HAVING`, un procedimiento con `CALL`, las pruebas de atomicidad y `SAVEPOINT`, un trigger con tablas de transición y la evidencia del borrado lógico.
- **Generar los scripts 06 a 10 y `ejecutar_todo.sh`.** Tres propuestas se corrigieron al probarlas: el ticket promedio se calculaba por línea en vez de por pedido; el top 3 por categoría devolvía decenas de filas por los empates (se cambió `DENSE_RANK` por `ROW_NUMBER`); y el trigger de auditoría usaba una sintaxis que PostgreSQL no admite con tablas de transición.
- **Acelerar la carga masiva.** La primera versión repetía casi siempre los mismos 11 productos; se detectó al revisar la distribución y se reescribió.
- **Redactar los documentos de la entrega.** Verifiqué cada dato contra los scripts y las evidencias.

Ningún script se aplicó sin probarlo antes en una base de prueba, según `protocolo_seguridad.md`.
