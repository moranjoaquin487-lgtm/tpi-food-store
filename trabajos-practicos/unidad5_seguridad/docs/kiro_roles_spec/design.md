# Diseño — U5 · Roles y permisos

## Roles y justificación (una oración cada uno)
| Rol | Tipo | Justificación |
|---|---|---|
| `rol_app_lectura` | Grupo | La tienda web muestra el catálogo y los pedidos: lee categorías, productos y pedidos, y nada con datos personales. |
| `rol_app_escritura` | Grupo | La tienda web registra ventas: inserta pedidos y sus líneas y descuenta stock, sin poder cambiar precios. |
| `rol_soporte` | Grupo | La mesa de ayuda consulta usuarios y clientes sin ver contraseñas, corrige el celular o la baja, y resetea contraseñas solo con la función. |
| `rol_reportes` | Grupo | El área comercial mira resultados agregados: vistas de ventas y la tabla anonimizada de usuarios, nunca datos personales. |
| `rol_auditor` | Grupo | Quien investiga un incidente lee los registros de auditoría y ningún dato del negocio. |
| `app_web` | Login | La aplicación: lectura y escritura de la tienda y la función de autenticación. |
| `admin_datos` | Login | El administrador de datos: todo sobre las tablas del esquema salvo modificar la auditoría, sin ser superusuario ni poder crear roles. |
| `usr_soporte`, `usr_reportes`, `usr_auditor` | Login | Un login personal por área, para que el log diga quién hizo qué. |

## Cómo se aplica
1. Se crean los roles que falten y se les quitan los atributos peligrosos (REQ-01).
2. Se revoca todo lo anterior, incluido lo de `PUBLIC`, para que el resultado sea exactamente lo que dice el archivo (REQ-02).
3. Se otorgan los permisos de cada rol de grupo, con permisos de columna donde hace falta (REQ-03 a REQ-07).
4. Se asignan los roles de grupo a los logins y se otorga `admin_datos`, con la auditoría de solo lectura (REQ-08, REQ-11).
5. `ALTER DEFAULT PRIVILEGES` para los objetos futuros que cree `postgres` (REQ-09).
6. Las contraseñas no se escriben en ningún archivo: se ponen con `\password`.

`verificacion_permisos.sql` compara el estado real de `pg_catalog` contra la tabla de permisos esperados y muestra lo que sobra y lo que falta (REQ-10).

## Notas de diseño

- **`admin_datos` no es dueño de ningún objeto.** Los objetos los crea y posee `postgres`. `admin_datos` recibe `SELECT`, `INSERT`, `UPDATE` y `DELETE` por `GRANT`, lo que permite revocarlos sin tocar la estructura. Que no sea dueño también impide que pueda hacer `DROP` o `ALTER` sobre las tablas.
- **`usuario_anon` y `rol_reportes`.** La tabla `usuario_anon` (con datos de usuarios anonimizados) no existe cuando se ejecuta `roles.sql`: se crea en la Parte D (`usuario_anon.sql`). El permiso `SELECT` sobre `usuario_anon` para `rol_reportes` se otorga allí. `verificacion_permisos.sql` lo incluye en la tabla `esperado` de forma condicional (`WHERE to_regclass('public.usuario_anon') IS NOT NULL`).
- **`vista_pedidos_cliente` no se otorga a `rol_reportes`.** Esta vista une pedidos con datos de clientes (nombre y apellido), lo que expone información personal. El área comercial solo necesita agregados, no tuplas individuales de clientes: por eso se otorgan `mv_facturacion_cat_mes` y `v_top5_categorias`, no `vista_pedidos_cliente`. `verificacion_permisos.sql` prueba explícitamente que `usr_reportes` recibe *permiso denegado* al intentar leerla.
