# PostgreSQL vs MongoDB para pedidos de Food Store

> Exportación de la sesión de OpenCode (agente Plan, modelo Big Pickle) con `/export`, sin cambios salvo una: se quitaron las dos líneas del encabezado con la fecha y la hora. Ojo al leerla: antes de responder, OpenCode abrió `docs/informe_u7.md`, que ya tenía el borrador de la conclusión, y lo cita al final. El contraste de dos de sus afirmaciones está en `pruebas_afirmaciones_ia.js` y en la sección 3 de `../informe_u7.md`.

**Session ID:** ses_e2faf8eb7ffeIXzKWIdqV4E9wM

---

## User

Tengo un sistema de pedidos, Food Store, en PostgreSQL 16. El modelo actual es relacional:
pedido (id, fecha, estado, forma_pago, id_cliente) y detalle_pedido (id_pedido, id_producto,
cantidad, precio_unitario), con producto (precio, stock), categoria y cliente. Los
triggers controlan el stock y la integridad, y las ventas se registran en transacciones.
El acceso más frecuente es leer un pedido completo, con sus líneas y los datos del
cliente. Hay que conservar la coherencia de cantidades y precios: el precio de cada línea
es el histórico de la venta y el stock no puede quedar negativo.
Compará PostgreSQL y MongoDB para almacenar y consultar estos pedidos. ¿Conviene mantener
PostgreSQL, usar MongoDB para los pedidos o combinar las dos? Justificá con criterios técnicos. 

---

## Assistant (Plan · Big Pickle · 14.9s)

_Thinking:_

The user asks a comparative technical analysis question (in Spanish) about PostgreSQL vs MongoDB for a food store ordering system. This is an academic/exam-style question. Plan mode is active - read-only. But this is not really a coding task; it's asking for an analysis/recommendation. I should check if there's context in the repo (unidad7_nosql) maybe a practice statement. Let me look at the working directory to see if there's relevant material.

I should likely give an answer directly rather than a "plan" but I can explore the repo quickly for context. Let me list files.

**Tool: bash**

**Input:**
```json
{
  "command": "Get-ChildItem -Force | Select-Object Name,Length,LastWriteTime",
  "workdir": "C:\\Users\\moran\\BD2\\tpi-food-store\\trabajos-practicos\\unidad7_nosql"
}
```

**Output:**
```

Name                          Length LastWriteTime      
----                          ------ -------------      
docs                                 12/11/2026 01:40:56
evidencias                           12/11/2026 11:14:52
prompts                              12/11/2026 01:40:56
01_estado_pedido.sql          1078   12/11/2026 01:40:56
02_exportar_pedidos.sql       3465   12/11/2026 01:40:56
cargar_mongodb.js             4187   12/11/2026 01:40:56
consultas_mongodb.js          2288   12/11/2026 01:40:56
consultas_postgresql.sql      2065   12/11/2026 01:40:56
pedidos_export.json           69794  12/11/2026 11:14:46
pruebas_integridad_mongodb.js 1814   12/11/2026 01:40:56
README.md                     1162   12/11/2026 01:40:56
verificar_consultas.sh        2066   12/11/2026 11:12:32



```

**Tool: bash**

**Input:**
```json
{
  "command": "Get-ChildItem -Force -Recurse -Depth 2 | Select-Object FullName | Select-Object -First 100",
  "workdir": "C:\\Users\\moran\\BD2\\tpi-food-store\\trabajos-practicos\\unidad7_nosql"
}
```

