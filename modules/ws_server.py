#!/usr/bin/env python3
"""
VPN PRO - WebSocket Proxy Server
Puerto: configurable (default 80)
Respuesta: HTTP/1.1 101 Switching Protocols
Soporta túnel SSH sobre WebSocket (HTTP CONNECT style)
"""

import socket
import threading
import select
import sys
import os
import signal
import logging
import time
from datetime import datetime

# ── Configuración ────────────────────────────────────────────
LISTEN_HOST = "0.0.0.0"
LISTEN_PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 80
SSH_HOST    = "127.0.0.1"
SSH_PORT    = 22
BUFFER_SIZE = 65536
TIMEOUT     = 60
LOG_FILE    = "/var/log/vpnpro/websocket.log"

os.makedirs("/var/log/vpnpro", exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [WS] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE),
        logging.StreamHandler(sys.stdout)
    ]
)
log = logging.getLogger(__name__)

# ── Respuesta WebSocket 101 ──────────────────────────────────
WS_RESPONSE = (
    "HTTP/1.1 101 Switching Protocols\r\n"
    "Upgrade: websocket\r\n"
    "Connection: Upgrade\r\n"
    "Sec-WebSocket-Accept: VpnPro2025\r\n"
    "\r\n"
)

CONNECT_RESPONSE = (
    "HTTP/1.1 200 Connection established\r\n"
    "Proxy-Agent: VPN-PRO/1.0\r\n"
    "\r\n"
)

stats = {"connections": 0, "active": 0, "bytes_in": 0, "bytes_out": 0}
stats_lock = threading.Lock()

# ── Manejo de cliente ────────────────────────────────────────
def handle_client(client_sock, addr):
    with stats_lock:
        stats["connections"] += 1
        stats["active"] += 1

    log.info(f"Nueva conexión: {addr[0]}:{addr[1]}")

    try:
        client_sock.settimeout(TIMEOUT)
        # Leer la petición HTTP inicial
        data = b""
        while b"\r\n\r\n" not in data:
            chunk = client_sock.recv(4096)
            if not chunk:
                break
            data += chunk

        request = data.decode("utf-8", errors="ignore")
        first_line = request.split("\r\n")[0] if request else ""

        # ── Detectar tipo de petición ────────────────────────
        if "CONNECT" in first_line:
            # Modo HTTP CONNECT (estándar para tunneling)
            client_sock.send(CONNECT_RESPONSE.encode())
            log.info(f"CONNECT desde {addr[0]}")
        elif "GET" in first_line or "WebSocket" in request or "Upgrade" in request:
            # Modo WebSocket Upgrade
            client_sock.send(WS_RESPONSE.encode())
            log.info(f"WebSocket Upgrade desde {addr[0]}")
        else:
            # Modo directo / payload custom
            client_sock.send(WS_RESPONSE.encode())

        # ── Conectar al servidor SSH local ───────────────────
        ssh_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        ssh_sock.settimeout(TIMEOUT)
        ssh_sock.connect((SSH_HOST, SSH_PORT))

        # ── Relay bidireccional ──────────────────────────────
        relay_data(client_sock, ssh_sock, addr)

    except Exception as e:
        log.debug(f"Conexión {addr[0]} cerrada: {e}")
    finally:
        try: client_sock.close()
        except: pass
        with stats_lock:
            stats["active"] -= 1

def relay_data(client_sock, ssh_sock, addr):
    """Relay bidireccional de datos entre cliente y SSH."""
    sockets = [client_sock, ssh_sock]
    while True:
        try:
            readable, _, exceptional = select.select(sockets, [], sockets, TIMEOUT)
            if exceptional or not readable:
                break
            for sock in readable:
                try:
                    data = sock.recv(BUFFER_SIZE)
                    if not data:
                        return
                    if sock is client_sock:
                        ssh_sock.sendall(data)
                        with stats_lock:
                            stats["bytes_in"] += len(data)
                    else:
                        client_sock.sendall(data)
                        with stats_lock:
                            stats["bytes_out"] += len(data)
                except:
                    return
        except:
            break

    try: ssh_sock.close()
    except: pass

# ── Servidor principal ───────────────────────────────────────
def start_server(port=LISTEN_PORT):
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((LISTEN_HOST, port))
    server.listen(200)

    log.info(f"═══════════════════════════════════════════")
    log.info(f"  VPN PRO WebSocket Proxy iniciado")
    log.info(f"  Puerto: {port}")
    log.info(f"  Target: {SSH_HOST}:{SSH_PORT}")
    log.info(f"  Respuesta: HTTP/1.1 101 Switching Protocols")
    log.info(f"═══════════════════════════════════════════")

    # PID file
    with open("/var/run/vpnpro-ws.pid", "w") as f:
        f.write(str(os.getpid()))

    def signal_handler(sig, frame):
        log.info("Deteniendo servidor WebSocket...")
        server.close()
        try: os.remove("/var/run/vpnpro-ws.pid")
        except: pass
        sys.exit(0)

    signal.signal(signal.SIGTERM, signal_handler)
    signal.signal(signal.SIGINT, signal_handler)

    while True:
        try:
            client_sock, addr = server.accept()
            t = threading.Thread(target=handle_client, args=(client_sock, addr), daemon=True)
            t.start()
        except Exception as e:
            if "Bad file descriptor" in str(e):
                break
            log.error(f"Error aceptando conexión: {e}")

if __name__ == "__main__":
    port = int(sys.argv[1]) if len(sys.argv) > 1 else LISTEN_PORT
    start_server(port)
