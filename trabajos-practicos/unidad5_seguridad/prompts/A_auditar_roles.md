# Prompt para OpenCode — Parte A.4: auditoría de roles.sql

Abrí OpenCode en la carpeta `trabajos-practicos/unidad5_seguridad` y pegá:

```
Auditá el archivo sql/roles.sql de este proyecto (PostgreSQL 16+, base Food Store).
Quiero que revises si cada rol cumple el principio de mínimo privilegio y que propongas
mejoras o correcciones concretas, con la sentencia SQL de cada una. No ejecutes nada
contra la base: solo leé el archivo y respondé.
```

Guardá la respuesta completa en `docs/respuestas_ia/A_auditoria_roles.md`.

Qué mirar en la respuesta, antes de aceptar algo:
- Si propone `GRANT ALL`, `GRANT ... ON ALL TABLES` a un rol de la aplicación o `WITH GRANT OPTION`, es más amplio de lo necesario. Anotalo en la bitácora como el caso que pide la consigna.
- Si propone darle `SELECT` sobre `usuario` a `app_web`, contradice el diseño: la app autentica con `fn_autenticar` y no lee la tabla.
- Si propone algo razonable (por ejemplo, `REVOKE CREATE ON SCHEMA public`, que ya está), comprobalo en la base con `\dp` o con `sql/verificacion_permisos.sql` antes de aceptarlo.