**Output:**
```

FullName                                                                                              
--------                                                                                              
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\docs                               
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\evidencias                         
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\prompts                            
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\01_estado_pedido.sql               
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\02_exportar_pedidos.sql            
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\cargar_mongodb.js                  
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\consultas_mongodb.js               
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\consultas_postgresql.sql           
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\pedidos_export.json                
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\pruebas_integridad_mongodb.js      
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\README.md                          
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\verificar_consultas.sh             
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\docs\informe_u7.md                 
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\evidencias\01_estado_pedido.txt    
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\evidencias\02_exportar_pedidos.txt 
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\evidencias\carga_mongodb.txt       
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\evidencias\consultas_mongodb.txt   
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\evidencias\consultas_postgresql.txt
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\evidencias\pruebas_integridad.txt  
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\evidencias\tabla_verificacion.md   
C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\prompts\comparacion_ia.md          



```

---

## Assistant (Plan · Big Pickle · 5.1s)

_Thinking:_

There's an existing report (docs/informe_u7.md) which might contain the analysis. Let me read it, plus README and the code files to tailor the answer to their actual system.

**Tool: read**

**Input:**
```json
{
  "filePath": "C:\\Users\\moran\\BD2\\tpi-food-store\\trabajos-practicos\\unidad7_nosql\\docs\\informe_u7.md"
}
```

