# spec: B4 · Vista `v_usuario_publico`

Objetivo: ofrecer una vista de seguridad sobre `usuario` que exponga solo los campos necesarios para reportes, ocultando `contrasena` y `celular`, y restringiendo el acceso de forma que un rol de solo lectura (`rol_reportes`) pueda consultar la vista pero no la tabla base.

Consulta afectada:
```sql
-- Consulta equivalente que la vista debe replicar exactamente:
SELECT id,
       nombre,
       apellido,
       mail,
       rol
FROM usuario
WHERE eliminado = FALSE;
```

Frecuencia: reportes de administración de usuarios; varias veces por día.

Columnas a exponer (en orden):

| # | Columna | Origen | Alias |
|---|---|---|---|
| 1 | `id` | `usuario.id` | — |
| 2 | `nombre` | `usuario.nombre` | — |
| 3 | `apellido` | `usuario.apellido` | — |
| 4 | `mail` | `usuario.mail` | — |
| 5 | `rol` | `usuario.rol` | — |

Filtro de vigencia: `usuario.eliminado = FALSE`. Solo los usuarios activos son relevantes para los reportes; los eliminados lógicamente no deben aparecer.

Columnas ocultas:

| Columna | Razón |
|---|---|
| `contrasena` | Dato de seguridad crítico: nunca debe ser accesible fuera del módulo de autenticación. Es la razón principal de esta vista. |
| `celular` | Dato de contacto personal; los reportes no lo usan y exponerlo innecesariamente amplía la superficie de datos personales sensibles. |
| `eliminado` | Siempre `FALSE` dentro de la vista; exponerlo sería redundante. |
| `created_at` | Metadato de auditoría; no lo consumen los reportes de usuarios. |

Control de acceso:

- El rol `rol_reportes` recibe `SELECT` sobre `v_usuario_publico`.
- El rol `rol_reportes` **no** recibe ningún permiso sobre la tabla `usuario`.
- El propietario de la vista (el rol que la crea, típicamente el owner del esquema) mantiene acceso completo a `usuario`.

Criterio de aceptación (dos partes):

**1. Equivalencia de datos:** ejecutar la consulta equivalente directa y la misma consulta sobre la vista; hacer `EXCEPT` en ambos sentidos. Ambos `EXCEPT` deben devolver 0 filas.

```sql
-- Verificación de equivalencia:
(SELECT id, nombre, apellido, mail, rol FROM v_usuario_publico)
EXCEPT
(SELECT id, nombre, apellido, mail, rol FROM usuario WHERE eliminado = FALSE);

(SELECT id, nombre, apellido, mail, rol FROM usuario WHERE eliminado = FALSE)
EXCEPT
(SELECT id, nombre, apellido, mail, rol FROM v_usuario_publico);
```

**2. Control de acceso:** con `SET ROLE rol_reportes`:

- `SELECT id, nombre FROM v_usuario_publico LIMIT 1;` debe ejecutarse sin error y devolver filas.
- `SELECT id, nombre FROM usuario LIMIT 1;` debe fallar con un error de permisos (`permission denied for table usuario`).

```sql
-- Verificación de permisos:
SET ROLE rol_reportes;
SELECT id, nombre FROM v_usuario_publico LIMIT 1;   -- debe funcionar
SELECT id, nombre FROM usuario LIMIT 1;              -- debe fallar
RESET ROLE;
```
