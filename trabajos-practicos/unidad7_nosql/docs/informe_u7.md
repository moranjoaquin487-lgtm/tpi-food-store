# TP Unidad 7 — Food Store en MongoDB: pedidos y detalle

**Moran, Joaquín Leandro** · Repositorio: `moranjoaquin487-lgtm/tpi-food-store`, carpeta `trabajos-practicos/unidad7_nosql`

## 1. Modelo documental y migración

### Origen en PostgreSQL

| Tabla | Clave primaria | Claves foráneas | Qué aporta al documento |
|---|---|---|---|
| `pedido` | `id_pedido` | `id_cliente` → `cliente` | fecha, estado, forma de pago |
| `detalle_pedido` | `id_detalle` (y `UNIQUE (id_pedido, id_producto)`) | `id_pedido` → `pedido`, `id_producto` → `producto` | cantidad y precio histórico de cada línea |
| `cliente` | `id_cliente` | — | nombre y apellido |
| `producto` / `categoria` | `id_producto` / `id_categoria` | `id_categoria` → `categoria` | nombre del producto y de la categoría |

El esquema no tenía estado de pedido. Se agregó la columna `estado` (`PENDIENTE`, `CONFIRMADO`, `ENTREGADO`, `CANCELADO`) en `01_estado_pedido.sql`, porque la consigna trabaja con él.

### Colección `foodstore.pedidos`

```text
{
  _id: 2,                                 ← id_pedido (se conserva)
  fecha: ISODate("2026-08-03T21:40:00Z"),
  estado: "ENTREGADO",
  forma_pago: "TARJETA",
  cliente: {                              ← objeto embebido
    id_cliente: 2, nombre: "Bruno", apellido: "Salinas"
  },
  lineas: [                               ← arreglo embebido
    { id_detalle: 3, id_producto: 3, producto: "Agua mineral 2L", categoria: "Bebidas",
      cantidad: 3, precio_unitario: Decimal128("1400.00"), subtotal: Decimal128("4200.00") },
    …
  ],
  total: Decimal128("…"),                 ← calculado al migrar
  origen: { motor: "postgresql", tablas: [ … ] }
}
```

**Identificadores conservados:** `_id` = `id_pedido`, `cliente.id_cliente`, `lineas[].id_detalle` y `lineas[].id_producto`. Así, cada documento se puede rastrear hasta su fila de origen.

**Migración:**

1. `02_exportar_pedidos.sql` arma el JSON en PostgreSQL. El subconjunto son los pedidos con al menos un producto del catálogo semilla: 62 pedidos, con todas sus líneas.
2. `cargar_mongodb.js` lo carga con `insertMany()`.
3. Los importes viajan como texto y se guardan como `Decimal128`, para no perder centavos en un `double`.

Evidencia: `evidencias/carga_mongodb.txt` (62 documentos insertados).

### Reglas de integridad que se conservan

- **R1. El total es la suma de las líneas, al centavo.** Se controla en la carga, con aritmética entera en centavos. Si un solo documento no cumple, no se carga ninguno.
- **R2. Toda línea tiene cantidad entera mayor que 0 y precio mayor o igual que 0, y todo pedido tiene al menos una línea.** La hace cumplir el validador `$jsonSchema` de la colección, también en las inserciones futuras. La prueba con cantidad 0 fue rechazada.

### Qué se embebió y qué no

Se embebieron las **líneas**. Solo existen dentro de su pedido (es una composición), siempre se leen junto con él y su precio es el **histórico de la venta**: no tiene que cambiar si después cambia el precio del producto. Ese es justamente el caso donde copiar el dato es correcto.

Del **cliente** se embebieron solo `id`, nombre y apellido, como foto del momento de la venta. El mail y el teléfono no hacen falta para mostrar un pedido.

**No** se embebieron el **stock** ni el **precio actual** del producto. Cambian con cada venta y los comparten todos los pedidos: copiarlos en cada documento obligaría a actualizar muchos documentos por cada cambio. Siguen en PostgreSQL.

## 2. Consultas y verificación

`consultas_mongodb.js` y `consultas_postgresql.sql`. Salidas: `evidencias/consultas_mongodb.txt` y `evidencias/consultas_postgresql.txt`.

| Consulta | Filtro en MongoDB | Resultado |
|---|---|---|
| a) Todos los pedidos | `find({}, {_id: 1, estado: 1})` | 62 pedidos |
| b) Por estado | `find({estado: "CANCELADO"})` | 10 pedidos |
| c) Con un producto | `find({"lineas.producto": "Yerba mate 1kg"})`, con proyección `$elemMatch` | 9 pedidos |
| d) Total superior al umbral | `find({total: {$gt: umbral}})` | 21 pedidos sobre un umbral de $ 10.928,97 |