**Output:**
```
<path>C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\docs\informe_u7.md</path>
<type>file</type>
<content>
1: # TP Unidad 7 — Food Store en MongoDB: pedidos y detalle
2: 
3: **Moran, Joaquín Leandro** · Repositorio: `moranjoaquin487-lgtm/tpi-food-store`, carpeta `trabajos-practicos/unidad7_nosql`
4: 
5: ## 1. Modelo documental y migración
6: 
7: ### Origen en PostgreSQL
8: 
9: | Tabla | Clave primaria | Claves foráneas | Qué aporta al documento |
10: |---|---|---|---|
11: | `pedido` | `id_pedido` | `id_cliente` → `cliente` | fecha, estado, forma de pago |
12: | `detalle_pedido` | `id_detalle` (y `UNIQUE (id_pedido, id_producto)`) | `id_pedido` → `pedido`, `id_producto` → `producto` | cantidad y precio histórico de cada línea |
13: | `cliente` | `id_cliente` | — | nombre y apellido |
14: | `producto` / `categoria` | `id_producto` / `id_categoria` | `id_categoria` → `categoria` | nombre del producto y de la categoría |
15: 
16: El esquema no tenía estado de pedido. Se agregó la columna `estado` (`PENDIENTE`, `CONFIRMADO`, `ENTREGADO`, `CANCELADO`) en `01_estado_pedido.sql`, porque la consigna trabaja con él.
17: 
18: ### Colección `foodstore.pedidos`
19: 
20: ```text
21: {
22:   _id: 2,                                 ← id_pedido (se conserva)
23:   fecha: ISODate("2026-08-03T21:40:00Z"),
24:   estado: "ENTREGADO",
25:   forma_pago: "TARJETA",
26:   cliente: {                              ← objeto embebido
27:     id_cliente: 2, nombre: "Bruno", apellido: "Salinas"
28:   },
29:   lineas: [                               ← arreglo embebido
30:     { id_detalle: 3, id_producto: 3, producto: "Agua mineral 2L", categoria: "Bebidas",
31:       cantidad: 3, precio_unitario: Decimal128("1400.00"), subtotal: Decimal128("4200.00") },
32:     …
33:   ],
34:   total: Decimal128("…"),                 ← calculado al migrar
35:   origen: { motor: "postgresql", tablas: [ … ] }
36: }
37: ```
38: 
39: **Identificadores conservados:** `_id` = `id_pedido`, `cliente.id_cliente`, `lineas[].id_detalle` y `lineas[].id_producto`. Así, cada documento se puede rastrear hasta su fila de origen.
40: 
41: **Migración:**
42: 
43: 1. `02_exportar_pedidos.sql` arma el JSON en PostgreSQL. El subconjunto son los pedidos con al menos un producto del catálogo semilla: 62 pedidos, con todas sus líneas.
44: 2. `cargar_mongodb.js` lo carga con `insertMany()`.
45: 3. Los importes viajan como texto y se guardan como `Decimal128`, para no perder centavos en un `double`.
46: 
47: Evidencia: `evidencias/carga_mongodb.txt` (62 documentos insertados).
48: 
49: ### Reglas de integridad que se conservan
50: 
51: - **R1. El total es la suma de las líneas, al centavo.** Se controla en la carga, con aritmética entera en centavos. Si un solo documento no cumple, no se carga ninguno.
52: - **R2. Toda línea tiene cantidad entera mayor que 0 y precio mayor o igual que 0, y todo pedido tiene al menos una línea.** La hace cumplir el validador `$jsonSchema` de la colección, también en las inserciones futuras. La prueba con cantidad 0 fue rechazada.
53: 
54: ### Qué se embebió y qué no
55: 
56: Se embebieron las **líneas**. Solo existen dentro de su pedido (es una composición), siempre se leen junto con él y su precio es el **histórico de la venta**: no tiene que cambiar si después cambia el precio del producto. Ese es justamente el caso donde copiar el dato es correcto.
57: 
58: Del **cliente** se embebieron solo `id`, nombre y apellido, como foto del momento de la venta. El mail y el teléfono no hacen falta para mostrar un pedido.
59: 
60: **No** se embebieron el **stock** ni el **precio actual** del producto. Cambian con cada venta y los comparten todos los pedidos: copiarlos en cada documento obligaría a actualizar muchos documentos por cada cambio. Siguen en PostgreSQL.
61: 
62: ## 2. Consultas y verificación
63: 
64: `consultas_mongodb.js` y `consultas_postgresql.sql`. Salidas: `evidencias/consultas_mongodb.txt` y `evidencias/consultas_postgresql.txt`.
65: 
66: | Consulta | Filtro en MongoDB | Resultado |
67: |---|---|---|
68: | a) Todos los pedidos | `find({}, {_id: 1, estado: 1})` | 62 pedidos |
69: | b) Por estado | `find({estado: "CANCELADO"})` | 10 pedidos |
70: | c) Con un producto | `find({"lineas.producto": "Yerba mate 1kg"})`, con proyección `$elemMatch` | 9 pedidos |
71: | d) Total superior al umbral | `find({total: {$gt: umbral}})` | 21 pedidos sobre un umbral de $ 10.928,97 |
72: 
73: **Umbral de d):** el ticket promedio del subconjunto migrado, calculado con `$avg` y redondeado a centavos. Separa los pedidos más grandes que lo habitual y se recalcula si cambian los datos, en lugar de ser un número elegido a ojo. PostgreSQL usa el mismo criterio: `ROUND(AVG(total), 2)`.
74: 
75: **Tabla de verificación**, generada por `verificar_consultas.sh` (`evidencias/tabla_verificacion.md`):
76: 
77: | Consulta | Cantidad en PostgreSQL | Cantidad en MongoDB | Coinciden los IDs |
78: |---|--:|--:|:-:|
79: | Estado seleccionado (CANCELADO) | 10 | 10 | Sí |
80: | Producto seleccionado (Yerba mate 1kg) | 9 | 9 | Sí |
81: 
82: **Diferencias:** ninguna. Coincidieron las cantidades y los IDs, y también la consulta d): 21 pedidos sobre $ 10.928,97 en los dos motores. La diferencia que puede aparecer es la deriva. La vista `v_pedidos_migrados_mongo` se recalcula en cada consulta: si se crea un pedido nuevo con un producto semilla después de exportar, PostgreSQL lo cuenta y MongoDB no. La corrección es exportar de nuevo, o filtrar en PostgreSQL por los IDs que se exportaron.
83: 
84: ## 3. Evaluación de la tecnología e IA
85: 
86: **Prompt:** `prompts/comparacion_ia.md`. Menciona el modelo actual, el acceso frecuente a pedidos completos y la coherencia de cantidades y precios. La respuesta completa está en `docs/respuestas_ia/comparacion.md`.
87: 
88: **Contraste de dos afirmaciones:**
89: 
90: | Afirmación de la IA | Contraste | ¿Se sostiene? |
91: |---|---|---|
92: | [completar: afirmación 1, citada] | [completar: resultado de `pruebas_integridad_mongodb.js` o enlace a la documentación oficial] | [completar] |
93: | [completar: afirmación 2, citada] | [completar] | [completar] |
94: 
95: Resultados de laboratorio disponibles (`evidencias/pruebas_integridad.txt`):
96: 
97: - MongoDB aceptó una línea con un `id_producto` inexistente: no hay claves foráneas.
98: - `$jsonSchema` aceptó un total que no es la suma de las líneas: no valida relaciones entre campos.
99: - Rechazó la cantidad 0.
100: - 200 lecturas del pedido completo tardaron 240 ms en total.
101: 
102: ## 4. Conclusión
103: 
104: > Borrador: revisalo y ajustalo con tu propio criterio antes de entregar (hasta 200 palabras).
105: 
106: Conviene **mantener PostgreSQL** como fuente de verdad de los pedidos, por dos criterios:
107: 
108: 1. **Coherencia transaccional.** Registrar una venta toca el pedido, sus líneas y el stock de varios productos en una sola transacción, con triggers que impiden vender sin stock. En MongoDB, el stock quedaría en otra colección. Habría que usar transacciones de varios documentos y reprogramar en la aplicación los controles que hoy hace el motor. El laboratorio mostró además que MongoDB acepta productos inexistentes y totales incoherentes si la aplicación no los controla.
109: 2. **Patrón de acceso.** Leer un pedido completo es más simple en un documento, con una sola operación y sin joins. Pero en Food Store ese acceso ya se resuelve con índices sobre `id_pedido`, y el volumen no justifica un segundo motor que habría que sincronizar.
110: 
111: Si en el futuro hiciera falta una vista documental, por ejemplo un historial de pedidos para la aplicación, la opción más económica es combinar: PostgreSQL como fuente y MongoDB, o una columna `JSONB` en el propio PostgreSQL, como copia de solo lectura regenerable.

(End of file - total 111 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "C:\\Users\\moran\\BD2\\tpi-food-store\\trabajos-practicos\\unidad7_nosql\\README.md"
}
```

