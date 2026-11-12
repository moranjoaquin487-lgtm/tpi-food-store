# Parte B — Activación y prueba de la auditoría

## 1. Configuración

Se aplicó con `sql/configurar_auditoria.sql`, como postgres. `ALTER SYSTEM` escribe en `postgresql.auto.conf` y `pg_reload_conf()` lo activa sin reiniciar. La salida, con los valores antes y después, está en `evidencias/B_configuracion.txt`.

| Parámetro | Antes | Después | Para qué |
|---|---|---|---|
| `log_connections` | `off` | `on` | Quién se conecta, desde dónde, con qué método de autenticación |
| `log_disconnections` | `off` | `on` | Cuándo termina la sesión y cuánto duró |
| `log_statement` | `none` | `mod` | Registra el DDL y las modificaciones: `INSERT`, `UPDATE`, `DELETE`, `TRUNCATE` y `COPY FROM` |
| `log_min_error_statement` | `error` | `error` | Registra el texto de toda sentencia que falla |
| `log_line_prefix` | `%m [%p] ` | `%m [%p] %q%u@%d %r app=%a ` | Agrega usuario, base, IP y puerto de origen, y aplicación |
| `logging_collector` | `on` | `on` | Ya venía activo en la instalación de Windows. Si estuviera apagado, requiere reiniciar el servicio |

La columna «Antes» tiene los valores por defecto de PostgreSQL. Los de esta instalación figuran en `evidencias/B_configuracion.txt`.

`log_connections` y `log_disconnections` rigen para las sesiones nuevas. Por eso el script se reconecta (`\c`) antes de mostrar los valores nuevos.

## 2. Secuencia de prueba

`scripts/correr_auditoria_test.sh` ejecuta `sql/auditoria_test.sql` conectado como `app_web`:

1. Una lectura del catálogo.
2. Un `INSERT` de un pedido de prueba y su línea.
3. Un `UPDATE` del stock.

Después intenta conectarse con una contraseña incorrecta. El fragmento de log, entre dos marcas, quedó en [`log_auditoria_prueba.txt`](log_auditoria_prueba.txt).

## 3. Qué sirve del log y qué queda afuera

**Lo que el log responde:**

| Pregunta | Dónde aparece | Ejemplo |
|---|---|---|
| ¿Quién? | `%u@%d` y `identity=` | `app_web@foodstore`, `identity="app_web" method=scram-sha-256` |
| ¿Qué? | `statement:` | El texto completo del `INSERT` y del `UPDATE` |
| ¿Cuándo? | `%m` | Hora con milisegundos |
| ¿Desde dónde? | `%r` y `connection received` | IP y puerto de origen |
| ¿Falló un acceso? | `FATAL` | `password authentication failed for user "app_web"` |

**Lo que este mecanismo no registra:**

- **Las lecturas.** La consulta del catálogo no aparece: con `mod` no se registra ningún `SELECT`. No se puede saber quién leyó qué datos.
- **Lo que pasa dentro de funciones y procedimientos.** Un `CALL sp_registrar_pedido(...)` no deja rastro de los `INSERT` que hace adentro.
- **Las filas y los valores.** El `UPDATE` aparece como texto, pero no qué filas cambió ni qué valor tenían antes.
- **Si la transacción se confirmó.** Con `mod`, `BEGIN`, `COMMIT` y `ROLLBACK` no se registran. Un `INSERT` deshecho se ve igual que uno confirmado.
- **La identidad real de la aplicación.** `app=` es lo que declara el cliente y se puede falsear.
- **Cuántos intentos hubo de verdad.** Una sola conexión con contraseña incorrecta dejó **dos** líneas `FATAL`. psql reintenta sin SSL después de fallar con SSL (`sslmode=prefer`). Contar intentos solo a partir del log da el doble.

**pgaudit, a nivel de nociones.** Es una extensión que agrega auditoría por clase (`READ`, `WRITE`, `ROLE`, `DDL`) y por objeto. Por ejemplo, podría registrar todo `SELECT` sobre `usuario` sin registrar el resto de las lecturas. También registra cada sentencia que se ejecuta dentro de funciones, e identifica el objeto y el tipo de operación de cada registro. Es lo que faltaría para responder «quién leyó la tabla de usuarios».

## 4. ¿El log es un activo sensible?

Sí. Contiene mails, IP, el texto de las sentencias con los datos que se insertaron y, como se comprobó en la Parte C, puede contener contraseñas si alguna sentencia las lleva como texto. Solo deberían leerlo el administrador de la base y quien audita. En el sistema operativo, el archivo tiene que pertenecer a la cuenta del servicio de PostgreSQL, con permisos de solo dueño (`log_file_mode = 0600` en Linux; en Windows, permisos sobre la carpeta `data\log` solo para la cuenta del servicio y los administradores). En el motor, leerlo con `pg_read_file` requiere ser superusuario o tener `pg_read_server_files`, y ningún rol de la aplicación tiene esos permisos.
