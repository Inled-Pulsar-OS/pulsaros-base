#!/bin/bash
set -e

# Asegurar que el directorio build existe
mkdir -p build

if [ "$1" == "--clean" ]; then
    echo "🧹 Limpiando directorio build..."
    pkexec rm -rf build/*
fi

echo "🚀 Iniciando construcción de PulsarOS..."

# Limpieza preventiva de montajes residuales
bash scripts/cleanup.sh

# 1. Bootstrap
bash scripts/01-bootstrap.sh

# 2. Customización
bash scripts/02-customize.sh

# 3. Temas y Extensiones GNOME
bash scripts/03-theme-gnome.sh

# 4. Tema de GRUB
bash scripts/04-grub-theme.sh

# 5. Calamares y Auto-instalador
bash scripts/05-calamares.sh

# 6. Plymouth Theme
bash scripts/06-plymouth.sh

echo "✅ Proceso finalizado."
echo "Para probar la distro, ejecuta: ./scripts/run-qemu.sh"