**Output:**
```
<path>C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\README.md</path>
<type>file</type>
<content>
1: # Unidad 7 — NoSQL: pedidos de Food Store en MongoDB
2: 
3: - **Alumno:** Moran, Joaquín Leandro
4: 
5: | Consigna | Archivo |
6: |---|---|
7: | Estado del pedido (faltaba en el esquema) | `01_estado_pedido.sql` |
8: | 1–2 Modelo y migración (`insertMany`) | `02_exportar_pedidos.sql` → `pedidos_export.json` → `cargar_mongodb.js` |
9: | 3 Reglas de integridad y qué se embebió | `cargar_mongodb.js` (control de R1 y validador `$jsonSchema`), informe sección 1 |
10: | 4 Consultas a–d en MongoDB | `consultas_mongodb.js` |
11: | 5 Equivalentes en PostgreSQL y tabla de verificación | `consultas_postgresql.sql`, `verificar_consultas.sh` → `evidencias/tabla_verificacion.md` |
12: | 6–7 Comparación con IA y contraste | `prompts/comparacion_ia.md`, `pruebas_integridad_mongodb.js`, `docs/respuestas_ia/comparacion.md` |
13: | Informe (hasta 5 páginas) | `docs/informe_u7.pdf` (fuente: `docs/informe_u7.md`) |
14: 
15: **Orden:**
16: 
17: 1. `ejecutar_segunda_entrega.sh` corre `01` y `02` y, si encuentra `mongosh`, también la carga, las consultas, las pruebas y la verificación.
18: 2. A mano: `mongosh --file cargar_mongodb.js`, `mongosh --file consultas_mongodb.js` y `./verificar_consultas.sh`.

(End of file - total 18 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "C:\\Users\\moran\\BD2\\tpi-food-store\\trabajos-practicos\\unidad7_nosql\\cargar_mongodb.js"
}
```

