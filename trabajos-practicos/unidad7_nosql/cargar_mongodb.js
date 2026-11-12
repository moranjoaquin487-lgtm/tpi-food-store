// U7 · Carga de los pedidos exportados desde PostgreSQL en MongoDB
// Uso (desde esta carpeta): mongosh "mongodb://localhost:27017" --file cargar_mongodb.js
// Con Atlas: mongosh "mongodb+srv://..." --file cargar_mongodb.js
//
// Reglas de integridad que se conservan en la migración:
//   R1. total = suma de cantidad × precio_unitario de sus líneas, al centavo.
//       Se controla antes de insertar: si un documento no cumple, no se carga ninguno.
//   R2. Cada línea tiene cantidad entera > 0 y precio_unitario >= 0, y todo pedido tiene
//       al menos una línea. Lo hace cumplir el validador $jsonSchema de la colección,
//       también para lo que se inserte después.

const fs = require('fs');

db = db.getSiblingDB('foodstore');

const ESTADOS = ['PENDIENTE', 'CONFIRMADO', 'ENTREGADO', 'CANCELADO'];
const FORMAS_PAGO = ['EFECTIVO', 'TARJETA', 'TRANSFERENCIA'];

// '2200.00' -> 220000 centavos, sin pasar por punto flotante
function centavos(texto) {
  const [entero, dec = ''] = texto.split('.');
  return parseInt(entero, 10) * 100 + parseInt((dec + '00').slice(0, 2), 10);
}
const dinero = (texto) => Decimal128.fromString(texto);

const origen = JSON.parse(fs.readFileSync('pedidos_export.json', 'utf8'));
print(`Documentos leídos de pedidos_export.json: ${origen.length}`);

// R1: control del total antes de convertir nada
const errores = origen.filter((p) =>
  p.lineas.reduce((s, l) => s + l.cantidad * centavos(l.precio_unitario), 0) !== centavos(p.total));
if (errores.length > 0) {
  throw new Error(`R1 no se cumple en los pedidos ${errores.map((p) => p._id).join(', ')}: no se carga nada`);
}

const documentos = origen.map((p) => ({
  _id: p._id,                                   // id_pedido de PostgreSQL
  fecha: new Date(p.fecha),
  estado: p.estado,
  forma_pago: p.forma_pago,
  cliente: p.cliente,                           // objeto embebido: id_cliente, nombre, apellido
  lineas: p.lineas.map((l) => ({                // arreglo embebido: las líneas del pedido
    id_detalle: l.id_detalle,
    id_producto: l.id_producto,
    producto: l.producto,
    categoria: l.categoria,
    cantidad: l.cantidad,
    precio_unitario: dinero(l.precio_unitario), // precio histórico de la venta
    subtotal: dinero(l.subtotal),
  })),
  total: dinero(p.total),
  origen: { motor: 'postgresql', tablas: ['pedido', 'detalle_pedido', 'cliente', 'producto', 'categoria'] },
}));

db.pedidos.drop();
db.createCollection('pedidos', {
  validator: {
    $jsonSchema: {
      bsonType: 'object',
      required: ['_id', 'fecha', 'estado', 'forma_pago', 'cliente', 'lineas', 'total'],
      properties: {
        _id: { bsonType: ['int', 'long'] },
        fecha: { bsonType: 'date' },
        estado: { enum: ESTADOS },
        forma_pago: { enum: FORMAS_PAGO },
        cliente: { bsonType: 'object', required: ['id_cliente', 'nombre', 'apellido'] },
        lineas: {
          bsonType: 'array',
          minItems: 1,
          items: {
            bsonType: 'object',
            required: ['id_producto', 'cantidad', 'precio_unitario'],
            properties: {
              cantidad: { bsonType: ['int', 'long'], minimum: 1 },
              precio_unitario: { bsonType: 'decimal', minimum: 0 },
            },
          },
        },
        total: { bsonType: 'decimal', minimum: 0 },
      },
    },
  },
  validationAction: 'error',
});

const r = db.pedidos.insertMany(documentos, { ordered: true });
print(`Documentos insertados: ${Object.keys(r.insertedIds).length}`);

db.pedidos.createIndex({ estado: 1 });
db.pedidos.createIndex({ 'lineas.id_producto': 1 });
db.pedidos.createIndex({ total: -1 });

print('Validador: un documento con cantidad 0 tiene que ser rechazado');
try {
  db.pedidos.insertOne({ ...documentos[0], _id: -1, lineas: [{ ...documentos[0].lineas[0], cantidad: 0 }] });
  print('  ERROR: se aceptó un documento inválido');
} catch (e) {
  print(`  Rechazado como se esperaba: ${e.codeName || e.message}`);
}
db.pedidos.deleteOne({ _id: -1 });   // por si el validador no estuviera activo

print(`Total en la colección: ${db.pedidos.countDocuments()}`);
printjson(db.pedidos.findOne({}, { lineas: { $slice: 2 } }));
