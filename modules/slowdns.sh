#!/bin/bash
# ── Módulo: SlowDNS ──────────────────────────────────────────
# SlowDNS tuneliza tráfico TCP sobre consultas DNS (TXT/CNAME records)
# Requiere: slowdns (iodine o dns2tcp como alternativa robusta)

SDNS_CONF="/etc/vpnpro/slowdns.conf"
mkdir -p /etc/vpnpro

menu_slowdns() {
    while true; do
        banner_seccion "GESTIÓN DE SLOWDNS" "🐢"

        # Estado actual
        local sdns_pid
        sdns_pid=$(pgrep -f "dns2tcpd\|iodined\|slowdns" 2>/dev/null | head -1)
        if [[ -n "$sdns_pid" ]]; then
            echo -e "  Estado: ${GREEN}● SlowDNS Activo${NC} (PID: $sdns_pid)"
        else
            echo -e "  Estado: ${RED}● SlowDNS Inactivo${NC}"
        fi
        separador

        echo -e "\n${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[1]${NC}  🔧  Instalar SlowDNS (dns2tcp)                 ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[2]${NC}  ⚙️   Configurar SlowDNS                         ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[3]${NC}  ▶️   Iniciar SlowDNS                            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[4]${NC}  ⏹️   Detener SlowDNS                            ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[5]${NC}  🔄  Reiniciar SlowDNS                          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[6]${NC}  📜  Ver logs SlowDNS                           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[7]${NC}  ℹ️   Ver configuración actual                   ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[8]${NC}  🔑  Generar claves DNS                         ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${RED}[0]${NC}  🔙  Volver                                     ${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
        echo -ne "\n  ${WHITE}Selecciona una opción ${YELLOW}[0-8]${WHITE}: ${NC}"
        read -r op

        case $op in
            1) sdns_instalar ;;
            2) sdns_configurar ;;
            3) sdns_iniciar ;;
            4) sdns_detener ;;
            5) sdns_detener; sleep 1; sdns_iniciar ;;
            6) sdns_logs ;;
            7) sdns_ver_config ;;
            8) sdns_generar_claves ;;
            0) break ;;
            *) msg_err "Opción inválida."; sleep 1 ;;
        esac
    done
}

# ── Instalar dns2tcp ─────────────────────────────────────────
sdns_instalar() {
    banner_seccion "INSTALAR SLOWDNS (dns2tcp)" "🔧"
    msg_info "dns2tcp es una implementación robusta de DNS tunneling"
    msg_info "Permite tunelizar SSH sobre consultas DNS\n"

    if command -v dns2tcpd &>/dev/null; then
        msg_ok "dns2tcp ya está instalado."
        presionar_enter; return
    fi

    msg_wait "Actualizando repositorios..."
    apt-get update -qq &>/dev/null
    echo ""

    msg_wait "Instalando dns2tcp..."
    if apt-get install -y dns2tcp &>/dev/null; then
        msg_ok "dns2tcp instalado correctamente."
    else
        msg_err "Error instalando dns2tcp. Intentando desde fuente..."
        # Alternativa: compilar desde fuente
        if check_internet; then
            apt-get install -y git make gcc &>/dev/null
            cd /tmp && git clone https://github.com/alex-sector/dns2tcp.git &>/dev/null
            cd dns2tcp && ./configure &>/dev/null && make &>/dev/null && make install &>/dev/null
            if command -v dns2tcpd &>/dev/null; then
                msg_ok "dns2tcp compilado e instalado."
            else
                msg_err "No se pudo instalar. Verifica conexión a internet."
            fi
        fi
    fi
    presionar_enter
}