**Output:**
```
<path>C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\cargar_mongodb.js</path>
<type>file</type>
<content>
1: // U7 · Carga de los pedidos exportados desde PostgreSQL en MongoDB
2: // Uso (desde esta carpeta): mongosh "mongodb://localhost:27017" --file cargar_mongodb.js
3: // Con Atlas: mongosh "mongodb+srv://..." --file cargar_mongodb.js
4: //
5: // Reglas de integridad que se conservan en la migración:
6: //   R1. total = suma de cantidad × precio_unitario de sus líneas, al centavo.
7: //       Se controla antes de insertar: si un documento no cumple, no se carga ninguno.
8: //   R2. Cada línea tiene cantidad entera > 0 y precio_unitario >= 0, y todo pedido tiene
9: //       al menos una línea. Lo hace cumplir el validador $jsonSchema de la colección,
10: //       también para lo que se inserte después.
11: 
12: const fs = require('fs');
13: 
14: db = db.getSiblingDB('foodstore');
15: 
16: const ESTADOS = ['PENDIENTE', 'CONFIRMADO', 'ENTREGADO', 'CANCELADO'];
17: const FORMAS_PAGO = ['EFECTIVO', 'TARJETA', 'TRANSFERENCIA'];
18: 
19: // '2200.00' -> 220000 centavos, sin pasar por punto flotante
20: function centavos(texto) {
21:   const [entero, dec = ''] = texto.split('.');
22:   return parseInt(entero, 10) * 100 + parseInt((dec + '00').slice(0, 2), 10);
23: }
24: const dinero = (texto) => Decimal128.fromString(texto);
25: 
26: const origen = JSON.parse(fs.readFileSync('pedidos_export.json', 'utf8'));
27: print(`Documentos leídos de pedidos_export.json: ${origen.length}`);
28: 
29: // R1: control del total antes de convertir nada
30: const errores = origen.filter((p) =>
31:   p.lineas.reduce((s, l) => s + l.cantidad * centavos(l.precio_unitario), 0) !== centavos(p.total));
32: if (errores.length > 0) {
33:   throw new Error(`R1 no se cumple en los pedidos ${errores.map((p) => p._id).join(', ')}: no se carga nada`);
34: }
35: 
36: const documentos = origen.map((p) => ({
37:   _id: p._id,                                   // id_pedido de PostgreSQL
38:   fecha: new Date(p.fecha),
39:   estado: p.estado,
40:   forma_pago: p.forma_pago,
41:   cliente: p.cliente,                           // objeto embebido: id_cliente, nombre, apellido
42:   lineas: p.lineas.map((l) => ({                // arreglo embebido: las líneas del pedido
43:     id_detalle: l.id_detalle,
44:     id_producto: l.id_producto,
45:     producto: l.producto,
46:     categoria: l.categoria,
47:     cantidad: l.cantidad,
48:     precio_unitario: dinero(l.precio_unitario), // precio histórico de la venta
49:     subtotal: dinero(l.subtotal),
50:   })),
51:   total: dinero(p.total),
52:   origen: { motor: 'postgresql', tablas: ['pedido', 'detalle_pedido', 'cliente', 'producto', 'categoria'] },
53: }));
54: 
55: db.pedidos.drop();
56: db.createCollection('pedidos', {
57:   validator: {
58:     $jsonSchema: {
59:       bsonType: 'object',
60:       required: ['_id', 'fecha', 'estado', 'forma_pago', 'cliente', 'lineas', 'total'],
61:       properties: {
62:         _id: { bsonType: ['int', 'long'] },
63:         fecha: { bsonType: 'date' },
64:         estado: { enum: ESTADOS },
65:         forma_pago: { enum: FORMAS_PAGO },
66:         cliente: { bsonType: 'object', required: ['id_cliente', 'nombre', 'apellido'] },
67:         lineas: {
68:           bsonType: 'array',
69:           minItems: 1,
70:           items: {
71:             bsonType: 'object',
72:             required: ['id_producto', 'cantidad', 'precio_unitario'],
73:             properties: {
74:               cantidad: { bsonType: ['int', 'long'], minimum: 1 },
75:               precio_unitario: { bsonType: 'decimal', minimum: 0 },
76:             },
77:           },
78:         },
79:         total: { bsonType: 'decimal', minimum: 0 },
80:       },
81:     },
82:   },
83:   validationAction: 'error',
84: });
85: 
86: const r = db.pedidos.insertMany(documentos, { ordered: true });
87: print(`Documentos insertados: ${Object.keys(r.insertedIds).length}`);
88: 
89: db.pedidos.createIndex({ estado: 1 });
90: db.pedidos.createIndex({ 'lineas.id_producto': 1 });
91: db.pedidos.createIndex({ total: -1 });
92: 
93: print('Validador: un documento con cantidad 0 tiene que ser rechazado');
94: try {
95:   db.pedidos.insertOne({ ...documentos[0], _id: -1, lineas: [{ ...documentos[0].lineas[0], cantidad: 0 }] });
96:   print('  ERROR: se aceptó un documento inválido');
97: } catch (e) {
98:   print(`  Rechazado como se esperaba: ${e.codeName || e.message}`);
99: }
100: db.pedidos.deleteOne({ _id: -1 });   // por si el validador no estuviera activo
101: 
102: print(`Total en la colección: ${db.pedidos.countDocuments()}`);
103: printjson(db.pedidos.findOne({}, { lineas: { $slice: 2 } }));

(End of file - total 103 lines)
</content>
```

