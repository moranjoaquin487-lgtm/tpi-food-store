"""Anonimiza un fragmento de log antes de dárselo a un asistente de IA.

Uso: python anonimizar_log.py < log_original.txt > log_anonimizado.txt

Criterio: los mails se seudonimizan igual que en sql/usuario_anon.sql. Este log no tiene
nombres, apellidos ni celulares, así que esos campos no se tratan acá (code review U4-U7, #14):
  * mails      -> 'anon_' + 10 caracteres de sha256('foodstore-u5:' + mail) + '@ejemplo.test'
  * IP y puerto de origen -> ip_origen_N (la misma IP recibe siempre el mismo N)
  * contraseñas pasadas como argumento a fn_autenticar o fn_resetear_password -> '***'
Los nombres de roles de base (app_web, admin_datos) no son datos personales y se conservan.
"""
import hashlib
import re
import sys

SAL = "foodstore-u5:"
MAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
# IPv4 o IPv6 seguidas de "(puerto)", como las escribe %r en log_line_prefix
IP_CON_PUERTO = re.compile(r"(?<![\w.:])((?:\d{1,3}\.){3}\d{1,3}|[0-9A-Fa-f]{0,4}(?::[0-9A-Fa-f]{0,4}){2,7})\((\d+)\)")
# "host=... port=..." de la línea "connection received"
HOST = re.compile(r"host=((?:\d{1,3}\.){3}\d{1,3}|[0-9A-Fa-f:]+)")
PUERTO = re.compile(r"port=\d+")
CLAVE = re.compile(r"((?:fn_autenticar|fn_resetear_password)\(\s*'[^']*'\s*,\s*)'[^']*'")

ips: dict[str, str] = {}


def alias_ip(ip: str) -> str:
    if ip not in ips:
        ips[ip] = f"ip_origen_{len(ips) + 1}"
    return ips[ip]


def alias_mail(m: re.Match) -> str:
    h = hashlib.sha256((SAL + m.group(0).lower()).encode("utf-8")).hexdigest()
    return f"anon_{h[:10]}@ejemplo.test"


def anonimizar(linea: str) -> str:
    linea = CLAVE.sub(r"\1'***'", linea)
    linea = MAIL.sub(alias_mail, linea)
    linea = IP_CON_PUERTO.sub(lambda m: f"{alias_ip(m.group(1))}(puerto)", linea)
    linea = HOST.sub(lambda m: f"host={alias_ip(m.group(1))}", linea)
    linea = PUERTO.sub("port=(puerto)", linea)
    return linea


def main() -> None:
    for linea in sys.stdin:
        sys.stdout.write(anonimizar(linea))


if __name__ == "__main__":
    main()
