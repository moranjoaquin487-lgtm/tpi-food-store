# Refactorización de `control_lote_almacen` hasta BCNF

## 1. El esquema heredado

`control_lote_almacen (lote_id, deposito_id, responsable_control_id)`, con clave primaria `(lote_id, deposito_id)`. Registra qué responsable controló cada lote en cada depósito.

Reglas de negocio relevadas:

- **R1.** Para un lote y un depósito, el responsable del control es uno solo.
- **R2.** Cada responsable pertenece a un único depósito.

La tabla se carga con datos de prueba en `sql/01_esquema_heredado.sql`: 8 depósitos, 24 responsables (3 por depósito), 300 lotes y 600 controles.

## 2. Dependencias funcionales

Abreviaturas: L = `lote_id`, D = `deposito_id`, R = `responsable_control_id`.

| DF | Origen | ¿Se cumple en los datos? |
|---|---|---|
| DF1: {L, D} → R | R1 | Sí: 0 violaciones |
| DF2: R → D | R2 | Sí: 0 violaciones |
| L → D | No es una regla | No: 200 lotes se controlan desde más de un depósito |
| L → R | No es una regla | No: 200 lotes tienen más de un responsable |

`sql/02_validar_dependencias.sql` comprueba cada fila de la tabla. Las dos últimas no se postulan: un lote puede pasar por varios depósitos y, por lo tanto, por varios responsables.

## 3. Claves candidatas

U = {L, D, R}.

- {L, D}⁺ = {L, D, R} = U. Ni {L}⁺ = {L} ni {D}⁺ = {D} alcanzan U, así que {L, D} es **clave candidata**.
- {R}⁺ = {R, D}: falta L, así que R no es clave.
- {L, R}⁺ = {L, R, D} = U, aplicando DF2. Ni {L} ni {R} alcanzan U, así que {L, R} también es **clave candidata**.

Los tres atributos son primos, y por eso la tabla está en 3FN: toda DF tiene a la derecha un atributo primo.

## 4. ¿Está en BCNF?

BCNF exige que el lado izquierdo de toda DF no trivial sea superclave.

| DF | Determinante | ¿Superclave? |
|---|---|---|
| {L, D} → R | {L, D} | Sí |
| R → D | {R} | **No**: {R}⁺ = {R, D} ≠ U |

**No está en BCNF.** DF2 es la dependencia violatoria.

## 5. Anomalías, medidas sobre los datos

- **Redundancia:** el dato «R pertenece a D» tiene 24 hechos distintos, guardados en 600 filas. Son 576 repeticiones.
- **Actualización:** si se cambia el depósito de un responsable en una sola de sus filas, la base queda con el mismo responsable en dos depósitos. El script lo reproduce dentro de `BEGIN … ROLLBACK`: el responsable 4 queda en `{1, 8}`.
- **Inserción:** un responsable nuevo que todavía no controló ningún lote no se puede registrar. `lote_id` es parte de la PK y no admite `NULL`, y el script muestra el error.
- **Borrado:** si se borran todos los controles de un responsable, se pierde también a qué depósito pertenece.

## 6. Descomposición

Se descompone por la DF violatoria R → D:

| Tabla | Atributos | Clave | DF que conserva |
|---|---|---|---|
| `responsable_deposito` (R1) | R, D | R | R → D |
| `control_lote` (R2) | L, R | {L, R} | — |

**Es sin pérdida (teorema de Heath).** El atributo común es R, y R es clave de R1. Por lo tanto, R1 ⋈ R2 reconstruye exactamente la relación original. La migración lo comprueba con `EXCEPT` en los dos sentidos: 0 tuplas perdidas y 0 espurias.

**No preserva DF1.** Ninguna de las dos tablas tiene L y D juntos. Sin una salvaguarda, dos responsables del mismo depósito podrían controlar el mismo lote, y la reunión devolvería dos responsables para el mismo (L, D). Es el caso clásico en el que BCNF obliga a elegir entre eliminar la redundancia y preservar todas las dependencias. Se eligió BCNF, y DF1 se controla con el trigger `fn_control_lote_df1`:

- Corre por sentencia sobre `control_lote` y sobre los cambios de depósito en `responsable_deposito`.
- Busca en la vista de reunión algún (L, D) repetido y, si encuentra uno, rechaza la operación.
- Toma un candado de transacción (`pg_advisory_xact_lock`) antes de controlar. Así, dos transacciones concurrentes no pueden pasar el control al mismo tiempo.

Las dos tablas nuevas quedan en BCNF. En R1, la única DF es R → D, con R como clave. En R2 no hay DF no triviales.

## 7. Resultado sobre las anomalías

`sql/05_pruebas_esquema_nuevo.sql` repite cada anomalía sobre el esquema nuevo, siempre dentro de `BEGIN … ROLLBACK`:

| Anomalía | Esquema heredado | Esquema nuevo |
|---|---|---|
| Inserción | Error: falta `lote_id` | El responsable se registra con 0 lotes |
| Borrado | Se pierde su depósito | Su depósito sigue registrado |
| Actualización | Una fila por lote (12 para el responsable 4) | `UPDATE 1` |
| DF1 | La garantiza la PK | La garantiza el trigger: rechaza al segundo responsable del mismo depósito y acepta el de otro depósito |
