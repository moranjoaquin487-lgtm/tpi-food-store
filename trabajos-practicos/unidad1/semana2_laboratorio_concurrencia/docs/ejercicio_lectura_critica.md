# Ejercicio de lectura crítica

Parte 3 de la Semana 2. Los dos scripts dicen «dar de baja registros vencidos» sobre el esquema genérico de cátedra. Antes de corregirlos, se ejecutaron tal como están escritos, dentro de `BEGIN ... ROLLBACK` y sobre un esquema de prueba que se borra al final, para ver en el motor qué hacen realmente:

- Script: [`food-store/lectura_critica_demo.sql`](../food-store/lectura_critica_demo.sql), se corre con `bash scripts/lectura_critica.sh`.
- Salida: [`evidencias/parte3_lectura_critica.txt`](../evidencias/parte3_lectura_critica.txt).

La consigna no da las columnas del esquema genérico. Supuse las mínimas para que los scripts tengan sentido:

| Tabla | Columnas supuestas |
|---|---|
| `pelicula` | `id`, `titulo`, `en_cartel` (BOOLEAN) |
| `funcion` | `id`, `pelicula_id` (FK a `pelicula`, NOT NULL), `activa` (BOOLEAN) |
| `categoria` | `id`, `nombre` |
| `producto` | `id`, `nombre`, `categoria_id` (FK a `categoria`, **admite NULL**) |

Datos de prueba: tres películas, dos en cartel y una retirada, con dos funciones activas cada una; cuatro categorías, dos con productos y dos sin; y un producto sin categoría.

## Script 1

```sql
-- Generado para: dar de baja las funciones de películas retiradas de cartel
UPDATE funcion
SET activa = FALSE;
```

**Qué haría tal como está.** No tiene `WHERE`, así que apaga **todas** las funciones de la tabla, de cualquier película. En la prueba: `UPDATE 6`, las seis funciones quedaron inactivas, cuando solo dos eran de la película retirada.

**Por qué no cumple lo que dice.** El script no mira la película: las funciones de las películas que siguen en cartel también dejan de estar activas. El motor no avisa nada porque la sintaxis es correcta; el único indicio es el número de filas afectadas, y hay que leerlo y compararlo con lo esperado.

**Corregido.**

```sql
UPDATE funcion
SET activa = FALSE
WHERE activa
  AND pelicula_id IN (SELECT id FROM pelicula WHERE NOT en_cartel);
```

- La subconsulta elige las películas retiradas. Acá `IN` no tiene el problema del Script 2: la subconsulta devuelve `pelicula.id`, que es clave primaria y no puede ser NULL.
- `WHERE activa` deja afuera las funciones que ya estaban inactivas, así el número de filas afectadas es exactamente lo que se da de baja.
- En la prueba: `UPDATE 2`, solo las dos funciones de la película retirada.

## Script 2

```sql
-- Generado para: limpiar las categorías sin productos asociados
DELETE FROM categoria
WHERE id NOT IN (SELECT categoria_id FROM producto);
```

**Qué haría tal como está.** Depende de los datos. Si ningún producto tiene `categoria_id` nulo, borra las categorías sin productos, que es lo que se pretende. Pero alcanza con **un** producto sin categoría para que no borre **ninguna**: en la prueba, `DELETE 0`, y las cuatro categorías siguen ahí.

**Por qué no cumple lo que dice.** `x NOT IN (a, b, NULL)` equivale a `x <> a AND x <> b AND x <> NULL`. Comparar con NULL da desconocido (NULL), así que la condición completa nunca llega a ser verdadera y ninguna fila se borra. La evidencia lo muestra para la categoría 3, que no tiene productos: `3 NOT IN (1, 1, 2, NULL)` da NULL, mientras que sin el NULL, `3 NOT IN (1, 1, 2)` da verdadero.

El script falla en silencio: termina sin error e informa `DELETE 0`, como si no hubiera nada para limpiar. Es el patrón de los casos reales de la consigna: un comando que «funcionó» sin hacer lo que decía.

**Corregido.**

```sql
DELETE FROM categoria c
WHERE NOT EXISTS (SELECT 1 FROM producto p WHERE p.categoria_id = c.id);
```

- `NOT EXISTS` pregunta, para cada categoría, si hay algún producto que la referencie. Un producto con `categoria_id` nulo no coincide con ninguna, así que no cambia el resultado.
- En la prueba: `DELETE 2`, se borran las categorías 3 y 4, las dos sin productos.
- También funciona dejar el `NOT IN` y filtrar los nulos en la subconsulta (`WHERE categoria_id IS NOT NULL`). Prefiero `NOT EXISTS` porque no depende de acordarse de ese filtro.

## Cómo correría cualquiera de los dos en mi base

Siguiendo [`protocolo_seguridad.md`](../protocolo_seguridad.md): sobre `foodstore_trabajo` y confirmando antes `SELECT current_database()`; primero un `SELECT COUNT(*)` con el mismo `WHERE` para saber cuántas filas deberían cambiar; después el script dentro de `BEGIN`, comparando el número de filas afectadas con ese conteo. Si coinciden, `COMMIT`; si no, `ROLLBACK`.

## Relación con mi proyecto

- En Food Store las categorías y los productos no se borran: se dan de baja con `activo = FALSE` (R7). El equivalente del Script 2 es una baja lógica con el mismo `NOT EXISTS`, mirando solo los productos activos. En la evidencia da `UPDATE 1`: la única categoría activa sin productos activos es Promociones.
- En mi esquema `producto.categoria_id` es `NOT NULL` (R1), así que un `NOT IN` no fallaría por este motivo. Igual uso `NOT EXISTS`: la corrección no depende de que esa columna nunca admita NULL.
- La demostración también repite el error del Script 1, un `UPDATE` sin `WHERE`, sobre mis tablas, dentro de `BEGIN ... ROLLBACK`:
  - `UPDATE categoria SET activo = FALSE` falla: la Regla B de la Parte 1 no deja dar de baja una categoría con productos activos, y el motor rechaza la sentencia entera.
  - `UPDATE producto SET activo = FALSE` pasa sin ningún error y da de baja los doce productos, porque ninguna regla lo impide.

Las reglas del motor atajan algunos errores, pero no todos. Por eso la lectura previa y la transacción siguen siendo obligatorias.
