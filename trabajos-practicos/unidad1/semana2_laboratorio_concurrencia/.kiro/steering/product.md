# Product

Academic practical work for the course **Base de Datos II** at UTN (Tecnicatura Universitaria en Programación), by Joaquín Leandro Moran.

The project is **Food Store**, a PostgreSQL database for a food store. It is not an application — there is no backend, frontend, or build system. The work covers:

- **Semana 2, Parte 0:** Security protocol and AI agent setup (OpenCode + Kiro).
- **Semana 2, Parte 1:** Business rules enforced by the database engine (triggers/constraints), specified in `specs/spec_restricciones.md` and generated with OpenCode.
- **Semana 2, Parte 2:** Concurrency laboratory — four scenarios demonstrating non-repeatable reads, phantom reads, lock wait, and deadlock, plus verification runs with the isolation level or locking mechanism that prevents each anomaly.
- **Semana 2, Parte 3:** Critical reading exercise — analysis of two dangerous scripts (`docs/ejercicio_lectura_critica.md` and `food-store/lectura_critica_demo.sql`).

All work targets the `foodstore_trabajo` database (a working copy of `foodstore_plantilla`). The original template is read-only and must never be modified.