**Umbral de d):** el ticket promedio del subconjunto migrado, calculado con `$avg` y redondeado a centavos. Separa los pedidos más grandes que lo habitual y se recalcula si cambian los datos, en lugar de ser un número elegido a ojo. PostgreSQL usa el mismo criterio: `ROUND(AVG(total), 2)`.

**Tabla de verificación**, generada por `verificar_consultas.sh` (`evidencias/tabla_verificacion.md`):

| Consulta | Cantidad en PostgreSQL | Cantidad en MongoDB | Coinciden los IDs |
|---|--:|--:|:-:|
| Estado seleccionado (CANCELADO) | 10 | 10 | Sí |
| Producto seleccionado (Yerba mate 1kg) | 9 | 9 | Sí |

**Diferencias:** ninguna. Coincidieron las cantidades y los IDs, y también la consulta d): 21 pedidos sobre $ 10.928,97 en los dos motores. La diferencia que puede aparecer es la deriva. La vista `v_pedidos_migrados_mongo` se recalcula en cada consulta: si se crea un pedido nuevo con un producto semilla después de exportar, PostgreSQL lo cuenta y MongoDB no. La corrección es exportar de nuevo, o filtrar en PostgreSQL por los IDs que se exportaron.

## 3. Evaluación de la tecnología e IA

**Prompt:** `prompts/comparacion_ia.md`. Menciona el modelo actual, el acceso frecuente a pedidos completos y la coherencia de cantidades y precios. La respuesta completa está en `docs/respuestas_ia/comparacion.md`.

**Contraste de dos afirmaciones:**

| Afirmación de la IA | Contraste | ¿Se sostiene? |
|---|---|---|
| «Posible con transacciones multi-documento (requiere replica set)» | `pruebas_afirmaciones_ia.js` (`evidencias/pruebas_afirmaciones_ia.txt`): mi servidor es standalone y la transacción falló con *This MongoDB deployment does not support retryable writes*. La documentación de transacciones también pide replica set o cluster: https://www.mongodb.com/docs/manual/core/transactions/ | **Sí.** Para una venta atómica en MongoDB habría que montar un replica set, aunque sea de un solo nodo. Es otro costo operativo a favor de quedarse en PostgreSQL |
| «`$jsonSchema` solo valida tipo/rango por campo; no puede expresar la suma. Queda a cargo de la aplicación» | La prueba 2 de `pruebas_integridad_mongodb.js` confirma la primera parte: `$jsonSchema` aceptó un total de 1.00. Pero `pruebas_afirmaciones_ia.js` creó un validador con `$expr` que compara `total` con la suma de `cantidad × precio_unitario`: aceptó el pedido real (4 líneas, $ 6851.78) y **rechazó** el de total 1.00. Es una función documentada: https://www.mongodb.com/docs/manual/core/schema-validation/specify-query-expression-rules/ | **A medias.** Sobre `$jsonSchema` es cierto, pero la conclusión es falsa: el motor puede hacer cumplir R1 con `$expr`, sin dejarlo a la aplicación. Lo que sigue sin tener MongoDB es integridad referencial entre colecciones, ni un control del stock que comparten todos los pedidos |

Resultados de laboratorio disponibles (`evidencias/pruebas_integridad.txt`):

- MongoDB aceptó una línea con un `id_producto` inexistente: no hay claves foráneas.
- `$jsonSchema` aceptó un total que no es la suma de las líneas: no valida relaciones entre campos.
- Rechazó la cantidad 0.
- 200 lecturas del pedido completo tardaron 240 ms en total.

## 4. Conclusión

> Borrador: revisalo y ajustalo con tu propio criterio antes de entregar (hasta 200 palabras).

Conviene **mantener PostgreSQL** como fuente de verdad de los pedidos, por dos criterios:

1. **Coherencia transaccional.** Registrar una venta toca el pedido, sus líneas y el stock de varios productos en una sola transacción, con triggers que impiden vender sin stock. En MongoDB, el stock quedaría en otra colección. Habría que usar transacciones de varios documentos y reprogramar en la aplicación los controles que hoy hace el motor. El laboratorio mostró además que MongoDB acepta productos inexistentes y totales incoherentes si la aplicación no los controla.
2. **Patrón de acceso.** Leer un pedido completo es más simple en un documento, con una sola operación y sin joins. Pero en Food Store ese acceso ya se resuelve con índices sobre `id_pedido`, y el volumen no justifica un segundo motor que habría que sincronizar.

Si en el futuro hiciera falta una vista documental, por ejemplo un historial de pedidos para la aplicación, la opción más económica es combinar: PostgreSQL como fuente y MongoDB, o una columna `JSONB` en el propio PostgreSQL, como copia de solo lectura regenerable.