**Tool: read**

**Input:**
```json
{
  "filePath": "C:\\Users\\moran\\BD2\\tpi-food-store\\trabajos-practicos\\unidad7_nosql\\pruebas_integridad_mongodb.js"
}
```

**Output:**
```
<path>C:\Users\moran\BD2\tpi-food-store\trabajos-practicos\unidad7_nosql\pruebas_integridad_mongodb.js</path>
<type>file</type>
<content>
1: // U7 · Pruebas de laboratorio para contrastar afirmaciones de la IA (consigna 7)
2: // Uso: mongosh "mongodb://localhost:27017" --file pruebas_integridad_mongodb.js
3: // Cada prueba inserta un documento de prueba y lo borra al final.
4: 
5: db = db.getSiblingDB('foodstore');
6: const idEjemplo = db.pedidos.findOne({ _id: { $gt: 0 } })._id;
7: const base = db.pedidos.findOne({ _id: idEjemplo }, { _id: 0 });
8: 
9: print('== 1. ¿Hay integridad referencial? Línea con un id_producto que no existe en ningún lado');
10: try {
11:   db.pedidos.insertOne({ ...base, _id: -10, lineas: [{ ...base.lineas[0], id_producto: 999999999, producto: 'No existe' }] });
12:   print('  ACEPTADO: MongoDB no verifica que id_producto exista (no hay claves foráneas)');
13: } catch (e) { print(`  Rechazado: ${e.codeName || e.message}`); }
14: 
15: print('== 2. ¿El validador controla la regla R1 (total = suma de las líneas)?');
16: try {
17:   db.pedidos.insertOne({ ...base, _id: -11, total: Decimal128.fromString('1.00') });
18:   print('  ACEPTADO: $jsonSchema valida tipos y rangos de cada campo, no relaciones entre campos');
19: } catch (e) { print(`  Rechazado: ${e.codeName || e.message}`); }
20: 
21: print('== 3. ¿El validador controla la regla R2 (cantidad > 0)?');
22: try {
23:   db.pedidos.insertOne({ ...base, _id: -12, lineas: [{ ...base.lineas[0], cantidad: 0 }] });
24:   print('  ACEPTADO (no debería)');
25: } catch (e) { print(`  Rechazado: ${e.codeName || e.message}`); }
26: 
27: print('== 4. Leer un pedido completo: una sola operación, sin joins');
28: const t0 = Date.now();
29: for (let i = 0; i < 200; i++) db.pedidos.findOne({ _id: idEjemplo });
30: print(`  200 lecturas de un pedido completo con findOne: ${Date.now() - t0} ms en total`);
31: 
32: db.pedidos.deleteMany({ _id: { $in: [-10, -11, -12] } });
33: print(`Documentos de prueba borrados. Total en la colección: ${db.pedidos.countDocuments()}`);

(End of file - total 33 lines)
</content>
```

