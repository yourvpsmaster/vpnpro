#!/bin/bash
# ── Módulo: Monitoreo del Sistema ────────────────────────────

menu_monitor() {
    while true; do
        banner_seccion "MONITOREO DEL SISTEMA" "📊"
        echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[1]${NC}  👁️   Usuarios SSH conectados en tiempo real     ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[2]${NC}  📈  Uso de CPU, RAM y Disco                    ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[3]${NC}  🌐  Conexiones de red activas                  ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[4]${NC}  📊  Monitor en vivo (actualiza cada 3s)        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[5]${NC}  📜  Últimas conexiones SSH (auth.log)          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[6]${NC}  ⚡  Procesos más activos                       ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${RED}[0]${NC}  🔙  Volver                                     ${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
        echo -ne "\n  ${WHITE}Selecciona una opción ${YELLOW}[0-6]${WHITE}: ${NC}"
        read -r op

        case $op in
            1) mon_usuarios_ssh ;;
            2) mon_recursos ;;
            3) mon_conexiones_red ;;
            4) mon_vivo ;;
            5) mon_auth_log ;;
            6) mon_procesos ;;
            0) break ;;
            *) msg_err "Opción inválida."; sleep 1 ;;
        esac
    done
}

mon_usuarios_ssh() {
    banner_seccion "USUARIOS SSH CONECTADOS" "👁️"
    local total
    total=$(ss -tnp 2>/dev/null | grep ':22' | grep -c ESTAB || echo 0)
    echo -e "  ${WHITE}Total conexiones SSH activas: ${GREEN}${total}${NC}\n"
    echo -e "  ${BOLD}${CYAN}Usuario          IP Origen            Desde${NC}"
    separador
    who 2>/dev/null | while IFS= read -r linea; do
        local user ip hora
        user=$(echo "$linea" | awk '{print $1}')
        ip=$(echo "$linea" | awk '{print $5}' | tr -d '()')
        hora=$(echo "$linea" | awk '{print $3, $4}')
        printf "  ${GREEN}%-16s${NC} ${YELLOW}%-20s${NC} ${CYAN}%s${NC}\n" "$user" "${ip:-local}" "$hora"
    done
    separador
    echo -e "\n  ${CYAN}Conexiones TCP en puerto 22:${NC}"
    ss -tnp 2>/dev/null | grep ':22' | grep ESTAB | \
        awk '{printf "  %s  →  %s\n", $4, $5}' | head -20
    presionar_enter
}

mon_recursos() {
    banner_seccion "USO DE RECURSOS" "📈"

    # CPU
    local cpu_uso
    cpu_uso=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "N/A")

    # RAM
    local ram_total ram_usado ram_libre ram_pct
    ram_total=$(free -m | awk '/^Mem:/{print $2}')
    ram_usado=$(free -m | awk '/^Mem:/{print $3}')
    ram_libre=$(free -m | awk '/^Mem:/{print $4}')
    ram_pct=$(awk "BEGIN {printf \"%.1f\", ($ram_usado/$ram_total)*100}")

    # Disco
    local disk_info
    disk_info=$(df -h / | awk 'NR==2 {print $3"/"$2" ("$5")"}')

    # Load average
    local load
    load=$(uptime | awk -F'load average:' '{print $2}' | xargs)

    echo -e "\n  ${BOLD}${WHITE}PROCESADOR${NC}"
    separador
    echo -e "  ${WHITE}Uso CPU   : ${GREEN}${cpu_uso}%${NC}"
    echo -e "  ${WHITE}Load Avg  : ${CYAN}${load}${NC}"

    echo -e "\n  ${BOLD}${WHITE}MEMORIA RAM${NC}"
    separador
    echo -e "  ${WHITE}Total     : ${CYAN}${ram_total} MB${NC}"
    echo -e "  ${WHITE}Usado     : ${YELLOW}${ram_usado} MB (${ram_pct}%)${NC}"
    echo -e "  ${WHITE}Libre     : ${GREEN}${ram_libre} MB${NC}"
    # Barra visual
    local barras=$((ram_pct / 5))
    local barra=""
    for ((i=0; i<20; i++)); do
        [[ $i -lt $barras ]] && barra+="█" || barra+="░"
    done
    echo -e "  [${YELLOW}${barra}${NC}] ${ram_pct}%"

    echo -e "\n  ${BOLD}${WHITE}DISCO${NC}"
    separador
    df -h | grep -v "tmpfs\|udev" | awk 'NR>1 {printf "  \033[1;37m%-20s\033[0m \033[0;32m%-8s\033[0m \033[1;33m%-8s\033[0m \033[0;36m%s\033[0m\n", $6, $3, $2, $5}'

    echo -e "\n  ${BOLD}${WHITE}RED${NC}"
    separador
    ip -s link 2>/dev/null | awk '
        /^[0-9]+:/ {iface=$2; sub(/:/, "", iface)}
        /RX:/ {getline; rx=$1}
        /TX:/ {getline; tx=$1}
        rx && tx {
            printf "  \033[1;37m%-12s\033[0m RX: \033[0;32m%-12s\033[0m TX: \033[0;36m%s\033[0m\n",
            iface, rx" bytes", tx" bytes"
            rx=""; tx=""
        }
    ' | head -10
    presionar_enter
}

