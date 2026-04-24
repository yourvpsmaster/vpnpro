#!/bin/bash
# ============================================================
#   SCRIPT VPN PRO - UBUNTU 22 - BY CHUMO STYLE
#   Inicio: escribir 'menu' en la terminal
# ============================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/modules/colors.sh"
source "$SCRIPT_DIR/modules/utils.sh"

# ── Verificar root ──────────────────────────────────────────
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}[✗] Este script requiere privilegios root. Usa: sudo menu${NC}"
    exit 1
fi

# ── Menú Principal ──────────────────────────────────────────
main_menu() {
    while true; do
        clear
        banner_principal
        echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}          ${BOLD}${WHITE}⚡  PANEL PRINCIPAL DE ADMINISTRACIÓN  ⚡${NC}     ${CYAN}║${NC}"
        echo -e "${CYAN}╠══════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC}                                                      ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[1]${NC}  👤  Gestión de Usuarios SSH                     ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[2]${NC}  🌐  Gestión de WebSocket                        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[3]${NC}  🐢  Gestión de SlowDNS                          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[4]${NC}  📊  Monitoreo del Sistema                       ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[5]${NC}  🔒  Configuración de Firewall/Puertos            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[6]${NC}  🛠️   Herramientas del Sistema                    ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[7]${NC}  ℹ️   Información del Servidor                    ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${RED}[0]${NC}  🚪  Salir                                       ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}                                                      ${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
        echo -ne "\n  ${WHITE}Selecciona una opción ${YELLOW}[0-7]${WHITE}: ${NC}"
        read -r opcion

        case $opcion in
            1) source "$SCRIPT_DIR/modules/ssh_users.sh"; menu_ssh ;;
            2) source "$SCRIPT_DIR/modules/websocket.sh"; menu_websocket ;;
            3) source "$SCRIPT_DIR/modules/slowdns.sh"; menu_slowdns ;;
            4) source "$SCRIPT_DIR/modules/monitor.sh"; menu_monitor ;;
            5) source "$SCRIPT_DIR/modules/firewall.sh"; menu_firewall ;;
            6) source "$SCRIPT_DIR/modules/tools.sh"; menu_tools ;;
            7) source "$SCRIPT_DIR/modules/info.sh"; mostrar_info ;;
            0) echo -e "\n  ${GREEN}[✓] Hasta luego!${NC}\n"; exit 0 ;;
            *) echo -e "\n  ${RED}[✗] Opción inválida.${NC}"; sleep 1 ;;
        esac
    done
}

main_menu
