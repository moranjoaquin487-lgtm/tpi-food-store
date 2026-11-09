# DUIA — Parte 2

Declaración de uso de IA del laboratorio de concurrencia.

- **Presentado por:** Moran, Joaquín Leandro

## Kiro — explicaciones de los cuatro escenarios

| Campo | Completar |
|---|---|
| Herramienta | Kiro, con el selector de modelo en Auto. |
| Spec o prompt utilizado | Un chat nuevo por escenario, con el contenido completo de `prompts/explicacion_escenario_1.md` a `4.md`. Esos pedidos los genera `laboratorio_concurrencia.sh reproducir` con los comandos y la salida real de cada sesión, sin título ni pistas sobre el nombre de la anomalía. |
| Qué generó | Una explicación por escenario: qué pasó y qué nivel de aislamiento o mecanismo de bloqueo lo evitaría. |
| Qué se aceptó | Las cuatro respuestas se guardaron sin editar en [`docs/explicaciones_ia/`](../explicaciones_ia/). |
| Qué se modificó o descartó, y por qué | No se modificó ninguna respuesta. Hubo dos errores míos al copiarlas: en el escenario 4 pegué primero la respuesta del 3, así que lo repetí en un chat nuevo; y las respuestas de los escenarios 2 a 4 no quedaron guardadas en el commit `3871360`, por lo que se guardaron en un commit posterior. Los errores de Kiro no se corrigieron en sus respuestas: se documentan en el informe. |
| Verificación realizada | Repetí cada experimento en el motor con `bash scripts/laboratorio_concurrencia.sh verificar`: REPEATABLE READ y SERIALIZABLE en los escenarios 1 y 2; NOWAIT, SKIP LOCKED, `lock_timeout` y SERIALIZABLE en el 3; y el mismo orden y SERIALIZABLE en el 4. Kiro propuso para el escenario 2 una alternativa que el script no probaba, `LOCK TABLE pedido IN SHARE MODE`, así que la verifiqué con `scripts/verificar_lock_table.sh`. Resultado: Kiro acertó en el diagnóstico de los cuatro escenarios, pero en el 3 afirmó que el nivel de aislamiento no cambia nada, y en SERIALIZABLE la sesión B falló con `40001`. El detalle está en [`docs/informe_concurrencia.md`](../informe_concurrencia.md). |

## Claude (Anthropic)

| Campo | Completar |
|---|---|
| Herramienta | Claude (Anthropic). |
| Spec o prompt utilizado | La consigna del TP, y después mis evidencias y las respuestas de Kiro. |
| Qué generó | Los fragmentos SQL de las dos sesiones (`food-store/concurrencia/`), el script `laboratorio_concurrencia.sh`, el script extra `verificar_lock_table.sh` y la redacción del informe y de esta DUIA. Antes de dármelo, probó `verificar_lock_table.sh` en una base de prueba con mi esquema y mis datos. También comparó las respuestas de Kiro con las evidencias y señaló las afirmaciones que había que verificar. |
| Qué se aceptó | Los scripts se usaron como estaban. El informe usa la salida real de mis evidencias. |
| Qué se modificó o descartó, y por qué | El informe aclara que dos alternativas que mencionó Kiro en el escenario 4 y el comportamiento de REPEATABLE READ en el escenario 3 no se probaron en el motor. |
| Verificación realizada | Corrí `reproducir`, `verificar` y `verificar_lock_table.sh` en mi PC y controlé los valores clave: 1050 → 1150 en el escenario 1, 2 → 3 en el 2, 1,38 s de espera en el 3 y `40P01` en el 4, y los resultados de cada verificación. |

## Lo que hice yo

Corrí los escenarios y las verificaciones, pasé cada pedido a Kiro y guardé sus respuestas, revisé la salida de cada evidencia y commiteé cada paso. Tengo que poder explicar en la defensa por qué cada nivel o mecanismo evita, o no evita, cada problema.
