"""Extrae del log del servidor el fragmento entre dos marcas.

Uso: python extraer_log.py MARCA
Lee el archivo de log actual con pg_read_binary_file (hace falta conectarse como postgres)
y devuelve las líneas desde 'MARCA INICIO <marca>' hasta 'MARCA FIN <marca>'.
Se lee en binario porque, en Windows con idioma español, el log puede estar en WIN1252.
"""
import base64
import os
import subprocess
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print("Uso: python extraer_log.py MARCA", file=sys.stderr)
        return 2
    marca = sys.argv[1]
    db = os.environ.get("DB", "foodstore")
    consulta = "SELECT encode(pg_read_binary_file(pg_current_logfile()), 'base64')"
    salida = subprocess.run(["psql", "-d", db, "-X", "-At", "-c", consulta],
                            capture_output=True, check=True).stdout
    datos = b"".join(salida.split())
    if not datos:
        print("No hay archivo de log: logging_collector está apagado (ver docs/informe_auditoria.md).", file=sys.stderr)
        return 1
    crudo = base64.b64decode(datos)
    try:
        texto = crudo.decode("utf-8")
    except UnicodeDecodeError:
        texto = crudo.decode("cp1252", errors="replace")

    lineas = texto.splitlines()
    inicio = next((i for i, l in enumerate(lineas) if f"MARCA INICIO {marca}" in l), None)
    fin = next((i for i, l in enumerate(lineas) if f"MARCA FIN {marca}" in l), None)
    if inicio is None or fin is None:
        print(f"No se encontraron las marcas de {marca} en el log actual.", file=sys.stderr)
        return 1
    sys.stdout.write("\n".join(lineas[inicio:fin + 1]) + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
