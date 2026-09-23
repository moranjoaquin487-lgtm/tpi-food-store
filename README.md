# TPI Food Store — Base de Datos II

**Tecnicatura Universitaria en Programación — UTN**
- **Alumno:** Moran, Joaquín Leandro
- **Entrega:** primera entrega parcial del TPI (Unidades 1, 2 y 3)
- **Motor:** PostgreSQL 16+ con PL/pgSQL

Food Store es un sistema de gestión de pedidos para un negocio de comidas: categorías, productos, clientes, pedidos y su detalle, más usuarios del sistema. Este repositorio reúne el modelo de datos, los scripts SQL, los objetos programables y la documentación que acreditan los nueve objetivos de la entrega. El informe técnico está en [`docs/informe_tecnico.md`](docs/informe_tecnico.md).

## Estructura

```
├── README.md
├── ejecutar_todo.sh            Ejecuta todo en orden y regenera evidencias/
├── protocolo_seguridad.md      Copia, transacción y respaldo
├── sql/                        Scripts numerados en orden de ejecución
│   ├── 01_schema.sql           DDL: tablas, ENUM, IDENTITY, PK/FK, CHECK, UNIQUE, índices
│   ├── 02_data.sql             Datos semilla
│   ├── 02b_carga_masiva_rapida.sql   50.000 productos / 20.000 clientes / 200.000 pedidos
│   ├── 02c_verificacion_carga_masiva.sql
│   ├── 03_restricciones.sql    Triggers de reglas de negocio
│   ├── 03b_pruebas_restricciones.sql
│   ├── 04_indices.sql          Decisiones de indexado (Unidad 3)
│   ├── 05_vistas.sql           Vistas (incluye la de seguridad sin contraseña)
│   ├── 05b_materializadas.sql  Vista materializada con índice único
│   ├── 06_funciones_procedimientos.sql
│   ├── 07_consultas.sql        JOIN, agregación, subconsultas, HAVING, ventana
│   ├── 08_transacciones.sql    Atomicidad, COMMIT, ROLLBACK, SAVEPOINT, aislamiento
│   ├── 09_soft_delete.sql      Borrado lógico y su impacto en consultas e índices
│   ├── 10_auditoria_precios.sql  Trigger con tablas de transición + JSONB
│   └── extra/carga_masiva_original.sql
├── docs/
│   ├── informe_tecnico.md
│   ├── Diagrama ER.png
│   ├── modelo_ER_relacional_normalizacion.md
│   ├── unidad1/  unidad2/  unidad3/   Informes y specs de cada unidad
│   └── duia/                         Declaraciones de uso de IA
└── evidencias/                 Salida real de cada script (psql -a)
```

## Cómo reproducir

Sobre una base **nueva**, nunca sobre una con datos que importen (ver `protocolo_seguridad.md`).

```bash
./ejecutar_todo.sh                  # crea tpi_food_store y corre todo
DB=otra_base ./ejecutar_todo.sh     # con otro nombre de base
```

El script recrea la base, corre los scripts en orden y deja la salida de cada uno en `evidencias/`. Los de construcción (01 a 06) corren en una sola transacción y se cortan ante el primer error. Los de prueba (02c, 03b, 07 a 10) muestran cada sentencia con su resultado e incluyen **errores esperados** —casos inválidos que el motor debe rechazar—.

Para correr un script suelto: `psql -d tpi_food_store -a -f sql/08_transacciones.sql`.

### Prueba con dos sesiones concurrentes

Las evidencias `08b` y `08c` salen de dos ventanas de `psql` abiertas a la vez:

| Paso | Sesión A | Sesión B |
|---|---|---|
| 1 | `BEGIN ISOLATION LEVEL READ COMMITTED;` (o `REPEATABLE READ`) | |
| 2 | `SELECT COUNT(*) FROM pedido WHERE id_cliente = 10;` | |
| 3 | | `INSERT INTO pedido (forma_pago, id_cliente) VALUES ('EFECTIVO', 10);` |
| 4 | Repetir el `SELECT` del paso 2 | |
| 5 | `COMMIT;` | |

En READ COMMITTED el conteo del paso 4 aumenta (lectura fantasma); en REPEATABLE READ no cambia.

## Objetivos de la entrega

| # | Objetivo | Dónde se acredita |
|---|---|---|
| 1 | Modelo ER | `docs/Diagrama ER.png` y Parte 1 de `docs/modelo_ER_relacional_normalizacion.md` |
| 2 | ER a modelo relacional (1:N y N:M) | Parte 2 del mismo documento; `detalle_pedido` en `01_schema.sql` |
| 3 | Normalización hasta 3FN/BCNF | Parte 3 del mismo documento |
| 4 | DDL completo | `01_schema.sql`, `04_indices.sql` |
| 5 | DML y consultas | `07_consultas.sql` |
| 6 | Vistas, funciones y procedimientos | `05_vistas.sql`, `05b_materializadas.sql`, `06_funciones_procedimientos.sql` |
| 7 | CHECK, UNIQUE y triggers | `01_schema.sql`, `03_restricciones.sql`, `10_auditoria_precios.sql` |
| 8 | Transacciones y concurrencia | `08_transacciones.sql`, evidencias `08b`/`08c`, `docs/unidad1/informe_concurrencia.md` |
| 9 | Borrado lógico | `09_soft_delete.sql`, índice parcial en `01_schema.sql`, vistas de vigentes |

## Origen del material

Los scripts `01` a `05b`, `03b`, `02c` y los informes de `docs/unidad1` a `docs/unidad3` provienen del trabajo realizado durante la cursada en el repositorio del equipo. Los scripts `02b`, `06` a `10`, el documento de modelado y normalización, `ejecutar_todo.sh` y el informe técnico se incorporaron para esta entrega. El uso de IA está declarado en `docs/duia/` y en la sección 5 del informe técnico.
