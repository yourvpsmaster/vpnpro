#!/bin/bash
# ── Módulo: Gestión de Usuarios SSH ─────────────────────────

CONFIG_SSH="/etc/vpnpro/ssh_users.conf"
mkdir -p /etc/vpnpro

menu_ssh() {
    while true; do
        banner_seccion "GESTIÓN DE USUARIOS SSH" "👤"
        echo -e "${CYAN}╔══════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[1]${NC}  ➕  Crear usuario SSH                          ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[2]${NC}  ❌  Eliminar usuario SSH                       ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[3]${NC}  🔄  Renovar expiración de usuario              ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[4]${NC}  🔒  Bloquear / Desbloquear usuario             ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[5]${NC}  📋  Listar todos los usuarios SSH              ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[6]${NC}  👁️   Ver usuarios conectados ahora              ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[7]${NC}  🔑  Cambiar contraseña de usuario              ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${YELLOW}[8]${NC}  📊  Límite de conexiones por usuario           ${CYAN}║${NC}"
        echo -e "${CYAN}║${NC}  ${RED}[0]${NC}  🔙  Volver al menú principal                  ${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════╝${NC}"
        echo -ne "\n  ${WHITE}Selecciona una opción ${YELLOW}[0-8]${WHITE}: ${NC}"
        read -r op

        case $op in
            1) crear_usuario_ssh ;;
            2) eliminar_usuario_ssh ;;
            3) renovar_usuario_ssh ;;
            4) toggle_usuario_ssh ;;
            5) listar_usuarios_ssh ;;
            6) usuarios_conectados ;;
            7) cambiar_password_ssh ;;
            8) limite_conexiones ;;
            0) break ;;
            *) msg_err "Opción inválida."; sleep 1 ;;
        esac
    done
}

# ── Crear usuario ────────────────────────────────────────────
crear_usuario_ssh() {
    banner_seccion "CREAR USUARIO SSH" "➕"
    echo -ne "  ${WHITE}Nombre de usuario: ${NC}"; read -r usuario
    if [[ -z "$usuario" ]]; then msg_err "Nombre vacío."; presionar_enter; return; fi
    if id "$usuario" &>/dev/null; then msg_err "El usuario ya existe."; presionar_enter; return; fi

    echo -ne "  ${WHITE}Contraseña (dejar vacío = auto): ${NC}"; read -r password
    [[ -z "$password" ]] && password=$(gen_password 12)

    echo -ne "  ${WHITE}Días de expiración [30]: ${NC}"; read -r dias
    [[ -z "$dias" ]] && dias=30

    echo -ne "  ${WHITE}Límite de conexiones simultáneas [2]: ${NC}"; read -r limite
    [[ -z "$limite" ]] && limite=2

    local exp_date
    exp_date=$(date -d "+${dias} days" +%Y-%m-%d)

    # Crear usuario sin directorio home real, solo para SSH tunnel
    useradd -M -s /bin/false -e "$exp_date" "$usuario" &>/dev/null
    echo "$usuario:$password" | chpasswd

    # Guardar en config
    echo "$usuario:$password:$exp_date:$limite:activo" >> "$CONFIG_SSH"

    separador
    echo -e "  ${GREEN}[✓] Usuario creado exitosamente${NC}\n"
    echo -e "  ${WHITE}Usuario   : ${GREEN}$usuario${NC}"
    echo -e "  ${WHITE}Contraseña: ${GREEN}$password${NC}"
    echo -e "  ${WHITE}Expira    : ${YELLOW}$exp_date${NC}"
    echo -e "  ${WHITE}Límite    : ${CYAN}$limite conexiones${NC}"
    separador
    presionar_enter
}

# ── Eliminar usuario ─────────────────────────────────────────
eliminar_usuario_ssh() {
    banner_seccion "ELIMINAR USUARIO SSH" "❌"
    listar_usuarios_ssh_simple
    echo -ne "\n  ${WHITE}Usuario a eliminar: ${NC}"; read -r usuario
    if ! id "$usuario" &>/dev/null; then msg_err "Usuario no encontrado."; presionar_enter; return; fi

    echo -ne "  ${YELLOW}¿Confirmar eliminación de '$usuario'? [s/N]: ${NC}"; read -r conf
    if [[ "$conf" =~ ^[Ss]$ ]]; then
        userdel -f "$usuario" &>/dev/null
        # Matar sesiones activas
        pkill -u "$usuario" &>/dev/null
        # Borrar del config
        sed -i "/^$usuario:/d" "$CONFIG_SSH" 2>/dev/null
        msg_ok "Usuario '$usuario' eliminado y sesiones cerradas."
    else
        msg_warn "Operación cancelada."
    fi
    presionar_enter
}

# ── Renovar expiración ───────────────────────────────────────
renovar_usuario_ssh() {
    banner_seccion "RENOVAR USUARIO SSH" "🔄"
    listar_usuarios_ssh_simple
    echo -ne "\n  ${WHITE}Usuario a renovar: ${NC}"; read -r usuario
    if ! id "$usuario" &>/dev/null; then msg_err "Usuario no encontrado."; presionar_enter; return; fi
    echo -ne "  ${WHITE}Días adicionales [30]: ${NC}"; read -r dias
    [[ -z "$dias" ]] && dias=30
    local exp_date
    exp_date=$(date -d "+${dias} days" +%Y-%m-%d)
    chage -E "$exp_date" "$usuario"
    # Actualizar config
    sed -i "s/^$usuario:\([^:]*\):[^:]*:\([^:]*\):\([^:]*\)/$usuario:\1:$exp_date:\2:\3/" "$CONFIG_SSH" 2>/dev/null
    msg_ok "Usuario '$usuario' renovado hasta $exp_date."
    presionar_enter
}

