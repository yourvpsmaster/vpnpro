#!/bin/bash
# ── Módulo: Herramientas del Sistema ─────────────────────────

menu_tools() {
    while true; do
        banner_seccion "HERRAMIENTAS DEL SISTEMA" "🛠️"
        echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[1]${NC}  🔄  Actualizar sistema (apt upgrade)           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[2]${NC}  🧹  Limpiar logs de VPN PRO                    ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[3]${NC}  ⚡  Optimizar SSH (/etc/ssh/sshd_config)       ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[4]${NC}  🔄  Reiniciar servicio SSH                     ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[5]${NC}  📦  Instalar dependencias VPN PRO              ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[6]${NC}  🌐  Verificar conectividad a internet          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[7]${NC}  🔁  Reiniciar TODOS los servicios VPN          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${RED}[0]${NC}  🔙  Volver                                     ${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
        echo -ne "\n  ${WHITE}Selecciona una opción ${YELLOW}[0-7]${WHITE}: ${NC}"
        read -r op

        case $op in
            1) tools_actualizar ;;
            2) tools_limpiar_logs ;;
            3) tools_optimizar_ssh ;;
            4) systemctl restart ssh && msg_ok "SSH reiniciado." && presionar_enter ;;
            5) tools_instalar_deps ;;
            6) tools_check_internet ;;
            7) tools_reiniciar_todo ;;
            0) break ;;
            *) msg_err "Opción inválida."; sleep 1 ;;
        esac
    done
}

tools_actualizar() {
    banner_seccion "ACTUALIZAR SISTEMA" "🔄"
    msg_info "Actualizando lista de paquetes..."
    apt-get update -qq
    msg_info "Actualizando paquetes..."
    apt-get upgrade -y
    msg_ok "Sistema actualizado."
    presionar_enter
}

tools_limpiar_logs() {
    banner_seccion "LIMPIAR LOGS" "🧹"
    local logdir="/var/log/vpnpro"
    if [[ -d "$logdir" ]]; then
        local size_antes
        size_antes=$(du -sh "$logdir" | cut -f1)
        find "$logdir" -name "*.log" -exec truncate -s 0 {} \;
        msg_ok "Logs limpiados. (Liberado ~$size_antes)"
    else
        msg_warn "No hay directorio de logs."
    fi
    presionar_enter
}

tools_optimizar_ssh() {
    banner_seccion "OPTIMIZAR SSH" "⚡"
    local sshd_conf="/etc/ssh/sshd_config"
    cp "$sshd_conf" "${sshd_conf}.bak.$(date +%Y%m%d)"

    # Optimizaciones para VPN/tunneling
    declare -A opts=(
        ["ClientAliveInterval"]="30"
        ["ClientAliveCountMax"]="3"
        ["TCPKeepAlive"]="yes"
        ["AllowTcpForwarding"]="yes"
        ["GatewayPorts"]="yes"
        ["MaxSessions"]="100"
        ["LoginGraceTime"]="30"
        ["UseDNS"]="no"
        ["Compression"]="yes"
    )

    for key in "${!opts[@]}"; do
        if grep -q "^${key}" "$sshd_conf"; then
            sed -i "s/^${key}.*/${key} ${opts[$key]}/" "$sshd_conf"
        else
            echo "${key} ${opts[$key]}" >> "$sshd_conf"
        fi
        msg_ok "$key = ${opts[$key]}"
    done

    systemctl restart ssh &>/dev/null
    msg_ok "SSH optimizado y reiniciado."
    presionar_enter
}

tools_instalar_deps() {
    banner_seccion "INSTALAR DEPENDENCIAS" "📦"
    local paquetes=("python3" "python3-pip" "openssh-server" "ufw" "net-tools"
                    "curl" "wget" "netcat-openbsd" "iproute2" "dns2tcp")
    for pkg in "${paquetes[@]}"; do
        if pkg_instalado "$pkg"; then
            echo -e "  ${GREEN}[✓]${NC} $pkg ya instalado."
        else
            msg_wait "Instalando $pkg..."
            apt-get install -y "$pkg" &>/dev/null && echo -e " ${GREEN}OK${NC}" || echo -e " ${RED}FALLO${NC}"
        fi
    done
    presionar_enter
}

tools_check_internet() {
    banner_seccion "VERIFICAR CONECTIVIDAD" "🌐"
    local hosts=("8.8.8.8" "1.1.1.1" "google.com")
    for host in "${hosts[@]}"; do
        if ping -c1 -W2 "$host" &>/dev/null; then
            msg_ok "Ping a $host: ${GREEN}OK${NC}"
        else
            msg_err "Ping a $host: ${RED}FALLO${NC}"
        fi
    done
    echo -e "\n  ${WHITE}IP Pública: ${GREEN}$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo 'N/A')${NC}"
    presionar_enter
}

tools_reiniciar_todo() {
    banner_seccion "REINICIAR SERVICIOS VPN" "🔁"
    # SSH
    systemctl restart ssh &>/dev/null && msg_ok "SSH reiniciado." || msg_err "Error SSH."
    # WebSocket
    pkill -f ws_server.py &>/dev/null
    sleep 1
    local ws_script
    ws_script="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ws_server.py"
    while IFS= read -r p; do
        nohup python3 "$ws_script" "$p" >> "/var/log/vpnpro/ws_${p}.log" 2>&1 &
        sleep 0.3
        msg_ok "WebSocket puerto $p reiniciado."
    done < "/etc/vpnpro/websocket.conf" 2>/dev/null
    # SlowDNS
    if command -v dns2tcpd &>/dev/null && [[ -f /etc/dns2tcpd.conf ]]; then
        pkill -f dns2tcpd &>/dev/null
        sleep 0.5
        dns2tcpd -F -f /etc/dns2tcpd.conf >> /var/log/vpnpro/slowdns.log 2>&1 &
        msg_ok "SlowDNS reiniciado."
    fi
    presionar_enter
}
