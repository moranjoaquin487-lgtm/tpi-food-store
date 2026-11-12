# Análisis de log PostgreSQL

> Exportación de la sesión de OpenCode (agente Plan, modelo Big Pickle) con `/export`, sin cambios salvo una: se quitaron las dos líneas del encabezado con la fecha y la hora. OpenCode se abrió en una carpeta fuera del repositorio que solo tenía una copia de `docs/log_simulacro_anonimizado.txt` sin las líneas de las marcas de inicio y fin del script, que decían «simulacro». El contraste con lo ejecutado está en el punto 5 de [`../informe_incidente.md`](../informe_incidente.md).

**Session ID:** ses_e2fc45c32ffeWh58RRsDLA1PZv

---

## User

Te paso un fragmento de log de PostgreSQL (archivo log_simulacro_anonimizado.txt).
Reconstruí qué ocurrió, en orden, y proponé una hipótesis de contención. 

---

## Assistant (Plan · Big Pickle · 5.2s)

_Thinking:_

**Exploring workspace**

Okay, the user wants to analyze a PostgreSQL log fragment to reconstruct events and propose a containment hypothesis. But they're in Plan Mode, so I can't make any changes. First, I need to locate and read the log file. I’ll start by exploring the workspace to see where it is. Once I find it, I can dive into the details and figure out the sequence of events.

**Tool: glob**

**Input:**
```json
{
  "pattern": "**/*.txt"
}
```

**Output:**
```
C:\Users\moran\BD2\incidente_c\log_simulacro_anonimizado.txt
```

---

## Assistant (Plan · Big Pickle · 1.2s)

**Tool: read**

**Input:**
```json
{
  "filePath": "C:\\Users\\moran\\BD2\\incidente_c\\log_simulacro_anonimizado.txt"
}
```

**Output:**
```
<path>C:\Users\moran\BD2\incidente_c\log_simulacro_anonimizado.txt</path>
<type>file</type>
<content>
1: 2026-11-12 11:14:37.049 -03 [9512] postgres@foodstore ip_origen_1(puerto) app=psql LOG:  desconexión: duración de sesión: 0:00:00.054 usuario=postgres base=foodstore host=ip_origen_1 port=(puerto)
2: 2026-11-12 11:14:37.354 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql LOG:  fn_autenticar: intento fallido mail=anon_336c5c15e0@ejemplo.test
3: 2026-11-12 11:14:37.354 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql CONTEXTO:  función PL/pgSQL fn_autenticar(text,text) en la línea 22 en RAISE
4: 2026-11-12 11:14:37.377 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql LOG:  fn_autenticar: intento fallido mail=anon_336c5c15e0@ejemplo.test
5: 2026-11-12 11:14:37.377 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql CONTEXTO:  función PL/pgSQL fn_autenticar(text,text) en la línea 22 en RAISE
6: 2026-11-12 11:14:37.400 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql LOG:  fn_autenticar: intento fallido mail=anon_336c5c15e0@ejemplo.test
7: 2026-11-12 11:14:37.400 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql CONTEXTO:  función PL/pgSQL fn_autenticar(text,text) en la línea 22 en RAISE
8: 2026-11-12 11:14:37.422 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql LOG:  fn_autenticar: intento fallido mail=anon_336c5c15e0@ejemplo.test
9: 2026-11-12 11:14:37.422 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql CONTEXTO:  función PL/pgSQL fn_autenticar(text,text) en la línea 22 en RAISE
10: 2026-11-12 11:14:37.444 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql LOG:  fn_autenticar: intento fallido mail=anon_336c5c15e0@ejemplo.test
11: 2026-11-12 11:14:37.444 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql CONTEXTO:  función PL/pgSQL fn_autenticar(text,text) en la línea 22 en RAISE
12: 2026-11-12 11:14:37.467 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql LOG:  fn_autenticar: inicio de sesion correcto mail=anon_336c5c15e0@ejemplo.test usuario_id=35
13: 2026-11-12 11:14:37.467 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql CONTEXTO:  función PL/pgSQL fn_autenticar(text,text) en la línea 17 en RAISE
14: 2026-11-12 11:14:37.469 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql ERROR:  permiso denegado a la tabla usuario
15: 2026-11-12 11:14:37.469 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql SENTENCIA:  SELECT * FROM usuario;
16: 2026-11-12 11:14:37.469 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql ERROR:  permiso denegado a la tabla usuario
17: 2026-11-12 11:14:37.469 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql SENTENCIA:  SELECT id, nombre, apellido, mail FROM usuario;
18: 2026-11-12 11:14:37.470 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql ERROR:  permiso denegado a la vista vista_usuario_reportes
19: 2026-11-12 11:14:37.470 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql SENTENCIA:  SELECT * FROM vista_usuario_reportes;
20: 2026-11-12 11:14:37.470 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql LOG:  sentencia: GRANT admin_datos TO rol_app_lectura;
21: 2026-11-12 11:14:37.471 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql ERROR:  se ha denegado el permiso para otorgar el rol «admin_datos»
22: 2026-11-12 11:14:37.471 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql DETALLE:  Sólo los roles con la opción ADMIN en el rol «admin_datos» pueden otorgar este rol.
23: 2026-11-12 11:14:37.471 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql SENTENCIA:  GRANT admin_datos TO rol_app_lectura;
24: 2026-11-12 11:14:37.471 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql LOG:  sentencia: GRANT admin_datos TO app_web;
25: 2026-11-12 11:14:37.471 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql ERROR:  se ha denegado el permiso para otorgar el rol «admin_datos»
26: 2026-11-12 11:14:37.471 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql DETALLE:  Sólo los roles con la opción ADMIN en el rol «admin_datos» pueden otorgar este rol.
27: 2026-11-12 11:14:37.471 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql SENTENCIA:  GRANT admin_datos TO app_web;
28: 2026-11-12 11:14:37.471 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql ERROR:  se ha denegado el permiso para definir el rol «admin_datos»
29: 2026-11-12 11:14:37.471 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql SENTENCIA:  SET ROLE admin_datos;
30: 2026-11-12 11:14:37.472 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql ERROR:  permiso denegado a la función fn_resetear_password
31: 2026-11-12 11:14:37.472 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql SENTENCIA:  SELECT fn_resetear_password('anon_336c5c15e0@ejemplo.test', '***');
32: 2026-11-12 11:14:37.473 -03 [15192] app_web@foodstore ip_origen_1(puerto) app=psql LOG:  desconexión: duración de sesión: 0:00:00.203 usuario=app_web base=foodstore host=ip_origen_1 port=(puerto)
33: Binary file docs/log_simulacro_anonimizado.txt matches

(End of file - total 33 lines)
</content>
```

