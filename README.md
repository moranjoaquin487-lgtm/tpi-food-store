# TPI Food Store

**Base de Datos II · UTN · Primera entrega (Unidades 1, 2 y 3)**

- **Alumno:** Moran, Joaquín Leandro
- **Motor:** PostgreSQL 16+ con PL/pgSQL

Food Store es un sistema de pedidos para un negocio de comidas: categorías, productos, clientes, pedidos y el detalle de cada pedido.

![Diagrama entidad-relación](docs/Diagrama%20ER.png)

## Documentación

| Documento | Qué tiene |
|---|---|
| [Informe técnico](docs/informe_tecnico.md) | Qué se implementó, cómo se probó, resultados y optimizaciones |
| [Modelo ER y normalización](docs/modelo_ER_relacional_normalizacion.md) | Diagrama, diccionario de datos, paso a modelo relacional y normalización hasta BCNF |
| [Declaración de uso de IA](docs/duia/DUIA_resumen.md) | Qué herramientas se usaron, para qué y qué se aceptó o descartó |

## Cómo ejecutarlo

Desde **Git Bash**, en la carpeta del proyecto:

```bash
./ejecutar_todo.sh
```

Crea la base `tpi_food_store` desde cero, corre todos los scripts en orden y guarda el resultado de cada uno en `evidencias/`. Tarda menos de un minuto.

- Otro usuario de PostgreSQL: `PGUSER=mi_usuario ./ejecutar_todo.sh`
- Otro nombre de base: `DB=otra_base ./ejecutar_todo.sh`

> ⚠️ El script **borra y recrea** la base indicada. Usalo solo con una base de prueba.

Las evidencias de prueba incluyen **errores a propósito**: son los casos inválidos que el motor tiene que rechazar.

## Scripts

| Script | Qué hace | Objetivo |
|---|---|:-:|
| `01_schema.sql` | Crea las tablas, tipos, claves, restricciones e índices | 4 |
| `02_data.sql` | Carga los datos de ejemplo | 5 |
| `02b_carga_masiva_rapida.sql` | Carga 50.000 productos, 20.000 clientes y 200.000 pedidos | 5 |
| `02c_verificacion_carga_masiva.sql` | Comprueba que la carga quedó bien distribuida | 5 |
| `03_restricciones.sql` | Triggers: no vender productos dados de baja ni sin stock | 7 |
| `03b_pruebas_restricciones.sql` | Casos válidos e inválidos de esas reglas | 7 |
| `04_indices.sql` | Decisión de indexado | 4 |
| `05_vistas.sql` | Vistas de reportes, incluida la de usuarios sin contraseña | 6 |
| `05b_materializadas.sql` | Vista materializada de facturación por categoría y mes | 6 |
| `06_funciones_procedimientos.sql` | Función `fn_total_pedido` y procedimiento `sp_registrar_pedido` | 6 |
| `07_consultas.sql` | JOIN, agregación, subconsultas, HAVING y funciones de ventana | 5 |
| `08_transacciones.sql` | Atomicidad, COMMIT, ROLLBACK, SAVEPOINT y niveles de aislamiento | 8 |
| `09_soft_delete.sql` | Borrado lógico y su efecto en consultas e índices | 9 |
| `10_auditoria_precios.sql` | Auditoría de precios con tablas de transición y JSONB | 7 |
| `11_optimizacion.sql` | Mediciones antes y después de cada optimización | 5 |

Las pruebas con **dos sesiones a la vez** (lectura fantasma y espera por bloqueo) las corre `ejecutar_todo.sh` al final, y quedan en `evidencias/08b`, `08c` y `08d`.

## Objetivos de la entrega

| # | Objetivo | Dónde |
|:-:|---|---|
| 1 | Modelo ER | [Modelo ER](docs/modelo_ER_relacional_normalizacion.md), Parte 1 |
| 2 | Paso a modelo relacional | Mismo documento, Parte 2 |
| 3 | Normalización hasta BCNF | Mismo documento, Parte 3 |
| 4 | DDL completo | `01`, `04` |
| 5 | Consultas | `07`, `11` |
| 6 | Vistas, funciones y procedimientos | `05`, `05b`, `06` |
| 7 | Reglas de negocio | `01`, `03`, `10` |
| 8 | Transacciones y concurrencia | `08` y evidencias `08b`, `08c`, `08d` |
| 9 | Borrado lógico | `09` |