---

## Assistant (Plan · Big Pickle · 12.9s)

_Thinking:_

The user is essentially asking the consigna 3 question: compare PostgreSQL and MongoDB, recommend. The repo already has an informe with a draft conclusion. But the user's message is a direct question, not a request to edit files. Plan mode is active. I should answer the question directly. Since plan mode says construct a plan, but this is an analytical question. I can provide the technical comparison and recommendation. No file changes.

I should be concise but this warrants detail since they asked "Justificá con criterios técnicos" — an academic answer. Let me craft a structured comparison tied to their actual model:

Key criteria:
1. Transactional coherence / integrity: multi-row transaction (pedido + detalle + stock update across products), triggers, CHECK constraints, foreign keys, non-negative stock. PostgreSQL wins strongly. MongoDB v4+ multi-document transactions exist (replica set required) but you must replicate triggers/validation in app; $jsonSchema can't enforce cross-field (total = sum lines) nor referential integrity; no CHECK on stock across collections. Lab showed it accepts nonexistent product and inconsistent total.
2. Access pattern: read complete order with lines + client — aggregate/document model better in MongoDB (1 read, no joins). But PostgreSQL with proper indexes and a couple of joins is also fast at this volume; could use JSONB or a materialized view.
3. Historical price: both handle; in Mongo embed snapshot (correct), in PG store precio_unitario in detalle (already does). Both fine.
4. Monetary precision: PG numeric vs Mongo Decimal128 — both fine; Mongo needs care (double pitfall).
5. Concurrency on stock: hot document/product rows. PostgreSQL row-level locking + atomic UPDATE ... WHERE stock >= qty returning prevents negative stock elegantly. MongoDB would need findOneAndUpdate with $inc and condition, or transactions; possible but more manual and cross-collection.
6. Reporting/analytics: joins, aggregations across products/categories/clients — PG stronger (SQL, window functions); Mongo aggregation possible but denormalization duplicates product/category names (risk of drift).
7. Schema evolution / flexibility: Mongo better for varying order attributes, but this model is stable and well-structured.
8. Operational cost: one engine vs two; sync/dual-write consistency, eventual consistency, migrations, backups, team skills. Adding Mongo only for reads = duplicating source of truth unless read-only replica.

Recommendation: keep PostgreSQL as source of truth. Optionally use JSONB for a denormalized read view (cheapest), or MongoDB as read-only projection/cache rebuilt from PG (CQRS-lite) only if read latency/scale demands it. Do not move orders wholesale to Mongo; do not dual-write as source of truth.

I can reference their files. Keep it structured. The instructions say <4 lines unless user asks for detail — user asked for a justified technical comparison, so detail is warranted. I'll use headers/tables. In Spanish.

Also mention the existing informe draft conclusion matches; maybe note the blank table in section 3 needs completion? Not asked. Keep focused.

Let me write a solid answer, maybe with a comparison table and verdict. Since plan mode, I'm not editing. Could mention "si querés lo plasmo en el informe" as next step. But don't be overly proactive. Maybe end with offer.

Let me produce the response.

## Comparación PostgreSQL vs. MongoDB para los pedidos de Food Store

