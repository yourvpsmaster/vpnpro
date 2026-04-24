#!/bin/bash
# ── Colores ─────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
PURPLE='\033[0;35m'
ORANGE='\033[0;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color
DIM='\033[2m'

# ── Banner Principal ────────────────────────────────────────
banner_principal() {
    local ip
    ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "N/A")
    local fecha
    fecha=$(date '+%d/%m/%Y %H:%M')
    local uptime_info
    uptime_info=$(uptime -p 2>/dev/null | sed 's/up //' || echo "N/A")

    echo -e "${CYAN}"
    echo '  ██╗   ██╗██████╗ ███╗   ██╗    ██████╗ ██████╗  ██████╗ '
    echo '  ██║   ██║██╔══██╗████╗  ██║    ██╔══██╗██╔══██╗██╔═══██╗'
    echo '  ██║   ██║██████╔╝██╔██╗ ██║    ██████╔╝██████╔╝██║   ██║'
    echo '  ╚██╗ ██╔╝██╔═══╝ ██║╚██╗██║    ██╔═══╝ ██╔══██╗██║   ██║'
    echo '   ╚████╔╝ ██║     ██║ ╚████║    ██║     ██║  ██║╚██████╔╝'
    echo '    ╚═══╝  ╚═╝     ╚═╝  ╚═══╝    ╚═╝     ╚═╝  ╚═╝ ╚═════╝ '
    echo -e "${NC}"
    echo -e "  ${DIM}${WHITE}═══════════════════════════════════════════════════════${NC}"
    echo -e "  ${WHITE}IP Servidor: ${GREEN}$ip${NC}   ${WHITE}Fecha: ${YELLOW}$fecha${NC}   ${WHITE}Uptime: ${CYAN}$uptime_info${NC}"
    echo -e "  ${DIM}${WHITE}═══════════════════════════════════════════════════════${NC}\n"
}

# ── Banner de Sección ───────────────────────────────────────
banner_seccion() {
    local titulo="$1"
    local icono="${2:-🔧}"
    clear
    echo -e "\n${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${icono}  ${BOLD}${WHITE}${titulo}${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}\n"
}

# ── Mensajes estándar ───────────────────────────────────────
msg_ok()    { echo -e "  ${GREEN}[✓]${NC} $1"; }
msg_err()   { echo -e "  ${RED}[✗]${NC} $1"; }
msg_warn()  { echo -e "  ${YELLOW}[!]${NC} $1"; }
msg_info()  { echo -e "  ${CYAN}[i]${NC} $1"; }
msg_wait()  { echo -ne "  ${YELLOW}[…]${NC} $1"; }

separador() {
    echo -e "  ${DIM}${CYAN}──────────────────────────────────────────────────────${NC}"
}

presionar_enter() {
    echo -e "\n  ${DIM}Presiona ${WHITE}ENTER${NC}${DIM} para continuar...${NC}"
    read -r
}
