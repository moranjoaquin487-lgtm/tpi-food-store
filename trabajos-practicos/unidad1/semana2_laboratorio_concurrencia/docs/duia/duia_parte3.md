# DUIA — Parte 3

Declaración de uso de IA del ejercicio de lectura crítica.

- **Presentado por:** Moran, Joaquín Leandro

| Campo | Completar |
|---|---|
| Herramienta | Claude (Anthropic). En esta parte no usé OpenCode ni Kiro. |
| Spec o prompt utilizado | Los dos scripts de la sección 6.3 de la consigna, con el pedido de analizar qué hacen realmente, explicar por qué no cumplen lo que dicen y corregirlos. |
| Qué generó | El análisis y las correcciones de [`docs/ejercicio_lectura_critica.md`](../ejercicio_lectura_critica.md), y la demostración [`food-store/lectura_critica_demo.sql`](../../food-store/lectura_critica_demo.sql), que corre cada script tal como está y corregido sobre un esquema de prueba, dentro de `BEGIN ... ROLLBACK`. La demostración también repite el error del Script 1 sobre mis tablas. Las columnas del esquema genérico son un supuesto, porque la consigna no las da; está aclarado en el documento. |
| Qué se aceptó | El análisis y las correcciones: para el Script 1, agregar el `WHERE` con la subconsulta de películas retiradas; para el Script 2, reemplazar `NOT IN` por `NOT EXISTS`. |
| Qué se modificó o descartó, y por qué | Nada. |
| Verificación realizada | Corrí `bash scripts/lectura_critica.sh` y controlé en [`evidencias/parte3_lectura_critica.txt`](../../evidencias/parte3_lectura_critica.txt) los siete resultados, en orden. Script 1 tal como está: `UPDATE 6` (todas las funciones); corregido: `UPDATE 2`. Script 2 tal como está: `DELETE 0` (el NULL anula el `NOT IN`); corregido: `DELETE 2`. Sobre mi base: el `UPDATE` sin `WHERE` sobre `categoria` falla por la Regla B; sobre `producto` da `UPDATE 12`, porque ninguna regla lo impide; y la baja lógica con `NOT EXISTS` da `UPDATE 1` (Promociones). |

## Lo que hice yo

Leí el ejercicio, corrí la demostración y comparé cada resultado con lo que dice el análisis. Tengo que poder explicar en la defensa por qué un `NOT IN` con un NULL en la subconsulta no borra nada.
