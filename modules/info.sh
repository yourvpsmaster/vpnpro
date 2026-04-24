#!/bin/bash
# ── Módulo: Información del Servidor ─────────────────────────

mostrar_info() {
    banner_seccion "INFORMACIÓN DEL SERVIDOR" "ℹ️"

    local ip_local ip_publica hostname_s os_info kernel uptime_s cpu_model cpu_cores ram_total disk_root
    ip_local=$(hostname -I | awk '{print $1}')
    ip_publica=$(curl -s --max-time 5 ifconfig.me 2>/dev/null || echo "N/A")
    hostname_s=$(hostname)
    os_info=$(lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)
    kernel=$(uname -r)
    uptime_s=$(uptime -p | sed 's/up //')
    cpu_model=$(grep "model name" /proc/cpuinfo | head -1 | cut -d':' -f2 | xargs)
    cpu_cores=$(nproc)
    ram_total=$(free -h | awk '/^Mem:/{print $2}')
    disk_root=$(df -h / | awk 'NR==2{print $3"/"$2" ("$5")"}')

    echo -e "  ${BOLD}${CYAN}╔══════ SERVIDOR ══════════════════════════════════╗${NC}"
    echo -e "  ${CYAN}║${NC}  ${WHITE}Hostname   :${NC} ${GREEN}$hostname_s${NC}"
    echo -e "  ${CYAN}║${NC}  ${WHITE}IP Local   :${NC} ${GREEN}$ip_local${NC}"
    echo -e "  ${CYAN}║${NC}  ${WHITE}IP Pública :${NC} ${YELLOW}$ip_publica${NC}"
    echo -e "  ${CYAN}║${NC}  ${WHITE}Sistema    :${NC} ${CYAN}$os_info${NC}"
    echo -e "  ${CYAN}║${NC}  ${WHITE}Kernel     :${NC} ${CYAN}$kernel${NC}"
    echo -e "  ${CYAN}║${NC}  ${WHITE}Uptime     :${NC} ${GREEN}$uptime_s${NC}"
    echo -e "  ${CYAN}╠══════ HARDWARE ══════════════════════════════════╣${NC}"
    echo -e "  ${CYAN}║${NC}  ${WHITE}CPU        :${NC} ${CYAN}$cpu_model${NC}"
    echo -e "  ${CYAN}║${NC}  ${WHITE}Núcleos    :${NC} ${GREEN}$cpu_cores${NC}"
    echo -e "  ${CYAN}║${NC}  ${WHITE}RAM Total  :${NC} ${GREEN}$ram_total${NC}"
    echo -e "  ${CYAN}║${NC}  ${WHITE}Disco /    :${NC} ${YELLOW}$disk_root${NC}"
    echo -e "  ${CYAN}╠══════ SERVICIOS VPN ══════════════════════════════╣${NC}"

    # SSH
    local ssh_conex ssh_status
    ssh_conex=$(ss -tnp 2>/dev/null | grep ':22' | grep -c ESTAB || echo 0)
    if systemctl is-active --quiet ssh; then
        ssh_status="${GREEN}● Activo${NC} (${ssh_conex} conexiones)"
    else
        ssh_status="${RED}● Inactivo${NC}"
    fi
    echo -e "  ${CYAN}║${NC}  ${WHITE}SSH        :${NC} $ssh_status"

    # WebSocket
    local ws_puertos ws_activos
    ws_puertos=$(cat /etc/vpnpro/websocket.conf 2>/dev/null | tr '\n' ',' | sed 's/,$//')
    ws_activos=$(pgrep -c -f ws_server.py 2>/dev/null || echo 0)
    echo -e "  ${CYAN}║${NC}  ${WHITE}WebSocket  :${NC} ${GREEN}$ws_activos proceso(s)${NC} en puertos: ${CYAN}${ws_puertos:-N/A}${NC}"

    # SlowDNS
    local sdns_pid
    sdns_pid=$(pgrep -f dns2tcpd 2>/dev/null)
    if [[ -n "$sdns_pid" ]]; then
        echo -e "  ${CYAN}║${NC}  ${WHITE}SlowDNS    :${NC} ${GREEN}● Activo${NC} (PID: $sdns_pid)"
    else
        echo -e "  ${CYAN}║${NC}  ${WHITE}SlowDNS    :${NC} ${RED}● Inactivo${NC}"
    fi

    echo -e "  ${CYAN}╠══════ USUARIOS SSH ══════════════════════════════╣${NC}"
    local total_users
    total_users=$(wc -l < /etc/vpnpro/ssh_users.conf 2>/dev/null || echo 0)
    echo -e "  ${CYAN}║${NC}  ${WHITE}Usuarios   :${NC} ${GREEN}$total_users registrados${NC}"
    echo -e "  ${CYAN}║${NC}  ${WHITE}Conectados :${NC} ${GREEN}$ssh_conex activos${NC}"
    echo -e "  ${CYAN}╚══════════════════════════════════════════════════╝${NC}"
    presionar_enter
}
