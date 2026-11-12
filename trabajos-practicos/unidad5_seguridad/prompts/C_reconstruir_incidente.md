# Prompt para OpenCode — Parte C.4: reconstrucción del incidente

La consigna pide darle a la IA el log anonimizado **sin contexto adicional**. No le cuentes qué hiciste ni qué esperás.

Abrí OpenCode en una carpeta vacía (así no puede leer los scripts del simulacro), copiá ahí `docs/log_simulacro_anonimizado.txt` y pegá:

```
Te paso un fragmento de log de PostgreSQL (archivo log_simulacro_anonimizado.txt).
Reconstruí qué ocurrió, en orden, y proponé una hipótesis de contención.
```

Guardá la respuesta completa en `docs/respuestas_ia/C_reconstruccion_incidente.md`. Después completá el punto 5 de `docs/informe_incidente.md` usando la tabla de hechos que el log sí y no sustenta.