mon_conexiones_red() {
    banner_seccion "CONEXIONES DE RED ACTIVAS" "🌐"
    echo -e "  ${BOLD}${CYAN}Resumen de puertos en uso:${NC}\n"
    ss -tlnp 2>/dev/null | awk 'NR>1 {printf "  \033[1;37m%-25s\033[0m \033[0;32m%s\033[0m\n", $4, $6}' | head -20
    separador
    echo -e "\n  ${CYAN}Conexiones ESTABLISHED:${NC}"
    ss -tnp 2>/dev/null | grep ESTAB | awk '{printf "  \033[1;33m%s\033[0m → \033[0;36m%s\033[0m\n", $4, $5}' | head -20
    echo -e "\n  ${WHITE}Total ESTAB: ${GREEN}$(ss -tnp 2>/dev/null | grep -c ESTAB)${NC}"
    presionar_enter
}

mon_vivo() {
    echo -e "\n  ${CYAN}Monitor en vivo activado. Presiona ${RED}Ctrl+C${CYAN} para salir.${NC}\n"
    sleep 1
    while true; do
        clear
        banner_seccion "MONITOR EN VIVO" "📊"
        local ssh_conex cpu_uso ram_pct uptime_s
        ssh_conex=$(ss -tnp 2>/dev/null | grep ':22' | grep -c ESTAB || echo 0)
        cpu_uso=$(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1 2>/dev/null || echo "?")
        ram_pct=$(free | awk '/^Mem:/{printf "%.0f", $3/$2*100}')
        uptime_s=$(uptime -p | sed 's/up //')
        ws_activos=$(pgrep -c -f ws_server.py 2>/dev/null || echo 0)

        echo -e "  ${WHITE}Uptime        : ${CYAN}$uptime_s${NC}"
        echo -e "  ${WHITE}CPU           : ${YELLOW}${cpu_uso}%${NC}"
        echo -e "  ${WHITE}RAM           : ${YELLOW}${ram_pct}%${NC}"
        echo -e "  ${WHITE}SSH Conectados: ${GREEN}$ssh_conex${NC}"
        echo -e "  ${WHITE}WS Procesos   : ${GREEN}$ws_activos${NC}"
        separador
        echo -e "  ${DIM}Actualizando en 3s... (Ctrl+C para salir)${NC}"
        sleep 3
    done
}

mon_auth_log() {
    banner_seccion "HISTORIAL DE ACCESOS SSH" "📜"
    echo -e "  ${CYAN}Últimos 20 accesos exitosos:${NC}\n"
    grep "Accepted" /var/log/auth.log 2>/dev/null | tail -20 | \
        awk '{printf "  \033[0;32m[✓]\033[0m %s %s %s - User: \033[1;37m%s\033[0m IP: \033[1;33m%s\033[0m\n", $1,$2,$3,$9,$11}'
    separador
    echo -e "\n  ${RED}Últimos 10 intentos FALLIDOS:${NC}\n"
    grep "Failed\|Invalid" /var/log/auth.log 2>/dev/null | tail -10 | \
        awk '{printf "  \033[0;31m[✗]\033[0m %s %s %s - \033[1;37m%s\033[0m\n", $1,$2,$3,$0}'
    presionar_enter
}

mon_procesos() {
    banner_seccion "PROCESOS MÁS ACTIVOS" "⚡"
    echo -e "  ${BOLD}${CYAN}PID      CPU%   MEM%   Proceso${NC}"
    separador
    ps aux --sort=-%cpu 2>/dev/null | awk 'NR>1 && NR<=16 {
        printf "  \033[1;33m%-8s\033[0m \033[0;32m%-6s\033[0m \033[0;36m%-6s\033[0m \033[1;37m%s\033[0m\n",
        $2, $3, $4, $11
    }'
    presionar_enter
}
