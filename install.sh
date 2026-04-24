#!/bin/bash
# ============================================================
#   VPN PRO - INSTALADOR AUTOMÁTICO
#   Ubuntu 22.04 LTS
#   Uso: sudo bash install.sh
# ============================================================

set -e

# ── Colores inline para el instalador ────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'; BOLD='\033[1m'

msg_ok()   { echo -e "  ${GREEN}[✓]${NC} $1"; }
msg_err()  { echo -e "  ${RED}[✗]${NC} $1"; }
msg_info() { echo -e "  ${CYAN}[i]${NC} $1"; }
msg_wait() { echo -ne "  ${YELLOW}[…]${NC} $1"; }

# ── Verificar root ────────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    msg_err "Necesitas ejecutar como root: sudo bash install.sh"
    exit 1
fi

# ── Verificar Ubuntu 22 ───────────────────────────────────────
if ! grep -q "22." /etc/os-release 2>/dev/null; then
    msg_err "Este script está optimizado para Ubuntu 22.04"
    echo -ne "  ${YELLOW}¿Continuar de todas formas? [s/N]: ${NC}"; read -r c
    [[ ! "$c" =~ ^[Ss]$ ]] && exit 1
fi

INSTALL_DIR="/opt/vpnpro"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

clear
echo -e "${CYAN}"
echo '  ██╗   ██╗██████╗ ███╗   ██╗    ██████╗ ██████╗  ██████╗ '
echo '  ██║   ██║██╔══██╗████╗  ██║    ██╔══██╗██╔══██╗██╔═══██╗'
echo '  ██║   ██║██████╔╝██╔██╗ ██║    ██████╔╝██████╔╝██║   ██║'
echo '  ╚██╗ ██╔╝██╔═══╝ ██║╚██╗██║    ██╔═══╝ ██╔══██╗██║   ██║'
echo '   ╚████╔╝ ██║     ██║ ╚████║    ██║     ██║  ██║╚██████╔╝'
echo '    ╚═══╝  ╚═╝     ╚═╝  ╚═══╝    ╚═╝     ╚═╝  ╚═╝ ╚═════╝ '
echo -e "${NC}"
echo -e "  ${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${BOLD}${WHITE}  INSTALADOR VPN PRO - Ubuntu 22.04${NC}"
echo -e "  ${WHITE}  WebSocket (Python3) + SlowDNS + SSH Manager${NC}"
echo -e "  ${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

echo -ne "  ${YELLOW}¿Iniciar instalación? [S/n]: ${NC}"; read -r confirm
[[ "$confirm" =~ ^[Nn]$ ]] && echo -e "  Instalación cancelada." && exit 0

echo ""
echo -e "  ${CYAN}[1/7] Actualizando repositorios...${NC}"
apt-get update -qq &>/dev/null && msg_ok "Repositorios actualizados."

echo -e "  ${CYAN}[2/7] Instalando dependencias...${NC}"
PKGS="python3 openssh-server ufw net-tools curl wget netcat-openbsd iproute2 dns2tcp"
for pkg in $PKGS; do
    if ! dpkg -l "$pkg" &>/dev/null; then
        apt-get install -y "$pkg" &>/dev/null && msg_ok "$pkg instalado." || msg_err "Error con $pkg (no crítico)."
    else
        msg_ok "$pkg ya presente."
    fi
done

echo -e "  ${CYAN}[3/7] Copiando archivos VPN PRO...${NC}"
mkdir -p "$INSTALL_DIR/modules"
mkdir -p /etc/vpnpro
mkdir -p /var/log/vpnpro

cp "$SCRIPT_DIR/menu.sh" "$INSTALL_DIR/"
cp "$SCRIPT_DIR/modules/"*.sh "$INSTALL_DIR/modules/"
cp "$SCRIPT_DIR/modules/ws_server.py" "$INSTALL_DIR/modules/"
chmod +x "$INSTALL_DIR/menu.sh"
chmod +x "$INSTALL_DIR/modules/"*.sh
msg_ok "Archivos copiados a $INSTALL_DIR"

echo -e "  ${CYAN}[4/7] Configurando acceso con comando 'menu'...${NC}"
cat > /usr/local/bin/menu << EOF
#!/bin/bash
sudo bash $INSTALL_DIR/menu.sh "\$@"
EOF
chmod +x /usr/local/bin/menu
msg_ok "Comando 'menu' creado. Ejecuta: menu"

echo -e "  ${CYAN}[5/7] Configurando WebSocket puerto 80...${NC}"
[[ ! -f /etc/vpnpro/websocket.conf ]] && echo "80" > /etc/vpnpro/websocket.conf
msg_ok "WebSocket configurado en puerto 80."

echo -e "  ${CYAN}[6/7] Creando servicio systemd para WebSocket...${NC}"
cat > /etc/systemd/system/vpnpro-websocket.service << EOF
[Unit]
Description=VPN PRO - WebSocket Proxy (HTTP/1.1 101 Switching Protocols)
After=network.target

[Service]
Type=forking
User=root
ExecStart=/bin/bash -c 'while IFS= read -r p; do python3 $INSTALL_DIR/modules/ws_server.py \$p >> /var/log/vpnpro/ws_\$p.log 2>&1 & done < /etc/vpnpro/websocket.conf'
ExecStop=/usr/bin/pkill -f ws_server.py
Restart=on-failure
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable vpnpro-websocket.service &>/dev/null
systemctl start vpnpro-websocket.service &>/dev/null
msg_ok "Servicio WebSocket habilitado y arrancado."

echo -e "  ${CYAN}[7/7] Configurando firewall básico...${NC}"
ufw --force enable &>/dev/null
ufw allow 22/tcp &>/dev/null
ufw allow 80/tcp &>/dev/null
ufw allow 53/udp &>/dev/null
msg_ok "UFW: puertos 22, 80, 53 abiertos."

# ── Resumen final ─────────────────────────────────────────────
echo ""
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}${BOLD}  ✓ VPN PRO instalado exitosamente!${NC}"
echo -e "  ${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${WHITE}Directorio    :${NC} ${GREEN}$INSTALL_DIR${NC}"
echo -e "  ${WHITE}Iniciar menú  :${NC} ${YELLOW}menu${NC}  (o: sudo bash $INSTALL_DIR/menu.sh)"
echo -e "  ${WHITE}WebSocket     :${NC} ${GREEN}Activo en puerto 80${NC}"
echo -e "  ${WHITE}Logs          :${NC} /var/log/vpnpro/"
echo ""
echo -e "  ${CYAN}Servicios disponibles:${NC}"
echo -e "   ${GREEN}•${NC} WebSocket Proxy   → puerto 80 (HTTP/1.1 101 Switching Protocols)"
echo -e "   ${GREEN}•${NC} SlowDNS (dns2tcp) → configurable desde el menú"
echo -e "   ${GREEN}•${NC} Gestión SSH       → crear/eliminar/monitorear usuarios"
echo ""
echo -e "  ${YELLOW}  👉 Escribe 'menu' para abrir el panel de administración${NC}\n"
