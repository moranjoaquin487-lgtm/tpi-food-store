// U7 · Pruebas de laboratorio para contrastar afirmaciones de la IA (consigna 7)
// Uso: mongosh "mongodb://localhost:27017" --file pruebas_integridad_mongodb.js
// Cada prueba inserta un documento de prueba y lo borra al final.

db = db.getSiblingDB('foodstore');
const idEjemplo = db.pedidos.findOne({ _id: { $gt: 0 } })._id;
const base = db.pedidos.findOne({ _id: idEjemplo }, { _id: 0 });

print('== 1. ¿Hay integridad referencial? Línea con un id_producto que no existe en ningún lado');
try {
  db.pedidos.insertOne({ ...base, _id: -10, lineas: [{ ...base.lineas[0], id_producto: 999999999, producto: 'No existe' }] });
  print('  ACEPTADO: MongoDB no verifica que id_producto exista (no hay claves foráneas)');
} catch (e) { print(`  Rechazado: ${e.codeName || e.message}`); }

print('== 2. ¿El validador controla la regla R1 (total = suma de las líneas)?');
try {
  db.pedidos.insertOne({ ...base, _id: -11, total: Decimal128.fromString('1.00') });
  print('  ACEPTADO: $jsonSchema valida tipos y rangos de cada campo, no relaciones entre campos');
} catch (e) { print(`  Rechazado: ${e.codeName || e.message}`); }

print('== 3. ¿El validador controla la regla R2 (cantidad > 0)?');
try {
  db.pedidos.insertOne({ ...base, _id: -12, lineas: [{ ...base.lineas[0], cantidad: 0 }] });
  print('  ACEPTADO (no debería)');
} catch (e) { print(`  Rechazado: ${e.codeName || e.message}`); }

print('== 4. Leer un pedido completo: una sola operación, sin joins');
const t0 = Date.now();
for (let i = 0; i < 200; i++) db.pedidos.findOne({ _id: idEjemplo });
print(`  200 lecturas de un pedido completo con findOne: ${Date.now() - t0} ms en total`);

db.pedidos.deleteMany({ _id: { $in: [-10, -11, -12] } });
print(`Documentos de prueba borrados. Total en la colección: ${db.pedidos.countDocuments()}`);
