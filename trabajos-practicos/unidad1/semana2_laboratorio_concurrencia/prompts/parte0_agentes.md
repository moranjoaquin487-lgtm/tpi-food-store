# Parte 0 — Pedidos a OpenCode y Kiro

Texto exacto que se les pasó a los agentes para dejar el repositorio listo. Los dos se abren sobre esta carpeta.

## OpenCode

**1. Comando `/init`** (modo Build). Genera `AGENTS.md` describiendo el repositorio.

**2. Reglas del protocolo** (modo Build, después de revisar el `AGENTS.md` generado):

```text
Agregá al final de AGENTS.md una sección "Reglas para agentes" que resuma protocolo_seguridad.md:
- No ejecutes psql ni ningún otro comando contra la base de datos: los scripts los corro yo.
- En los archivos .sql que generes no escribas BEGIN, COMMIT ni ROLLBACK: la transacción la abren los scripts de la carpeta scripts/.
- Antes de escribir cualquier archivo, proponé un plan y esperá mi confirmación.
- Comentarios y mensajes de error en español.
No cambies nada más del archivo.
```

## Kiro

**1. Steering base.** En la versión de Kiro que usé: panel de Kiro → sección *Agent Steering & Skills* → **+** → *Project steering files*. Crea `product.md`, `tech.md` y `structure.md` en `.kiro/steering/`.

**2. Convenciones del esquema** (chat de Kiro):

```text
Creá el archivo .kiro/steering/esquema.md con las convenciones del esquema, sacadas de food-store/schema.sql:
- Nombres de tablas y columnas: tabla en singular y snake_case, clave primaria id con GENERATED ALWAYS AS IDENTITY, clave foránea <tabla>_id; detalle_pedido tiene clave compuesta (pedido_id, producto_id).
- Baja lógica: categoria y producto se dan de baja con activo = FALSE y nunca se borran; por eso las claves foráneas que apuntan a ellas usan ON DELETE RESTRICT.
- El tipo ENUM tipo_forma_pago y sus tres valores.
- Lo que explican los comentarios de cada tabla (reglas R1 a R7).
Solo lo que está en el archivo: no agregues convenciones que el esquema no tenga.
```

**3. Corrección** (chat de Kiro, después de comparar los cuatro archivos con `schema.sql`, `data.sql` y el README):

```text
Corregí tres errores en los steering docs, sin cambiar nada más:
1. En product.md, la Parte 3 no es sobre concurrencia: es la lectura crítica de dos scripts peligrosos (docs/ejercicio_lectura_critica.md y food-store/lectura_critica_demo.sql). Corregí esa línea.
2. En structure.md, data.sql no tiene 5 pedidos: tiene 7. Los pedidos 1 a 5 son la planilla del TP1. Corregí esa línea.
3. En esquema.md falta R3: según el comentario de schema.sql, detalle_pedido es la entidad asociativa de la relación N:M entre pedido y producto (R3). Agregalo en la sección de detalle_pedido.
```
