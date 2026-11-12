# Requisitos — U5 · Usuarios, roles y permisos de Food Store

Principio: **mínimo privilegio**. Cada rol de grupo representa una función del negocio y cada login recibe solo los roles de su función. Lo implementa `sql/roles.sql` y lo verifica `sql/verificacion_permisos.sql`.

| ID | Requisito (EARS) | Se prueba con |
|---|---|---|
| REQ-01 | THE SYSTEM SHALL crear los roles sin `SUPERUSER`, `CREATEDB`, `CREATEROLE` ni `BYPASSRLS`, y los roles de grupo sin `LOGIN`. | `A_03_verificacion_permisos.txt`, `\du` |
| REQ-02 | THE SYSTEM SHALL quitarle a `PUBLIC` el `CONNECT` a la base, el `CREATE` sobre `public` y el `EXECUTE` de las funciones. | `A_03`, comparación contra la spec |
| REQ-03 | WHEN `app_web` registra una venta, THE SYSTEM SHALL permitirle insertar en `pedido` y `detalle_pedido` y actualizar solo la columna `stock` de `producto`. | `A_03`, pruebas con `SET ROLE` |
| REQ-04 | IF `app_web` intenta leer `usuario` o `cliente`, THEN THE SYSTEM SHALL rechazarlo; la autenticación pasa solo por `fn_autenticar`. | `A_03`, pruebas con `SET ROLE` |
| REQ-05 | WHEN soporte atiende a un usuario, THE SYSTEM SHALL dejarle ver `usuario` sin la columna `contrasena`, cambiar solo `celular` y `eliminado`, y resetear contraseñas solo con `fn_resetear_password`. | `A_03`, permisos de columna |
| REQ-06 | THE SYSTEM SHALL darle a `rol_reportes` solo vistas de ventas, agregados y `usuario_anon`, nunca tablas con datos personales. | `A_03`, `D_equivalencia.txt` |
| REQ-07 | THE SYSTEM SHALL darle a `rol_auditor` solo lectura de `auditoria_seguridad` y `auditoria_precio`. | `A_03` |
| REQ-08 | THE SYSTEM SHALL darle a `admin_datos` `SELECT`, `INSERT`, `UPDATE` y `DELETE` sobre las tablas del esquema, sin `TRUNCATE`, `REFERENCES` ni `TRIGGER`. | `A_03` |
| REQ-09 | WHEN `postgres` crea un objeto nuevo, THE SYSTEM SHALL no darle acceso a `PUBLIC` y otorgárselo solo a `admin_datos`. | `roles.sql (sección 6)`, `A_04_comprobacion_auditoria_ia.txt` |
| REQ-10 | WHEN se corre la verificación, THE SYSTEM SHALL mostrar 0 privilegios de más y 0 de menos respecto de esta spec. | `A_03_verificacion_permisos.txt` |
| REQ-11 | IF `admin_datos` intenta insertar, modificar o borrar filas de `auditoria_seguridad` o `auditoria_precio`, THEN THE SYSTEM SHALL rechazarlo; los registros los escriben solo las funciones `SECURITY DEFINER`. | `A_03`, `A_04_comprobacion_auditoria_ia.txt` |
