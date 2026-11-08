#!/usr/bin/env bash
# Parte 3: muestra en el motor qué hace realmente cada script (todo dentro de BEGIN ... ROLLBACK).
set -u
cd "$(dirname "$0")/.."
export PGUSER="${PGUSER:-postgres}" PGCLIENTENCODING=UTF8 PGOPTIONS="-c client_min_messages=warning"
mkdir -p evidencias
psql -d foodstore_trabajo -a -f food-store/lectura_critica_demo.sql > evidencias/parte3_lectura_critica.txt 2>&1
echo ">> evidencias/parte3_lectura_critica.txt"