# ── Configurar dns2tcp ───────────────────────────────────────
sdns_configurar() {
    banner_seccion "CONFIGURAR SLOWDNS" "⚙️"

    echo -ne "  ${WHITE}Dominio DNS para túnel (ej: dns.tudominio.com): ${NC}"
    read -r dominio
    [[ -z "$dominio" ]] && dominio="tunnel.vpnpro.local"

    echo -ne "  ${WHITE}IP del servidor [$(hostname -I | awk '{print $1}')]: ${NC}"
    read -r server_ip
    [[ -z "$server_ip" ]] && server_ip=$(hostname -I | awk '{print $1}')

    echo -ne "  ${WHITE}Puerto DNS para escuchar [53]: ${NC}"
    read -r dns_port
    [[ -z "$dns_port" ]] && dns_port=53

    echo -ne "  ${WHITE}Puerto SSH destino [22]: ${NC}"
    read -r ssh_port
    [[ -z "$ssh_port" ]] && ssh_port=22

    # Crear configuración dns2tcpd
    cat > /etc/dns2tcpd.conf << EOF
# VPN PRO - dns2tcpd Configuration
listen    = 0.0.0.0
port      = ${dns_port}
user      = nobody
chroot    = /tmp
domain    = ${dominio}
resources = ssh:127.0.0.1:${ssh_port}
# key     = tu_clave_secreta
EOF

    # Guardar en config vpnpro
    cat > "$SDNS_CONF" << EOF
DOMINIO=$dominio
SERVER_IP=$server_ip
DNS_PORT=$dns_port
SSH_PORT=$ssh_port
EOF

    msg_ok "Configuración guardada en /etc/dns2tcpd.conf"
    separador
    echo -e "\n  ${CYAN}📋 Instrucciones para el CLIENTE:${NC}"
    echo -e "  ${WHITE}1. Instalar dns2tcp en el cliente${NC}"
    echo -e "  ${WHITE}2. Ejecutar:${NC}"
    echo -e "  ${GREEN}   dns2tcpc -r ssh -z $dominio -d 53 -l 2222 $server_ip${NC}"
    echo -e "  ${WHITE}3. Conectar SSH:${NC}"
    echo -e "  ${GREEN}   ssh usuario@127.0.0.1 -p 2222${NC}"
    separador
    presionar_enter
}

# ── Iniciar SlowDNS ──────────────────────────────────────────
sdns_iniciar() {
    banner_seccion "INICIANDO SLOWDNS" "▶️"

    if ! command -v dns2tcpd &>/dev/null; then
        msg_err "dns2tcp no está instalado. Usa opción 1 para instalar."
        presionar_enter; return
    fi

    if [[ ! -f /etc/dns2tcpd.conf ]]; then
        msg_err "No hay configuración. Usa opción 2 para configurar."
        presionar_enter; return
    fi

    # Detener si ya está corriendo
    pkill -f dns2tcpd &>/dev/null
    sleep 0.5

    # Iniciar
    dns2tcpd -F -f /etc/dns2tcpd.conf >> /var/log/vpnpro/slowdns.log 2>&1 &
    sleep 1

    local pid
    pid=$(pgrep -f dns2tcpd)
    if [[ -n "$pid" ]]; then
        msg_ok "SlowDNS iniciado (PID: $pid)"

        # Abrir puerto DNS en firewall
        if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
            local dns_port
            dns_port=$(grep DNS_PORT "$SDNS_CONF" 2>/dev/null | cut -d= -f2)
            ufw allow "${dns_port:-53}/udp" &>/dev/null
            msg_info "Puerto UDP ${dns_port:-53} abierto en firewall."
        fi
    else
        msg_err "Error iniciando SlowDNS. Revisa los logs."
    fi
    presionar_enter
}

sdns_detener() {
    pkill -f dns2tcpd &>/dev/null
    msg_ok "SlowDNS detenido."
    [[ "${1}" != "silent" ]] && presionar_enter
}

sdns_logs() {
    banner_seccion "LOGS SLOWDNS" "📜"
    local logfile="/var/log/vpnpro/slowdns.log"
    if [[ -f "$logfile" ]]; then
        echo -e "  ${CYAN}Últimas 30 líneas:${NC}\n"
        tail -30 "$logfile"
    else
        msg_warn "No hay logs disponibles aún."
    fi
    presionar_enter
}

sdns_ver_config() {
    banner_seccion "CONFIGURACIÓN ACTUAL SLOWDNS" "ℹ️"
    if [[ -f /etc/dns2tcpd.conf ]]; then
        echo -e "  ${CYAN}Archivo /etc/dns2tcpd.conf:${NC}\n"
        cat /etc/dns2tcpd.conf | while IFS= read -r linea; do
            echo -e "  ${WHITE}$linea${NC}"
        done
    else
        msg_warn "No hay configuración. Usa opción 2."
    fi
    presionar_enter
}

sdns_generar_claves() {
    banner_seccion "GENERAR CLAVE DNS" "🔑"
    local clave
    clave=$(tr -dc 'A-Za-z0-9' </dev/urandom | head -c 32)
    echo -e "\n  ${WHITE}Clave generada: ${GREEN}$clave${NC}\n"
    echo -e "  ${CYAN}Agrega esta línea a /etc/dns2tcpd.conf:${NC}"
    echo -e "  ${YELLOW}key = $clave${NC}\n"
    echo -e "  ${CYAN}Y en el cliente usa:${NC}"
    echo -e "  ${YELLOW}dns2tcpc -k $clave ...${NC}"
    presionar_enter
}
