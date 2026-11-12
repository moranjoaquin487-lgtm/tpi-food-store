# Parte D — Verificación de equivalencia de agregados

Consulta: cantidad de usuarios por rol y por mes de alta, sobre `usuario_anon` y sobre `usuario` (`sql/equivalencia_agregados.sql`).

## Resultados lado a lado

```
== Lado a lado
   rol   | mes_alta | usuarios_real | usuarios_anon | coincide 
---------+----------+---------------+---------------+----------
 USUARIO | 2026-01  |             8 |             8 | sí
 USUARIO | 2026-02  |             8 |             8 | sí
 USUARIO | 2026-03  |            34 |            34 | sí
 USUARIO | 2026-04  |             9 |             9 | sí
 USUARIO | 2026-05  |            12 |            12 | sí
 USUARIO | 2026-06  |            12 |            12 | sí
 USUARIO | 2026-07  |            12 |            12 | sí
 USUARIO | 2026-08  |            13 |            13 | sí
 USUARIO | 2026-09  |            11 |            11 | sí
 USUARIO | 2026-10  |            13 |            13 | sí
 USUARIO | 2026-11  |             2 |             2 | sí
 ADMIN   | 2026-01  |             2 |             2 | sí
 ADMIN   | 2026-02  |             3 |             3 | sí
 ADMIN   | 2026-03  |             3 |             3 | sí
 ADMIN   | 2026-04  |             3 |             3 | sí
 ADMIN   | 2026-05  |             1 |             1 | sí
 ADMIN   | 2026-11  |             1 |             1 | sí
(17 filas)

== Resumen (se espera: 0 grupos distintos y el mismo total)
 grupos_distintos | total_real | total_anon 
------------------+------------+------------
                0 |        147 |        147
(1 fila)

```

## Qué no debería salir nunca hacia un asistente de IA sin anonimizar

Los mails, nombres, apellidos y celulares de `usuario` y de `cliente`, y los hashes de `usuario.contrasena`. Tampoco las IP y los mails del log de auditoría, que están en `auditoria_seguridad` y en el log del servidor, ni cualquier volcado de `pedido` unido a `cliente`, que liga a una persona con lo que compró. Para pedirle ayuda a la IA alcanza con la estructura de las tablas (`\d usuario`) o con `usuario_anon`: los agregados dan lo mismo, como muestra la tabla de arriba.
