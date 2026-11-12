# Parte C — Simulacro de incidente de acceso indebido

> El simulacro se ejecutó únicamente contra la base propia de desarrollo.

## 1. Escenario y secuencia ejecutada

**Supuesto:** alguien obtuvo la contraseña de `app_web` (por ejemplo, de un archivo de configuración del servidor web) y se conecta directo a la base. `scripts/simulacro_incidente.sh` ejecuta `sql/simulacro_incidente.sql` como `app_web`:

| # | Acción | Resultado esperado |
|:-:|---|---|
| 1 | 5 llamadas a `fn_autenticar` con contraseñas incorrectas para `usuario007` | Ninguna fila (rechazo) |
| 2 | `fn_autenticar` con la contraseña correcta | Devuelve el usuario |
| 3 | `SELECT * FROM usuario`, `SELECT id, nombre, apellido, mail FROM usuario`, `SELECT * FROM vista_usuario_reportes` | `permiso denegado` |
| 4 | `GRANT admin_datos TO rol_app_lectura`, `GRANT admin_datos TO app_web`, `SET ROLE admin_datos`, `fn_resetear_password(...)` | `permiso denegado` |

## 2. ¿Falló el escalamiento?

**Sí.** Evidencia: `evidencias/C_simulacro_verificacion.txt`. Antes y después del simulacro, `pg_has_role('app_web', 'admin_datos', 'MEMBER')` y `pg_has_role('rol_app_lectura', 'admin_datos', 'MEMBER')` dan `f`, y `admin_datos` sigue con 0 miembros. Cada intento quedó en el log con su `ERROR`:

- `se ha denegado el permiso para otorgar el rol «admin_datos»`: nadie tiene `ADMIN OPTION` sobre ese rol.
- `se ha denegado el permiso para definir el rol «admin_datos»`.
- `permiso denegado a la función fn_resetear_password`: es exclusiva de soporte.

El esquema de permisos de la Parte A no tiene el defecto que buscaba el simulacro.

## 3. Log anonimizado

[`log_simulacro_anonimizado.txt`](log_simulacro_anonimizado.txt), generado con `scripts/anonimizar_log.py` con el mismo criterio que `usuario_anon`:

- mails → seudónimo `anon_…@ejemplo.test`
- IP y puerto → `ip_origen_N`
- contraseñas en llamadas a funciones → `'***'`

El original, con los mails, queda en `evidencias/privado/`, que no se sube al repositorio. Control: 0 apariciones de `@foodstore` en el archivo anonimizado.

## 4. Reconstrucción hecha por la IA

Prompt (sin contexto adicional al log): [`../prompts/C_reconstruir_incidente.md`](../prompts/C_reconstruir_incidente.md). Respuesta completa de OpenCode: [`respuestas_ia/C_reconstruccion_incidente.md`](respuestas_ia/C_reconstruccion_incidente.md).

## 5. Contraste entre la respuesta de la IA y lo ejecutado

Qué sustenta el log y qué no, según la secuencia ejecutada:

| Hecho | ¿Lo sustenta el log? |
|---|---|
| Una sola sesión de `app_web`, desde un único origen, que duró menos de un segundo | Sí: `conexión autorizada` y `desconexión: duración de sesión` |
| 5 intentos fallidos y 1 exitoso contra la misma cuenta | Sí: 6 mensajes `LOG` de `fn_autenticar` (5 «intento fallido» y 1 «inicio de sesion correcto») con el mismo seudónimo |
| El atacante conocía la contraseña de `app_web` | Sí: `método=scram-sha-256`, sin fallos de conexión previos |
| Cómo obtuvo esa contraseña | **No.** El log no lo dice |
| Leyó datos de usuarios | **No.** Los tres intentos terminaron en `permiso denegado` |
| Leyó otras tablas, como pedidos o productos, que `app_web` sí puede leer | **No se puede saber.** Con `log_statement = mod`, un `SELECT` exitoso no deja rastro. Es un límite del registro, no evidencia de que no ocurrió |
| Escaló privilegios | **No.** 4 intentos, todos rechazados |
| Las 5 contraseñas probadas fueron un ataque de diccionario | **No.** El log solo muestra que fallaron: las contraseñas están anonimizadas |
| Origen externo | **No.** `ip_origen_1` es un seudónimo; en el simulacro era la propia máquina |
| Hora local del ataque | Solo con cuidado: el log está en la zona horaria del servidor (`log_timezone`) |

Contraste con la respuesta de OpenCode:

| | Detalle |
|---|---|
| Qué acertó | El orden de los hechos: 5 intentos fallidos y 1 exitoso contra la misma cuenta, separados por unos 23 ms; los tres intentos de leer `usuario` y la vista rechazados; los dos `GRANT`, el `SET ROLE` y `fn_resetear_password` rechazados. Concluyó bien que el escalamiento no tuvo éxito y que no hay modificaciones de roles en el log. Varias medidas coinciden con mi decisión: rotar la contraseña de `app_web`, limitar los intentos de `fn_autenticar` y revisar las membresías de `admin_datos` |
| Qué omitió | Lo más grave: la sesión de `app_web` ya estaba autenticada con su contraseña (`método=scram-sha-256`) **antes** de los intentos. El atacante tenía la credencial de la base de la aplicación. OpenCode la incluye en «rotar credenciales» sin decir que es el hecho central. Tampoco señaló el límite del registro: con `log_statement = mod`, un `SELECT` que sí funcionó, por ejemplo sobre `pedido`, no deja rastro |
| Qué afirmó sin sustento en el log | (1) «Con el rol `app_web` autenticado (usuario_id 35)»: mezcla el login de la base con el usuario de la aplicación. La fuerza bruta no le dio el rol `app_web`, que ya tenía desde la conexión. (2) «Bloquear `ip_origen_1` en el firewall»: es un seudónimo de la anonimización, y nada en el log dice que el origen sea externo. (3) «Terminar la sesión PID 15192 si sigue activa»: el mismo log muestra su desconexión a los 0,203 s. Lo detecté comparando cada afirmación con las líneas del log y con `sql/simulacro_incidente.sql` |

## 6. Decisión de contención

> La decisión es mía, tomada a partir de la evidencia del log y de la verificación de roles. No es una acción ejecutada automáticamente a partir de lo que sugirió la IA. Ninguna medida se aplicó sobre la base: es lo que haría en un caso real.

| Medida | Por qué | Evidencia que la justifica |
|---|---|---|
| Cambiar la contraseña de `app_web` y sacarla del archivo de configuración del servidor web | La sesión se autenticó con la contraseña correcta: la credencial está comprometida | `conexión autenticada: identidad=«app_web»` |
| Restringir `app_web` en `pg_hba.conf` a la IP del servidor web | Hoy se acepta desde cualquier origen | Línea de `pg_hba.conf` de la `conexión autenticada` |
| Forzar el cambio de contraseña de `usuario007` | Su contraseña fue adivinada | 5 fallos y 1 éxito sobre la misma cuenta |
| Agregar a `fn_autenticar` un bloqueo temporal tras varios fallos seguidos | Hoy no hay límite de intentos | `auditoria_seguridad`: 5 fallos en menos de 1 s |
| **No** revertir roles | El escalamiento falló y no hay membresías nuevas | `C_simulacro_verificacion.txt` |
| Mientras dure la investigación, registrar también las lecturas de `app_web` (`ALTER ROLE app_web SET log_statement = 'all'`, o pgaudit) | Con `mod` no se puede saber si leyó pedidos | Fila «leyó otras tablas» del contraste |
