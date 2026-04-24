#!/bin/bash
# ── Módulo: Firewall y Puertos ───────────────────────────────

menu_firewall() {
    while true; do
        banner_seccion "FIREWALL / PUERTOS" "🔒"
        local ufw_status
        ufw_status=$(ufw status 2>/dev/null | head -1 | awk '{print $2}')
        echo -e "  Estado UFW: $([ "$ufw_status" = "active" ] && echo "${GREEN}● Activo${NC}" || echo "${RED}● Inactivo${NC}")\n"

        echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[1]${NC}  🔓  Abrir puerto (TCP/UDP)                    ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[2]${NC}  🔐  Cerrar puerto                             ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[3]${NC}  📋  Listar reglas del firewall                ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[4]${NC}  ✅  Activar UFW                               ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[5]${NC}  ❌  Desactivar UFW                            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[6]${NC}  🛡️   Reglas básicas VPN (SSH+WS+DNS)           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[7]${NC}  🔍  Puertos en escucha                        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${RED}[0]${NC}  🔙  Volver                                     ${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
        echo -ne "\n  ${WHITE}Selecciona una opción ${YELLOW}[0-7]${WHITE}: ${NC}"
        read -r op

        case $op in
            1) fw_abrir_puerto ;;
            2) fw_cerrar_puerto ;;
            3) fw_listar ;;
            4) ufw --force enable &>/dev/null && msg_ok "UFW activado." && presionar_enter ;;
            5) ufw disable &>/dev/null && msg_ok "UFW desactivado." && presionar_enter ;;
            6) fw_reglas_vpn ;;
            7) fw_puertos_escucha ;;
            0) break ;;
            *) msg_err "Opción inválida."; sleep 1 ;;
        esac
    done
}

fw_abrir_puerto() {
    banner_seccion "ABRIR PUERTO" "🔓"
    echo -ne "  ${WHITE}Puerto: ${NC}"; read -r puerto
    echo -ne "  ${WHITE}Protocolo [tcp/udp/both]: ${NC}"; read -r proto
    [[ -z "$proto" ]] && proto="tcp"

    if [[ "$proto" == "both" ]]; then
        ufw allow "${puerto}/tcp" &>/dev/null
        ufw allow "${puerto}/udp" &>/dev/null
    else
        ufw allow "${puerto}/${proto}" &>/dev/null
    fi
    # También con iptables como respaldo
    iptables -I INPUT -p "${proto}" --dport "$puerto" -j ACCEPT 2>/dev/null
    msg_ok "Puerto $puerto/$proto abierto."
    presionar_enter
}

fw_cerrar_puerto() {
    banner_seccion "CERRAR PUERTO" "🔐"
    echo -ne "  ${WHITE}Puerto: ${NC}"; read -r puerto
    echo -ne "  ${WHITE}Protocolo [tcp]: ${NC}"; read -r proto
    [[ -z "$proto" ]] && proto="tcp"
    ufw deny "${puerto}/${proto}" &>/dev/null
    msg_ok "Puerto $puerto/$proto cerrado."
    presionar_enter
}

fw_listar() {
    banner_seccion "REGLAS FIREWALL" "📋"
    ufw status numbered 2>/dev/null || iptables -L -n --line-numbers 2>/dev/null | head -40
    presionar_enter
}

fw_reglas_vpn() {
    banner_seccion "REGLAS BÁSICAS VPN" "🛡️"
    msg_info "Aplicando reglas esenciales para VPN PRO...\n"

    # SSH
    ufw allow 22/tcp &>/dev/null && msg_ok "SSH puerto 22 abierto."
    # WebSocket puertos
    while IFS= read -r p; do
        ufw allow "${p}/tcp" &>/dev/null && msg_ok "WebSocket puerto $p abierto."
    done < "/etc/vpnpro/websocket.conf" 2>/dev/null
    # DNS para SlowDNS
    ufw allow 53/udp &>/dev/null && msg_ok "DNS UDP 53 abierto (SlowDNS)."
    # HTTP/HTTPS
    ufw allow 80/tcp &>/dev/null
    ufw allow 443/tcp &>/dev/null && msg_ok "HTTP/HTTPS abiertos."
    # Loopback
    ufw allow in on lo &>/dev/null

    msg_ok "Reglas VPN aplicadas."
    presionar_enter
}

fw_puertos_escucha() {
    banner_seccion "PUERTOS EN ESCUCHA" "🔍"
    echo -e "  ${BOLD}${CYAN}Puerto    Proto  Proceso${NC}"
    separador
    ss -tlnp 2>/dev/null | awk 'NR>1 {
        split($4, a, ":")
        printf "  \033[1;33m%-9s\033[0m \033[0;36m%-6s\033[0m \033[1;37m%s\033[0m\n",
        a[length(a)], "TCP", $6
    }'
    ss -ulnp 2>/dev/null | awk 'NR>1 {
        split($4, a, ":")
        printf "  \033[1;33m%-9s\033[0m \033[0;35m%-6s\033[0m \033[1;37m%s\033[0m\n",
        a[length(a)], "UDP", $6
    }'
    presionar_enter
}