### Criterios técnicos

| Criterio | PostgreSQL (actual) | MongoDB (documento `pedido` + `lineas[]`) |
|---|---|---|
| **Coherencia transaccional de la venta** | Una transacción cubre `pedido` + `detalle_pedido` + `UPDATE producto SET stock...` de varios productos. ACID nativo. | Posible con transacciones multi-documento (requiere replica set), pero el stock vive en otra colección: hay que orquestarlo desde la aplicación. |
| **Stock no negativo** | `CHECK (stock >= 0)`, `UPDATE ... WHERE stock >= :cantidad` con bloqueo de fila, o trigger. El motor lo garantiza. | Sin `CHECK` entre colecciones. Se resuelve con `findOneAndUpdate({_id, stock: {$gte: q}}, {$inc: {stock: -q}})` o transacción; si se olvida, queda stock negativo. |
| **Integridad referencial** | `FOREIGN KEY` a `cliente` y `producto`. | No existe. El laboratorio (`pruebas_integridad_mongodb.js:11`) confirma que acepta un `id_producto` inexistente. |
| **Reglas entre campos (total = Σ líneas)** | `CHECK`/trigger o cálculo en la transacción. | `$jsonSchema` solo valida tipo/rango por campo; no puede expresar la suma (`pruebas_integridad_mongodb.js:17`). Queda a cargo de la aplicación. |
| **Precio histórico por línea** | `detalle_pedido.precio_unitario` ya lo conserva. | Correcto embeberlo como snapshot en la línea (no debe seguir al precio actual del producto). |
| **Precisión monetaria** | `numeric` exacto. | `Decimal128` exacto, pero hay que evitar `double` (el loader ya lo hace). |
| **Lectura de un pedido completo** | Join `pedido`+`detalle`+`cliente`, resuelto con índices; 1 sola ida y vuelta. | Ventaja real: `findOne({_id})`, sin joins, un documento. |
| **Reportes/analítica (por producto, categoría, cliente, período)** | SQL con joins, `GROUP BY`, window functions. | `aggregate` posible, pero obliga a duplicar nombre/categoría en cada pedido → riesgo de deriva. |
| **Evolución del esquema** | Migraciones; esquema estable y ya modelado. | Flexible, pero este dominio es estable: la flexibilidad no aporta. |
| **Costo operativo** | Un solo motor, un backup, un equipo. | Segundo motor + sincronización (doble escritura o CDC), consistencia eventual, más superficie de fallo. |

### Veredicto

**Conviene mantener PostgreSQL como fuente de verdad de los pedidos.** Las dos razones decisivas son las que plantea el enunciado:

1. **Coherencia de cantidades, precios y stock**: la venta es una operación atómica que toca pedido, líneas y stock de varios productos. PostgreSQL la garantiza con transacción + FK + `CHECK`/trigger; en MongoDB esas garantías hay que reimplementarlas en la aplicación y el motor no las hace cumplir (lo demostró el laboratorio).
2. **Patrón de acceso**: leer un pedido completo es más natural en un documento, pero a este volumen ya se resuelve con índices y un join; no compensa introducir un segundo motor que sincronizar.

**No conviene migrar los pedidos en bloque a MongoDB**, porque se pierden FK, `CHECK` y atomicidad de stock a cambio de una mejora de lectura marginal.

**Combinar solo tiene sentido como proyección de lectura**, no como segunda fuente: PostgreSQL sigue siendo el origen y se publica una copia de solo lectura regenerable. La opción más económica incluso es una columna **`JSONB`** en PostgreSQL con el pedido denormalizado; MongoDB recién se justifica si el historial de pedidos crece mucho y la latencia/volumen de lectura supera lo que da un índice relacional (patrón CQRS con CDC).

Esto coincide con el borrador de conclusión en `docs/informe_u7.md:102`. ¿Querés que lo integre/ajuste en el informe y complete la tabla de contraste de la sección 3?

---