---

## Assistant (Plan · Big Pickle · 35.6s)

_Thinking:_

**Reconstructing the timeline**

Okay, the user wants me to analyze the PostgreSQL log and reconstruct what happened, step by step. I’ll need to identify the attack pattern, like brute force or credential stuffing, and see if there was an attempt at privilege escalation. After that, I’ll suggest a containment strategy.

I’ll start by analyzing the logs and building the timeline from there. The first timestamp is 11:14:37, so I’ll begin with that.

**Analyzing the log and containment proposal**

Okay, so the log shows a series of failed authentication attempts followed by a successful login. The attacker likely used brute force or password spraying to gain access to the app_web account. After logging in, they tried escalating privileges and enumerating users, but all actions were blocked due to insufficient privileges.

For containment, I’ll suggest terminating the session, rotating credentials, reviewing logs for brute force attempts, and enforcing rate limiting and MFA. I’ll also check for any lateral movement and review function security.

## Reconstrucción cronológica

| Hora | Evento | Detalle |
|---|---|---|
| 11:14:37.049 | Desconexión previa | Sesión de `postgres` finaliza. |
| 11:14:37.354 - 11:14:37.444 | Fuerza bruta / intentos fallidos | 5 intentos fallidos consecutivos desde la conexión `app_web` (PID 15192, `ip_origen_1`) contra `fn_autenticar` para `mail=anon_336c5c15e0@ejemplo.test`. Muy próximos entre sí (~23 ms). |
| 11:14:37.467 | Autenticación exitosa | `fn_autenticar` reporta inicio de sesión correcto para ese mail con `usuario_id=35`. |
| 11:14:37.469 - 11:14:37.470 | Enumeración de datos | Intentos de `SELECT * FROM usuario`, `SELECT id,nombre,apellido,mail FROM usuario` y `SELECT * FROM vista_usuario_reportes`. Todos denegados por permisos. |
| 11:14:37.470 - 11:14:37.471 | Intento de escalado de privilegios | `GRANT admin_datos TO rol_app_lectura` y `GRANT admin_datos TO app_web`. Denegados (solo roles con opción `ADMIN` sobre `admin_datos` pueden otorgarlo). |
| 11:14:37.471 | Intento de cambio de rol | `SET ROLE admin_datos`. Denegado. |
| 11:14:37.472 | Intento de acción privilegiada | `SELECT fn_resetear_password('anon_336c5c15e0@ejemplo.test', '***')`. Denegado por permisos. |
| 11:14:37.473 | Desconexión | Sesión `app_web` finaliza (duración ~0.203 s). | 

## Hipótesis

- **Acceso inicial:** Se trató de un ataque de fuerza bruta/credenciales contra la cuenta asociada a `anon_336c5c15e0@ejemplo.test`. Tras múltiples intentos fallidos se logró una autenticación exitosa (posible credencial válida o credenciales previamente filtradas).
- **Post-explotación:** Con el rol `app_web` autenticado (usuario_id 35) el actor intentó enumerar usuarios/reportes, escalar privilegios (otorgar/cambiar al rol `admin_datos`) y ejecutar `fn_resetear_password`. Todos los intentos fueron bloqueados por el modelo de permisos vigente.
- **Resultado:** No hay evidencia en este log de que se haya comprometido un rol privilegiado o de una modificación exitosa de datos/roles. El intento fue contenido por controles de autorización. 

## Propuesta de contención (priorizada)

| Acción | Razón |
|---|---|
| Terminar la sesión activa | Si la sesión PID 15192 aún está activa, finalizarla con `pg_terminate_backend(15192)`. |
| Rotar credenciales | Rotar la contraseña de `usuario_id=35` y credenciales del rol/servicio `app_web`. Invalidar tokens/sesiones vigentes. |
| Bloquear origen | Bloquear/restringir `ip_origen_1` a nivel de `pg_hba.conf`, firewall o WAF mientras se investiga. |
| Revisar alcance | Buscar en logs el mismo mail/IP/usuario_id en un rango temporal amplio (éxitos/fallos, otras sentencias) para detectar movimiento lateral o intentos previos. |
| Hardening de autenticación | Aplicar rate limiting/lockout a `fn_autenticar`, MFA si aplica y alertas por ráfagas de fallidos seguidas de un éxito. |
| Verificación de privilegios | Auditar pertenencia a roles, opciones `ADMIN` sobre `admin_datos`, `SECURITY DEFINER` de `fn_resetear_password` y permisos mínimos de `app_web`. |
| Preservar evidencia | Conservar este log, conexiones activas, `pg_authid/role membership` y registros de auditoría antes de cambios. |

---

