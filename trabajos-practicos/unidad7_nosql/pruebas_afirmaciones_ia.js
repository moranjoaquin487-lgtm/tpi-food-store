// U7 · Consigna 7 — Contraste en el laboratorio de dos afirmaciones de OpenCode
// (docs/respuestas_ia/comparacion.md). No toca la colección pedidos: usa colecciones
// temporales y las borra al final.
// Uso (desde esta carpeta): mongosh "mongodb://localhost:27017" --file pruebas_afirmaciones_ia.js
db = db.getSiblingDB('foodstore');

print('== Afirmación 1: «las transacciones multi-documento son posibles, pero requieren replica set»');
const hola = db.hello();
print(`  Este servidor: ${hola.setName ? 'replica set ' + hola.setName : 'standalone (sin replica set)'}`);
const sesion = db.getMongo().startSession();
try {
  sesion.startTransaction();
  sesion.getDatabase('foodstore').prueba_transaccion.insertOne({ x: 1 });
  sesion.commitTransaction();
  print('  La transacción se confirmó');
} catch (e) {
  print(`  La transacción falló: ${e.codeName || ''} — ${e.message}`);
  try { sesion.abortTransaction(); } catch (_) { /* ya no estaba abierta */ }
} finally {
  sesion.endSession();
}
db.prueba_transaccion.drop();

print('== Afirmación 2: «$jsonSchema no puede expresar que el total sea la suma de las líneas: queda a cargo de la aplicación»');
print('   Un validador con $expr (operadores de consulta) sí puede comparar campos:');
db.prueba_validador_expr.drop();
db.createCollection('prueba_validador_expr', {
  validator: {
    $expr: {
      $eq: ['$total', { $sum: { $map: { input: '$lineas', in: { $multiply: ['$$this.cantidad', '$$this.precio_unitario'] } } } }]
    }
  },
  validationAction: 'error'
});
const base = db.pedidos.findOne({ _id: { $gt: 0 } }, { _id: 0, lineas: 1, total: 1 });
print(`  Pedido de ejemplo: ${base.lineas.length} líneas, total ${base.total}`);
try {
  db.prueba_validador_expr.insertOne({ _id: 1, ...base });
  print('  Con el total correcto: aceptado');
} catch (e) { print(`  Con el total correcto: rechazado (${e.codeName || e.message})`); }
try {
  db.prueba_validador_expr.insertOne({ _id: 2, ...base, total: Decimal128.fromString('1.00') });
  print('  Con total = 1.00: ACEPTADO');
} catch (e) { print(`  Con total = 1.00: rechazado (${e.codeName || e.message})`); }
db.prueba_validador_expr.drop();
print('Colecciones de prueba borradas.');
