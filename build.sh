#!/bin/bash
set -e

# Archivo para trackear el progreso
STATE_FILE="build/.build_state"
mkdir -p build

CONTINUE_MODE=false
if [ "$1" == "--continue" ]; then
    CONTINUE_MODE=true
    echo "⏭️ Modo continuación activado. Saltando scripts completados..."
elif [ "$1" == "--clean" ]; then
    echo "🧹 Limpiando directorio build y estado..."
    bash scripts/cleanup.sh
    pkexec rm -rf build/*
    rm -f "$STATE_FILE"
fi

# Función para ejecutar scripts y trackear éxito
run_script() {
    local script_path=$1
    local script_name=$(basename "$script_path")

    if $CONTINUE_MODE && grep -q "^$script_name$" "$STATE_FILE" 2>/dev/null; then
        echo "✅ Saltando $script_name (ya completado)"
        return 0
    fi

    echo "▶️ Ejecutando $script_name..."
    bash "$script_path"
    
    # Si tiene éxito, lo anotamos en el archivo de estado
    echo "$script_name" >> "$STATE_FILE"
}

echo "🚀 Iniciando construcción de PulsarOS..."

# Limpieza preventiva de montajes residuales (siempre se ejecuta por seguridad)
if [ "$1" != "--clean" ]; then
    bash scripts/cleanup.sh
fi

# Lista de scripts de construcción en orden
run_script "scripts/01-bootstrap.sh"
run_script "scripts/02-customize.sh"
run_script "scripts/03-theme-gnome.sh"
run_script "scripts/04-grub-theme.sh"
run_script "scripts/05-calamares.sh"
run_script "scripts/06-plymouth.sh"
run_script "scripts/07-branding.sh"

echo "✅ Proceso finalizado."
# Limpiar el archivo de estado al finalizar con éxito total
rm -f "$STATE_FILE"

echo "Para probar la distro, ejecuta: ./scripts/run-qemu.sh"
