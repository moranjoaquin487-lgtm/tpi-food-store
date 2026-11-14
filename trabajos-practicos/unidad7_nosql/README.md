# Unidad 7 — NoSQL: pedidos de Food Store en MongoDB

- **Alumno:** Moran, Joaquín Leandro

| Consigna | Archivo |
|---|---|
| Estado del pedido (faltaba en el esquema) | `01_estado_pedido.sql` |
| 1–2 Modelo y migración (`insertMany`) | `02_exportar_pedidos.sql` → `pedidos_export.json` → `cargar_mongodb.js` |
| 3 Reglas de integridad y qué se embebió | `cargar_mongodb.js` (control de R1 y validador `$jsonSchema`), informe sección 1 |
| 4 Consultas a–d en MongoDB | `consultas_mongodb.js` |
| 5 Equivalentes en PostgreSQL y tabla de verificación | `consultas_postgresql.sql`, `verificar_consultas.sh` → `evidencias/tabla_verificacion.md` |
| 6–7 Comparación con IA y contraste | `prompts/comparacion_ia.md`, `pruebas_integridad_mongodb.js`, `docs/respuestas_ia/comparacion.md` |
| Informe (hasta 5 páginas) | [`docs/Informe_TP_U7_Moran.pdf`](docs/Informe_TP_U7_Moran.pdf) (fuente: `docs/informe_u7.md`) |

**Orden:**

1. `ejecutar_segunda_entrega.sh` corre `01` y `02` y, si encuentra `mongosh`, también la carga, las consultas, las pruebas y la verificación.
2. A mano: `mongosh --file cargar_mongodb.js`, `mongosh --file consultas_mongodb.js` y `./verificar_consultas.sh`.
