# Unidad 1 · Semana 2 — Laboratorio de concurrencia e IA

**Base de Datos II · UTN · Tecnicatura Universitaria en Programación**

- **Presentado por:** Moran, Joaquín Leandro
- **Proyecto:** Food Store, con el `schema.sql` del TP1, sobre PostgreSQL 18.6
- **IA:** OpenCode, Kiro y Claude. Qué hizo cada una está en las DUIA de [`docs/duia/`](docs/duia/).

Esta carpeta es la raíz del trabajo: los scripts se corren y los agentes se abren desde acá.

## Dónde está cada parte de la consigna

| Consigna | Archivos |
|---|---|
| Parte 0 — Protocolo de seguridad | [`protocolo_seguridad.md`](protocolo_seguridad.md) |
| Parte 0 — OpenCode y Kiro | `AGENTS.md` (`/init` de OpenCode), `.kiro/steering/` (Kiro) y los pedidos en [`prompts/parte0_agentes.md`](prompts/parte0_agentes.md) |
| Parte 1 — Spec | [`specs/spec_restricciones.md`](specs/spec_restricciones.md), commiteada antes de generar el código |
| Parte 1 — Restricciones | `food-store/restricciones.sql` y `food-store/pruebas_restricciones.sql`, generados con OpenCode; pedidos en [`prompts/parte1_opencode.md`](prompts/parte1_opencode.md) y plan en `docs/plan_opencode_parte1.md` |
| Parte 1 — Prueba y aplicación | [`scripts/aplicar_restricciones.sh`](scripts/aplicar_restricciones.sh) y las evidencias `parte1_1` a `parte1_3` |
| Parte 2 — Laboratorio | [`food-store/concurrencia/`](food-store/concurrencia/), [`scripts/laboratorio_concurrencia.sh`](scripts/laboratorio_concurrencia.sh) y las evidencias `e1` a `e4` |
| Parte 2 — Explicaciones de la IA | Pedidos en `prompts/explicacion_escenario_1.md` a `4`, respuestas tal cual en [`docs/explicaciones_ia/`](docs/explicaciones_ia/) |
| Parte 2 — Informe | `docs/informe_concurrencia.md` |
| Parte 3 — Lectura crítica | [`docs/ejercicio_lectura_critica.md`](docs/ejercicio_lectura_critica.md), con la demostración en [`food-store/lectura_critica_demo.sql`](food-store/lectura_critica_demo.sql) |
| DUIA | `docs/duia/duia_parte1.md`, `duia_parte2.md` y `duia_parte3.md` |

La defensa oral es presencial y no forma parte de esta carpeta.

## Cómo reproducirlo

Desde Git Bash, en esta carpeta, con la contraseña de PostgreSQL cargada en la sesión:

```bash
read -s -p "Contraseña de postgres: " PGPASSWORD; echo; export PGPASSWORD
bash scripts/crear_base.sh                          # plantilla y copia de trabajo
bash scripts/aplicar_restricciones.sh               # Parte 1: prueba que termina en ROLLBACK
bash scripts/aplicar_restricciones.sh --confirmar   # Parte 1: respaldo, COMMIT y casos de prueba
bash scripts/laboratorio_concurrencia.sh reproducir # Parte 2: los cuatro escenarios
bash scripts/laboratorio_concurrencia.sh verificar  # Parte 2: cada escenario con el nivel o mecanismo que lo evita
bash scripts/lectura_critica.sh                     # Parte 3
```

> ⚠️ `crear_base.sh` borra y vuelve a crear `foodstore_plantilla` y `foodstore_trabajo`.

Cada script guarda su salida en `evidencias/`. Las evidencias incluyen errores a propósito: son los casos que el motor tiene que rechazar. Otro usuario de PostgreSQL: `PGUSER=mi_usuario bash scripts/...`.

`food-store/schema.sql` es una copia del [`schema.sql` del TP1](../semana1_modelo_er_normalizacion_ddl/schema.sql). `food-store/data.sql` carga los datos iniciales, con los cinco pedidos de la planilla del TP1.
