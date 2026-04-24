#!/bin/bash
# ── Módulo: Gestión de WebSocket ─────────────────────────────

WS_CONF="/etc/vpnpro/websocket.conf"
WS_SCRIPT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ws_server.py"
mkdir -p /etc/vpnpro

# Puertos por defecto
[[ ! -f "$WS_CONF" ]] && echo "80" > "$WS_CONF"

menu_websocket() {
    while true; do
        banner_seccion "GESTIÓN DE WEBSOCKET" "🌐"

        # Estado de servicios activos
        echo -e "  ${BOLD}Estado actual de WebSocket:${NC}"
        separador
        while IFS= read -r puerto; do
            local pid
            pid=$(pgrep -f "ws_server.py $puerto" 2>/dev/null)
            if [[ -n "$pid" ]]; then
                echo -e "  Puerto ${GREEN}$puerto${NC}: ${GREEN}● Activo${NC} (PID: $pid)"
            else
                echo -e "  Puerto ${YELLOW}$puerto${NC}: ${RED}● Inactivo${NC}"
            fi
        done < "$WS_CONF"
        separador

        echo -e "\n${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[1]${NC}  ▶️   Iniciar WebSocket (todos los puertos)       ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[2]${NC}  ⏹️   Detener WebSocket (todos los puertos)       ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[3]${NC}  🔄  Reiniciar WebSocket                         ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[4]${NC}  ➕  Agregar nuevo puerto                        ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[5]${NC}  ➖  Eliminar un puerto                          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[6]${NC}  📋  Ver puertos configurados                    ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[7]${NC}  📜  Ver logs del WebSocket                      ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[8]${NC}  🔍  Test de conexión WebSocket                  ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${RED}[0]${NC}  🔙  Volver                                     ${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
        echo -ne "\n  ${WHITE}Selecciona una opción ${YELLOW}[0-8]${WHITE}: ${NC}"
        read -r op

        case $op in
            1) ws_iniciar_todos ;;
            2) ws_detener_todos ;;
            3) ws_detener_todos; sleep 1; ws_iniciar_todos ;;
            4) ws_agregar_puerto ;;
            5) ws_eliminar_puerto ;;
            6) ws_listar_puertos ;;
            7) ws_ver_logs ;;
            8) ws_test ;;
            0) break ;;
            *) msg_err "Opción inválida."; sleep 1 ;;
        esac
    done
}

ws_iniciar_todos() {
    banner_seccion "INICIANDO WEBSOCKET" "▶️"
    # Verificar python3
    if ! command -v python3 &>/dev/null; then
        msg_warn "Instalando Python3..."
        apt-get install -y python3 &>/dev/null
    fi

    while IFS= read -r puerto; do
        local pid
        pid=$(pgrep -f "ws_server.py $puerto" 2>/dev/null)
        if [[ -n "$pid" ]]; then
            msg_warn "Puerto $puerto ya está activo (PID: $pid)"
        else
            nohup python3 "$WS_SCRIPT" "$puerto" >> "/var/log/vpnpro/ws_${puerto}.log" 2>&1 &
            sleep 0.5
            pid=$(pgrep -f "ws_server.py $puerto" 2>/dev/null)
            if [[ -n "$pid" ]]; then
                msg_ok "WebSocket iniciado en puerto ${GREEN}$puerto${NC} (PID: $pid)"
            else
                msg_err "Error iniciando WebSocket en puerto $puerto"
            fi
        fi
    done < "$WS_CONF"
    presionar_enter
}

ws_detener_todos() {
    banner_seccion "DETENIENDO WEBSOCKET" "⏹️"
    while IFS= read -r puerto; do
        pkill -f "ws_server.py $puerto" 2>/dev/null && \
            msg_ok "Puerto $puerto detenido." || \
            msg_warn "Puerto $puerto no estaba activo."
    done < "$WS_CONF"
    presionar_enter
}

ws_agregar_puerto() {
    banner_seccion "AGREGAR PUERTO WEBSOCKET" "➕"
    echo -e "  ${CYAN}Puertos actuales:${NC} $(tr '\n' ' ' < "$WS_CONF")\n"
    echo -ne "  ${WHITE}Nuevo puerto (1-65535): ${NC}"; read -r puerto

    # Validar
    if ! [[ "$puerto" =~ ^[0-9]+$ ]] || [[ "$puerto" -lt 1 ]] || [[ "$puerto" -gt 65535 ]]; then
        msg_err "Puerto inválido."; presionar_enter; return
    fi

    if grep -q "^${puerto}$" "$WS_CONF" 2>/dev/null; then
        msg_warn "El puerto $puerto ya está configurado."; presionar_enter; return
    fi

    echo "$puerto" >> "$WS_CONF"
    # Abrir en firewall si ufw está activo
    if command -v ufw &>/dev/null && ufw status | grep -q "Status: active"; then
        ufw allow "$puerto/tcp" &>/dev/null
        msg_info "Puerto $puerto abierto en UFW."
    fi

    # Iniciar inmediatamente
    nohup python3 "$WS_SCRIPT" "$puerto" >> "/var/log/vpnpro/ws_${puerto}.log" 2>&1 &
    sleep 0.5
    local pid
    pid=$(pgrep -f "ws_server.py $puerto")
    msg_ok "Puerto $puerto agregado e iniciado (PID: $pid)."
    presionar_enter
}

