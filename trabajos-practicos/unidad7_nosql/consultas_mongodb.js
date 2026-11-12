// U7 · Consultas documentales sobre foodstore.pedidos
// Uso: mongosh "mongodb://localhost:27017" --file consultas_mongodb.js

db = db.getSiblingDB('foodstore');

const ESTADO = 'CANCELADO';          // existe en los datos migrados (ver la consulta a)
const PRODUCTO = 'Yerba mate 1kg';   // producto del catálogo semilla

print('== a) Todos los pedidos, con su identificador y estado');
const a = db.pedidos.find({}, { _id: 1, estado: 1 }).sort({ _id: 1 }).toArray();
a.forEach((p) => print(`${p._id}\t${p.estado}`));
print(`Cantidad: ${a.length}`);
print('Pedidos por estado:');
printjson(db.pedidos.aggregate([{ $group: { _id: '$estado', pedidos: { $sum: 1 } } }, { $sort: { _id: 1 } }]).toArray());

print(`\n== b) Pedidos en estado ${ESTADO}`);
const b = db.pedidos.find({ estado: ESTADO }, { _id: 1, estado: 1, fecha: 1 }).sort({ _id: 1 }).toArray();
b.forEach((p) => print(`${p._id}\t${p.estado}\t${p.fecha.toISOString()}`));
print(`Cantidad: ${b.length}   IDs: ${JSON.stringify(b.map((p) => p._id))}`);

print(`\n== c) Pedidos que contienen el producto "${PRODUCTO}" en el arreglo de líneas`);
const c = db.pedidos.find({ 'lineas.producto': PRODUCTO },
                          { _id: 1, estado: 1, lineas: { $elemMatch: { producto: PRODUCTO } } })
                    .sort({ _id: 1 }).toArray();
c.forEach((p) => print(`${p._id}\t${p.estado}\tcantidad=${p.lineas[0].cantidad}\tprecio=${p.lineas[0].precio_unitario}`));
print(`Cantidad: ${c.length}   IDs: ${JSON.stringify(c.map((p) => p._id))}`);

print('\n== d) Pedidos con total superior al ticket promedio del subconjunto migrado');
// Umbral: el promedio de los totales. Separa los pedidos "más grandes que lo habitual"
// y se recalcula con los datos, en vez de ser un número elegido a ojo.
const [{ promedio }] = db.pedidos.aggregate([{ $group: { _id: null, promedio: { $avg: '$total' } } }]).toArray();
const umbral = Decimal128.fromString(Number(promedio.toString()).toFixed(2));
print(`Umbral (promedio de total, redondeado a centavos): ${umbral}`);
const d = db.pedidos.find({ total: { $gt: umbral } }, { _id: 1, total: 1 }).sort({ total: -1 }).toArray();
d.forEach((p) => print(`${p._id}\ttotal=${p.total}`));
print(`Cantidad: ${d.length}   IDs: ${JSON.stringify(d.map((p) => p._id).sort((x, y) => x - y))}`);
