#!/bin/bash
# ── Utilidades generales ─────────────────────────────────────

# Verifica si un paquete está instalado
pkg_instalado() {
    dpkg -l "$1" &>/dev/null && return 0 || return 1
}

# Instala paquete si no está
instalar_pkg() {
    if ! pkg_instalado "$1"; then
        msg_wait "Instalando $1..."
        apt-get install -y "$1" &>/dev/null && msg_ok "$1 instalado." || msg_err "Error instalando $1."
    fi
}

# Verifica si un servicio está activo
servicio_activo() {
    systemctl is-active --quiet "$1"
}

# Estado visual de servicio
estado_servicio() {
    local nombre="$1"
    local servicio="$2"
    if servicio_activo "$servicio"; then
        echo -e "  ${WHITE}$nombre:${NC} ${GREEN}● Activo${NC}"
    else
        echo -e "  ${WHITE}$nombre:${NC} ${RED}● Inactivo${NC}"
    fi
}

# Genera contraseña aleatoria
gen_password() {
    tr -dc 'A-Za-z0-9@#$%' </dev/urandom | head -c "${1:-12}"
}

# Verifica conectividad
check_internet() {
    ping -c1 -W2 8.8.8.8 &>/dev/null && return 0 || return 1
}