ws_eliminar_puerto() {
    banner_seccion "ELIMINAR PUERTO WEBSOCKET" "➖"
    echo -e "  ${CYAN}Puertos configurados:${NC}"
    cat -n "$WS_CONF"
    echo -ne "\n  ${WHITE}Puerto a eliminar: ${NC}"; read -r puerto

    if [[ "$puerto" == "80" ]]; then
        msg_warn "El puerto 80 es el puerto principal. ¿Seguro? [s/N]: "
        read -r conf
        [[ ! "$conf" =~ ^[Ss]$ ]] && presionar_enter && return
    fi

    pkill -f "ws_server.py $puerto" 2>/dev/null
    sed -i "/^${puerto}$/d" "$WS_CONF"
    msg_ok "Puerto $puerto eliminado."
    presionar_enter
}

ws_listar_puertos() {
    banner_seccion "PUERTOS WEBSOCKET CONFIGURADOS" "📋"
    echo -e "  ${BOLD}${CYAN}Puerto    Estado         PID        Log${NC}"
    separador
    while IFS= read -r puerto; do
        local pid
        pid=$(pgrep -f "ws_server.py $puerto" 2>/dev/null)
        local log_size="N/A"
        [[ -f "/var/log/vpnpro/ws_${puerto}.log" ]] && log_size=$(du -sh "/var/log/vpnpro/ws_${puerto}.log" 2>/dev/null | cut -f1)
        if [[ -n "$pid" ]]; then
            printf "  ${GREEN}%-9s${NC} ${GREEN}%-14s${NC} %-10s ${DIM}%s${NC}\n" "$puerto" "● Activo" "$pid" "$log_size"
        else
            printf "  ${YELLOW}%-9s${NC} ${RED}%-14s${NC} %-10s ${DIM}%s${NC}\n" "$puerto" "● Inactivo" "-" "$log_size"
        fi
    done < "$WS_CONF"
    separador
    presionar_enter
}

ws_ver_logs() {
    banner_seccion "LOGS WEBSOCKET" "📜"
    echo -e "  ${CYAN}Puertos disponibles:${NC} $(tr '\n' ' ' < "$WS_CONF")"
    echo -ne "  ${WHITE}Puerto a ver [80]: ${NC}"; read -r puerto
    [[ -z "$puerto" ]] && puerto=80
    local logfile="/var/log/vpnpro/ws_${puerto}.log"
    if [[ -f "$logfile" ]]; then
        echo -e "\n  ${CYAN}Últimas 30 líneas de ws_${puerto}.log:${NC}\n"
        tail -30 "$logfile"
    else
        msg_warn "No hay log para el puerto $puerto."
    fi
    presionar_enter
}

ws_test() {
    banner_seccion "TEST DE CONEXIÓN WEBSOCKET" "🔍"
    echo -ne "  ${WHITE}Puerto a probar [80]: ${NC}"; read -r puerto
    [[ -z "$puerto" ]] && puerto=80
    local ip
    ip=$(hostname -I | awk '{print $1}')
    echo -e "\n  ${CYAN}Probando WebSocket en $ip:$puerto...${NC}\n"
    # Test con curl
    if command -v curl &>/dev/null; then
        local respuesta
        respuesta=$(curl -s -o /dev/null -w "%{http_code}" \
            -H "Upgrade: websocket" \
            -H "Connection: Upgrade" \
            -H "Sec-WebSocket-Key: VpnProTest==" \
            -H "Sec-WebSocket-Version: 13" \
            --max-time 5 \
            "http://$ip:$puerto/" 2>/dev/null)
        if [[ "$respuesta" == "101" ]]; then
            msg_ok "Respuesta: ${GREEN}HTTP/1.1 101 Switching Protocols ✓${NC}"
        else
            msg_warn "Código de respuesta: $respuesta (verifica que el servicio esté activo)"
        fi
    else
        # Test manual con nc
        echo -e "GET / HTTP/1.1\r\nUpgrade: websocket\r\nConnection: Upgrade\r\n\r\n" | \
            nc -w 3 "$ip" "$puerto" 2>/dev/null | head -5
    fi
    presionar_enter
}

# ── Auto-arranque al instalar ─────────────────────────────────
ws_crear_servicio_systemd() {
    local ws_script="$1"
    cat > /etc/systemd/system/vpnpro-ws.service << EOF
[Unit]
Description=VPN PRO WebSocket Proxy
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash -c 'while IFS= read -r p; do python3 ${ws_script} \$p & done < /etc/vpnpro/websocket.conf; wait'
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    systemctl daemon-reload
    systemctl enable vpnpro-ws.service &>/dev/null
    msg_ok "Servicio systemd creado y habilitado."
}
