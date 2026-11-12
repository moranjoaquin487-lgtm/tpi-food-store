# Prompt para la IA — Consigna 6: PostgreSQL vs. MongoDB para los pedidos

Usá OpenCode (o la herramienta que declares en la DUIA) y pegá:

```
Tengo un sistema de pedidos, Food Store, en PostgreSQL 16. El modelo actual es relacional:
pedido (id, fecha, estado, forma_pago, id_cliente) y detalle_pedido (id_pedido, id_producto,
cantidad, precio_unitario), con producto (precio, stock), categoria y cliente. Los
triggers controlan el stock y la integridad, y las ventas se registran en transacciones.
El acceso más frecuente es leer un pedido completo, con sus líneas y los datos del
cliente. Hay que conservar la coherencia de cantidades y precios: el precio de cada línea
es el histórico de la venta y el stock no puede quedar negativo.
Compará PostgreSQL y MongoDB para almacenar y consultar estos pedidos. ¿Conviene mantener
PostgreSQL, usar MongoDB para los pedidos o combinar las dos? Justificá con criterios técnicos.
```

Guardá la respuesta completa en `docs/respuestas_ia/comparacion.md`.

Para la consigna 7, elegí dos afirmaciones concretas de la respuesta y contrastalas:
- Si afirma que **MongoDB no tiene integridad referencial**, la prueba 1 de `pruebas_integridad_mongodb.js` lo muestra.
- Si afirma que **un validador de esquema garantiza la coherencia del pedido**, la prueba 2 muestra que `$jsonSchema` no controla que el total sea la suma de las líneas.
- Si afirma que **MongoDB no tiene transacciones**, es falso desde la versión 4.0, que agregó transacciones de varios documentos sobre réplicas: https://www.mongodb.com/docs/manual/core/transactions/
- Si afirma que **leer un pedido embebido es una sola operación**, la prueba 4 y la documentación de embedding lo respaldan: https://www.mongodb.com/docs/manual/data-modeling/embedding/
