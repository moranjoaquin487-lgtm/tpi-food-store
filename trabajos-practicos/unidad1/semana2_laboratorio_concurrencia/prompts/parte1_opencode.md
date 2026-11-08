# Parte 1 — Pedidos a OpenCode

Texto exacto que se le pasó a OpenCode para generar las restricciones. La spec (`specs/spec_restricciones.md`) se commiteó antes de este paso.

## 1. Plan (modo Plan)

```text
Leé specs/spec_restricciones.md, food-store/schema.sql y food-store/data.sql. Proponé un plan para crear dos archivos:

1. food-store/restricciones.sql: las reglas A, B y C de la spec, garantizadas por el motor con restricciones declarativas donde alcancen, o con funciones PL/pgSQL y triggers donde no. Tiene que poder ejecutarse más de una vez: DROP ... IF EXISTS o CREATE OR REPLACE antes de cada objeto. Mensajes de error en español que digan qué regla se violó.

2. food-store/pruebas_restricciones.sql: los 8 casos de la tabla de la spec, en el mismo orden, cada uno con un comentario que diga el número de caso y el resultado esperado. Cada caso es una sentencia suelta, sin bloques DO ni manejo de excepciones: en los casos inválidos se tiene que ver el error del motor. Buscá las filas por nombre o email, nunca por id. En el caso 4, después del UPDATE agregá un SELECT que muestre que las líneas ya vendidas de la Muzzarella conservan su precio.

Condiciones para los dos archivos: no escribas BEGIN, COMMIT ni ROLLBACK, porque la transacción la abre scripts/aplicar_restricciones.sh; no ejecutes nada contra la base; comentarios en español.

Todavía no escribas ningún archivo: mostrame solo el plan.
```

## 2. Escritura (modo Build, después de revisar el plan)

```text
El plan está bien. Escribí los dos archivos.
```

## 3. Si hace falta

Una línea del diff que no se entiende (modo Plan):

```text
¿Qué hace la línea N de food-store/restricciones.sql y qué pasaría si la sacara?
```

Un caso de prueba que no da lo que dice la spec (modo Plan, y después Build):

```text
El caso N dio <resultado> y la spec dice <resultado esperado>. Proponé cómo corregir food-store/restricciones.sql para que cumpla la spec.
```