# ── Bloquear / Desbloquear ───────────────────────────────────
toggle_usuario_ssh() {
    banner_seccion "BLOQUEAR / DESBLOQUEAR USUARIO" "🔒"
    listar_usuarios_ssh_simple
    echo -ne "\n  ${WHITE}Usuario: ${NC}"; read -r usuario
    if ! id "$usuario" &>/dev/null; then msg_err "Usuario no encontrado."; presionar_enter; return; fi
    local estado
    estado=$(passwd -S "$usuario" | awk '{print $2}')
    if [[ "$estado" == "L" ]]; then
        passwd -u "$usuario" &>/dev/null
        msg_ok "Usuario '$usuario' DESBLOQUEADO."
    else
        passwd -l "$usuario" &>/dev/null
        pkill -u "$usuario" &>/dev/null
        msg_ok "Usuario '$usuario' BLOQUEADO y sesiones cerradas."
    fi
    presionar_enter
}

# ── Listar usuarios ──────────────────────────────────────────
listar_usuarios_ssh() {
    banner_seccion "LISTA DE USUARIOS SSH" "📋"
    echo -e "  ${BOLD}${CYAN}Usuario          Expira        Estado      Conexiones${NC}"
    separador

    if [[ ! -f "$CONFIG_SSH" ]]; then
        msg_warn "No hay usuarios registrados."
        presionar_enter
        return
    fi

    while IFS=: read -r user pass exp limite estado; do
        local st_color="${GREEN}"
        [[ "$estado" == "bloqueado" ]] && st_color="${RED}"
        local conex
        conex=$(who | grep -c "^$user " 2>/dev/null || echo 0)
        printf "  ${WHITE}%-16s${NC} ${YELLOW}%-13s${NC} ${st_color}%-11s${NC} ${CYAN}%s/%s${NC}\n" \
            "$user" "$exp" "$estado" "$conex" "$limite"
    done < "$CONFIG_SSH"
    separador
    presionar_enter
}

listar_usuarios_ssh_simple() {
    if [[ -f "$CONFIG_SSH" ]]; then
        echo -e "\n  ${CYAN}Usuarios registrados:${NC}"
        awk -F: '{print "  • "$1" (exp: "$3")"}' "$CONFIG_SSH"
    fi
}

# ── Usuarios conectados ──────────────────────────────────────
usuarios_conectados() {
    banner_seccion "USUARIOS SSH CONECTADOS" "👁️"
    local total
    total=$(ss -tnp | grep ':22' | grep -c ESTAB 2>/dev/null || echo 0)
    echo -e "  ${WHITE}Conexiones SSH activas: ${GREEN}${total}${NC}\n"
    echo -e "  ${BOLD}${CYAN}Usuario          IP Remota           Tiempo${NC}"
    separador
    who | awk '{printf "  \033[1;37m%-16s\033[0m \033[1;33m%-20s\033[0m \033[0;36m%s %s\033[0m\n", $1, $5, $3, $4}'
    separador
    echo -e "\n  ${CYAN}Detalle de conexiones por socket:${NC}"
    ss -tnp | grep ':22' | grep ESTAB | awk '{print "  "$4" → "$5}' | head -20
    presionar_enter
}

# ── Cambiar contraseña ───────────────────────────────────────
cambiar_password_ssh() {
    banner_seccion "CAMBIAR CONTRASEÑA" "🔑"
    listar_usuarios_ssh_simple
    echo -ne "\n  ${WHITE}Usuario: ${NC}"; read -r usuario
    if ! id "$usuario" &>/dev/null; then msg_err "Usuario no encontrado."; presionar_enter; return; fi
    echo -ne "  ${WHITE}Nueva contraseña (vacío = auto): ${NC}"; read -r password
    [[ -z "$password" ]] && password=$(gen_password 12)
    echo "$usuario:$password" | chpasswd
    sed -i "s/^$usuario:[^:]*:/$usuario:$password:/" "$CONFIG_SSH" 2>/dev/null
    msg_ok "Contraseña actualizada: ${GREEN}$password${NC}"
    presionar_enter
}

# ── Límite de conexiones ─────────────────────────────────────
limite_conexiones() {
    banner_seccion "LÍMITE DE CONEXIONES" "📊"
    listar_usuarios_ssh_simple
    echo -ne "\n  ${WHITE}Usuario: ${NC}"; read -r usuario
    echo -ne "  ${WHITE}Nuevo límite de conexiones: ${NC}"; read -r limite
    sed -i "s/^$usuario:\([^:]*\):\([^:]*\):[^:]*:/$usuario:\1:\2:$limite:/" "$CONFIG_SSH" 2>/dev/null
    msg_ok "Límite actualizado a $limite para '$usuario'."
    presionar_enter
}
